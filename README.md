# My Love Depot 💗

Inventario y finanzas personales para un pequeño negocio, hecho en **Flutter**
(PWA para teléfono, tablet o computadora) con una **API en Node.js + MySQL**.

Sube la foto de un producto y la **IA llena la ficha** (nombre, tono, categoría,
descripción y etiquetas) y te ofrece **fotografías de catálogo**. Controla
entradas y ventas con su ganancia real, recibe alertas de stock bajo y lleva tus
finanzas con un **presupuesto semanal**.

---

## Índice

1. [Qué puedes hacer](#qué-puedes-hacer)
2. [Guía rápida de uso](#guía-rápida-de-uso)
3. [Qué necesitas instalar](#qué-necesitas-instalar)
4. [Ponerlo en marcha en tu computadora](#ponerlo-en-marcha-en-tu-computadora)
5. [Variables de entorno](#variables-de-entorno)
6. [Comandos útiles](#comandos-útiles)
7. [Publicar en internet](#publicar-en-internet)
8. [Instalar la app en el teléfono](#instalar-la-app-en-el-teléfono)
9. [IA: ficha y fotografías del producto](#ia-ficha-y-fotografías-del-producto)
10. [Generador de modelos 3D (opcional)](#generador-de-modelos-3d-opcional)
11. [Solución de problemas](#solución-de-problemas)
12. [Estructura del proyecto](#estructura-del-proyecto)

---

## Qué puedes hacer

| Sección | Para qué sirve |
| --- | --- |
| **Nuevo producto con IA** | Arrastra o elige la foto del producto: la IA identifica marca y tono, redacta la descripción, sugiere la categoría (la crea si no existe) y genera 4 fotografías de catálogo para elegir. Todo se puede editar. |
| **Resumen** | Unidades en stock, valor del almacén, ganancias de hoy y del mes, productos que requieren atención (con **Reabastecer**) y últimos movimientos. |
| **Productos** | Catálogo en cuadrícula o lista, búsqueda por nombre, tono o SKU, filtro de stock bajo y chips de categoría. **Entrada** y **Salida** abren el registro con la ganancia de la venta. |
| **Categorías** | Crear, renombrar y ver productos, unidades y valor de cada una. Una categoría con productos no se puede eliminar. |
| **Movimientos** | Historial de entradas y salidas con la ganancia de cada venta. |
| **Finanzas** | Presupuesto semanal (lunes a domingo): cuánto puedes gastar esta semana, cuánto llevas ahorrado, saldo disponible, gráfica semana a semana y gastos por categoría. |
| **Ayuda** | En el menú lateral (o el menú ⋮ en el teléfono) hay una guía de cada sección. |

Reglas que respeta la app (y valida también la API):

- **Ganancia** de una venta = (precio − costo) × cantidad. El precio y el costo se
  guardan en el movimiento, así que editar el producto después no cambia ventas pasadas.
- Una **salida** nunca puede superar el stock disponible.
- Eliminar un **producto** o un **gasto** muestra **Deshacer** durante 5 segundos.
- **Saldo disponible** = fondo inicial − gastos totales. Hay un interruptor para
  sumarle las ganancias por ventas (apagado por defecto).
- **Llevas ahorrado** = suma de (presupuesto − gasto) de cada semana cerrada desde
  tu primer gasto. Si te pasas en una semana, resta.

Todo se guarda primero en el dispositivo (carga instantánea y funciona sin
conexión) y se sincroniza con la API cuando hay sesión e internet.

## Guía rápida de uso

1. **Inicia sesión** con el usuario `wifey` o `husband` y la contraseña que se
   configuró en el servidor.
2. **Agrega productos** con **Nuevo producto**: sube una foto con el empaque o la
   etiqueta visible y espera unos segundos. Revisa lo que llenó la IA (los campos
   con la marca morada **IA**), elige una de las fotografías y completa **precio**
   y **costo**. Solo el nombre y el precio son obligatorios.
3. **Cada venta** se registra con **Salida** en la tarjeta del producto; cada
   compra o reposición con **Entrada**. Ajusta la cantidad con − / + o escríbela.
4. **Revisa el Resumen** cada día: ganancias y qué productos hay que reabastecer.
5. **En Finanzas**, define tu **presupuesto semanal** y tu **fondo inicial**, y
   registra cada gasto con su categoría (Comida, Farmacia…).

---

## Qué necesitas instalar

| Herramienta | Versión | Para qué | Obligatorio |
| --- | --- | --- | --- |
| [Flutter SDK](https://docs.flutter.dev/get-started/install) | estable (Dart ≥ 3.4) | Compilar y ejecutar la app | Sí |
| Google Chrome | reciente | Ejecutar la app en modo desarrollo | Sí |
| [Node.js](https://nodejs.org/) | 22 o superior | Ejecutar la API | Sí |
| MySQL | 8.x | Base de datos (local, [Aiven](https://aiven.io/) u otro) | Sí |
| Cuenta de [Cloudinary](https://cloudinary.com/) | gratuita | Guardar fotos de productos en producción | Solo en producción¹ |
| API key de [Google Gemini](https://aistudio.google.com/apikey) | plan gratuito | Análisis de fotos con IA | No² |
| [Docker](https://www.docker.com/) | reciente | Levantar MySQL local con un comando | No |
| Python | 3.10 o superior | Generador de modelos 3D | No |
| Android Studio / Xcode | reciente | Compilar APK Android / app iOS nativa | No |

¹ En local usa `MEDIA_STORAGE=local`: las fotos se guardan en `backend/uploads`
y no hace falta Cloudinary.

² Sin la clave la app funciona igual: el análisis avisa que la IA no está
configurada, el formulario se llena a mano y las fotografías de catálogo se
siguen generando (eso corre en tu servidor, no en la IA).

> **macOS:** si instalaste Flutter en `~/development/flutter`, agrégalo al PATH
> añadiendo esta línea a `~/.zshrc` y abriendo una terminal nueva:
>
> ```bash
> export PATH="$HOME/development/flutter/bin:$PATH"
> ```
>
> Comprueba la instalación con `flutter doctor`.

---

## Ponerlo en marcha en tu computadora

La app **necesita la API** para iniciar sesión, así que se levantan las dos
partes: base de datos + API, y después la app.

### 1. Base de datos

Con Docker (lo más sencillo):

```bash
docker compose up -d
```

Esto crea una base `my_love_depot` con usuario `depot` / contraseña `depot` en
`localhost:3306`. Si no usas Docker, crea esa base en cualquier MySQL 8 o usa
la URI de Aiven.

Sin Docker ni Homebrew en macOS (Apple Silicon) se puede usar el MySQL oficial
portátil, sin instalar nada en el sistema:

```bash
cd ~/development
curl -LO https://cdn.mysql.com/Downloads/MySQL-8.4/mysql-8.4.9-macos15-arm64.tar.gz
tar -xzf mysql-8.4.9-macos15-arm64.tar.gz && mv mysql-8.4.9-macos15-arm64 mysql
mysql/bin/mysqld --no-defaults --initialize-insecure --datadir=$HOME/development/mysql-data
# Arrancarlo (cada vez que reinicies la computadora):
mysql/bin/mysqld --no-defaults --datadir=$HOME/development/mysql-data \
  --bind-address=127.0.0.1 --mysqlx=OFF &
# Crear la base y el usuario (solo la primera vez):
mysql/bin/mysql --no-defaults -uroot -h127.0.0.1 -e "CREATE DATABASE my_love_depot; \
  CREATE USER 'depot'@'%' IDENTIFIED BY 'depot'; GRANT ALL ON my_love_depot.* TO 'depot'@'%';"
```

### 2. API (`backend/`)

```bash
cd backend
cp .env.example .env        # En Windows: Copy-Item .env.example .env
npm install
```

Edita `backend/.env` (ver [Variables de entorno](#variables-de-entorno)). Como
mínimo:

```dotenv
DATABASE_URL=mysql://depot:depot@localhost:3306/my_love_depot
JWT_SECRET=<cadena aleatoria larga>
WIFEY_PASSWORD=<contraseña de 12+ caracteres>
HUSBAND_PASSWORD=<otra contraseña de 12+ caracteres>
MEDIA_STORAGE=local
ALLOWED_ORIGINS=http://localhost:8080
GEMINI_API_KEY=<tu clave de Gemini, opcional y gratuita>
```

Para generar un `JWT_SECRET` seguro:

```bash
node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"
```

Crea las tablas y arranca la API:

```bash
npm run db:init
npm run dev
```

Comprueba que responde en <http://localhost:3000/health> (`{"status":"ok"}`).

### 3. App Flutter (raíz del repositorio)

```bash
flutter pub get
flutter run -d chrome --web-port 8080 \
  --dart-define=API_BASE_URL=http://localhost:3000
```

En PowerShell cambia `\` por `` ` `` al final de cada línea.

`--web-port 8080` hace que el origen coincida con `ALLOWED_ORIGINS`; si usas
otro puerto, agrégalo a esa variable.

La primera vez la app muestra **productos de demostración** para que veas cómo
se ve; puedes editarlos o eliminarlos.

---

## Variables de entorno

Todas viven en `backend/.env` (nunca lo subas a Git; ya está en `.gitignore`).

| Variable | Obligatoria | Descripción |
| --- | --- | --- |
| `PORT` | No | Puerto de la API. Por omisión `3000`. |
| `DATABASE_URL` | Sí | URI MySQL: `mysql://usuario:contraseña@host:puerto/base`. |
| `DATABASE_CA_CERT_BASE64` | No | Certificado CA en Base64 (Aiven). Vacío en `localhost`. |
| `MEDIA_STORAGE` | No | `cloudinary` (por omisión, producción) o `local` (fotos en `backend/uploads`, para desarrollo). |
| `PUBLIC_API_URL` | No | URL pública de la API, para armar los enlaces de las fotos con `MEDIA_STORAGE=local`. Por omisión `http://localhost:3000`. |
| `CLOUDINARY_CLOUD_NAME` | Con `cloudinary` | Nombre de tu cuenta de Cloudinary. |
| `CLOUDINARY_API_KEY` | Con `cloudinary` | API key de Cloudinary. |
| `CLOUDINARY_API_SECRET` | Con `cloudinary` | API secret de Cloudinary. |
| `GEMINI_API_KEY` | No | Activa el análisis de fotos con Google Gemini (plan gratuito). Sin ella, la app avisa y se llena a mano. |
| `GEMINI_MODEL` | No | Modelo de Gemini. Por omisión `gemini-flash-latest`. |
| `AI_PROVIDER` | No | `gemini` o `anthropic`. Vacío: usa el que tenga clave, Gemini primero. |
| `ANTHROPIC_API_KEY` | No | Alternativa de pago: análisis con Claude. |
| `AI_MODEL` | No | Modelo de Claude. Por omisión `claude-sonnet-5-5` (`claude-haiku-5-5` es el más barato). |
| `AI_TIMEOUT_MS` | No | Tiempo máximo de espera de la IA. Por omisión `60000`. |
| `JWT_SECRET` | Sí | Clave para firmar las sesiones (64+ caracteres aleatorios). |
| `WIFEY_USERNAME` / `HUSBAND_USERNAME` | No | Usuarios. Por omisión `wifey` y `husband`. |
| `WIFEY_PASSWORD` / `HUSBAND_PASSWORD` | Sí | Contraseñas de cada usuario. |
| `ALLOWED_ORIGINS` | Sí | URLs que pueden usar la API, separadas por comas y sin `/` final. |
| `MODEL3D_PYTHON` | No | Intérprete de Python para el generador 3D (`python3`, o `python` en Windows). |
| `MODEL3D_RESOLUTION` | No | Resolución de la rejilla de vóxeles (48 por omisión en `.env.example`). |
| `MODEL3D_TIMEOUT_MS` | No | Tiempo máximo de generación del modelo. |

La app Flutter recibe solo una variable, en tiempo de compilación:

| Variable | Ejemplo |
| --- | --- |
| `API_BASE_URL` | `--dart-define=API_BASE_URL=https://mi-api.onrender.com` |

Ninguna contraseña se compila dentro de la app.

---

## Comandos útiles

| Dónde | Comando | Qué hace |
| --- | --- | --- |
| raíz | `flutter run -d chrome --web-port 8080 --dart-define=API_BASE_URL=http://localhost:3000` | App en modo desarrollo |
| raíz | `flutter analyze` | Revisa el código Dart |
| raíz | `flutter test` | Ejecuta las pruebas (lógica + pantallas en tamaño teléfono y tablet) |
| raíz | `flutter build web --release --dart-define=API_BASE_URL=<url>` | Genera la PWA en `build/web` |
| raíz | `flutter build apk --release --dart-define=API_BASE_URL=<url>` | Genera el APK de Android |
| raíz | `docker compose up -d` / `docker compose down` | Enciende / apaga MySQL local |
| `backend/` | `npm run dev` | API con recarga automática |
| `backend/` | `npm run db:init` | Crea o actualiza las tablas |
| `backend/` | `npm run db:clear` | **Borra** los datos de la base |
| `backend/` | `npm run typecheck` | Revisa los tipos de TypeScript |
| `backend/` | `npm run build && npm start` | API compilada (como en producción) |

---

## Publicar en internet

### API en Render

El archivo `render.yaml` define un Web Service Docker gratuito con raíz en
`backend/` y health check en `/health`.

1. Sube el repositorio a GitHub.
2. En Render elige **New → Blueprint** y conecta el repositorio.
3. Render leerá `render.yaml` y pedirá las variables secretas: `DATABASE_URL`
   (la URI de Aiven), `DATABASE_CA_CERT_BASE64`, las tres de Cloudinary,
   `WIFEY_PASSWORD`, `HUSBAND_PASSWORD` y `ALLOWED_ORIGINS` (la URL final de la
   PWA). `JWT_SECRET` se genera solo.

Al arrancar, el contenedor aplica `schema.sql` automáticamente. Las imágenes
van a Cloudinary y los datos a MySQL; nada depende del disco de Render.

El plan gratuito se duerme tras un rato sin tráfico. La app muestra primero los
datos guardados en el dispositivo mientras la API despierta, y luego sincroniza.

### App (PWA)

```bash
flutter build web --release --dart-define=API_BASE_URL=https://<tu-api>.onrender.com
```

Publica la carpeta `build/web` en cualquier hosting **con HTTPS** (Render Static
Site, Netlify, Firebase Hosting, GitHub Pages…). HTTPS es necesario para que la
app se pueda instalar y para usar la cámara. Después agrega esa URL exacta a
`ALLOWED_ORIGINS` en la API.

---

## Instalar la app en el teléfono

Desde la app también puedes tocar **DESCARGAR APP** (o el ícono 📲 en el
teléfono) para ver estas instrucciones.

- **iPhone / iPad (Safari):** abre la URL de la PWA → botón **Compartir** →
  **Agregar a inicio** → **Agregar**.
- **Android (Chrome):** abre la URL → menú **⋮** → **Instalar aplicación** o
  **Agregar a la pantalla principal**.

### APK Android

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://<tu-api>.onrender.com
```

El archivo queda en `build/app/outputs/flutter-apk/app-release.apk`.

### iOS nativo

Solo se puede compilar en una Mac con Xcode:

```bash
flutter create --platforms=ios .
flutter pub get
open ios/Runner.xcworkspace
```

Selecciona tu equipo de Apple Developer, conecta el iPhone y ejecuta
`flutter run`. Para TestFlight o App Store se necesita cuenta de Apple Developer.

---

## IA: ficha y fotografías del producto

Todo pasa por la API; las claves de IA **nunca** llegan a la app.

| Endpoint | Qué hace |
| --- | --- |
| `POST /api/ai/analyze-product` | Recibe la foto (`multipart`, campo `image`) y le pide a la IA (visión, salida JSON estricta) `{ name, brand, shade, category, description, tags[], confidence }`. Le pasa las categorías existentes para que elija una de ellas cuando encaje; la descripción sale en español, 2–3 frases de venta. |
| `POST /api/ai/product-photos` | Recibe la foto (`image`) y un juego (`set`, 0 o 1). Quita el fondo y compone 4 fotografías de 1024×1024 sobre fondos de estudio (blanco, rosa pastel, sombra suave, contraste; el segundo juego: degradado rosa, menta, arena y lavanda). Devuelve los JPEG en Base64. |

Cómo se usa en la app: al subir la foto, la app llama a los dos endpoints a la
vez y muestra el progreso (*Detectando el producto → Identificando marca y tono →
Redactando descripción y categoría → Generando fotografías*). Si la IA falla o
tarda demasiado, aparece un aviso y el formulario sigue siendo editable. La foto
elegida se sube como foto principal del producto.

Detalles que conviene saber:

- **Proveedor:** Google Gemini (`gemini-flash-latest`) por omisión. Su plan
  gratuito tiene límites diarios de uso; si se alcanzan, la app lo avisa y puedes
  llenar la ficha a mano. Crea la clave en <https://aistudio.google.com/apikey>.
  En el plan gratuito, Google puede usar lo que envías para mejorar sus productos.
- **Alternativa de pago:** Claude, con `AI_PROVIDER=anthropic` y
  `ANTHROPIC_API_KEY`. Con `AI_MODEL=claude-haiku-5-5` cuesta fracciones de
  centavo por producto.
- **Costo:** cada análisis es una sola llamada con una imagen reducida a ~1.5 MP;
  las fotografías de catálogo no usan la IA.
- **Privacidad:** la foto del producto se envía al proveedor de IA para analizarla.
- **Quitar el fondo** se hace en el servidor con `sharp` (`backend/src/product-photos.ts`):
  toma el color de los bordes como fondo y lo "inunda" hacia adentro. Funciona muy
  bien con **fondo liso** y contrastado; con fondos muy cargados no se puede
  separar el producto y se usa la foto completa con esquinas redondeadas.

## Generador de modelos 3D (opcional)

La API incluye un endpoint (`POST /api/products/:id/model`) que reconstruye un
modelo `.glb` a partir de las fotos del producto usando
`backend/tools/model3d` (Python, numpy y Pillow). **La app actual no muestra el
visor 3D**; el generador queda disponible para uso desde la API o por separado.

```bash
cd backend/tools/model3d
pip install -r requirements.txt
python build_model.py --input <carpeta-con-view-0..4> --output producto.glb
```

Opciones: `--resolution` (lado de la rejilla de vóxeles, 56 por omisión) y
`--smooth` (pasadas de suavizado, 4 por omisión).

Usa el método de **casco visual**: segmenta la silueta de cada foto, la extruye
desde su ángulo y se queda con la intersección. Con varias vistas ortogonales
el contorno sale exacto, pero no recupera concavidades (un tazón sale macizo).
Las fotos con **fondo liso y contrastado** dan los mejores resultados.

---

## Solución de problemas

| Síntoma | Causa probable y solución |
| --- | --- |
| *"La IA no está configurada en el servidor"* | Agrega `GEMINI_API_KEY` a `backend/.env` y reinicia la API. |
| *"Se alcanzó el límite gratuito de Gemini"* | Espera un rato o al día siguiente; mientras tanto llena la ficha a mano. |
| Las fotografías generadas recortan mal el producto | Toma la foto sobre un fondo liso que contraste con el producto, con el producto completo y centrado. |
| *"La app no tiene servidor configurado"* al iniciar sesión | Falta `--dart-define=API_BASE_URL=...` al ejecutar o compilar la app. |
| *"No hay conexión con el servidor"* | La API no está corriendo, la URL es incorrecta, o el origen de la app no está en `ALLOWED_ORIGINS`. Revisa la consola del navegador (error CORS). |
| *"Usuario o contraseña incorrectos"* | Verifica `WIFEY_PASSWORD` / `HUSBAND_PASSWORD` en `backend/.env` y reinicia la API. Tras 8 intentos fallidos se bloquea 15 minutos. |
| La API se cierra con *"Falta la variable …"* | Completa esa variable en `backend/.env`. |
| Error SSL al conectar a MySQL | En Aiven, agrega `DATABASE_CA_CERT_BASE64`. En local usa `localhost` en `DATABASE_URL`. |
| La primera carga en producción tarda | Render gratuito estaba dormido; espera unos segundos. |
| No aparece la opción de instalar la app | La PWA debe servirse por HTTPS y abrirse en Safari (iOS) o Chrome (Android). |
| `flutter: command not found` | Agrega Flutter al PATH (ver [Qué necesitas instalar](#qué-necesitas-instalar)). |

---

## Estructura del proyecto

```text
lib/                      App Flutter
  main.dart               Punto de entrada
  src/app.dart            Tema visual y navegación login ↔ inicio
  src/inventory_store.dart Estado, guardado local y sincronización
  src/api_client.dart     Cliente HTTP de la API
  src/models.dart         Producto, categoría y movimiento
  src/ui/                 Sistema visual: colores, tipografía y componentes
                          (Button, Chip, Card, Modal, StockPill, Toast…)
  src/screens/            Shell con sidebar, vistas (Resumen, Productos,
                          Categorías, Movimientos, Finanzas) y modales
                          (producto con IA, movimiento, gasto, fondo, presupuesto)
  src/widgets/            Mascota, banner e instalación PWA
assets/fonts/             Figtree (licencia OFL)
test/                     Pruebas de lógica y de pantallas
web/                      index.html, manifest e íconos de la PWA
backend/                  API Express + TypeScript
  src/server.ts           Rutas de la API
  src/ai.ts               Análisis de la foto con IA (Gemini o Claude)
  src/product-photos.ts   Quitar fondo y componer fotografías de catálogo
  src/media-storage.ts    Fotos en Cloudinary o en disco (desarrollo)
  src/migrate.ts          Aplica schema.sql
  schema.sql              Tablas MySQL
  tools/model3d/          Generador de modelos 3D (Python)
docker-compose.yml        MySQL local para desarrollo
render.yaml               Despliegue de la API en Render
viewer3d/                 Visor 3D independiente (Vite + three.js)
```
