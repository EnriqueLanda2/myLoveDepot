import Anthropic from '@anthropic-ai/sdk';
import { betaZodOutputFormat } from '@anthropic-ai/sdk/helpers/beta/zod';
import sharp from 'sharp';
import { z } from 'zod';

/**
 * Análisis de la foto de un producto con IA (visión + salida JSON estricta).
 *
 * Proveedores:
 * - `gemini` (por omisión): Google Gemini. Tiene un plan gratuito con límites
 *   diarios. Requiere GEMINI_API_KEY.
 * - `anthropic`: Claude. De pago por uso. Requiere ANTHROPIC_API_KEY.
 *
 * Si no se fija AI_PROVIDER, se usa el que tenga clave (Gemini primero).
 * Las claves solo viven en el servidor; la app nunca las ve.
 */

const AI_TIMEOUT_MS = Number(process.env.AI_TIMEOUT_MS ?? 60_000);
const GEMINI_MODEL = process.env.GEMINI_MODEL ?? 'gemini-flash-latest';
const CLAUDE_MODEL = process.env.AI_MODEL ?? 'claude-sonnet-5-5';

// El respaldo automático ante rechazos de Claude solo existe en estos modelos;
// en los demás (p. ej. Haiku) enviarlo provoca un error 400.
const CLAUDE_FALLBACK_MODELS = new Set([
  'claude-sonnet-5-5', 'claude-opus-5-5', 'claude-opus-5', 'claude-fable-5-1',
]);

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

const SYSTEM = `Eres el asistente de catálogo de una pequeña tienda de belleza, perfumería y regalos en México.
Recibes la foto de un producto y llenas su ficha para el inventario.

- Identifica el producto por lo que se ve en el empaque o etiqueta. No inventes marcas ni tonos que no se lean o reconozcan; si no estás seguro, deja el campo vacío y baja "confidence".
- "category": elige una de las categorías existentes cuando el producto encaje razonablemente. Solo si ninguna encaja, propone una nueva de una o dos palabras, con mayúscula inicial.
- "description": 2 o 3 frases de venta en español neutro, concretas (qué es, cómo se usa o se siente, para quién). Sin emojis ni exageraciones.
- "tags": de 3 a 6 etiquetas cortas en español, útiles para buscar el producto.`;

type Provider = 'gemini' | 'anthropic';

function chooseProvider(): Provider {
  const configured = process.env.AI_PROVIDER?.trim().toLowerCase();
  if (configured === 'gemini' || configured === 'anthropic') return configured;
  if (process.env.GEMINI_API_KEY) return 'gemini';
  if (process.env.ANTHROPIC_API_KEY || process.env.ANTHROPIC_AUTH_TOKEN) return 'anthropic';
  throw new AiError(503, 'La IA no está configurada en el servidor (falta GEMINI_API_KEY).');
}

