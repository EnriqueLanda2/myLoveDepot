import sharp from 'sharp';

export type MediaType = 'image' | 'video';

export interface ValidatedMedia {
  safeBuffer: Buffer;
  mediaType: MediaType;
  mimeType: string;
  format: string;
}

export class FileValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'FileValidationError';
  }
}

// Firmas binarias permitidas (Magic Bytes)
const MAGIC_SIGNATURES: {
  mediaType: MediaType;
  format: string;
  mime: string;
  check: (buf: Buffer) => boolean;
}[] = [
  // JPEG: FF D8 FF
  {
    mediaType: 'image',
    format: 'jpeg',
    mime: 'image/jpeg',
    check: (buf) => buf.length >= 3 && buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff,
  },
  // PNG: 89 50 4E 47 0D 0A 1A 0A
  {
    mediaType: 'image',
    format: 'png',
    mime: 'image/png',
    check: (buf) =>
      buf.length >= 8 &&
      buf[0] === 0x89 &&
      buf[1] === 0x50 &&
      buf[2] === 0x4e &&
      buf[3] === 0x47 &&
      buf[4] === 0x0d &&
      buf[5] === 0x0a &&
      buf[6] === 0x1a &&
      buf[7] === 0x0a,
  },
  // WebP: RIFF....WEBP
  {
    mediaType: 'image',
    format: 'webp',
    mime: 'image/webp',
    check: (buf) =>
      buf.length >= 12 &&
      buf.subarray(0, 4).toString('ascii') === 'RIFF' &&
      buf.subarray(8, 12).toString('ascii') === 'WEBP',
  },
  // GIF: GIF87a o GIF89a
  {
    mediaType: 'image',
    format: 'gif',
    mime: 'image/gif',
    check: (buf) =>
      buf.length >= 6 &&
      (buf.subarray(0, 6).toString('ascii') === 'GIF87a' ||
        buf.subarray(0, 6).toString('ascii') === 'GIF89a'),
  },
  // MP4 / M4V / QuickTime: 'ftyp' atom at offset 4
  {
    mediaType: 'video',
    format: 'mp4',
    mime: 'video/mp4',
    check: (buf) => {
      if (buf.length < 16) return false;
      const ftyp = buf.subarray(4, 8).toString('ascii');
      return ftyp === 'ftyp';
    },
  },
  // QuickTime MOV: 'moov' or 'mdat' or 'wide' at offset 4
  {
    mediaType: 'video',
    format: 'mov',
    mime: 'video/quicktime',
    check: (buf) => {
      if (buf.length < 16) return false;
      const box = buf.subarray(4, 8).toString('ascii');
      return box === 'moov' || box === 'mdat' || box === 'wide' || box === 'free';
    },
  },
  // WebM / Matroska: 1A 45 DF A3 (EBML Header)
  {
    mediaType: 'video',
    format: 'webm',
    mime: 'video/webm',
    check: (buf) =>
      buf.length >= 4 &&
      buf[0] === 0x1a &&
      buf[1] === 0x45 &&
      buf[2] === 0xdf &&
      buf[3] === 0xa3,
  },
];

