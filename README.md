# Eco — Videojuego de Memoria Táctil y Reflejos

**Asignatura:** Desarrollo de Aplicaciones Móviles  
**Unidad:** Unidad 2 (Práctica Integradora 2)  
**Integrante:** Pamela Urbán García  
**Plataforma Objetivo:** Android (Flutter & Dart)  

---

## 📌 Descripción del Proyecto
**Eco** es un juego móvil original diseñado para trabajar la memoria espacial y la atención mediante retroalimentación háptica (vibración) y estímulos visuales controlados. El jugador cuenta con 10 segundos para memorizar el laberinto al inicio de cada partida; una vez transcurrido este tiempo, el mapa desaparece y el usuario debe guiarse a ciegas utilizando controles de movimiento y avisos de vibración graduada cuando se acerca peligrosamente a los bordes.

---

## 🛠️ Tecnologías y Herramientas Utilizadas
* **Framework:** Flutter (Dart)
* **Entorno de desarrollo:** Visual Studio Code / Android Studio
* **Control de versiones:** Git y GitHub
* **Librerías principales:** 
  * `sensors_plus` (Gestión de sensores y acelerómetro)
  * `vibration` (Control de patrones y pulsos hápticos)

---

## 🎮 Características del Producto Mínimo Funcional (PMF)
1. **Fase de Memorización:** Visualización previa del laberinto con un temporizador descendente de 10 segundos.
2. **Modo de Control:** Compatible con acelerómetro móvil y controles por teclado (flechas de dirección) para pruebas en escritorio.
3. **Sistema Háptico Graduado:** Emisión de pulsos de vibración según la proximidad a los muros del laberinto.
4. **Indicador Visual de Peligro:** Destello e iluminación de alerta cuando el jugador se encuentra cerca de un borde.
5. **Sistema de Oportunidades y Racha:** Gestión de 3 vidas/oportunidades y puntuación acumulativa al completar el recorrido con éxito desde el punto de **INICIO** hasta el **FIN**.

---

## 📂 Estructura del Repositorio
```text
eco/
│
├── lib/
│   └── main.dart          # Lógica principal, pantallas (Menú, Juego, Resultados) y controles
├── android/               # Configuración nativa para Android
├── ios/                   # Configuración nativa para iOS
├── pubspec.yaml           # Dependencias y configuración del proyecto Flutter
└── README.md              # Documentación y bitácora del proyecto
