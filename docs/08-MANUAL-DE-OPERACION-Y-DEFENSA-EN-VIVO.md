# Documento 08: Manual de Operación y Protocolo de Defensa en Vivo

## 1. Guía Rápida para el Día de la Defensa

Este manual resume los pasos exactos que debe seguir el estudiante durante la evaluación ante el jurado o profesor, cubriendo desde el escaneo del diagrama hasta la demostración por voz en modo avión.

---

## 2. Lista de Comprobación Previa (Pre-Flight Checklist)

* [ ] Laptop con cargador conectado (para evitar estrangulamiento térmico de la CPU en batería).
* [ ] Cable USB de datos de alta calidad (evitar cables exclusivamente de carga que no transmiten datos).
* [ ] Teléfono Android con batería superior al 50% y pantalla configurada para no apagarse automáticamente (*Permanecer activa durante la carga* en Opciones de Desarrollador).
* [ ] Volumen multimedia del teléfono configurado al 80% con el motor de voz en español probado previamente.
* [ ] Terminal abierta en la laptop con el comando preparado: `adb reverse tcp:8080 tcp:8080`.

---

## 3. Guion de Demostración para 5 Escenarios de Diagramas Posibles

Dado que el profesor presentará un diagrama sorpresa, a continuación se presentan los guiones exactos de interacción verbal para los 5 dominios de negocio más habituales en exámenes de ingeniería de software:

### Escenario 1: Comercio Electrónico / Ventas
* **Entidades Típicas:** `Cliente`, `Producto`, `Venta`.
* **Diálogo de Demostración:**
  1. *Estudiante:* *"Listar clientes"*
     * *Sistema:* *"No hay registros cargados para Cliente."*
  2. *Estudiante:* *"Registrar un nuevo cliente llamado Martín"*
     * *Sistema (TTS):* *"¿Cuál es el valor para el campo obligatorio: email, telefono?"*
  3. *Estudiante:* *"Su email es martin@correo.com y telefono 112233"*
     * *Sistema (TTS):* *"Registro de Cliente creado exitosamente en el servidor."*
  4. *Estudiante:* *"Mostrar clientes"*
     * *Sistema:* *"Se encontraron 1 registros para Cliente."* (Despliega tarjeta con los datos de Martín).

### Escenario 2: Sistema Hospitalario / Clínica Médica
* **Entidades Típicas:** `Paciente`, `Medico`, `Cita`.
* **Diálogo de Demostración:**
  1. *Estudiante:* *"Crear nuevo médico"*
     * *Sistema (TTS):* *"¿Cuál es el valor para el campo obligatorio: nombre, especialidad, matricula?"*
  2. *Estudiante:* *"Nombre Andrea especialidad Cardiologia matricula 5544"*
     * *Sistema (TTS):* *"Registro de Medico creado exitosamente en el servidor."*
  3. *Estudiante:* *"Consultar medicos"*
     * *Sistema:* *"Se encontraron 1 registros para Medico."*

### Escenario 3: Gestión Hotelera
* **Entidades Típicas:** `Huesped`, `Habitacion`, `Reserva`.
* **Diálogo de Demostración:**
  1. *Estudiante:* *"Registrar habitacion con numero 204"*
     * *Sistema (TTS):* *"¿Cuál es el valor para el campo obligatorio: tipo, precio?"*
  2. *Estudiante:* *"Tipo Suite y precio 120"*
     * *Sistema (TTS):* *"Registro de Habitacion creado exitosamente en el servidor."*

### Escenario 4: Biblioteca / Sistema Universitario
* **Entidades Típicas:** `Estudiante`, `Libro`, `Prestamo`.
* **Diálogo de Demostración:**
  1. *Estudiante:* *"Agregar libro llamado Don Quijote"*
     * *Sistema (TTS):* *"¿Cuál es el valor para el campo obligatorio: isbn, autor?"*
  2. *Estudiante:* *"Autor Cervantes e isbn 97801"*
     * *Sistema (TTS):* *"Registro de Libro creado exitosamente en el servidor."*

### Escenario 5: Alquiler de Vehículos
* **Entidades Típicas:** `Vehiculo`, `Conductor`, `Contrato`.
* **Diálogo de Demostración:**
  1. *Estudiante:* *"Nuevo vehiculo marca Toyota modelo Corolla"*
     * *Sistema (TTS):* *"¿Cuál es el valor para el campo obligatorio: patente, anio?"*
  2. *Estudiante:* *"Patente AF123 y anio 2024"*
     * *Sistema (TTS):* *"Registro de Vehiculo creado exitosamente en el servidor."*

---

## 4. Matriz de Contingencia y Respuesta ante Preguntas Difíciles del Jurado

### Pregunta 1: *"¿Cómo sé que la aplicación no se está comunicando con OpenAI o Google en secreto?"*
* **Demostración de Respuesta:** Active el **Modo Avión** en el teléfono móvil frente a ellos. Desconecte el Wi-Fi de la laptop. Luego ejecute una orden por voz. El sistema responderá normalmente, demostrando de forma empírica que el modelo Vosk y el backend corren aislados sin acceso a WAN.

### Pregunta 2: *"¿Qué sucede si el diagrama tiene una relación entre entidades como una Venta con Cliente?"*
* **Demostración de Respuesta:** Explique que el generador de UmlStudio mapea las relaciones de clave foránea como atributos identificadores (ej. `clienteId`). Cuando el usuario intenta registrar una Venta, el motor NLU detecta que `clienteId` es requerido y solicita por voz: *"¿Cuál es el identificador de cliente para esta venta?"*.

### Pregunta 3: *"Si el cable USB se desconecta accidentalmente, ¿qué ocurre?"*
* **Acción de Recuperación Inmediata:**
  1. Reconectar el cable.
  2. Ejecutar nuevamente en la terminal: `adb reverse tcp:8080 tcp:8080`.
  3. Tocar el botón de estado en la parte superior de la app para refrescar el esquema. La recuperación toma menos de 4 segundos.
