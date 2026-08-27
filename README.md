# My Love Depot

Aplicación de inventario local pensada para tablets, creada con Flutter y lista
para compilarse como PWA o APK Android.

## Funciones del MVP

- Dashboard con existencias, valor total y alertas de stock bajo.
- Alta y edición de productos (nombre, SKU, categoría, precio y existencia).
- Entradas y salidas de inventario con validación de existencias.
- Buscador y filtros por estado.
- Historial de movimientos.
- Persistencia local en el dispositivo y datos de demostración iniciales.
- Escaneo de códigos de barras y QR con incremento automático de stock.
- Captura de fotografía desde la cámara o selección desde la galería.
- Visualizador interactivo para modelos 3D en formato GLB o glTF.

## Ejecutar

1. Instala [Flutter](https://docs.flutter.dev/get-started/install/windows/mobile).
2. Verifica la instalación con `flutter doctor`.
3. Desde esta carpeta ejecuta:

```powershell
flutter pub get
flutter run -d chrome
```

Para generar la PWA de producción:

```powershell
flutter build web --release
```

Los archivos resultantes estarán en `build/web`. Deben publicarse mediante
HTTPS para que la instalación y el service worker funcionen correctamente.

Para generar un APK instalable en una tablet Samsung, primero crea los archivos
nativos que no se guardan en este repositorio y luego compila:

```powershell
flutter create --platforms=android .
flutter build apk --release
```

## Instalación en una tablet Samsung

Abre la URL publicada con Chrome, toca el menú de tres puntos y elige
**Instalar aplicación** o **Agregar a pantalla principal**. La PWA se abrirá en
modo independiente, como una app.

> Este MVP guarda la información en un solo dispositivo. Para sincronizar varias
> tablets, compartir usuarios o respaldar datos en la nube hará falta agregar un
> backend.

## Cámara, códigos y modelos 3D

Al escanear un código existente se registra una entrada de una unidad. Si el
código es nuevo, se abre el formulario con el código precargado. Chrome debe
tener permiso para usar la cámara y la PWA debe servirse mediante HTTPS.

La fotografía y el modelo 3D son recursos distintos. Una fotografía se guarda
directamente con el producto; para la vista 3D se proporciona una URL pública a
un archivo `.glb` o `.gltf` con CORS habilitado. Generar automáticamente un
modelo 3D real requiere varias fotos y un proceso o servicio de fotogrametría.

## Backend, MySQL y Cloudinary

La API está en `backend/`. Guarda productos y movimientos en MySQL y sube las
fotografías a Cloudinary. Las credenciales nunca deben agregarse a Flutter ni
confirmarse en Git.

```powershell
cd backend
Copy-Item .env.example .env
npm install
npm run db:init
npm run dev
```

Completa primero `backend/.env` con la conexión MySQL, el certificado CA de
Aiven codificado en Base64, las tres credenciales de Cloudinary y una clave
propia larga para `INVENTORY_API_KEY`. El despliegue ejecuta automáticamente la
creación de tablas antes de iniciar la API.

Para conectar Flutter durante desarrollo:

```powershell
flutter run -d chrome `
  --dart-define=API_BASE_URL=http://localhost:3000 `
  --dart-define=INVENTORY_API_KEY=tu-clave-de-inventario
```

En producción usa la URL HTTPS de la API y configura `ALLOWED_ORIGINS` con el
dominio exacto de la PWA. La clave compartida limita accesos casuales, pero antes
de admitir varios usuarios debe sustituirse por autenticación individual.

### Desplegar la API en Render

El archivo `render.yaml` de la raíz define un Web Service Docker gratuito con
directorio `backend/` y health check en `/health`.

1. Sube el repositorio a GitHub.
2. En Render selecciona **New → Blueprint** y conecta el repositorio.
3. Render detectará `render.yaml` y solicitará las variables marcadas como
   secretas.
4. Usa en `DATABASE_URL` la URI MySQL entregada por Aiven.
5. Agrega las tres credenciales de Cloudinary.
6. Genera y guarda una clave larga como `INVENTORY_API_KEY`.
7. En `ALLOWED_ORIGINS` coloca la URL final de la PWA, sin `/` al final.

Al iniciar, el contenedor aplica automáticamente `schema.sql`. No se guardan
archivos en el disco efímero de Render: las imágenes quedan en Cloudinary y los
datos en Aiven.

El servicio gratuito puede entrar en reposo después de un periodo sin tráfico.
Flutter muestra primero la copia local mientras Render despierta y después
sincroniza el inventario.

## Usar en iPhone

Para la PWA, publica `build/web` en un sitio HTTPS. En el iPhone abre la URL con
Safari, toca **Compartir** y después **Agregar a inicio**. Safari solicitará el
permiso de cámara la primera vez que se use el escáner.

Una aplicación iOS nativa solamente puede compilarse y firmarse en macOS con
Xcode. En una Mac ejecuta:

```bash
flutter create --platforms=ios .
flutter pub get
open ios/Runner.xcworkspace
```

Después selecciona el equipo de Apple Developer en Xcode, conecta el iPhone y
ejecuta `flutter run`. Para distribuir con TestFlight o App Store se necesita
una cuenta de Apple Developer.
