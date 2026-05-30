# Manual Técnico - AgroMarket / AppPedidos

## 1. Integrantes - Roles

| Integrante / Equipo | Rol principal | Responsabilidades |
|---|---|---|
| UMASoftFACTORY / Leandro | Desarrollo full app Flutter | Vistas, controladores, servicios, modelos, BD, compilados y publicación. |
| Responsable de BD | Diseño y administración MySQL | Tablas, relaciones, datos de prueba, conexión y hosting. |
| Responsable de pruebas | QA y entrega | Pruebas funcionales, APK, Windows ZIP, Releases y Pages. |

## 2. Introducción

AgroMarket / AppPedidos es una aplicación Flutter para pedidos agrícolas. Conecta clientes con productores y permite administrar productos, pedidos, recargas, usuarios y reportes administrativos.

## 3. Descripción / objetivo

El objetivo es ofrecer una plataforma instalable para Android y Windows donde los clientes compren productos agrícolas, los productores administren su oferta y los administradores controlen recargas, usuarios y reportes.

## 4. Video ilustrativo

Pendiente de agregar enlace de YouTube: `https://www.youtube.com/watch?v=CODIGO_DEL_VIDEO`

## 5. Requisitos funcionales

- **RF-01 Autenticación:** Permitir inicio de sesión mediante correo y contraseña validada con bcrypt.
- **RF-02 Sesión persistente:** Mantener la sesión activa usando almacenamiento local y redirigir por rol al iniciar.
- **RF-03 Registro de cliente:** Registrar clientes con datos personales, correo, contraseña, celular y ubicación.
- **RF-04 Registro de productor:** Registrar productores con datos de empresa, descripción, modalidad de entrega y ubicación.
- **RF-05 Recuperación de contraseña:** Enviar código/token de recuperación por correo, verificarlo y permitir cambio de contraseña.
- **RF-06 Dashboard por rol:** Mostrar interfaz inicial diferente para cliente, productor y administrador.
- **RF-07 Catálogo de productos:** Listar productos activos con información de precio, unidad, stock, imagen y productor.
- **RF-08 Detalle de producto:** Mostrar información ampliada del producto y permitir agregarlo al carrito.
- **RF-09 Carrito de compras:** Agregar, actualizar, eliminar productos y evitar mezclar productos de diferentes productores.
- **RF-10 Creación de pedidos:** Crear pedidos validando saldo, stock, productor y precios reales desde la base de datos.
- **RF-11 Estados de pedido:** Gestionar los estados: pendiente, en preparación, enviado, completado y cancelado.
- **RF-12 Cancelación de pedido:** Reponer stock y devolver saldo cuando un pedido se cancela.
- **RF-13 Reseñas:** Permitir reseñas solo para pedidos completados y por el cliente dueño del pedido.
- **RF-14 Recarga de saldo/monedas:** Solicitar recargas con comprobante y esperar aprobación administrativa.
- **RF-15 Aprobación de recargas:** Permitir al administrador aprobar o rechazar solicitudes y acreditar saldo al aprobar.
- **RF-16 Configuración del QR:** Permitir al administrador configurar imagen QR y valor en Bs por moneda.
- **RF-17 Gestión de productos productor:** Crear, editar, listar, buscar, filtrar y actualizar stock de productos.
- **RF-18 Perfil de productor:** Editar descripción, imagen, ubicación de entrega, modalidad y horarios de atención.
- **RF-19 Notificaciones:** Registrar y mostrar notificaciones por eventos de pedidos y cambios de estado.
- **RF-20 Reportes PDF:** Generar reportes administrativos con métricas, top empresas, clientes, productos y sectores.
- **RF-21 Gestión de usuarios admin:** Crear, editar, activar/desactivar usuarios administradores, clientes y empresas.
- **RF-22 Página de descargas:** Publicar una página web en GitHub Pages con botones de descarga para APK y Windows ZIP.


## 6. Arquitectura del software

Arquitectura por capas en Flutter:

```text
Vistas Flutter -> Controllers ChangeNotifier -> Services -> Models -> DBConnection -> MySQL
```

Capas principales:

- `controllers`: 8 controladores de estado.
- `core`: conexión, email, sesión, imágenes, ubicación y helpers.
- `models`: 18 modelos.
- `services`: 15 servicios de datos.
- `views`: pantallas por rol: auth, client, producer y admin.
- `widgets`: componentes reutilizables.

