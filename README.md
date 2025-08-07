# 🏭 LH Tarja - Aplicación de Gestión Agrícola

## 📋 Descripción General

**LH Tarja** es una aplicación móvil desarrollada en Flutter para la gestión integral de actividades agrícolas, rendimientos, permisos y recursos humanos en el sector agrícola. La aplicación permite a los usuarios gestionar actividades, registrar rendimientos individuales y grupales, administrar permisos y gestionar personal de manera eficiente.

## 🎯 Funcionalidades Principales

### 🔐 **Autenticación y Seguridad**
- **Login seguro** con JWT tokens
- **Refresh automático** de tokens
- **Gestión de sesiones** con SharedPreferences
- **Navegación protegida** por roles de usuario

### 📊 **Gestión de Actividades**
- **Crear actividades** con tipo de CECO específico
- **Editar actividades** existentes
- **Visualizar actividades** con indicadores de rendimiento
- **Asignación automática** de CECO según tipo
- **Indicadores visuales** de rendimientos asociados

### 📈 **Rendimientos**
- **Rendimientos Individuales Propios**: Registro de rendimiento por colaborador
- **Rendimientos Individuales de Contratista**: Rendimiento por trabajador contratista
- **Rendimientos Grupales**: Rendimiento grupal por actividad
- **Visualización con unidades**: Muestra la unidad correspondiente al lado del valor
- **Edición y eliminación** de rendimientos existentes

### 👥 **Gestión de Personal**
- **Colaboradores**: Gestión de empleados propios
- **Trabajadores**: Gestión de trabajadores contratistas
- **Contratistas**: Administración de empresas contratistas
- **Usuarios**: Gestión de usuarios del sistema

### 📝 **Permisos**
- **Crear permisos** con validación de fechas
- **Editar permisos** existentes
- **Visualización** por mes y año
- **Gestión de estados** de permisos

### 🏢 **CECO (Centros de Costo)**
- **CECO Administrativo**: Gestión de costos administrativos
- **CECO Productivo**: Gestión de costos de producción
- **CECO Maquinaria**: Gestión de costos de maquinaria
- **CECO Inversión**: Gestión de costos de inversión
- **CECO Riego**: Gestión de costos de riego con equipos y sectores

### 📊 **Reportes y Indicadores**
- **Horas trabajadas**: Reporte detallado de horas por colaborador
- **Indicadores**: Métricas de rendimiento y productividad
- **Filtros por fecha**: Visualización por períodos específicos

## 🏗️ Arquitectura del Proyecto

### 📁 Estructura de Directorios

```
lib/
├── config/           # Configuraciones de la aplicación
├── models/           # Modelos de datos (eliminados - no utilizados)
├── pages/            # Páginas principales de la aplicación
├── providers/        # Providers para gestión de estado
├── services/         # Servicios de API y autenticación
├── theme/            # Temas y estilos de la aplicación
├── utils/            # Utilidades y helpers
├── widgets/          # Widgets reutilizables
└── main.dart         # Punto de entrada de la aplicación
```

### 🔧 **Servicios Principales**

#### **ApiService** (`lib/services/api_service.dart`)
- **Gestión centralizada** de todas las llamadas a la API
- **Métodos para actividades**: CRUD completo de actividades
- **Métodos para rendimientos**: Individuales y grupales
- **Métodos para personal**: Colaboradores, trabajadores, contratistas
- **Métodos para permisos**: Crear, editar, listar
- **Métodos para CECO**: Todos los tipos de centros de costo
- **Manejo de errores** y reintentos automáticos

#### **LoginService** (`lib/services/login_services.dart`)
- **Autenticación** de usuarios
- **Gestión de tokens** JWT
- **Refresh automático** de tokens
- **Almacenamiento seguro** de credenciales

### 🎨 **Temas y UI**

#### **AppTheme** (`lib/theme/app_theme.dart`)
- **Tema claro y oscuro** configurados
- **Colores personalizados** para la aplicación
- **Estilos consistentes** en toda la aplicación

#### **ThemeProvider** (`lib/providers/theme_provider.dart`)
- **Gestión de estado** del tema
- **Cambio dinámico** entre temas
- **Persistencia** de preferencias de tema

## 📱 Páginas Principales

