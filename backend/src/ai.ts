import Anthropic from '@anthropic-ai/sdk';
import { betaZodOutputFormat } from '@anthropic-ai/sdk/helpers/beta/zod';
import sharp from 'sharp';
import { z } from 'zod';

/**
 * Análisis de la foto de un producto con Claude (visión + salida JSON estricta).
 * La API key solo vive en el servidor; la app nunca la ve.
 */

export const AI_MODEL = process.env.AI_MODEL ?? 'claude-sonnet-5-5';
const AI_TIMEOUT_MS = Number(process.env.AI_TIMEOUT_MS ?? 60_000);

export class AiError extends Error {
  constructor(public readonly status: number, message: string) {
    super(message);
    this.name = 'AiError';
  }
}

const ProductAnalysis = z.object({
  name: z.string().describe('Nombre comercial completo, incluida la marca. Ej. "Elf Halo Glow Beauty Wand Blush"'),
  brand: z.string().describe('Marca visible en el empaque; cadena vacía si no se distingue'),
  shade: z.string().describe('Tono, aroma, tamaño o variante. Cadena vacía si no aplica'),
  category: z.string().describe('Una de las categorías existentes si encaja; si no, una nueva corta'),
  description: z.string().describe('2 o 3 frases de venta en español'),
  tags: z.array(z.string()).describe('De 3 a 6 etiquetas cortas en español'),
  confidence: z.number().describe('Qué tan seguro estás de la identificación, de 0 a 1'),
});

export type ProductAnalysis = z.infer<typeof ProductAnalysis>;

let client: Anthropic | null = null;
function getClient() {
  if (!process.env.ANTHROPIC_API_KEY && !process.env.ANTHROPIC_AUTH_TOKEN) {
    throw new AiError(503, 'La IA no está configurada en el servidor (falta ANTHROPIC_API_KEY).');
  }
  client ??= new Anthropic({ timeout: AI_TIMEOUT_MS, maxRetries: 1 });
  return client;
}

const SYSTEM = `Eres el asistente de catálogo de una pequeña tienda de belleza, perfumería y regalos en México.
Recibes la foto de un producto y llenas su ficha para el inventario.

- Identifica el producto por lo que se ve en el empaque o etiqueta. No inventes marcas ni tonos que no se lean o reconozcan; si no estás seguro, deja el campo vacío y baja "confidence".
- "category": elige una de las categorías existentes cuando el producto encaje razonablemente. Solo si ninguna encaja, propone una nueva de una o dos palabras, con mayúscula inicial.
- "description": 2 o 3 frases de venta en español neutro, concretas (qué es, cómo se usa o se siente, para quién). Sin emojis ni exageraciones.
- "tags": de 3 a 6 etiquetas cortas en español, útiles para buscar el producto.`;

export async function analyzeProductImage(image: Buffer, categories: string[]): Promise<ProductAnalysis> {
  // Claude no necesita más de ~1.5 MP; reducir acelera y abarata la llamada.
  const jpeg = await sharp(image)
    .rotate()
    .resize({ width: 1568, height: 1568, fit: 'inside', withoutEnlargement: true })
    .flatten({ background: '#FFFFFF' })
    .jpeg({ quality: 85 })
    .toBuffer();

  const categoryList = categories.length
    ? categories.map((name) => `- ${name}`).join('\n')
    : '(todavía no hay categorías registradas)';

  let response;
  try {
    response = await getClient().beta.messages.parse({
      model: AI_MODEL,
      max_tokens: 16000,
      // Si los filtros de seguridad rechazan la petición, la API la reintenta
      // en el modelo de respaldo recomendado en lugar de devolver el rechazo.
      betas: ['server-side-fallback-2026-07-01'],
      fallbacks: 'default',
      output_config: { effort: 'low', format: betaZodOutputFormat(ProductAnalysis) },
      system: SYSTEM,
      messages: [{
        role: 'user',
        content: [
          {
            type: 'image',
            source: { type: 'base64', media_type: 'image/jpeg', data: jpeg.toString('base64') },
          },
          {
            type: 'text',
            text: `Categorías existentes en la tienda:\n${categoryList}\n\nLlena la ficha de este producto.`,
          },
        ],
      }],
    });
  } catch (error) {
    if (error instanceof AiError) throw error;
    if (error instanceof Anthropic.AuthenticationError || error instanceof Anthropic.PermissionDeniedError) {
      throw new AiError(503, 'La API key de la IA no es válida.');
    }
    if (error instanceof Anthropic.RateLimitError) {
      throw new AiError(429, 'La IA está saturada en este momento. Intenta de nuevo en un minuto.');
    }
    if (error instanceof Anthropic.APIConnectionTimeoutError) {
      throw new AiError(504, 'La IA tardó demasiado en responder. Intenta de nuevo.');
    }
    if (error instanceof Anthropic.APIConnectionError) {
      throw new AiError(502, 'No se pudo conectar con el servicio de IA.');
    }
    if (error instanceof Anthropic.APIError) {
      console.error('Error de la API de Claude', error.status, error.message);
      throw new AiError(502, 'El servicio de IA devolvió un error.');
    }
    throw error;
  }

  if (response.stop_reason === 'refusal') {
    throw new AiError(422, 'La IA no pudo analizar esta imagen. Llena la ficha manualmente.');
  }
  const parsed = response.parsed_output;
  if (!parsed) {
    throw new AiError(502, 'La IA respondió en un formato inesperado. Intenta de nuevo.');
  }

  const known = new Map(categories.map((name) => [name.toLowerCase(), name]));
  const category = parsed.category.trim();
  return {
    name: parsed.name.trim(),
    brand: parsed.brand.trim(),
    shade: parsed.shade.trim(),
    // Respeta la grafía exacta de una categoría existente.
    category: known.get(category.toLowerCase()) ?? category,
    description: parsed.description.trim(),
    tags: [...new Set(parsed.tags.map((tag) => tag.trim()).filter(Boolean))].slice(0, 6),
    confidence: Math.min(1, Math.max(0, parsed.confidence)),
  };
}
