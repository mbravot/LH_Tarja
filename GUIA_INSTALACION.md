# 🚀 Guía de Instalación Rápida - LH Tarjas

## ⚡ Instalación en 5 minutos

### 1. Prerrequisitos
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.2.3+)
- [Git](https://git-scm.com/downloads)
- [Android Studio](https://developer.android.com/studio) o [VS Code](https://code.visualstudio.com/)
- [Dart](https://dart.dev/get-dart) (incluido con Flutter)

### 2. Clonar el Repositorio
```bash
git clone https://github.com/mbravot/app_LH_Tarjas.git
cd app_LH_Tarjas
```

### 3. Instalar Dependencias
```bash
flutter pub get
```

### 4. Configurar API
La aplicación está configurada para usar la API de producción:
```dart
// lib/services/login_services.dart y lib/services/api_service.dart
final String baseUrl = 'https://apilhtarja-927498545444.us-central1.run.app/api';
```

### 5. Ejecutar la Aplicación
```bash
flutter run
```

## 🔧 Configuración Detallada

### Verificar Flutter
```bash
flutter doctor
```

### Configurar Dispositivo
```bash
# Listar dispositivos disponibles
flutter devices

# Ejecutar en dispositivo específico
flutter run -d chrome  # Web
flutter run -d android # Android
flutter run -d ios     # iOS
```

### Configuración de IDE

#### VS Code
1. Instalar extensión "Flutter"
2. Instalar extensión "Dart"
3. Configurar Flutter SDK path

#### Android Studio
1. Instalar plugin "Flutter"
2. Instalar plugin "Dart"
3. Configurar Android SDK

## 🐛 Solución de Problemas Comunes

### Error: "Flutter command not found"
```bash
# Agregar Flutter al PATH
export PATH="$PATH:`pwd`/flutter/bin"
```

### Error: "No connected devices"
```bash
# Verificar dispositivos
flutter devices

# Iniciar emulador Android
flutter emulators --launch <emulator_id>
```

### Error: "Dependencies not found"
```bash
# Limpiar cache
flutter clean
flutter pub get
```

### Error: "API connection failed"
1. Verificar URL del servidor (ya configurada para producción)
2. Verificar conectividad de internet
3. Verificar que el servidor esté ejecutándose

### Error: "Token expired"
La aplicación maneja automáticamente la renovación de tokens, pero si persiste:
1. Verificar que el refresh token esté válido
2. Limpiar SharedPreferences si es necesario
3. Revisar logs de la aplicación

## 📱 Configuración de Dispositivos

### Android
1. Habilitar "Modo desarrollador"
2. Habilitar "Depuración USB"
3. Conectar dispositivo via USB
4. Autorizar depuración en el dispositivo

### iOS (Solo macOS)
1. Instalar Xcode
2. Configurar certificados de desarrollo
3. Conectar dispositivo iOS
4. Confiar en el certificado de desarrollador

### Web
1. No requiere configuración adicional
2. Ejecutar con `flutter run -d chrome`

## 🔐 Configuración de Autenticación

### Variables de Entorno
```dart
// lib/services/login_services.dart
final String baseUrl = 'https://apilhtarja-927498545444.us-central1.run.app/api';
```

### Credenciales de Prueba
```json
{
  "usuario": "mbravo",
  "clave": "password123"
}
```

### Configuración de Tokens
La aplicación maneja automáticamente:
- Almacenamiento de access_token y refresh_token
- Renovación automática de tokens
- Manejo de sesiones expiradas
- Limpieza automática de datos al logout

## 📊 Comandos Útiles

### Desarrollo
```bash
flutter run              # Ejecutar en modo debug
flutter run --release    # Ejecutar en modo release
flutter hot reload       # Recarga en caliente (r)
flutter hot restart      # Reinicio en caliente (R)
```

### Build
```bash
flutter build apk        # Android APK
flutter build appbundle  # Android App Bundle
flutter build ios        # iOS
flutter build web        # Web
```

### Testing
```bash
flutter test             # Ejecutar tests
flutter test --coverage  # Tests con cobertura
```

### Análisis
```bash
flutter analyze          # Análisis estático
flutter format .         # Formatear código
```

## 🎯 Estructura del Proyecto

```
app_LH_Tarjas/
├── lib/                    # Código fuente
│   ├── main.dart          # Punto de entrada
│   ├── pages/             # Páginas (44 archivos)
│   │   ├── home_page.dart # Página principal
│   │   ├── actividades_page.dart # Gestión de actividades
│   │   ├── rendimientos_page.dart # Gestión de rendimientos
│   │   ├── indicadores_page.dart # Indicadores
│   │   ├── usuarios_page.dart # Gestión de usuarios
│   │   ├── trabajadores_page.dart # Gestión de trabajadores
│   │   ├── contratistas_page.dart # Gestión de contratistas
│   │   └── ...            # Otras páginas especializadas
│   ├── services/          # Servicios API
│   │   ├── api_service.dart # Servicio principal (4315 líneas)
│   │   └── login_services.dart # Autenticación
│   ├── providers/         # Gestión de estado
│   ├── widgets/           # Widgets reutilizables
│   └── theme/             # Temas y estilos
├── assets/                # Recursos
│   └── images/           # Imágenes
├── test/                  # Tests
├── android/              # Configuración Android
├── ios/                  # Configuración iOS
├── web/                  # Configuración Web
└── pubspec.yaml          # Dependencias
```

## 🔍 Debugging

### Logs de Debug
```dart
// Los logs están optimizados para producción
logDebug("🔍 Datos del backend: $data");
logInfo("ℹ️ Login exitoso");
logError("❌ Error de conexión");
```

### Flutter Inspector
- Presionar `F12` en VS Code
- Usar "Flutter Inspector" en Android Studio
- Verificar widgets en tiempo real

### Performance
```bash
flutter run --profile    # Modo profile
flutter run --trace-startup  # Trazar inicio
```

### Manejo de Errores
La aplicación incluye manejo automático de:
- Tokens expirados
- Errores de conexión
- Respuestas HTML inesperadas
- Timeouts de red
- Errores de validación

## 📚 Recursos Adicionales

### Documentación
- [Flutter Docs](https://docs.flutter.dev/)
- [Dart Docs](https://dart.dev/guides)
- [Material Design](https://material.io/design)
- [DOCUMENTACION_TECNICA.md](DOCUMENTACION_TECNICA.md) - Documentación técnica completa

### Comunidad
- [Flutter Community](https://flutter.dev/community)
- [Stack Overflow](https://stackoverflow.com/questions/tagged/flutter)
- [Reddit r/FlutterDev](https://www.reddit.com/r/FlutterDev/)

### Herramientas
- [Flutter Inspector](https://docs.flutter.dev/development/tools/flutter-inspector)
- [Flutter DevTools](https://docs.flutter.dev/development/tools/devtools)
- [Flutter Performance](https://docs.flutter.dev/perf)

## 🆘 Soporte

### Problemas Comunes
1. **App no inicia**: Verificar dependencias con `flutter pub get`
2. **Errores de API**: La URL ya está configurada para producción
3. **Problemas de UI**: Usar Flutter Inspector
4. **Errores de build**: Limpiar con `flutter clean`
5. **Tokens expirados**: La app maneja esto automáticamente

### Contacto
- Crear issue en [GitHub](https://github.com/mbravot/app_LH_Tarjas/issues)
- Contactar al equipo de desarrollo
- Revisar la documentación técnica completa

### Funcionalidades Disponibles
La aplicación incluye:
- ✅ Sistema de autenticación completo
- ✅ Gestión de actividades agrícolas
- ✅ Sistema de rendimientos
- ✅ Gestión de personal
- ✅ Sistema de CECOs
- ✅ Gestión de usuarios y permisos
- ✅ Interfaz moderna y responsive

---

**Tiempo estimado de instalación**: 5-10 minutos  
**Última actualización**: Diciembre 2024  
**Estado**: Aplicación completamente funcional con todas las características implementadas 