### 🏠 **HomePage** (`lib/pages/home_page.dart`)
- **Dashboard principal** de la aplicación
- **Navegación** a todas las secciones
- **Información del usuario** y sucursal
- **Menú lateral** con todas las opciones

### 🔐 **LoginPage** (`lib/pages/login_page.dart`)
- **Formulario de login** con validación
- **Gestión de errores** de autenticación
- **Indicadores de carga** durante el login
- **Persistencia** de credenciales

### 📋 **ActividadesPage** (`lib/pages/actividades_page.dart`)
- **Lista de actividades** con filtros
- **Indicadores visuales** de rendimientos
- **Información detallada**: labor, unidad, tarifa, CECO
- **Navegación** a rendimientos y edición

### 📊 **RendimientosPage** (`lib/pages/rendimientos_page.dart`)
- **Visualización de rendimientos** por actividad
- **Tres tipos**: Individuales propios, de contratista y grupales
- **Unidades mostradas** junto a los valores
- **Acciones**: Crear, editar, eliminar rendimientos

### 👥 **Gestión de Personal**

#### **ColaboradoresPage** (`lib/pages/colaboradores_page.dart`)
- **Lista de colaboradores** con búsqueda
- **Acciones**: Crear, editar, eliminar
- **Información detallada** de cada colaborador

#### **TrabajadoresPage** (`lib/pages/trabajadores_page.dart`)
- **Gestión de trabajadores** contratistas
- **Filtros por tipo** de trabajador
- **Acciones completas** de CRUD

#### **ContratistasPage** (`lib/pages/contratistas_page.dart`)
- **Administración de empresas** contratistas
- **Información de contacto** y servicios
- **Gestión completa** de contratistas

### 📝 **PermisosPage** (`lib/pages/permisos_page.dart`)
- **Lista de permisos** por mes/año
- **Filtros avanzados** de búsqueda
- **Estados visuales** de permisos
- **Acciones**: Crear, editar, eliminar

### 🏢 **Formularios CECO**

#### **CECO Productivo** (`lib/pages/ceco_productivo_form.dart`)
- **Asignación de CECO** productivo a actividades
- **Prevención de navegación** sin asignar CECO
- **Validación automática** de datos

#### **CECO Riego** (`lib/pages/ceco_riego_form.dart`)
- **Gestión de equipos** de riego
- **Sectores de riego** por equipo
- **Asignación automática** de CECO
- **Navegación controlada**

#### **Otros CECO**: Administrativo, Maquinaria, Inversión
- **Formularios específicos** para cada tipo
- **Validación de datos** consistente
- **Prevención de navegación** sin completar

### 📊 **Reportes**

#### **HorasTrabajadasPage** (`lib/pages/horas_trabajadas_page.dart`)
- **Reporte detallado** de horas por colaborador
- **Filtros por fecha** y actividad
- **Visualización gráfica** de datos
- **Exportación** de reportes

#### **IndicadoresPage** (`lib/pages/indicadores_page.dart`)
- **Métricas de rendimiento** y productividad
- **Indicadores clave** de la operación
- **Visualización** de tendencias

### ℹ️ **Información**

#### **InfoPage** (`lib/pages/info_page.dart`)
- **Información de la aplicación** y desarrolladores
- **Animaciones** atractivas
- **Detalles técnicos** del proyecto
- **Información de contacto**

## 🔧 Configuración y Dependencias

### 📦 **Dependencias Principales**

```yaml
dependencies:
  flutter: sdk: flutter
  http: ^1.1.0                    # Llamadas HTTP a la API
  shared_preferences: ^2.2.2      # Almacenamiento local
  dropdown_search: ^5.0.6         # Dropdowns avanzados
  collection: ^1.18.0             # Utilidades de colecciones
  flutter_slidable: ^3.0.1        # Gestos deslizables
  cupertino_icons: ^1.0.2         # Iconos de iOS
  intl: ^0.20.2                   # Internacionalización
  multi_select_flutter: ^4.1.3    # Selección múltiple
  provider: ^6.0.5                # Gestión de estado
  crypto: ^3.0.3                  # Criptografía
```

### 🎨 **Assets**
- **Imágenes**: `assets/images/lh.jpg`, `assets/images/fondo.jpg`
- **Iconos**: Configurados con `flutter_launcher_icons`

## 🚀 Instalación y Uso