export async function analyzeProductImage(image: Buffer, categories: string[]): Promise<ProductAnalysis> {
  // Ningún modelo necesita más de ~1.5 MP; reducir acelera y abarata la llamada.
  const jpeg = await sharp(image)
    .rotate()
    .resize({ width: 1568, height: 1568, fit: 'inside', withoutEnlargement: true })
    .flatten({ background: '#FFFFFF' })
    .jpeg({ quality: 85 })
    .toBuffer();

  const categoryList = categories.length
    ? categories.map((name) => `- ${name}`).join('\n')
    : '(todavía no hay categorías registradas)';
  const prompt = `Categorías existentes en la tienda:\n${categoryList}\n\nLlena la ficha de este producto.`;

  const parsed = chooseProvider() === 'gemini'
    ? await analyzeWithGemini(jpeg, prompt)
    : await analyzeWithClaude(jpeg, prompt);

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

// ── Gemini ───────────────────────────────────────────────────────────────────

// Esquema de respuesta en el formato de Gemini (subconjunto de OpenAPI).
const GEMINI_SCHEMA = {
  type: 'OBJECT',
  properties: {
    name: { type: 'STRING', description: 'Nombre comercial completo, incluida la marca' },
    brand: { type: 'STRING', description: 'Marca visible; vacío si no se distingue' },
    shade: { type: 'STRING', description: 'Tono, aroma, tamaño o variante; vacío si no aplica' },
    category: { type: 'STRING', description: 'Una categoría existente si encaja; si no, una nueva corta' },
    description: { type: 'STRING', description: '2 o 3 frases de venta en español' },
    tags: { type: 'ARRAY', items: { type: 'STRING' }, description: 'De 3 a 6 etiquetas cortas en español' },
    confidence: { type: 'NUMBER', description: 'Seguridad de la identificación, de 0 a 1' },
  },
  required: ['name', 'brand', 'shade', 'category', 'description', 'tags', 'confidence'],
  propertyOrdering: ['name', 'brand', 'shade', 'category', 'description', 'tags', 'confidence'],
};

interface GeminiResponse {
  candidates?: Array<{
    finishReason?: string;
    content?: { parts?: Array<{ text?: string; thought?: boolean }> };
  }>;
  promptFeedback?: { blockReason?: string };
  error?: { code?: number; message?: string; status?: string };
}

/** Modelos a intentar, en orden: el configurado y respaldos con plan gratuito. */
function geminiModels(): string[] {
  const fallbacks = (process.env.GEMINI_FALLBACK_MODELS ?? 'gemini-flash-lite-latest,gemini-2.5-flash')
    .split(',')
    .map((model) => model.trim())
    .filter(Boolean);
  return [...new Set([GEMINI_MODEL, ...fallbacks])];
}

class GeminiCallError extends Error {
  constructor(
    public readonly httpStatus: number,
    public readonly status: string,
    message: string,
  ) {
    super(message);
  }

  /** Saturación o falla temporal de Google: conviene reintentar. */
  get transient() {
    return this.httpStatus >= 500 || this.status === 'UNAVAILABLE' || this.status === 'INTERNAL';
  }

  get keyProblem() {
    return /API key not valid|API_KEY_INVALID|API key expired/i.test(this.message);
  }
}

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

async function callGemini(
  key: string,
  model: string,
  jpeg: Buffer,
  prompt: string,
  withSchema: boolean,
): Promise<ProductAnalysis> {
  const schemaHint = withSchema
    ? ''
    : '\n\nResponde solo con un objeto JSON con las claves: name, brand, shade, category, description, tags (lista de textos) y confidence (número de 0 a 1).';
  let response: Response;
  try {
    response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent`,
      {
        method: 'POST',
        // La clave va en un encabezado y no en la URL, para que no quede en logs.
        headers: { 'content-type': 'application/json', 'x-goog-api-key': key },
        body: JSON.stringify({
          systemInstruction: { parts: [{ text: SYSTEM }] },
          contents: [{
            role: 'user',
            parts: [
              { inlineData: { mimeType: 'image/jpeg', data: jpeg.toString('base64') } },
              { text: prompt + schemaHint },
            ],
          }],
          generationConfig: {
            responseMimeType: 'application/json',
            ...(withSchema ? { responseSchema: GEMINI_SCHEMA } : {}),
          },
        }),
        signal: AbortSignal.timeout(AI_TIMEOUT_MS),
      },
    );
  } catch (error) {
    if ((error as Error).name === 'TimeoutError') {
      throw new AiError(504, 'La IA tardó demasiado en responder. Intenta de nuevo.');
    }
    throw new GeminiCallError(503, 'UNAVAILABLE', 'No se pudo conectar con Gemini.');
  }

  const data = (await response.json().catch(() => ({}))) as GeminiResponse;
  if (!response.ok) {
    throw new GeminiCallError(
      response.status,
      data.error?.status ?? '',
      data.error?.message ?? `HTTP ${response.status}`,
    );
  }

  const candidate = data.candidates?.[0];
  if (data.promptFeedback?.blockReason || candidate?.finishReason === 'SAFETY') {
    throw new AiError(422, 'La IA no pudo analizar esta imagen. Llena la ficha manualmente.');
  }
  const text = (candidate?.content?.parts ?? [])
    .filter((part) => !part.thought && part.text)
    .map((part) => part.text)
    .join('')
    // Sin esquema, algunos modelos envuelven el JSON en ```json … ```.
    .replace(/^\s*```(?:json)?\s*/i, '')
    .replace(/\s*```\s*$/, '');
  try {
    const raw = JSON.parse(text) as Record<string, unknown>;
    return ProductAnalysis.parse({
      name: raw.name ?? '',
      brand: raw.brand ?? '',
      shade: raw.shade ?? '',
      category: raw.category ?? '',
      description: raw.description ?? '',
      tags: Array.isArray(raw.tags) ? raw.tags.map(String) : [],
      confidence: Number(raw.confidence ?? 0.5) || 0,
    });
  } catch {
    throw new GeminiCallError(502, 'MALFORMED', `Respuesta no válida (finishReason ${candidate?.finishReason ?? '—'})`);
  }
}

async function analyzeWithGemini(jpeg: Buffer, prompt: string): Promise<ProductAnalysis> {
  const key = process.env.GEMINI_API_KEY?.trim();
  if (!key) throw new AiError(503, 'La IA no está configurada en el servidor (falta GEMINI_API_KEY).');

  let last: GeminiCallError | null = null;
  for (const model of geminiModels()) {
    let withSchema = true;
    for (let attempt = 0; attempt < 3; attempt++) {
      try {
        return await callGemini(key, model, jpeg, prompt, withSchema);
      } catch (error) {
        if (!(error instanceof GeminiCallError)) throw error;
        last = error;
        console.error(`Gemini (${model}) respondió ${error.httpStatus} ${error.status}: ${error.message}`);
        if (error.keyProblem) {
          throw new AiError(503, 'La GEMINI_API_KEY no es válida. Revísala en Render o en backend/.env.');
        }
        if (error.httpStatus === 429 || error.status === 'RESOURCE_EXHAUSTED') {
          // El límite gratuito es por modelo: el siguiente puede tener cupo.
          break;
        }
        if (error.httpStatus === 404 || error.status === 'NOT_FOUND') break;
        if (error.httpStatus === 400 && withSchema) {
          // Un modelo que no acepta el esquema se reintenta pidiendo JSON simple.
          withSchema = false;
          continue;
        }
        if (error.transient || error.status === 'MALFORMED') {
          await sleep(800 * (attempt + 1));
          continue;
        }
        break;
      }
    }
  }

  if (last && (last.httpStatus === 429 || last.status === 'RESOURCE_EXHAUSTED')) {
    throw new AiError(429, 'Se alcanzó el límite gratuito de Gemini. Espera un momento o intenta mañana.');
  }
  if (last && last.httpStatus === 403) {
    throw new AiError(503, `Gemini rechazó la clave: ${last.message}`);
  }
  if (last?.transient) {
    throw new AiError(503, 'Gemini está saturado en este momento. Intenta de nuevo en un minuto.');
  }
  // Se muestra el motivo real de Google para poder corregirlo.
  throw new AiError(502, `Gemini devolvió un error: ${(last?.message ?? 'desconocido').slice(0, 200)}`);
}

// ── Claude ───────────────────────────────────────────────────────────────────

let claudeClient: Anthropic | null = null;

async function analyzeWithClaude(jpeg: Buffer, prompt: string): Promise<ProductAnalysis> {
  if (!process.env.ANTHROPIC_API_KEY && !process.env.ANTHROPIC_AUTH_TOKEN) {
    throw new AiError(503, 'La IA no está configurada en el servidor (falta ANTHROPIC_API_KEY).');
  }
  claudeClient ??= new Anthropic({ timeout: AI_TIMEOUT_MS, maxRetries: 1 });

  let response;
  try {
    response = await claudeClient.beta.messages.parse({
      model: CLAUDE_MODEL,
      max_tokens: 16000,
      // Si los filtros de seguridad rechazan la petición, la API la reintenta
      // en el modelo de respaldo recomendado en lugar de devolver el rechazo.
      ...(CLAUDE_FALLBACK_MODELS.has(CLAUDE_MODEL)
        ? { betas: ['server-side-fallback-2026-07-01'], fallbacks: 'default' as const }
        : {}),
      output_config: { effort: 'low', format: betaZodOutputFormat(ProductAnalysis) },
      system: SYSTEM,
      messages: [{
        role: 'user',
        content: [
          {
            type: 'image',
            source: { type: 'base64', media_type: 'image/jpeg', data: jpeg.toString('base64') },
          },
          { type: 'text', text: prompt },
        ],
      }],
    });
  } catch (error) {
    if (error instanceof Anthropic.AuthenticationError || error instanceof Anthropic.PermissionDeniedError) {
      throw new AiError(503, 'La ANTHROPIC_API_KEY no es válida.');
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
  if (!response.parsed_output) {
    throw new AiError(502, 'La IA respondió en un formato inesperado. Intenta de nuevo.');
  }
  return response.parsed_output;
}
