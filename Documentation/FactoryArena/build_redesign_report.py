from pathlib import Path
from html import escape
import base64, json
r=Path('C:/ProyectoFinalRV'); out=r/'Documentation/FactoryArena'; evidence=r/'Assets/FactoryArena/Generated/Redesign'
md=[]; html=[]
def heading(t,level=2): md.extend(['#'*level+' '+t,'']);html.append(f'<h{level}>{escape(t)}</h{level}>')
def p(t): md.extend([t,'']);html.append('<p>'+escape(t)+'</p>')
def bullets(items):
 md.extend(['- '+x for x in items]+['']);html.append('<ul>'+''.join('<li>'+escape(x)+'</li>' for x in items)+'</ul>')
def table(headers,rows):
 md.extend(['| '+' | '.join(headers)+' |','| '+' | '.join(['---']*len(headers))+' |']+['| '+' | '.join(map(str,x))+' |' for x in rows]+[''])
 html.append('<table><thead><tr>'+''.join('<th>'+escape(x)+'</th>' for x in headers)+'</tr></thead><tbody>'+''.join('<tr>'+''.join('<td>'+escape(str(x))+'</td>' for x in row)+'</tr>' for row in rows)+'</tbody></table>')
def photo(name,caption):
 path=evidence/(name+'.png');md.extend([f'![{caption}]({path.as_posix()})','']);data=base64.b64encode(path.read_bytes()).decode();html.append(f'<figure><img src="data:image/png;base64,{data}" alt="{escape(caption)}"><figcaption>{escape(caption)}</figcaption></figure>')
def link(path,label):
 md.extend([f'[{label}]({path.as_posix()})','']);html.append('<p><code>'+escape(str(path))+'</code> — '+escape(label)+'</p>')
heading('FÁBRICA MORTAL · Informe del rediseño visual',1)
p('Proyecto: C:\\ProyectoFinalRV. Cierre de la revisión: 2 de noviembre de 2026. Unity 6000.5.6f1 / URP 17.5.0. Este documento corresponde al rediseño con los dos paquetes Kenney; el informe Word anterior describe la primera versión del mapa.')
p('Resultado: la escena FactoryArena existente quedó transformada y guardada, con arquitectura exterior, maquinaria detallada, señalización, materiales derivados y animación visual vinculada a los mecanismos originales. La arena conserva su distribución y sus sistemas físicos. No se instaló ningún paquete ni se descargaron assets durante este rediseño.')
heading('1. Dirección artística y composición')
p('Fábrica industrial cartoon elevada, activa y ordenada. El azul acero forma la base; el amarillo identifica estructuras y maquinaria; el cian señala controles y zonas seguras; el rojo/naranja comunica peligro. La prensa sigue siendo el centro visual. La plataforma jugable mantiene aproximadamente 28 × 20 unidades, dentro de un recinto decorativo mayor.')
table(['Capa','Trabajo realizado'],[
('Arena','Suelo segmentado conservado, perfiles reforzados, tiras antideslizantes, marcos de aparición y perímetros de peligro.'),
('Maquinaria cercana','Prensa reconstruida visualmente; transmisiones de las cintas; paneles de control; plataformas laterales con maquinaria y cajas.'),
('Entorno exterior','Cinco edificios al fondo, dos laterales, depósitos, dos torres de agua y grupos de contenedores. Pórtico transversal, pasarela y conducción inferior conectan la composición.')])
heading('2. Mejoras por elemento')
bullets([
'Arquitectura: base industrial inferior, edificios escalados a la composición, columnas unidas por una viga y pasarela trasera. Los edificios quedan detrás y a los lados para mantener la vista sobre la arena.',
'Prensa: bloque superior azul, fachada amarilla PRESS 09, coronas hidráulicas importadas, conductos, collares y pernos. La placa incorpora una fascia pesada con franjas diagonales. El nuevo vástago central cambia su longitud siguiendo la posición real de la placa.',
'Peligro de la prensa: suelo enmarcado con bandas y dos tiras luminosas. La emisión responde a advertencia y compresión; conserva el ciclo original y su trigger.',
'Cintas: motores y carcasas en ambos extremos, válvulas, engranajes, soportes y flechas. Se conservan los rodillos y las lamas móviles originales. Engranajes y flechas responden a la velocidad, sentido y detención reales.',
'Palancas: pantallas industriales, balizas, identificación A/B y conductos hacia sus cintas. La palanca roja y su activación temporal se conservan. La baliza cambia con el estado y parpadea durante los últimos 1,5 segundos de sabotaje.',
'Suelo y bordes: perfiles perimetrales, refuerzos amarillos, paneles seguros y detalles antideslizantes. Los huecos para caer y las barandas parciales originales permanecen.',
'Materiales: ocho materiales URP Lit nuevos más un material para texto. Los atlas de ambos paquetes se conservan y reciben tintes derivados. Metal expuesto, pintura, goma y emisión tienen acabados distintos.',
'Iluminación: luz principal cálida con sombras suaves, relleno direccional frío sin sombras, luces industriales existentes y ambiente de tres colores. Niebla lineal para profundidad.',
'URP: cámara con HDR y postprocesado; Volume global con tonemapping Neutral, bloom moderado, contraste/saturación suaves, viñeta ligera y FXAA.',
'Cámara: encuadre elevado ajustado a la fábrica, revisión frontal, lateral y cenital. La cámara de MultiplayerTest no se modificó.'
])
heading('3. Inspección y modelos utilizados')
p('Se inventariaron 180 modelos FBX y se generaron nueve láminas de catálogo para inspeccionar su geometría y apariencia. La escena utiliza 23 modelos distintos, repartidos en 79 instancias importadas. Se revisaron escalas, orientaciones, atlas de color y compatibilidad visual con los materiales derivados URP.')
models=(evidence/'ModelsUsed.txt').read_text().splitlines()
for kit in ('FactoryKit','CityKitIndustrial'):
 heading(kit,3);bullets([Path(x).stem for x in models if '/'+kit+'/' in x])