## 7. Base de datos

Base de datos MySQL `app_pedidos`. Tablas principales: `user`, `location`, `pickuplocation`, `deliverymode`, `productfamily`, `producerproductfamily`, `product`, `orders`, `orderdetail`, `request`, `appconfig`, `review`, `schedule`, `notification`, `passwordresettoken`.

Estados:

- Roles: 0=Cliente, 1=Productor, 2=Administrador.
- Request: 0=Pendiente, 1=Aprobado, 2=Rechazado.
- Pedidos: 0=Pendiente, 1=En preparación, 2=Enviado, 3=Completado, 4=Cancelado.
- Regla de moneda: 1 moneda = 100 Bs.

## 8. Credenciales de prueba

| Rol | Correo | Contraseña |
|---|---|---|
| Productor | kanguronutria@gmail.com | Nutria123 |
| Admin | nutriadelfin4@gmail.com | Delfin123 |
| Cliente | alejandro74862@gmail.com | Ale12345 |

## 9. Requisitos del sistema

- Android: 2 GB RAM mínimo, conexión a internet, permiso para instalar APK.
- Windows: Windows 10/11 64 bits, 4 GB RAM mínimo, conexión a internet, extraer ZIP antes de ejecutar.
- Server/BD: MySQL remoto con conexión segura y usuario de aplicación.

## 10. Instalación y configuración

Página de descarga: https://leo2398.github.io/proyecto-base-Leandro/

APK Android: https://github.com/Leo2398/proyecto-base-Leandro/releases/download/v1.0.0/app-release.apk

Windows ZIP: https://github.com/Leo2398/proyecto-base-Leandro/releases/download/v1.0.0/AgroMarket-Windows.zip

### Android

1. Abrir la página de descarga.
2. Descargar `app-release.apk`.
3. Permitir instalación de origen desconocido si Android lo solicita.
4. Instalar y abrir la app.

### Windows

1. Descargar `AgroMarket-Windows.zip`.
2. Extraer el ZIP completo.
3. Abrir `app_pedidos.exe` desde la carpeta extraída.
4. No borrar `data` ni archivos `.dll`.

## 11. Hosting

- Sitio Web: GitHub Pages.
- B.D.: MySQL remoto.
- API: no existe API propia; Flutter se conecta directamente a MySQL.
- Binarios: GitHub Releases.

## 12. GIT

Repositorio: https://github.com/Leo2398/proyecto-base-Leandro

Rama final: `main`.

Release final: `v1.0.0`.

## 13. Dockerizado

No se entrega dockerizado en la versión final porque es una app Flutter instalable sin backend API separado. Para dockerizar en el futuro se recomienda crear una API backend y un `docker-compose.yml` con backend + MySQL.

## 14. Personalización

- Valor por moneda y QR: `appconfig`.
- Conexión BD: `lib/core/db_connection.dart`.
- Reportes PDF: `admin_reports_view.dart` y `admin_pdf_preview_view.dart`.
- Página descarga: `index.html`.

## 15. Seguridad

- bcrypt para contraseñas.
- Roles diferenciados.
- Sesión persistente.
- Pedidos con validación de saldo y stock.
- Recargas requieren aprobación administrativa.
- Recomendación: mover conexión BD a backend/API y no publicar secretos reales.

## 16. Glosario

- APK: instalable Android.
- ZIP Windows: paquete con `.exe`, `data` y `.dll`.
- Provider: gestión de estado.
- Request: solicitud de recarga.
- Balance: saldo del usuario.

## 17. Referencias

- Flutter: https://docs.flutter.dev/
- GitHub Pages: https://docs.github.com/pages
- GitHub Releases: https://docs.github.com/repositories/releasing-projects-on-github
- MySQL: https://dev.mysql.com/doc/

## 18. Herramientas

- Lenguajes: Dart, SQL, HTML, CSS.
- Frameworks: Flutter, Material Design.
- Paquetes: Provider, mysql_client, bcrypt, shared_preferences, geolocator, geocoding, flutter_map, pdf, printing, file_saver, mailer.

## 19. Bibliografía

Flutter Documentation, Dart Documentation, GitHub Docs, MySQL Reference Manual, Material Design y documentación de paquetes Pub.dev.
