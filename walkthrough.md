# Mejoras en Modelo 3D, Guía de Encuadre y Descarga PWA (iOS/Android)

## 1. Renderizado 3D y Colores de Caras Faltantes (`atlas.py`)
- **Problema solucionado**: Cuando el usuario subía 1 o 2 fotos (por ejemplo solo la frontal), los laterales y la parte posterior se proyectaban sobre celdas neutras vacías de tono grisáceo.
- **Solución implementada**:
  - **Mapeo Inteligente de Vistas**: Si falta la vista posterior (Atrás), se genera usando la vista frontal volteada horizontalmente. Si faltan los laterales (Izquierda/Derecha), se sintetizan con el reflejo lateral o la vista frontal.
  - **Extracción de Color Dominante del Producto**: Se calcula el color mediano de los píxeles internos del producto para rellenar los bordes neutros del atlas de textura. Las caras ya no se ven grises ni planas, sino con el color vibrante exacto del producto.

## 2. Guía Interactiva de Encuadre de Fotos (`product_form.dart`)
- **Marco de Encuadre Interactivo (Dialog `_openCameraGuide`)**:
  - Se agregó una retícula y caja de encuadre con miras de cámara (`_FramingGridPainter`) para que el usuario sepa exactamente dónde colocar y centrar el objeto.
  - Indicador de orientación por ángulo (Frente 📷, Atrás 🔄, Izquierda 👈, Derecha 👉, Arriba 👆).
  - Indicadores con tips de iluminación, contraste de fondo y evitar recortar bordes.
  - Contador de progreso: `1 / 5 fotos capturadas` (indicando cuándo es suficiente para generar el avatar 3D).

## 3. Descarga e Instalación de App en iOS y Android (`index.html`, `manifest.json`, `home_screen.dart`)
- **Botón "DESCARGAR APP" en AppBar**:
  - Se añadió el botón de descarga en el AppBar principal.
- **Modal con Guía Paso a Paso para iOS y Android**:
  - **iOS (iPhone/iPad en Safari)**:
    1. Tocar el botón **Compartir** (cuadro con flecha ⎋).
    2. Seleccionar **"Agregar a inicio"** (Add to Home Screen 📲).
    3. Tocar "Agregar" para instalar como aplicación nativa.
  - **Android / Chrome / Edge**:
    1. Tocar el menú de tres puntos (⋮).
    2. Seleccionar **"Instalar aplicación"** o **"Agregar a la pantalla principal"**.
- **Configuración PWA nativa (`web/manifest.json` y `web/index.html`)**:
  - Encabezados `mobile-web-app-capable`, `apple-touch-icon`, `theme-color` `#d94f87` y manejador de evento `beforeinstallprompt`.

---

## Estado en GitHub
Todos los cambios están subidos en el commit `bedb59a` en la rama `main` del repositorio `EnriqueLanda2/myLoveDepot`.
