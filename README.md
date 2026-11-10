# UmlStudio Mobile Assistant (Voice & Chat NLU)

Asistente móvil inteligente con IA local (STT Vosk offline + TTS Android nativo + NLU slot-filling dinámico), diseñado para interactuar de forma **universal y desacoplada** con cualquier backend Spring Boot generado a partir de diagramas de clases en **UmlStudio**.

---

## 🚀 Características Principales

1. **Compatibilidad Universal con UmlStudio (Zero Code Coupling & Soporte UUID):**
   * Lee e ingesta dinámicamente el contrato OpenAPI 3.0 (`/v3/api-docs`) generado por UmlStudio.
   * Resuelve entidades, campos obligatorios, tipos de datos y rutas pluralizadas (`/api/{entidad}`) en tiempo de ejecución.
   * **Soporte de Modelos Empresariales Complejos y UUIDs:** Totalmente compatible con esquemas con identificadores UUID (36 caracteres) y enteros.
   * **Navegación Ordinal por Voz:** Permite interactuar con registros mediante expresiones naturales (*"eliminar el primero"*, *"consultar el segundo"*, *"borrar el último"*), resolviendo el UUID exacto sin exigir al usuario dictar hashes hexadecimales complejos.
   * **Búsqueda por Clave Natural:** Reconoce nombres o títulos hablados (*"eliminar cliente Juan"*, *"consultar experiencia Safari"*) mapeándolos a su ID correspondiente.
   * Funciona automáticamente con cualquier modelo de dominio (Ventas, Experiencias, Turismo, Pagos, Escuela, etc.) sin recompilar la app.

2. **Modo Voz en Vivo (Estilo Gemini Live con Paginación Conversacional):**
   * Interfaz inmersiva *Voice-First* con un **Orbe Fluido Multidimensional** que reacciona visualmente según el estado (Escuchando, Procesando, Respondiendo).
   * Motor de reconocimiento acústico offline con **Vosk Engine** en español (~43 MB), sin consumo de datos ni latencia de red.
   * Síntesis de voz natural en español mediante el motor nativo de Android (**Google TTS**).
   * **Paginación y Resumen Conversacional (Primeros 5 Registros):** Al consultar listas extensas, verbaliza con claridad los primeros 5 elementos y resume el resto (*"Se encontraron 19 registros para Experiencia. Los primeros 5 son: Safari, Buceo... y 14 registros más. Podés verlos todos en el Explorador o consultar uno por su posición o nombre"*), evitando la fatiga auditiva.
   * **Aislamiento Acústico Inteligente:** Silencia el micrófono durante la respuesta del altavoz para evitar retroalimentación en bucle (*acoustic echo loop*) y añade un margen de disipación de 400 ms.
   * **Temporizador de Fin de Enunciado (Debounce de 900 ms):** Evita la fragmentación de oraciones ante pausas naturales al hablar.

3. **Modo Chat Tradicional:**
   * Alternancia instantánea a vista de chat con historial de conversación.
   * Entrada de texto por teclado con sugerencias contextuales y confirmaciones de mutación.

4. **Explorador de Base de Datos Dinámico (Data Studio con Selectores Relacionales):**
   * Panel visual que lista automáticamente todas las tablas detectadas desde el esquema OpenAPI.
   * Acordeones colapsables por entidad con visualización detallada de registros, recuento dinámico y claves foráneas/atributos.
   * **Selectores Relacionales en Cascada (Dropdowns para `*_id`):** Al crear o editar registros que posean claves foráneas (`cliente_id`, `user_id`, `experiencia_id`, etc.), el sistema detecta la entidad padre y despliega un menú desplegable con los nombres y registros reales de esa tabla, vinculando su UUID/ID automáticamente.
   * **Selectores Booleanos Dinámicos:** Manejo directo de campos booleanos mediante selector Verdadero/Falso.
   * Modales interactivos para **Crear**, **Editar** y **Eliminar** registros de forma visual.
   * **Atajo de Voz In-Situ:** Permite emitir comandos hablados directamente sobre el explorador, ejecutando las operaciones en el backend y refrescando la pantalla en tiempo real sin navegar fuera de ella.