link(evidence/'ModelInventory.txt','Inventario completo de modelos y dimensiones')
heading('4. Archivos creados y modificados')
p('Todas las rutas de Assets que siguen pertenecen a C:\\ProyectoFinalRV. La decoración está serializada en la escena: se puede inspeccionar y editar fuera de Play Mode.')
table(['Tipo','Ruta / contenido'],[
('Escena modificada','Assets/FactoryArena/Scenes/FactoryArena.unity'),
('Prefabs visuales nuevos','Assets/FactoryArena/Prefabs/Visuals/IndustrialCampus.prefab; ConveyorDriveVisuals.prefab; OperatorStationVisuals.prefab; HydraulicPressVisuals.prefab'),
('Materiales nuevos','Assets/FactoryArena/Materials/Redesign/: PaintedSteel, BrushedMetal, IndustrialYellow, Rubber, SignalCyan, WarningAmber, FactoryKitDerived, CityKitDerived, IndustrialSignText (.mat)'),
('Recursos de renderizado','Materials/Redesign/FactoryVolume.asset y DepthText.shader'),
('Animación visual nueva','Scripts/Runtime/FactoryVisualMotion.cs: lee el estado de mecanismos, anima vástago, balizas, flechas y engranajes.'),
('Herramientas nuevas de Editor','Scripts/Editor/ArtCatalog.cs, FactoryRedesign.cs y FactoryVisualReview.cs.'),
('Comprobador temporal nuevo','Scripts/Runtime/RedesignRegressionProbe.cs, protegido con UNITY_EDITOR. Se añadió solo durante pruebas; no quedó en la escena.'),
('Pruebas existentes reutilizadas','FactoryValidation.cs se ejecutó sin modificarlo. Su salida LocalValidation.txt se actualizó.'),
('Evidencias','Assets/FactoryArena/Generated/Redesign/: catálogo, imágenes, inventarios y resultados de auditoría/pruebas.'),
('Documentación y protección','Documentation/FactoryArena/: este informe, su versión HTML, audit_redesign.py y Backups/BeforeVisualRedesign.zip.')])
p('Los cuatro prefabs nuevos contienen conjuntos de presentación reutilizables. El cableado completo de mecanismos y el blindaje móvil de la placa están guardados en FactoryArena. No sustituyen automáticamente a los prefabs funcionales antiguos. FactoryRedesign.Apply es la herramienta de aplicación inicial y evita ejecutarse sobre una escena ya rediseñada; para continuar trabajando se debe abrir la escena guardada.')
heading('5. Protección e integridad')
p('Se creó una copia recuperable antes de modificar el mapa. La auditoría SHA-256 comparó 418 archivos originales: modelos, metadatos, MultiplayerTest, paquetes, ajustes del proyecto y scripts funcionales. Resultado: ningún archivo modificado ni ausente en ese conjunto. Los cambios de Git anteriores a este trabajo se conservaron.')
p('La comparación de la escena también conserva los 17 bloques de física serializados directamente en la versión anterior; no se añadieron bloques de física. Esta cifra no cuenta los componentes procedentes de prefabs. La inspección completa del mapa registra 162 colliders y un Rigidbody, todos de la base funcional; el nuevo grupo VisualRedesign tiene cero colliders y cero Rigidbody.')
p('ConveyorBelt, ControlLever, HydraulicPress y HazardZone permanecen intactos. FallDetection es el nombre de un GameObject que usa HazardZone; no existía un script independiente FallDetection.cs. La geometría visual antigua que se sustituyó permanece conservada con sus renderers desactivados.')
link(out/'Backups/BeforeVisualRedesign.zip','Copia anterior al rediseño')
link(evidence/'PreservationAudit.txt','Comparación de archivos y componentes físicos')
heading('6. Pruebas ejecutadas realmente')
table(['Comprobación','Resultado observado'],[
('Compilación y consola','Compilación final sin errores. La consulta final indica compilationFailed=false, compiling=false y consoleErrors=0.'),
('Integridad de FactoryArena','0 scripts faltantes; 0 referencias serializadas rotas; 0 materiales nulos, incompatibles o con shader de error.'),
('Play Mode','Se verificó que Time.frameCount avanzaba mediante job wait, antes de aceptar las pruebas.'),
('Cintas con Rigidbody','Ambas desplazaron un cubo ~1,76456 unidades en el intervalo de 1 s. Al invertir, cambió el signo del desplazamiento. Con velocidad 3,5 se midió ±3,5; detenidas, velocidad horizontal 0.'),
('Palancas','Activación repetida seguida de una única inversión; tras 6,3 s ambas restauraron la dirección y dejaron de estar activas.'),
('Prensa','Se observaron Rest, Warning, Descending, Compression y Rising. Placa entre y=0,65 e y=4. El sensor de prueba recibió 86 eventos con la zona armada.'),
('Vástago visual','Error máximo medido en su extremo inferior respecto de la placa: ~0,000000238 unidades, durante el ciclo observado.'),
('Puntos de aparición','4/4 con raycast a suelo sólido y cero colliders bloqueando el volumen inicial. Cuatro cápsulas de 1,8 m quedaron apoyadas, con centro y≈0,934.'),
('Caída','Un cuerpo soltado fuera de la plataforma activó el detector de caída: 6 notificaciones durante su paso por el trigger.'),
('Engranajes y flechas','Detención: giro 0°. En marcha: ~18° en 0,3 s. Tras inversión, las flechas cambiaron a 270°/90° en correspondencia con dirección −1/+1.'),
('MultiplayerTest','Se abrió de forma aditiva, se revisó y se cerró sin guardarlo. 0 scripts faltantes y 0 referencias serializadas rotas. Archivos intactos en la auditoría.'),
('Revisión visual','Capturas reales desde cámaras de Unity durante Play Mode, Game View y Scene View. Inspección general, frontal, lateral, cenital y de mecanismos.')])
p('Los conteos de eventos del trigger incluyen notificaciones de permanencia; no equivalen a 86 impactos distintos ni a 6 cuerpos diferentes. Las pruebas fueron locales y con cuerpos temporales, no con personajes definitivos ni clientes de red.')
for name,label in [('Regression.txt','Resultados de aparición, caída, prensa y animación visual'),('FactoryArenaIntegrity.txt','Auditoría de la escena FactoryArena'),('MultiplayerTestIntegrity.txt','Auditoría de MultiplayerTest')]:link(evidence/name,label)
link(r/'Assets/FactoryArena/Generated/LocalValidation.txt','Regresión de cintas, palancas y ciclo de prensa')
heading('7. Rendimiento y alcance de la medición')
p('Inventario de la escena: 547 renderers activos, 15 materiales distintos y 39.836 triángulos sumados por instancia, sin aplicar visibilidad. Solo la luz principal proyecta sombras; las otras seis luces no. Se desactivaron sombras en textos y detalles pequeños, se reutilizaron materiales y se habilitó instancing donde corresponde. 313 renderers decorativos tienen la marca Batching Static; en Play Mode se observaron 303 formando parte de lotes estáticos.')
p('Una muestra de UnityStats en el Editor registró 783 llamadas de dibujo, 44 cambios SetPass y 85.429 triángulos renderizados. Son contadores del Editor y sus pasadas/vistas, no una medición aislada de una build. La geometría es moderada, pero el número de envíos de render merece perfilado posterior en una build con personajes. No se midieron tiempos CPU/GPU representativos ni se garantiza 60 FPS en gama media.')
link(evidence/'RenderStats.txt','Muestra de estadísticas del Editor')
heading('8. Segunda revisión artística')
p('La primera pasada detectó escalas incorrectas en algunas instancias importadas, rótulos demasiado grandes, flechas bajo la superficie y textos que se dibujaban por delante de objetos que debían taparlos. Se corrigieron las escalas conservando las escalas raíz de importación, se redujeron y reposicionaron rótulos, se elevaron las flechas y se creó un shader de texto con prueba de profundidad. También se ajustaron niebla, luz principal, relleno y fondo del rótulo principal. Después se volvieron a guardar los prefabs y a capturar el resultado.')
table(['Criterio visual (valoración editorial /5)','Antes','Después'],[('Paleta',3,4),('Coherencia de estilo',2,4),('Arquitectura y profundidad',1,4),('Silueta y detalle de maquinaria',2,4),('Iluminación',2,3),('Comunicación de mecanismos',2,4)])
p('Estas notas son una autoevaluación visual, no resultados de una prueba con jugadores. Personajes, interfaz general, audio y efectos de combate quedan fuera del alcance de este rediseño.')
heading('9. Limitaciones e incidencias')
bullets([
'FactoryArena todavía no está validada ni sincronizada en multijugador. No se hicieron pruebas online, Relay ni sesiones de cuatro jugadores durante este trabajo.',
'Las plataformas laterales y el recinto inferior son decorativos y no transitables; deliberadamente no tienen colliders. La zona jugable sigue siendo la arena original.',
'La circulación se comprobó mediante conservación de colliders y pruebas de aparición/caída; falta recorrer el mapa con el personaje físico definitivo, incluidos agarres y lanzamientos.',
'No se creó una build ni un benchmark de hardware. La legibilidad con cuatro personajes y la posible oclusión de estos por la prensa requieren una futura prueba de juego.',
'Hubo bloqueos y tiempos de espera durante la recarga de scripts del editor, mostrando Unity Version Control y callbacks internos ocupados. Se recuperó la conexión reiniciando el editor sobre archivos guardados y se completaron las pruebas.',
'La consola final conserva una advertencia del paquete de integración Visual Studio: no pudo utilizar el puerto UDP 56326 para mensajería VS/Unity. No se modificó el firewall ni se atribuye esa advertencia al mapa. No hay errores de consola en la revisión final.',
'Los mecanismos conservan su alcance anterior: los triggers notifican peligro/caída; no se añadieron reglas de eliminación, puntuación ni daño de un personaje definitivo.'
])
heading('10. Evidencias visuales')
p('Todas las imágenes siguientes son capturas reales del proyecto renderizadas por Unity. Before corresponde a la versión previa. Los encuadres antes/después son semejantes, pero no idénticos; las vistas de detalle y Game View se capturaron durante Play Mode. Scene View muestra el mapa editable con la visualización propia del editor.')
photo('Before','Antes del rediseño')
photo('Gameplay','Después: cámara elevada de la arena')
photo('Press','Prensa hidráulica durante el ciclo de movimiento')
photo('Conveyors','Cintas, transmisiones y señalización direccional')
photo('Lever','Estación de sabotaje con panel y baliza')
photo('Exterior','Entorno industrial y pasarela de mantenimiento')
photo('GameView','Captura de Game View mediante Unity CLI')
photo('SceneView','Captura de Scene View mediante Unity CLI')
p('También se guardaron Front.png, Elevated.png y Side.png, además de las nueve láminas Catalog_0.png a Catalog_8.png y las capturas intermedias de revisión.')
heading('11. Estado de entrega')
p('FactoryArena queda abierta, guardada y fuera de Play Mode. Los objetos temporales de prueba ya no forman parte de la escena. Run In Background quedó restaurado a false; auto-tick estaba habilitado previamente y se mantuvo. Para revisar el resultado, abrir Assets/FactoryArena/Scenes/FactoryArena.unity. La edición continúa directamente desde la jerarquía guardada, especialmente FactoryArena/VisualRedesign y la maquinaria original.')
(out/'Informe_Rediseno_Fabrica_Mortal.md').write_text('\n'.join(md),encoding='utf-8')
css='''body{font:16px/1.65 system-ui,sans-serif;background:#edf1f4;color:#233747;margin:0}main{max-width:1080px;margin:auto;background:white;padding:48px}h1{font-size:38px;line-height:1.15;border-bottom:8px solid #f4b733;padding-bottom:24px}h2{margin-top:48px;color:#283f52}h3{color:#41677f}table{border-collapse:collapse;width:100%;font-size:14px}td,th{border:1px solid #d5dfe5;text-align:left;padding:10px;vertical-align:top}th{background:#283f52;color:white}tr:nth-child(even){background:#f4f7f9}img{width:100%;height:auto}figure{margin:32px 0}figcaption{font-size:14px;color:#526677}code{overflow-wrap:anywhere;font-size:13px}li{margin-bottom:8px}@media print{body{background:white}main{padding:0}h2,h3{break-after:avoid}figure,tr{break-inside:avoid}h1{font-size:28px}}'''
(out/'Informe_Rediseno_Fabrica_Mortal.html').write_text('<!doctype html><html lang="es"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Fábrica Mortal — Informe del rediseño</title><style>'+css+'</style><main>'+''.join(html)+'</main></html>',encoding='utf-8')
print('Reports generated:',len(md),'markdown blocks;',len(models),'models')
