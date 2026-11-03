# Factory Arena

Abrir Scenes/FactoryArena.unity. Vista local independiente; no contiene NetworkManager.

## Prueba manual
Entrar en Play Mode. En Lever_A o Lever_B, usar el menú contextual del componente ControlLever > Activate sabotage. Activaciones durante los seis segundos activos se ignoran. Los cubos Rigidbody se pueden colocar sobre las cintas (centro y=1, z=5 o -5).

## Integración futura
ConveyorBelt.Velocity expone la velocidad superficial. Transporta Rigidbody dinámicos en contacto superior, preservando la velocidad vertical. El controlador futuro puede consumir Velocity en lugar de esta respuesta física; no conectar ambos métodos a la vez. No utiliza TestPlayer. Al salir de contacto ya no aplica velocidad; el cuerpo conserva su inercia física.
ControlLever.Activate es el punto de entrada para una futura interacción mantenida. La inversión restaura la dirección anterior; llamadas repetidas durante el efecto son ignoradas.
HydraulicPress.state y los tiempos del Inspector describen el ciclo. HazardZone.detected entrega el GameObject con Rigidbody; puede invocarse repetidamente mientras permanece dentro y debe conectarse a lógica idempotente. No aplica daño, elimina ni reaparece jugadores.
Todos los mecanismos son locales. La futura integración debe autorizar cambios desde el host y replicar estados y tiempo de ciclo; no sincronizar cada pieza decorativa.

## Verificación ejecutada
Compilación limpia. Dos cubos Rigidbody: desplazamiento normal e invertido ±1.76456 por segundo, velocidad acelerada ±3.5, parada 0. Ambas palancas invierten y restauran, incluyendo doble activación. Prensa recorre los cinco estados. Raycasts desde los cuatro spawns encuentran suelo. Cápsula fuera del borde activó una vez FallDetection.
LocalValidation.txt conserva las medidas de Play Mode. FactoryValidation es un componente de pruebas opcional; no está guardado en la escena.

No se realizó una partida de red con este mapa ni una prueba de rendimiento en hardware de gama media.