5. **Resolución Léxica de Numerales Hablados en Español:**
   * Parser integrado (`_spanishWordToNumber`) capaz de resolver palabras numéricas (*"tres"*, *"siete"*, *"veintidós"*, *"el número cuatro"*) a identificadores enteros (`3`, `7`, `22`, `4`), garantizando que las órdenes de eliminación y consulta por voz funcionen con naturalidad.

---

## 🛠️ Requisitos Previos

* **Java Development Kit (JDK):** Versión 17 o 21.
* **Flutter SDK:** Versión 3.10.7 o superior (`flutter --version`).
* **Android SDK / Herramientas de Plataforma:** `adb` configurado en el `PATH`.
* **Dispositivo Físico o Emulador Android:** Android 11+ (API 30+), con depuración USB habilitada.
* **Motor Google TTS:** Paquete `com.google.android.tts` instalado en el dispositivo.

---

## 📋 Guía de Despliegue y Pruebas Paso a Paso

### Paso 1: Generación del Backend en UmlStudio

1. Diseñar el diagrama de clases en la aplicación web de **UmlStudio**.
2. Exportar o generar el código fuente Spring Boot mediante el servicio de generación de código (`codegen`).
3. El proyecto generado incluirá las entidades JPA, repositorios, controladores REST y la documentación Springdoc OpenAPI 3.0.

> *Nota: Este repositorio ya incluye un backend real generado en la carpeta `backend_generated/` para el sistema `VentaSystem` (Entidades: `Cliente`, `Producto`, `Venta`).*

---

### Paso 2: Compilación y Puesta en Marcha del Backend

Abre una terminal en tu equipo anfitrión:

```bash
cd backend_generated
./mvnw clean spring-boot:run
```

El servidor Spring Boot iniciará en el puerto `8080`. Para verificar que la API REST y el contrato OpenAPI estén activos:

```bash
curl -s http://localhost:8080/v3/api-docs | head -c 100
```
Debe responder con el JSON del contrato OpenAPI (`{"openapi":"3.1.0","info":...}`).

---

### Paso 3: Redirección de Red mediante ADB (Túnel Inverso USB)

Para que el dispositivo Android físico conectado por USB pueda comunicarse con `http://localhost:8080` de tu laptop sin depender de redes WiFi comunes ni configurar IPs manuales, ejecuta:

```bash
adb reverse tcp:8080 tcp:8080
```

Verifica que el túnel esté activo:
```bash
adb reverse --list
# Salida esperada: (dispositivo) tcp:8080 tcp:8080
```

---

### Paso 4: Configuración del Dispositivo Android

Asegúrate de que el motor de voz por defecto sea Google TTS:

```bash
adb shell settings put secure tts_default_synth com.google.android.tts
```

Verifica el volumen multimedia:
```bash
adb shell cmd media_session volume --stream 3 --set 12
```

---

### Paso 5: Compilación e Instalación de la Aplicación Flutter

Desde la raíz de este proyecto (`UmlStudioADB`):

```bash
# 1. Instalar dependencias
flutter pub get

# 2. Ejecutar suite de pruebas de regresión
flutter test

# 3. Compilar APK debug
flutter build apk --debug

# 4. Instalar en el dispositivo conectado
adb install -r build/app/outputs/flutter-apk/app-debug.apk

# 5. Iniciar la aplicación
adb shell am start -n com.umlstudio.umlstudio_mobile/.MainActivity
```

---

## 🗣️ Catálogo de Comandos de Voz Admitidos

