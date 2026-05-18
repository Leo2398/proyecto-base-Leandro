# AgroMarket / App Pedidos

## Manual Técnico

**AgroMarket / App Pedidos** es una aplicación móvil desarrollada en **Flutter** para conectar clientes con productores de productos orgánicos. El sistema permite publicar productos, realizar pedidos, gestionar monedas internas, administrar recargas, revisar reportes y controlar usuarios desde interfaces separadas por rol.

---

## Información general del proyecto

| Campo | Detalle |
|---|---|
| Proyecto | AgroMarket / App Pedidos |
| Tecnología principal | Flutter + Dart + Provider + MySQL |
| Tipo de sistema | Aplicación móvil de pedidos |
| Arquitectura | Por capas: views, controllers, services, models y core |
| Gestión de estado | Provider / ChangeNotifier |
| Base de datos | MySQL |
| Repositorio | https://github.com/Leo2398/proyecto-base-Leandro |
| Versión del documento | 1.0 - Versión final |

> **Seguridad:** Este repositorio no debe publicar credenciales reales, contraseñas de base de datos, tokens SMTP ni claves de servicios externos. Las credenciales de prueba deben entregarse por privado al docente o evaluador.

---

## Integrantes y roles

| Integrante | Rol principal | Responsabilidades técnicas |
|---|---|---|
| Leandro Mateo Suárez Cabrera | Desarrollador Flutter / Integración final | Implementación de vistas, controllers, services, conexión MySQL, flujos de cliente, productor y administrador, dockerización y entrega final. |

---

## Objetivo del proyecto

El objetivo principal de AgroMarket / App Pedidos es brindar una plataforma móvil para pedidos de productos agrícolas y orgánicos, permitiendo que:

- Los productores publiquen productos con imagen, familia, descripción, precio, unidad, stock y fecha de cosecha.
- Los clientes revisen productos, los agreguen al carrito y generen pedidos.
- El sistema valide saldo, stock y precios reales antes de confirmar una compra.
- Los usuarios realicen recargas de monedas mediante comprobantes.
- El administrador apruebe o rechace recargas, gestione usuarios y genere reportes.
- Cada rol tenga su propio dashboard y navegación adaptada.

---

## Roles del sistema

| Rol | Descripción |
|---|---|
| Cliente | Compra productos, administra carrito, realiza pedidos, recarga monedas y califica pedidos completados. |
| Productor | Publica productos, administra stock, horarios, ubicación, pedidos recibidos, monedas y estadísticas. |
| Administrador | Gestiona usuarios, empresas, clientes, recargas, configuración del QR/precio de moneda y reportes PDF. |

---

## Requisitos funcionales principales

| Código | Módulo | Requisito |
|---|---|---|
| RF-01 | Login | Iniciar sesión con email y contraseña encriptada mediante bcrypt. |
| RF-02 | Sesión persistente | Mantener sesión activa con SharedPreferences y redirigir según rol. |
| RF-03 | Registro cliente | Registrar clientes con datos personales y ubicación. |
| RF-04 | Registro productor | Registrar productores con información de empresa, ubicación, familias y modalidad de entrega. |
| RF-05 | Recuperación de contraseña | Enviar código por correo para recuperar contraseña. |
| RF-06 | Catálogo cliente | Mostrar productos activos y productores disponibles. |
| RF-07 | Carrito | Agregar, aumentar, disminuir y eliminar productos. El carrito no mezcla productores. |
| RF-08 | Creación de pedido | Crear pedidos validando saldo, stock real y precio desde base de datos. |
| RF-09 | Estados de pedido | Cambiar pedidos entre pendiente, preparación, enviado, completado o cancelado. |
| RF-10 | Cancelación con reversión | Reponer stock y reembolsar saldo cuando se cancela un pedido. |
| RF-11 | Reseñas | Calificar pedidos completados con puntuación de 1 a 5. |
| RF-12 | Productos productor | Listar, buscar, filtrar, crear, editar y actualizar stock de productos. |
| RF-13 | Perfil productor | Configurar imagen, descripción, ubicación y horarios de atención. |
| RF-14 | Recarga de monedas | Solicitar recarga con comprobante y esperar aprobación administrativa. |
| RF-15 | Administración de recargas | Aprobar o rechazar solicitudes y acreditar saldo si corresponde. |
| RF-16 | Configuración admin | Configurar precio por moneda y QR de pago. |
| RF-17 | Reportes PDF | Generar reportes de empresas, clientes, productos y sectores. |
| RF-18 | Notificaciones | Generar notificaciones por eventos del sistema. |

---

## Arquitectura del software

El proyecto utiliza una arquitectura por capas en Flutter:

```txt
lib/
├── controllers/          Estado de UI y lógica de aplicación
├── core/                 Conexión BD, sesión, cifrado, email, ubicación e imágenes
├── models/               Modelos de datos y entidades
├── services/             Acceso a MySQL y operaciones del sistema
├── services/interfaces/  Contratos de servicios
├── views/
│   ├── admin/            Pantallas del administrador
│   ├── auth/             Login, registro y recuperación
│   ├── client/           Pantallas del cliente
│   └── producer/         Pantallas del productor
├── widgets/              Componentes reutilizables
└── main.dart             Arranque, providers y redirección por rol