### 📋 **Requisitos Previos**
- Flutter SDK >=3.2.3
- Dart SDK compatible
- Android Studio / VS Code
- Dispositivo Android o emulador

### ⚙️ **Configuración**

1. **Clonar el repositorio**:
   ```bash
   git clone [URL_DEL_REPOSITORIO]
   cd app_lh_tarja
   ```

2. **Instalar dependencias**:
   ```bash
   flutter pub get
   ```

3. **Configurar API**:
   - Editar `lib/services/api_service.dart`
   - Actualizar `baseUrl` con la URL de tu API

4. **Ejecutar la aplicación**:
   ```bash
   flutter run
   ```

### 📱 **Generar APK**

```bash
flutter build apk --release
```

## 🔗 Integración con Backend

### 🌐 **API Endpoints Principales**

La aplicación se conecta a una API Flask que proporciona los siguientes endpoints:

- **Autenticación**: `/auth/login`, `/auth/refresh`
- **Actividades**: `/actividades`, `/actividades/{id}`
- **Rendimientos**: `/rendimientos/individuales`, `/rendimientos/grupales`
- **Personal**: `/colaboradores`, `/trabajadores`, `/contratistas`
- **Permisos**: `/permisos`, `/permisos/{id}`
- **CECO**: `/ceco/{tipo}`, `/ceco/riego/equipos`

### 🔐 **Autenticación JWT**

- **Login**: Obtiene access_token y refresh_token
- **Refresh automático**: Renueva tokens expirados
- **Almacenamiento seguro**: Tokens en SharedPreferences
- **Navegación protegida**: Verificación de autenticación

## 🎨 Características de UI/UX

### 🎯 **Diseño Responsivo**
- **Adaptable** a diferentes tamaños de pantalla
- **Navegación intuitiva** con drawer y bottom navigation
- **Feedback visual** para todas las acciones

### 🎨 **Temas**
- **Tema claro**: Colores claros para uso diurno
- **Tema oscuro**: Colores oscuros para uso nocturno
- **Cambio dinámico**: Sin reiniciar la aplicación

### 📊 **Indicadores Visuales**
- **Indicadores de rendimiento**: Verde/rojo según estado
- **Iconos informativos**: Para diferentes tipos de datos
- **Animaciones**: Transiciones suaves entre páginas

## 🔧 Características Técnicas

### 🏗️ **Arquitectura**
- **Patrón Provider**: Gestión de estado
- **Separación de responsabilidades**: Services, Pages, Widgets
- **Código limpio**: Sin archivos innecesarios
- **Mantenibilidad**: Estructura clara y documentada

### 🔒 **Seguridad**
- **Tokens JWT**: Autenticación segura
- **Validación de datos**: En frontend y backend
- **Manejo de errores**: Robustez en la aplicación
- **Logs condicionales**: Solo en desarrollo

### ⚡ **Performance**
- **Lazy loading**: Carga bajo demanda
- **Caching**: Datos almacenados localmente
- **Optimización de imágenes**: Assets optimizados
- **Tree shaking**: Eliminación de código no usado

## 📝 Notas de Desarrollo

### 🗑️ **Archivos Eliminados**
- `lib/services/rendimiento_service.dart`: No se utilizaba
- `lib/config/api_config.dart`: Funcionalidad duplicada
- `lib/models/rendimiento_grupal.dart`: No se instanciaba
- `lib/models/rendimiento_individual.dart`: No se utilizaba

### 🔄 **Mejoras Implementadas**
- **Unidades en rendimientos**: Visualización mejorada
- **Prevención de navegación**: En formularios CECO
- **Indicadores visuales**: Para rendimientos en actividades
- **Optimización de logs**: Mejor rendimiento

## 🤝 Contribución

### 📋 **Guías de Desarrollo**
1. **Mantener estructura** de directorios
2. **Usar ApiService** para todas las llamadas HTTP
3. **Documentar** funciones complejas
4. **Seguir** convenciones de Flutter
5. **Probar** cambios antes de commit

### 🐛 **Reporte de Bugs**
- Describir el problema claramente
- Incluir pasos para reproducir
- Adjuntar logs si es necesario
- Especificar dispositivo y versión

## 📞 Soporte

Para soporte técnico o preguntas sobre la aplicación, contactar al equipo de desarrollo.

---

**Desarrollado con ❤️ para LH Tarja**
