# APP_MOVIL_BASE

Aplicación móvil base desarrollada en Flutter para gestión empresarial con sistema de autenticación y múltiples funcionalidades.

## 📱 Descripción

Esta aplicación móvil proporciona una base sólida para aplicaciones empresariales con las siguientes características principales:

- **Sistema de autenticación** con JWT tokens
- **Gestión de usuarios** con roles y perfiles
- **Selección de sucursales** activas
- **Interfaz moderna** con Material Design 3
- **Arquitectura modular** y escalable
- **Soporte multi-plataforma** (Android, iOS, Web)

## 🏗️ Arquitectura del Proyecto

```
lib/
├── config/
│   └── api_config.dart          # Configuración de API
├── main.dart                    # Punto de entrada
├── models/                      # Modelos de datos
│   ├── rendimiento_grupal.dart
│   └── rendimiento_individual.dart
├── pages/                       # Páginas de la aplicación
│   ├── home_page.dart          # Página principal
│   ├── login_page.dart         # Página de login
│   ├── cambiar_clave_page.dart # Cambio de contraseña
│   └── cambiar_sucursal_page.dart # Cambio de sucursal
├── providers/                   # Providers (Estado)
│   └── theme_provider.dart
├── services/                    # Servicios de API
│   ├── api_service.dart        # Servicio principal de API
│   └── login_services.dart     # Servicios de autenticación
├── theme/                       # Temas y estilos
│   └── app_theme.dart
├── utils/                       # Utilidades
│   └── colors.dart
└── widgets/                     # Widgets reutilizables
    ├── layout/
    │   └── app_bar.dart        # AppBar personalizado
    └── token_checker.dart      # Verificador de tokens
```

## 🚀 Características Principales

### 🔐 Sistema de Autenticación
- Login con usuario y contraseña
- Tokens JWT (access_token y refresh_token)
- Almacenamiento seguro en SharedPreferences
- Renovación automática de tokens
- Logout con limpieza de datos

### 👤 Gestión de Usuarios
- Visualización del nombre del usuario (no username)
- Gestión de roles y perfiles
- Cambio de contraseña
- Selección de sucursal activa

### 🏢 Gestión de Sucursales
- Lista de sucursales disponibles
- Cambio de sucursal activa
- Persistencia de sucursal seleccionada
- Validación de permisos por sucursal

### 🎨 Interfaz de Usuario
- Material Design 3
- Tema personalizable
- Navegación con drawer
- Bottom navigation bar
- Indicadores de carga
- Mensajes de confirmación

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
  provider: ^6.0.5                # Gestión de estado
  crypto: ^3.0.3                  # Encriptación
  intl: ^0.20.2                   # Internacionalización
```

## 🔧 Configuración

### 1. Clonar el Repositorio
```bash
git clone https://github.com/mbravot/APP_MOVIL_BASE.git
cd APP_MOVIL_BASE
```

### 2. Instalar Dependencias
```bash
flutter pub get
```

### 3. Configurar API
Editar `lib/services/login_services.dart`:
```dart
final String baseUrl = 'http://tu-servidor:puerto/api';
```

### 4. Ejecutar la Aplicación
```bash
flutter run
```

## 📱 Estructura de la Base de Datos

### Tabla de Usuarios
```sql
CREATE TABLE `general_dim_usuario` (
  `id` varchar(45) NOT NULL,
  `id_sucursalactiva` int NOT NULL,
  `usuario` varchar(45) NOT NULL,
  `nombre` varchar(45) NOT NULL,
  `apellido_paterno` varchar(45) NOT NULL,
  `apellido_materno` varchar(45) DEFAULT NULL,
  `clave` varchar(255) NOT NULL,
  `fecha_creacion` date NOT NULL,
  `id_estado` int NOT NULL DEFAULT '1',
  `correo` varchar(100) NOT NULL,
  `id_rol` int NOT NULL DEFAULT '3',
  `id_perfil` int NOT NULL DEFAULT '1',
  PRIMARY KEY (`id`)
);
```

## 🔌 API Endpoints

### Autenticación
- `POST /api/auth/login` - Login de usuario
- `POST /api/auth/refresh` - Renovar token

### Usuarios
- `GET /api/usuarios` - Listar usuarios
- `PUT /api/usuarios/{id}` - Actualizar usuario

### Sucursales
- `GET /api/sucursales` - Listar sucursales
- `PUT /api/usuarios/sucursal` - Cambiar sucursal activa

## 🎯 Funcionalidades Implementadas

### ✅ Completadas
- [x] Sistema de login/logout
- [x] Gestión de tokens JWT
- [x] Visualización de nombre de usuario
- [x] Cambio de sucursal
- [x] Cambio de contraseña
- [x] Interfaz responsive
- [x] Manejo de errores
- [x] Logs de debug

### 🚧 En Desarrollo
- [ ] Pestaña de Actividades
- [ ] Pestaña de Indicadores
- [ ] Gestión de permisos
- [ ] Notificaciones push

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

### Logs de Debug
La aplicación incluye un sistema de logging condicional:
- `logDebug()` - Información de debug
- `logInfo()` - Información general
- `logError()` - Errores

### Variables de Entorno
- `baseUrl` - URL del servidor API
- `access_token` - Token de acceso
- `refresh_token` - Token de renovación
- `user_name` - Nombre del usuario
- `user_sucursal` - Sucursal activa

## 📦 Build y Deploy

### Android
```bash
flutter build apk --release
```

### iOS
```bash
flutter build ios --release
```

### Web
```bash
flutter build web --release
```

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

## 📞 Soporte

Para soporte técnico o preguntas:
- Crear un issue en GitHub
- Contactar al equipo de desarrollo

---

**Versión**: 1.0.0  
**Última actualización**: Diciembre 2024  
**Estado**: En desarrollo activo
