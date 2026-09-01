# My Love Depot

Aplicación de inventario local pensada para tablets, creada con Flutter y lista
para compilarse como PWA o APK Android.

## Funciones del MVP

- Dashboard con existencias, valor total y alertas de stock bajo.
- Alta y edición de productos (nombre, SKU, categoría, precio y existencia).
- Catálogo de categorías registrables, con desplegable en el formulario.
- Entradas y salidas de inventario con validación de existencias.
- Buscador y filtros por estado.
- Historial de movimientos.
- Persistencia local en el dispositivo y datos de demostración iniciales.
- Escaneo de códigos de barras y QR con acceso directo a registrar stock.
- Captura de hasta cinco vistas verificadas del producto.
- Modelo 3D generado en el servidor a partir de esas fotos, sin pedir URLs.
- Inicio de sesión JWT para los roles `wifey` y `husband`.

## Categorías

Las categorías viven en su propia tabla y se administran desde la pestaña
**Categorías**: se crean, se renombran (el cambio se propaga a los productos que
las usan) y se eliminan cuando ningún producto las ocupa. El formulario de
producto ya no pide escribir la categoría a mano: la elige de un desplegable, y
desde ahí mismo se puede registrar una nueva sin cerrar el formulario.

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

Los datos se conservan localmente para una carga rápida y se sincronizan con la
API cuando existe una sesión válida y conexión disponible.

## Cámara, códigos y vistas del producto

Al escanear un código existente se abre el formulario de entrada de stock con
una unidad sugerida; el usuario confirma la cantidad. Si el código es nuevo, se
abre el formulario con el código precargado. Chrome debe
tener permiso para usar la cámara y la PWA debe servirse mediante HTTPS.

El formulario exige una vista frontal y acepta hasta cuatro vistas adicionales
(Frente, Atrás, Izquierda, Derecha y Arriba). Antes de subirla, la API comprueba
resolución, enfoque, iluminación, contraste con el fondo, encuadre y centrado.
Si la captura no sirve para obtener una silueta limpia, la app explica qué debe
corregirse y obliga a repetir el escaneo.

## Modelo 3D a partir de las fotos

El formulario ya no pide una URL `.glb` ni `.gltf`. Cuando se guardan fotos
nuevas, la API reconstruye el modelo con el generador de `backend/tools/model3d`,
escrito en Python (numpy y Pillow). El detalle del producto lo muestra en un
visor que se puede girar, con un botón para regenerarlo.

El método es **casco visual** (*shape from silhouette*):

1. Cada foto se segmenta para separar el producto del fondo y quedarse con su
   silueta.
2. Las razones de aspecto de las siluetas resuelven las proporciones X:Y:Z del
   producto por mínimos cuadrados.
3. Cada silueta se extruye a lo largo del eje desde el que se fotografió y el
   volumen es la **intersección** de todas esas extrusiones.
4. La superficie se extrae de los vóxeles, se relaja con un suavizado de Taubin
   y se texturiza proyectando sobre cada cara la foto que la mira de frente.
5. El resultado se escribe como `.glb` con la textura embebida y se sube a
   Cloudinary.

Conviene saber qué es y qué no es. Con cinco vistas ortogonales el contorno sale
exacto y **no se inventa nada**: se obtiene el volumen más pequeño compatible con
las fotos. Lo que este método no puede recuperar son las concavidades, porque
ninguna silueta las delata; un tazón sale como un cilindro macizo. No es
fotogrametría y no pretende serlo.

Con una sola foto frontal se genera un avatar `.glb` completamente giratorio,
pero la profundidad es una aproximación proporcional porque la cámara no ve la
parte trasera ni los costados. Cada vista adicional reemplaza parte de esa
estimación con geometría observada y mejora la fidelidad.

Las fotos salen mucho mejor con **fondo liso y contrastado**: de ahí depende la
segmentación. Si ninguna foto se puede separar del fondo, la API responde con un
mensaje que lo explica en lugar de generar un modelo inservible.

El generador también se puede usar suelto, sin la API:

```powershell
cd backend/tools/model3d
pip install -r requirements.txt
python build_model.py --input <carpeta-con-view-0..4> --output producto.glb
```

Acepta `--resolution` (lado de la rejilla de vóxeles, 56 por omisión) y
`--smooth` (pasadas de suavizado, 4 por omisión).

## Backend, MySQL y Cloudinary

La API está en `backend/`. Guarda productos y movimientos en MySQL y sube las
fotografías a Cloudinary. Las credenciales nunca deben agregarse a Flutter ni
confirmarse en Git.

```powershell
cd backend
Copy-Item .env.example .env
npm install
pip install -r tools/model3d/requirements.txt
npm run db:init
npm run dev
```

En Windows el ejecutable de Python suele llamarse `python` y no `python3`; en ese
caso agrega `MODEL3D_PYTHON=python` a `backend/.env`. La imagen Docker instala su
propio intérprete y ya trae la variable configurada.

Completa primero `backend/.env` con la conexión MySQL, el certificado CA de
Aiven codificado en Base64, las tres credenciales de Cloudinary y una clave
propia larga para `JWT_SECRET`, además de las contraseñas de `wifey` y `husband`.
El despliegue ejecuta automáticamente la
creación de tablas antes de iniciar la API.

Para conectar Flutter durante desarrollo:

```powershell
flutter run -d chrome `
  --dart-define=API_BASE_URL=http://localhost:3000
```

En producción usa la URL HTTPS de la API y configura `ALLOWED_ORIGINS` con el
dominio exacto de la PWA. El JWT se obtiene al iniciar sesión y no se compila
ninguna contraseña dentro del frontend.

### Desplegar la API en Render

El archivo `render.yaml` de la raíz define un Web Service Docker gratuito con
directorio `backend/` y health check en `/health`.

1. Sube el repositorio a GitHub.
2. En Render selecciona **New → Blueprint** y conecta el repositorio.
3. Render detectará `render.yaml` y solicitará las variables marcadas como
   secretas.
4. Usa en `DATABASE_URL` la URI MySQL entregada por Aiven.
5. Agrega las tres credenciales de Cloudinary.
6. Configura `JWT_SECRET`, `WIFEY_PASSWORD` y `HUSBAND_PASSWORD` como secretos.
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