| Intención | Ejemplos de Frases Habladas | Acción Ejecutada |
| :--- | :--- | :--- |
| **Listar Todos** | *"Listar clientes"*, *"Mostrar productos"*, *"Ver ventas"* | `GET /api/{entidad}` con verbalización clara (hasta 5 items) y resumen del excedente. |
| **Navegación Ordinal** | *"Eliminar el primero"*, *"Consultar el segundo"*, *"Borrar el último"* | Resuelve la posición sobre la lista previa y despacha la acción (compatible con UUID e Integer). |
| **Búsqueda Clave Natural** | *"Eliminar cliente Juan"*, *"Consultar Auriculares"* | Resuelve el ID a partir del nombre o título hablado. |
| **Consultar por ID** | *"Consultar cliente con ID 1"*, *"Ver producto dos"*, *"Ver experiencia [UUID]"* | `GET /api/{entidad}/{id}` con lectura de atributos. |
| **Creación Asistida (Multi-Turno)** | *"Registrar nuevo cliente"* | La máquina entra en recolección de ranuras (*slot-filling*) y repregunta: *¿Cuál es el valor para el campo obligatorio: nombre?* |
| **Creación Directa** | *"Crear producto nombre Teclado precio 45"* | Extrae ranuras simultáneas y dispara `POST /api/{entidad}` en un solo turno. |
| **Actualización** | *"Actualizar cliente con id 1 nombre Carlos edad 38"* | `PUT /api/{entidad}/{id}` con los campos modificados. |
| **Eliminación con Numerales** | *"Eliminar cliente siete"*, *"Borrar producto con ID tres"* | `DELETE /api/{entidad}/{id}` resolviendo numerales hablados a dígitos enteros. |
| **Cancelación** | *"Cancelar"*, *"Salir"*, *"Olvídalo"* | Limpia el estado conversacional y restablece la máquina FSM. |

---

## 🗄️ Explorador de Base de Datos (Data Studio)

Puedes acceder pulsando el icono de tabla (**📊**) en la barra superior tanto desde el **Modo Voz en Vivo** como desde el **Modo Chat**.

* **Listado de Tablas:** Muestra todas las tablas detectadas en `/v3/api-docs` con su conteo de registros.
* **Acordeón Colapsable:** Toca cualquier tabla (ej. `Cliente`) para desplegar sus registros en tiempo real.
* **Operaciones CRUD Visuales:**
  * **+ (Agregar):** Abre un formulario dinámico según los campos del esquema OpenAPI.
  * **✏️ (Editar):** Modifica los campos existentes del registro.
  * **🗑️ (Eliminar):** Confirma y elimina el registro de la base de datos.
* **Atajo de Voz In-Situ:** En la parte inferior se encuentra un muelle de voz flotante. Puedes decir por ejemplo *"eliminar cliente siete"* y la tabla se actualizará automáticamente frente a tus ojos sin salir de la pantalla.

---

## 🧪 Verificación y Pruebas Automatizadas

El proyecto cuenta con una pirámide de pruebas unitarias y de widgets que cubren:

1. **Parser OpenAPI:** Extracción de entidades, propiedades requeridas y rutas kebab-plurales.
2. **Máquina de Estados FSM:** Diálogos multi-turno, tolerancia fonética (Levenshtein), coerción de tipos y cancelación.
3. **Parser de Numerales en Español:** Pruebas unitarias para palabras numéricas (*"tres"*, *"siete"*, *"el dos"*).
4. **Widgets & UI:** Renderizado del Orbe fluido, navegación entre vistas y explorador de base de datos.

Para ejecutar los tests:

```bash
flutter test
```
*Resultado esperado: 31/31 tests aprobados (100% verde).*

---

## 📐 Estructura del Código

```text
lib/
├── core/
│   └── theme/                    # Tokens de diseño Obsidian, CanvasGridPainter
├── features/
│   ├── audio/
│   │   └── data/                 # VoskAudioService (STT offline) y TtsService (TTS nativo)
│   ├── chat/
│   │   ├── presentation/         # ChatScreen, ChatViewModel
│   │   ├── views/                # VoiceLiveView (Gemini Live)
│   │   └── widgets/              # FluidVoiceOrb, ChatMessageBubble
│   ├── database/
│   │   └── presentation/         # DatabaseExplorerScreen (CRUD visual y voz in-situ)
│   ├── nlu/
│   │   └── logic/                # DialogStateMachine (FSM, Levenshtein, SpanishNumberParser)
│   └── schema/
│       ├── data/                 # SchemaRepository, OpenApiParser
│       └── domain/               # EntityDescriptor, FieldDescriptor
└── main.dart                     # Punto de entrada de la aplicación
```
