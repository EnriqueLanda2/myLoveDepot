# My Love Depot 💗

Inventario y finanzas personales para un pequeño negocio, hecho en **Flutter**
(PWA para teléfono, tablet o computadora) con una **API en Node.js + MySQL**.

Registra productos con foto, controla entradas y ventas, recibe alertas de stock
bajo, revisa tus ganancias del día y del mes, y lleva un control de tus gastos.

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
9. [Generador de modelos 3D (opcional)](#generador-de-modelos-3d-opcional)
10. [Solución de problemas](#solución-de-problemas)
11. [Estructura del proyecto](#estructura-del-proyecto)

---

## Qué puedes hacer

| Sección | Para qué sirve |
| --- | --- |
| **Resumen** | Unidades en stock, valor del almacén, ganancias de hoy y del mes, acciones rápidas y lista de productos con stock bajo (tócalos para reabastecer). |
| **Productos** | Catálogo con foto o video, búsqueda, filtro por categoría y por stock bajo. Botones `+1 ENTRADA`, `−1 VENTA` y **Ajustar** para mover varias unidades. |
| **Categorías** | Crear, renombrar (se actualiza en todos los productos) y eliminar categorías sin productos. |
| **Movimientos** | Historial de entradas y salidas, filtrable por tipo, categoría, mes y año. |
| **Finanzas** | Fondo inicial, registro de gastos personales, saldo disponible y en qué se va el dinero. |
| **Ayuda** | El botón **?** de la barra superior explica cada sección dentro de la app. |

Todo se guarda primero en el dispositivo (carga instantánea y funciona sin
conexión) y se sincroniza con la API cuando hay sesión e internet.

## Guía rápida de uso

1. **Inicia sesión** con el usuario `wifey` o `husband` y la contraseña que se
   configuró en el servidor.
2. **Crea tus categorías** (por ejemplo *Hombre*, *Mujer*, *Unisex*) en la
   pestaña **Categorías**, o directamente desde el formulario de producto con
   *Registrar categoría*.
3. **Agrega productos** con el botón **Nuevo**: nombre, precio, existencia y el
   número con el que quieres que te avise (*Avisarme cuando queden*).
4. **Cada venta** se registra con `−1 VENTA` en la tarjeta del producto; cada
   compra o reposición con `+1 ENTRADA`, o con **Ajustar** si son varias unidades.
5. **Revisa el Resumen** cada día: verás tus ganancias y qué productos hay que
   reabastecer.
6. **En Finanzas**, define tu fondo inicial y anota tus gastos para conocer tu
   saldo disponible.

---

## Qué necesitas instalar

| Herramienta | Versión | Para qué | Obligatorio |
| --- | --- | --- | --- |
| [Flutter SDK](https://docs.flutter.dev/get-started/install) | estable (Dart ≥ 3.4) | Compilar y ejecutar la app | Sí |
| Google Chrome | reciente | Ejecutar la app en modo desarrollo | Sí |
| [Node.js](https://nodejs.org/) | 22 o superior | Ejecutar la API | Sí |
| MySQL | 8.x | Base de datos (local, [Aiven](https://aiven.io/) u otro) | Sí |
| Cuenta de [Cloudinary](https://cloudinary.com/) | gratuita | Guardar fotos y videos de productos | Sí¹ |
| [Docker](https://www.docker.com/) | reciente | Levantar MySQL local con un comando | No |
| Python | 3.10 o superior | Generador de modelos 3D | No |
| Android Studio / Xcode | reciente | Compilar APK Android / app iOS nativa | No |

¹ La API no arranca sin las tres variables de Cloudinary. Para probar en local
puedes usar valores de relleno; solo fallará la subida de fotos.

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
CLOUDINARY_CLOUD_NAME=...
CLOUDINARY_API_KEY=...
CLOUDINARY_API_SECRET=...
ALLOWED_ORIGINS=http://localhost:8080
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
| `CLOUDINARY_CLOUD_NAME` | Sí | Nombre de tu cuenta de Cloudinary. |
| `CLOUDINARY_API_KEY` | Sí | API key de Cloudinary. |
| `CLOUDINARY_API_SECRET` | Sí | API secret de Cloudinary. |
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
  src/screens/            Pantallas (inicio, login, producto, stock, categorías)
  src/widgets/            Mascota, banner e instalación PWA
test/                     Pruebas de lógica y de pantallas
web/                      index.html, manifest e íconos de la PWA
backend/                  API Express + TypeScript
  src/server.ts           Rutas de la API
  src/migrate.ts          Aplica schema.sql
  schema.sql              Tablas MySQL
  tools/model3d/          Generador de modelos 3D (Python)
docker-compose.yml        MySQL local para desarrollo
render.yaml               Despliegue de la API en Render
viewer3d/                 Visor 3D independiente (Vite + three.js)
```
