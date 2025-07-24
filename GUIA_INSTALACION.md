# 🚀 Guía de Instalación Rápida - APP_MOVIL_BASE

## ⚡ Instalación en 5 minutos

### 1. Prerrequisitos
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.2.3+)
- [Git](https://git-scm.com/downloads)
- [Android Studio](https://developer.android.com/studio) o [VS Code](https://code.visualstudio.com/)
- [Dart](https://dart.dev/get-dart) (incluido con Flutter)

### 2. Clonar el Repositorio
```bash
git clone https://github.com/mbravot/APP_MOVIL_BASE.git
cd APP_MOVIL_BASE
```

### 3. Instalar Dependencias
```bash
flutter pub get
```

### 4. Configurar API
Editar `lib/services/login_services.dart`:
```dart
final String baseUrl = 'http://tu-servidor:puerto/api';
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
1. Verificar URL del servidor
2. Verificar conectividad de red
3. Verificar que el servidor esté ejecutándose

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
final String baseUrl = 'http://192.168.1.37:5000/api';
```

### Credenciales de Prueba
```json
{
  "usuario": "mbravo",
  "clave": "password123"
}
```

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
APP_MOVIL_BASE/
├── lib/                    # Código fuente
│   ├── main.dart          # Punto de entrada
│   ├── pages/             # Páginas
│   ├── services/          # Servicios API
│   ├── widgets/           # Widgets reutilizables
│   └── ...
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
// Los logs aparecen en la consola
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

## 📚 Recursos Adicionales

### Documentación
- [Flutter Docs](https://docs.flutter.dev/)
- [Dart Docs](https://dart.dev/guides)
- [Material Design](https://material.io/design)

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
2. **Errores de API**: Verificar URL y conectividad
3. **Problemas de UI**: Usar Flutter Inspector
4. **Errores de build**: Limpiar con `flutter clean`

### Contacto
- Crear issue en [GitHub](https://github.com/mbravot/APP_MOVIL_BASE/issues)
- Contactar al equipo de desarrollo

---

**Tiempo estimado de instalación**: 5-10 minutos  
**Última actualización**: Diciembre 2024 