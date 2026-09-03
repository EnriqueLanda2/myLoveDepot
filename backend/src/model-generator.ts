import { spawn } from 'node:child_process';
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';

const python = process.env.MODEL3D_PYTHON ?? (process.platform === 'win32' ? 'python' : 'python3');
const script = process.env.MODEL3D_SCRIPT
  ?? path.resolve(process.cwd(), 'tools/model3d/build_model.py');
const timeoutMs = Number(process.env.MODEL3D_TIMEOUT_MS ?? 180_000);
const resolution = Number(process.env.MODEL3D_RESOLUTION ?? 56);

const MAX_IMAGE_BYTES = 12 * 1024 * 1024;
const MAX_MODEL_BYTES = 24 * 1024 * 1024;

export type ModelView = { viewIndex: number; imageUrl: string };

export type ModelReport = {
  views: number[];
  skippedViews: number[];
  grid: number[];
  extents: number[];
  triangles: number;
  bytes: number;
};

export class ModelBuildError extends Error {}

/** Solo un modelo a la vez: el plan gratuito de Render no da para dos. */
let building = false;

export function isBuilding() {
  return building;
}

export async function buildModel(views: ModelView[]) {
  if (views.length === 0) {
    throw new ModelBuildError('El producto todavía no tiene fotografías.');
  }
  if (building) {
    throw new ModelBuildError('Ya se está generando otro modelo. Intenta en un momento.');
  }
  building = true;
  const workspace = await mkdtemp(path.join(tmpdir(), 'depot-model-'));
  try {
    await Promise.all(views.map((view) => download(view, workspace)));
    const report = await runPython(workspace);
    const glb = await readFile(path.join(workspace, 'model.glb'));
    if (glb.byteLength > MAX_MODEL_BYTES) {
      throw new ModelBuildError('El modelo generado es demasiado grande.');
    }
    
    let render: Buffer | undefined;
    try {
      render = await readFile(path.join(workspace, 'render.png'));
    } catch {
      // Ignore if render failed or is missing
    }

    return { glb, report, render };
  } finally {
    building = false;
    await rm(workspace, { recursive: true, force: true });
  }
}

async function download(view: ModelView, workspace: string) {
  const response = await fetch(view.imageUrl);
  if (!response.ok) {
    throw new ModelBuildError(`No se pudo descargar la vista ${view.viewIndex}.`);
  }
  const bytes = Buffer.from(await response.arrayBuffer());
  if (bytes.byteLength > MAX_IMAGE_BYTES) {
    throw new ModelBuildError(`La vista ${view.viewIndex} pesa demasiado.`);
  }
  const extension = path.extname(new URL(view.imageUrl).pathname) || '.webp';
  await writeFile(path.join(workspace, `view-${view.viewIndex}${extension}`), bytes);
}

function runPython(workspace: string) {
  return new Promise<ModelReport>((resolve, reject) => {
    const child = spawn(python, [
      script,
      '--input', workspace,
      '--output', path.join(workspace, 'model.glb'),
      '--resolution', String(resolution),
    ], { stdio: ['ignore', 'pipe', 'pipe'] });

    let stdout = '';
    let stderr = '';
    child.stdout.on('data', (chunk) => { stdout += chunk; });
    child.stderr.on('data', (chunk) => { stderr += chunk; });

    const timer = setTimeout(() => {
      child.kill('SIGKILL');
      reject(new ModelBuildError('La generación del modelo tardó demasiado.'));
    }, timeoutMs);

    child.on('error', (error) => {
      clearTimeout(timer);
      reject(new ModelBuildError(
        `No se pudo ejecutar Python (${python}). ${error.message}`,
      ));
    });

    child.on('close', (code) => {
      clearTimeout(timer);
      if (code !== 0) {
        reject(new ModelBuildError(
          stderr.trim().split('\n').at(-1) ?? 'El generador de modelos falló.',
        ));
        return;
      }
      try {
        resolve(JSON.parse(stdout) as ModelReport);
      } catch {
        reject(new ModelBuildError('El generador devolvió una respuesta ilegible.'));
      }
    });
  });
}