// Patrones de código peligroso, polyglots y webshells
const MALICIOUS_PATTERNS = [
  /<\?php/i,
  /<\?=/i,
  /<%/i,
  /<script[\s>]/i,
  /<\/script>/i,
  /<iframe[\s>]/i,
  /<object[\s>]/i,
  /<embed[\s>]/i,
  /<svg[\s>]/i,
  /eval\s*\(/i,
  /base64_decode\s*\(/i,
  /system\s*\(/i,
  /passthru\s*\(/i,
  /shell_exec\s*\(/i,
  /exec\s*\(/i,
  /popen\s*\(/i,
  /proc_open\s*\(/i,
  /powershell/i,
  /cmd\.exe/i,
  /#!\/bin\//i,
];

/**
 * Escanea el buffer buscando scripts, firmas ejecutables o payloads inyectados.
 */
function inspectForMaliciousContent(buffer: Buffer): void {
  // 1. Detectar cabecera ejecutable PE de Windows (MZ)
  if (buffer.length >= 2 && buffer[0] === 0x4d && buffer[1] === 0x5a) {
    throw new FileValidationError(
      'Archivo rechazado por seguridad: contiene firma de ejecutable DOS/Windows.',
    );
  }

  // 2. Detectar binario ejecutable ELF de Linux (\x7fELF)
  if (
    buffer.length >= 4 &&
    buffer[0] === 0x7f &&
    buffer[1] === 0x45 &&
    buffer[2] === 0x4c &&
    buffer[3] === 0x46
  ) {
    throw new FileValidationError(
      'Archivo rechazado por seguridad: contiene firma de ejecutable Linux ELF.',
    );
  }

  // 3. Detectar binario Mach-O de macOS (0xFEEDFACE, 0xFEEDFACF, 0xCAFEBABE)
  if (buffer.length >= 4) {
    const magic32 = buffer.readUInt32BE(0);
    if (
      magic32 === 0xfeedface ||
      magic32 === 0xfeedfacf ||
      magic32 === 0xcafebabe
    ) {
      throw new FileValidationError(
        'Archivo rechazado por seguridad: contiene firma de binario macOS Mach-O.',
      );
    }
  }

  // 4. Muestreo de texto para detectar código PHP / JS / Web / Shell scripts incrustados
  // Se analizan los primeros 128 KB y los últimos 64 KB (lugares típicos de payloads políglotas)
  const headChunk = buffer.subarray(0, Math.min(buffer.length, 131072)).toString('latin1');
  const tailStart = Math.max(0, buffer.length - 65536);
  const tailChunk = buffer.subarray(tailStart).toString('latin1');

  for (const pattern of MALICIOUS_PATTERNS) {
    if (pattern.test(headChunk) || pattern.test(tailChunk)) {
      throw new FileValidationError(
        'Archivo rechazado por seguridad: el contenido incluye código o scripts ejecutables no permitidos.',
      );
    }
  }
}

/**
 * Valida minuciosamente un archivo multimedia recibido:
 * - Rechaza formatos no permitidos (solo imágenes y videos).
 * - Verifica Magic Bytes reales.
 * - Detecta y rechaza archivos corruptos.
 * - Detecta y rechaza código malicioso/polyglots/ejecutables.
 * - Para imágenes: re-codifica con Sharp a WebP eliminando EXIF/metadatos y payloads parásitos.
 */
export async function validateAndSanitizeMedia(
  input: Buffer,
  originalFilename = '',
): Promise<ValidatedMedia> {
  if (!input || input.length < 16) {
    throw new FileValidationError('El archivo subido está corrupto o vacío.');
  }

  // Límite máximo: 25 MB
  if (input.length > 25 * 1024 * 1024) {
    throw new FileValidationError('El archivo excede el tamaño máximo permitido (25 MB).');
  }

  // 1. Escaneo de código malicioso
  inspectForMaliciousContent(input);

  // 2. Comprobación de Magic Bytes
  const matched = MAGIC_SIGNATURES.find((sig) => sig.check(input));
  if (!matched) {
    throw new FileValidationError(
      'Formato de archivo no válido o corrupto. Solo se permiten imágenes (JPEG, PNG, WebP, GIF) o videos (MP4, WebM, MOV).',
    );
  }

  // 3. Validación de integridad según tipo
  if (matched.mediaType === 'image') {
    try {
      const sharpInstance = sharp(input, { failOn: 'error', limitInputPixels: 30_000_000 });
      const metadata = await sharpInstance.metadata();

      if (!metadata.width || !metadata.height || metadata.width <= 0 || metadata.height <= 0) {
        throw new FileValidationError('La imagen está corrupta o no tiene dimensiones válidas.');
      }

      if (metadata.width < 10 || metadata.height < 10) {
        throw new FileValidationError('La resolución de la imagen es insuficiente.');
      }

      // Re-codificación segura: elimina cualquier metadato EXIF, comentarios o bytes parásitos
      const safeBuffer = await sharp(input, { failOn: 'error', limitInputPixels: 30_000_000 })
        .rotate() // orienta según EXIF antes de limpiarlo
        .resize({ width: 1800, height: 1800, fit: 'inside', withoutEnlargement: true })
        .webp({ quality: 88, effort: 4 })
        .toBuffer();

      return {
        safeBuffer,
        mediaType: 'image',
        mimeType: 'image/webp',
        format: 'webp',
      };
    } catch (err: unknown) {
      if (err instanceof FileValidationError) throw err;
      throw new FileValidationError(
        'El archivo de imagen está corrupto o dañado y no pudo ser decodificado.',
      );
    }
  } else {
    // Video: Verificación de estructura básica de contenedor
    if (matched.format === 'mp4' || matched.format === 'mov') {
      // Un MP4/MOV legítimo debe tener un tamaño mínimo de caja y átomos clave
      const boxSize = input.readUInt32BE(0);
      if (boxSize > input.length && boxSize !== 1 && boxSize !== 0) {
        throw new FileValidationError('El archivo de video MP4/MOV está truncado o corrupto.');
      }
    } else if (matched.format === 'webm') {
      // EBML header mínimo
      if (input.length < 32) {
        throw new FileValidationError('El archivo de video WebM está truncado o incompleto.');
      }
    }

    return {
      safeBuffer: input,
      mediaType: 'video',
      mimeType: matched.mime,
      format: matched.format,
    };
  }
}
