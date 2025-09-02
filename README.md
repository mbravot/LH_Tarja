# LH Tarjas - Aplicación Móvil

Aplicación móvil desarrollada en Flutter para la gestión integral de actividades agrícolas, rendimientos y personal de la empresa LH Tarjas.

## 📱 Descripción

Esta aplicación móvil proporciona una solución completa para la gestión empresarial agrícola con las siguientes características principales:

- **Sistema de autenticación** con JWT tokens y renovación automática
- **Gestión completa de actividades** agrícolas (individuales y múltiples)
- **Sistema de rendimientos** (individuales, grupales y múltiples)
- **Gestión de personal** (trabajadores, contratistas, colaboradores)
- **Administración de CECOs** por categorías (productivos, administrativos, maquinaria, inversión, riego)
- **Gestión de usuarios** con roles y perfiles
- **Selección de sucursales** activas
- **Interfaz moderna** con Material Design 3
- **Arquitectura modular** y escalable
- **Soporte multi-plataforma** (Android, iOS, Web)

## 🏗️ Arquitectura del Proyecto

```
lib/
├── main.dart                       # Punto de entrada
├── old_main.dart                   # Versión anterior del main
├── pages/                          # Páginas principales (44 archivos)
│   ├── home_page.dart             # Página principal con navegación
│   ├── login_page.dart            # Página de autenticación
│   ├── actividades_page.dart      # Gestión de actividades
│   ├── rendimientos_page.dart     # Gestión de rendimientos
│   ├── indicadores_page.dart      # Página de indicadores
│   ├── usuarios_page.dart         # Gestión de usuarios
│   ├── trabajadores_page.dart     # Gestión de trabajadores
│   ├── contratistas_page.dart     # Gestión de contratistas
│   ├── colaboradores_page.dart    # Gestión de colaboradores
│   ├── permisos_page.dart         # Gestión de permisos
│   └── ...                        # Otras páginas especializadas
├── providers/                      # Gestión de estado
│   └── theme_provider.dart        # Provider para temas
├── services/                       # Servicios de API
│   ├── api_service.dart           # Servicio principal de API (4315 líneas)
│   └── login_services.dart        # Servicios de autenticación
├── theme/                          # Temas y estilos
│   └── app_theme.dart             # Configuración de temas
├── utils/                          # Utilidades
│   └── colors.dart                # Paleta de colores
└── widgets/                        # Widgets reutilizables
    ├── layout/
    │   └── app_bar.dart           # AppBar personalizado
    └── token_checker.dart         # Verificador de tokens
```

## 🚀 Características Principales

### 🔐 Sistema de Autenticación
- Login con usuario y contraseña
- Tokens JWT (access_token y refresh_token)
- Renovación automática de tokens
- Almacenamiento seguro en SharedPreferences
- Logout con limpieza de datos
- Manejo automático de sesiones expiradas

### 🌾 Gestión de Actividades Agrícolas
- **Actividades Individuales**: Crear, editar y gestionar actividades específicas
- **Actividades Múltiples**: Gestión de actividades que involucran múltiples elementos
- **Categorización**: Por especie, variedad, cuartel y tipo de labor
- **Estados**: Seguimiento del progreso de las actividades
- **Asignación**: Asignar trabajadores y recursos a actividades

### 📊 Sistema de Rendimientos
- **Rendimientos Individuales**: Registro de trabajo individual de trabajadores
- **Rendimientos Grupales**: Trabajo en equipo con distribución de porcentajes
- **Rendimientos Múltiples**: Gestión compleja de múltiples rendimientos
- **Cálculos Automáticos**: Cálculo de horas, costos y productividad
- **Historial**: Seguimiento histórico de rendimientos

### 👥 Gestión de Personal
- **Trabajadores**: Registro y gestión de trabajadores por sucursal
- **Contratistas**: Administración de empresas contratistas
- **Colaboradores**: Gestión de colaboradores internos
- **Permisos**: Sistema de permisos y ausencias
- **Horas Trabajadas**: Control de tiempo y asistencia

### 🏢 Gestión de Sucursales
- Lista de sucursales disponibles
- Cambio de sucursal activa
- Persistencia de sucursal seleccionada
- Validación de permisos por sucursal
- Configuración específica por ubicación

### 💰 Sistema de CECOs
- **CECOs Productivos**: Centros de costo para producción
- **CECOs Administrativos**: Centros de costo administrativos
- **CECOs Maquinaria**: Centros de costo para equipos
- **CECOs Inversión**: Centros de costo para inversiones
- **CECOs Riego**: Centros de costo para sistemas de riego

### 🎨 Interfaz de Usuario
- Material Design 3
- Tema personalizable
- Navegación con drawer lateral
- Bottom navigation bar con 4 pestañas principales
- Indicadores de carga
- Mensajes de confirmación
- Formularios intuitivos

## 📋 Requisitos del Sistema

### Flutter
- **Versión**: 3.2.3 o superior
- **SDK**: Dart 3.0+

### Dependencias Principales
```yaml
dependencies:
  flutter: sdk: flutter
  http: ^1.1.0                    # Cliente HTTP
  shared_preferences: ^2.2.2      # Almacenamiento local
  dropdown_search: ^5.0.6         # Búsqueda con dropdown
  collection: ^1.18.0             # Utilidades de colecciones
  flutter_slidable: ^3.0.1        # Widgets deslizables
  cupertino_icons: ^1.0.2         # Iconos iOS
  intl: ^0.20.2                   # Internacionalización
  multi_select_flutter: ^4.1.3    # Selección múltiple
  provider: ^6.0.5                # Gestión de estado
  crypto: ^3.0.3                  # Encriptación
```

