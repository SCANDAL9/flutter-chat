# Guía de Ejecución para la Demostración en Vivo (Paso a Paso)

Esta es tu guía rápida y lista para combate el día de la presentación. Sigue el orden exacto para evitar sorpresas o bloqueos técnicos.

---

## 📋 Resumen Previo (Arquitectura de la Demo)

```
[ Celular Android ]  ---> (USB ADB Reverse 8080/9000) ---> [ Laptop / PC ]
(flutter-chat app)                                         ├── Spring Boot (Puerto 9000)
                                                           └── PostgreSQL (Docker :5433)
```

---

## Paso 0: Levantar la Base de Datos PostgreSQL (Docker)

El backend generado exige PostgreSQL en el puerto `5433` con base de datos `umlstudio_demo`.

Abre una terminal en tu laptop y ejecuta:

```bash
docker run --name umlstudio-postgres-demo -e POSTGRES_DB=umlstudio_demo -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres -p 5433:5432 -d postgres:17-alpine
```

> **Verificación:** Si ya estaba creado de antes, solo enciéndelo:
> ```bash
> docker start umlstudio-postgres-demo
> ```

---

## Paso 1: Descomprimir y Levantar el Backend (`.zip`)

1. Coloca el `.zip` en tu carpeta de trabajo y descomprímelo:
   ```bash
   cd ~/Descargas/Proyectos/diagramador/test-export
   unzip -q test1.zip -d backend_demo
   cd backend_demo
   ```

2. Arranca el servidor Spring Boot:
   ```bash
   ./mvnw spring-boot:run
   ```

3. **Verificación visual en terminal:**
   Espera hasta ver:
   ```
   Started Test1Application in X.XXX seconds (process running for ...)
   Tomcat started on port 9000 (http) with context path '/'
   ```

> **Comprobación rápida (opcional en otra pestaña):**
> ```bash
> curl -s http://localhost:9000/v3/api-docs | head -n 5
> ```
> Debe responder el JSON de OpenAPI 3.0.

---

## Paso 2: Conectar el Teléfono y Tunelizar Puertos con ADB

1. Conecta el celular por cable USB (debe tener activada la **Depuración USB** en Opciones de Desarrollador).
2. En una terminal nueva, crea el puente de red para que el celular hable con tu laptop:
   ```bash
   adb reverse tcp:8080 tcp:9000
   adb reverse tcp:9000 tcp:9000
   ```
3. Verifica que los túneles estén activos:
   ```bash
   adb reverse --list
   ```
   *Debe listar `tcp:8080 tcp:9000` y `tcp:9000 tcp:9000`.*

---

## Paso 3: Abrir la Aplicación en el Teléfono

1. Toca el ícono de **UmlStudio Mobile** (`flutter-chat`) en tu teléfono.
2. Observa la barra superior:
   - Debe mostrar un **punto verde brillante**.
   - El texto dirá: `UmlStudio Live • 3 Entidades` (o el número de tablas de tu zip).
   - El Asistente de voz te dará la bienvenida: *"Esquema sincronizado con éxito. X entidades listas..."*.

*(Si por alguna razón ves el punto rojo, toca el botón de configuración de servidor arriba a la derecha y pon `http://localhost:8080` o `http://localhost:9000`).*

---

## Paso 4: Guión de la Demostración en Vivo

Te recomendamos seguir esta secuencia para impresionar a la audiencia mostrando primero lo más futurista (voz), luego el chat y finalmente la persistencia de datos:

### 🎙️ Bloque 1: Modo Voz en Vivo (Voz Offline + IA)
1. **Consulta general:**
   - Toca el orbe azul brillante o el micrófono inferior.
   - Di claro: *"Consultar materias"* o *"Dame las materias"*.
   - El asistente mostrará la transcripción en vivo y responderá por audio y en pantalla.
2. **Consulta puntual por ID:**
   - Toca el micrófono y di: *"Consultar materia con ID 4"* (o cualquier ID existente).
   - El asistente desglosará código, nombre y créditos.
3. **Registro conversacional asistido (Slot-filling):**
   - Di: *"Crear estudiante"*.
   - El asistente preguntará: *"¿Cuál es el valor para el campo obligatorio: nombre, apellido, email?"*.
   - Responde: *"Carlos, apellido Gómez, email carlos@universidad.edu"*.
   - Se creará el registro automáticamente en el servidor y te confirmará el ID creado.

---

### 💬 Bloque 2: Modo Chat Tradicional
1. En la barra superior, toca el botón **"Modo Chat"**.
2. Escribe una actualización para demostrar la edición:
   - `"modificar materia con id 4 nombre Cálculo Avanzado"`
   - Demuestra cómo el motor *read-merge-write* actualiza el nombre sin romper las restricciones de clave o créditos en Spring Boot.
3. Consulta registros con acentos y caracteres especiales:
   - `"consultar estudiantes"`
   - Verás cómo se renderizan tildes y eñes con total fidelidad UTF-8 sin caracteres extraños (*mojibake*).

---

### 📊 Bloque 3: Explorador de Base de Datos Visual
1. Toca el ícono de tabla en la barra superior (**"Base de Datos"**).
2. Muestra:
   - El acordeón con contadores de registros en vivo en cada tabla.
   - Despliega la tabla `Estudiante` o `Materia`.
   - Modifica un registro tocando el botón del lápiz (38dp de zona táctil fácil).
   - Crea un nuevo registro con el botón flotante `+ Crear nuevo...`.
   - Elimina un registro con confirmación protegida.

---

## 🚨 Plan de Contingencia (Respuestas a Imprevistos en Vivo)

| Situación | Causa Probable | Solución Inmediata en Vivo |
| :--- | :--- | :--- |
| **Punto rojo en la app (sin conexión)** | Cable USB se desconectó o ADB perdió el puente. | Corre en tu terminal: `adb reverse tcp:8080 tcp:9000` y toca el botón de sincronizar (flechas circulares). |
| **Error `HTTP 500` al consultar un ID** | Consultaste un ID que no existe y el backend no tiene `@RestControllerAdvice`. | Di con tranquilidad a la audiencia: *"Como el backend exportado no implementa aún el advice de excepciones, el servidor devuelve 500 ante entidades inexistentes, pero nuestra app lo captura sin caerse"*. |
| **La voz no reconoce bien por ruido de la sala** | Vosk escucha ruido ambiental fuerte. | Pasa inmediatamente al **Modo Chat** (botón arriba a la derecha) o usa el teclado. |
| **El backend dice `Address already in use: 9000`** | Dejaste otro proceso corriendo en el puerto 9000. | Mata el proceso ocupado: `lsof -ti :9000 \| xargs kill -9` y vuelve a correr `./mvnw spring-boot:run`. |

¡Con esto tienes todo el control técnico asegurado para la presentación!