## 🔧 Configuración

### 1. Clonar el Repositorio
```bash
git clone https://github.com/mbravot/app_LH_Tarjas.git
cd app_LH_Tarjas
```

### 2. Instalar Dependencias
```bash
flutter pub get
```

### 3. Configurar API
La aplicación está configurada para usar la API de producción:
```dart
// lib/services/login_services.dart y lib/services/api_service.dart
final String baseUrl = 'https://apilhtarja-927498545444.us-central1.run.app/api';
```

### 4. Ejecutar la Aplicación
```bash
flutter run
```

## 🌐 API Endpoints

### Autenticación
- `POST /api/auth/login` - Login de usuario
- `POST /api/auth/refresh` - Renovar token
- `POST /api/auth/cambiar-clave` - Cambiar contraseña

### Actividades
- `GET /api/actividades/` - Listar actividades
- `POST /api/actividades/` - Crear actividad
- `PUT /api/actividades/{id}` - Actualizar actividad
- `DELETE /api/actividades/{id}` - Eliminar actividad

### Rendimientos
- `GET /api/rendimientos/{idActividad}` - Obtener rendimientos
- `POST /api/rendimientos/` - Crear rendimientos
- `PUT /api/rendimientos/{id}` - Actualizar rendimiento
- `DELETE /api/rendimientos/{id}` - Eliminar rendimiento

### Usuarios y Sucursales
- `GET /api/usuarios/` - Listar usuarios
- `POST /api/usuarios/` - Crear usuario
- `PUT /api/usuarios/{id}` - Actualizar usuario
- `GET /api/usuarios/sucursal-activa` - Obtener sucursal activa

### Opciones y CECOs
- `GET /api/opciones/` - Obtener opciones generales
- `GET /api/opciones/especies` - Listar especies
- `GET /api/opciones/variedades` - Listar variedades
- `GET /api/opciones/cecos` - Listar CECOs

## 🎯 Funcionalidades Implementadas

### ✅ Completadas
- [x] Sistema de login/logout con JWT
- [x] Gestión de tokens y renovación automática
- [x] Gestión completa de actividades agrícolas
- [x] Sistema de rendimientos (individuales, grupales, múltiples)
- [x] Gestión de trabajadores y contratistas
- [x] Sistema de CECOs por categorías
- [x] Gestión de usuarios y permisos
- [x] Cambio de sucursal y contraseña
- [x] Interfaz responsive con Material Design 3
- [x] Manejo de errores y validaciones
- [x] Sistema de cache para optimización
- [x] Gestión de colaboradores y permisos
- [x] Sistema de riego y maquinaria
- [x] Gestión de inversiones y cuarteles

### 🚧 En Desarrollo
- [ ] Notificaciones push
- [ ] Reportes avanzados
- [ ] Sincronización offline
- [ ] Integración con sistemas externos

## 🛠️ Desarrollo

### Estructura de Commits
```
feat: nueva funcionalidad
fix: corrección de errores
docs: documentación
style: cambios de estilo
refactor: refactorización
test: pruebas
chore: tareas de mantenimiento
```

### Sistema de Logging
La aplicación incluye un sistema de logging condicional optimizado para producción:
```dart
// Los logs están comentados para mejorar rendimiento en producción
logDebug("🔍 Datos del backend: $data");
logInfo("ℹ️ Login exitoso");
logError("❌ Error de conexión");
```

### Variables de Entorno
- `baseUrl` - URL del servidor API
- `access_token` - Token de acceso JWT
- `refresh_token` - Token de renovación
- `user_name` - Nombre del usuario
- `user_sucursal` - Sucursal activa

## 📦 Build y Deploy

### Android
```bash
flutter build apk --release
flutter build appbundle --release
```

### iOS
```bash
flutter build ios --release
```

### Web
```bash
flutter build web --release
```

## 🔧 Funcionalidades Avanzadas

### Sistema de Cache Inteligente
- Cache en memoria con TTL de 2 minutos
- Invalidación automática al modificar datos
- Reducción de llamadas a API
- Mejora en rendimiento de la aplicación

### Gestión de Estados de Carga
- Indicadores de carga en todas las operaciones
- Manejo de estados de error
- Retry automático en fallos de red
- Feedback visual para el usuario

### Validación de Datos
- Validación en tiempo real de formularios
- Verificación de permisos por rol
- Sanitización de entrada de usuario
- Manejo de errores de validación

### Navegación Avanzada
- Navegación con drawer lateral
- Bottom navigation bar con 4 pestañas
- Navegación anidada
- Gestión de stack de navegación

## 🤝 Contribución

1. Fork el proyecto
2. Crear una rama para tu feature (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abrir un Pull Request

## 📄 Licencia

Este proyecto está bajo la Licencia MIT. Ver el archivo `LICENSE` para más detalles.

## 👥 Autores

- **Miguel Bravo** - *Desarrollo inicial* - [mbravot](https://github.com/mbravot)

## 🙏 Agradecimientos

- Flutter team por el framework
- La comunidad de Flutter por las librerías
- Material Design por los componentes
- Equipo de LH Tarjas por el soporte y feedback

## 📞 Soporte

Para soporte técnico o preguntas:
- Crear un issue en GitHub
- Contactar al equipo de desarrollo
- Revisar la documentación técnica completa

---

**Versión**: 1.0.0  
**Última actualización**: Diciembre 2024  
**Estado**: En desarrollo activo con funcionalidades completas  
**Documentación**: Ver `DOCUMENTACION_TECNICA.md` para detalles técnicos completos
