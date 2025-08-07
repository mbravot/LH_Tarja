# 📚 Documentación Técnica - LH Tarja

## 🏗️ Arquitectura del Sistema

### 📊 Diagrama de Arquitectura

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Flutter App   │    │   Flask API     │    │   Database      │
│                 │    │                 │    │                 │
│  ├─ UI Layer    │◄──►│  ├─ Auth        │◄──►│  ├─ Users       │
│  ├─ Services    │    │  ├─ Activities  │    │  ├─ Activities  │
│  ├─ Providers   │    │  ├─ Rendimientos│    │  ├─ Rendimientos│
│  └─ Models      │    │  └─ Permisos    │    │  └─ Permisos    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### 🔄 Flujo de Datos

1. **Autenticación**: Login → JWT Token → Almacenamiento Local
2. **Llamadas API**: Service → HTTP Request → API Response → UI Update
3. **Gestión de Estado**: Provider → State Change → UI Rebuild

## 🔧 Servicios Principales

### 📡 ApiService

```dart
class ApiService {
  final String baseUrl = 'https://apilhtarja-927498545444.us-central1.run.app/api';
  
  // Métodos principales
  Future<List<Map<String, dynamic>>> getActividades() async { ... }
  Future<bool> crearRendimientoIndividualPropio(Map<String, dynamic> data) async { ... }
  Future<List<Map<String, dynamic>>> getColaboradores() async { ... }
  // ... más métodos
}
```

#### 🔑 Características Clave:
- **Gestión centralizada** de todas las llamadas HTTP
- **Manejo automático** de tokens JWT
- **Reintentos automáticos** en caso de error
- **Logging condicional** para desarrollo

### 🔐 LoginService

```dart
class LoginService {
  Future<bool> login(String usuario, String password) async {
    // Validación de credenciales
    // Almacenamiento de tokens
    // Actualización de estado de autenticación
  }
  
  Future<bool> refreshToken() async {
    // Renovación automática de tokens
    // Manejo de errores de expiración
  }
}
```

## 📱 Páginas y Navegación

### 🏠 HomePage - Dashboard Principal

```dart
class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Estado de la aplicación
  String userName = '';
  String userSucursal = '';
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('LH Tarja')),
      drawer: _buildDrawer(),
      body: _buildBody(),
    );
  }
}
```

### 📋 ActividadesPage - Gestión de Actividades

#### 🎯 Características Principales:
- **Lista de actividades** con filtros
- **Indicadores visuales** de rendimientos
- **Navegación** a rendimientos y edición
- **Información detallada**: labor, unidad, tarifa, CECO

#### 📊 Indicadores de Rendimiento:
```dart
Widget _buildRendimientoIndicator(Map<String, dynamic> actividad) {
  bool tieneRendimientos = _tieneRendimientos(actividad);
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: tieneRendimientos ? Colors.green : Colors.red,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      tieneRendimientos ? 'Con rendimientos' : 'Sin rendimientos',
      style: TextStyle(color: Colors.white, fontSize: 12),
    ),
  );
}
```

### 📊 RendimientosPage - Gestión de Rendimientos

#### 🎯 Tipos de Rendimientos:

1. **Rendimientos Individuales Propios**
   ```dart
   // Estructura de datos
   {
     "id": "uuid",
     "id_actividad": "uuid",
     "id_colaborador": "string",
     "rendimiento": "55",
     "horas_trabajadas": "7",
     "nombre_colaborador": "JUAN GUILLERMO"
   }
   ```

2. **Rendimientos Individuales de Contratista**
   ```dart
   // Estructura de datos
   {
     "id": "uuid",
     "id_actividad": "uuid",
     "id_trabajador": "uuid",
     "rendimiento": 25.0,
     "porcentaje": 0.5,
     "nombre_trabajador": "TRABAJADOR"
   }
   ```

3. **Rendimientos Grupales**
   ```dart
   // Estructura de datos
   {
     "id": "uuid",
     "id_actividad": "uuid",
     "cantidad_trab": 5,
     "rendimiento_total": 25.0,
     "labor": "AMONTONAR SARMIENTO"
   }
   ```

#### 🎨 Visualización con Unidades:
```dart
Widget _buildRendimientoWithUnit(String value, String unit) {
  return Row(
    children: [
      Icon(Icons.speed, color: Colors.green, size: 18),
      SizedBox(width: 4),
      Text('Rendimiento: $value'),
      SizedBox(width: 8),
      Icon(Icons.category, color: Colors.blue[600], size: 14),
      SizedBox(width: 2),
      Text(
        unit,
        style: TextStyle(
          color: Colors.blue[600],
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    ],
  );
}
```

## 🏢 Formularios CECO

### 📋 CECO Riego - Formulario Complejo

```dart
class CecoRiegoForm extends StatefulWidget {
  final Map<String, dynamic> actividad;
  
  @override
  _CecoRiegoFormState createState() => _CecoRiegoFormState();
}

class _CecoRiegoFormState extends State<CecoRiegoForm> {
  // Estados del formulario
  String? _selectedCaseta;
  String? _selectedEquipo;
  String? _selectedSector;
  Map<String, dynamic>? _selectedCeco;
  
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Prevenir navegación sin asignar CECO
        return await _showExitDialog();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('CECO Riego'),
          automaticallyImplyLeading: false, // Deshabilitar botón atrás
        ),
        body: _buildForm(),
      ),
    );
  }
}
```

#### 🔄 Flujo de Datos CECO Riego:
1. **Selección de Caseta** → Carga equipos disponibles
2. **Selección de Equipo** → Carga sectores disponibles
3. **Selección de Sector** → Asigna CECO automáticamente
4. **Validación** → Prevenir navegación sin completar

## 🔐 Autenticación y Seguridad

### 🔑 JWT Token Management

```dart
class TokenManager {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  
  static Future<void> saveTokens(String accessToken, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
    await prefs.setString(_refreshTokenKey, refreshToken);
  }
  
  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey);
  }
  
  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }
}
```

### 🔄 Refresh Token Flow

```dart
Future<bool> refreshToken() async {
  try {
    final refreshToken = await TokenManager.getRefreshToken();
    if (refreshToken == null) return false;
    
    final response = await http.post(
      Uri.parse('$baseUrl/auth/refresh'),
      headers: {
        'Authorization': 'Bearer $refreshToken',
        'Content-Type': 'application/json',
      },
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      await TokenManager.saveTokens(
        data['access_token'],
        data['refresh_token'],
      );
      return true;
    }
    return false;
  } catch (e) {
    return false;
  }
}
```

## 🎨 UI/UX Components

### 🎯 Custom Widgets

#### 📊 Activity Card
```dart
class ActivityCard extends StatelessWidget {
  final Map<String, dynamic> actividad;
  final VoidCallback onTap;
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(actividad['nombre_labor'] ?? ''),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Unidad: ${actividad['nombre_unidad'] ?? ''}'),
            Text('Tarifa: \$${actividad['tarifa'] ?? ''}'),
            Text('CECO: ${actividad['nombre_ceco'] ?? ''}'),
            _buildRendimientoIndicator(actividad),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
```

#### 🔄 Loading Widget
```dart
class LoadingWidget extends StatelessWidget {
  final String message;
  
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(message),
        ],
      ),
    );
  }
}
```

### 🎨 Theme Management

```dart
class AppTheme {
  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primarySwatch: Colors.green,
    scaffoldBackgroundColor: Colors.grey[50],
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.green,
      foregroundColor: Colors.white,
    ),
  );
  
  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.green,
    scaffoldBackgroundColor: Colors.grey[900],
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.grey[800],
      foregroundColor: Colors.white,
    ),
  );
}
```

## 🔧 Error Handling

### 📝 Error Management Strategy

```dart
class ApiErrorHandler {
  static String handleError(dynamic error) {
    if (error is SocketException) {
      return 'Error de conexión. Verifica tu conexión a internet.';
    } else if (error is TimeoutException) {
      return 'Tiempo de espera agotado. Intenta nuevamente.';
    } else if (error is FormatException) {
      return 'Error en el formato de datos.';
    } else {
      return 'Error inesperado: ${error.toString()}';
    }
  }
  
  static void showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }
}
```

## 📊 Data Models

### 🏗️ Activity Model (Conceptual)

```dart
// Estructura de datos de actividad
{
  "id": "uuid",
  "nombre_labor": "AFEITAR RACIMOS",
  "nombre_unidad": "RACIMOS",
  "tarifa": "1000",
  "nombre_ceco": "CECO PRODUCTIVO",
  "id_ceco": "123",
  "fecha": "2025-01-15",
  "tiene_rendimientos": true
}
```

### 👥 User Model (Conceptual)

```dart
// Estructura de datos de usuario
{
  "id": "uuid",
  "usuario": "admin",
  "nombre": "Administrador",
  "sucursal": "Sucursal Principal",
  "rol": "admin",
  "activo": true
}
```

## 🔄 State Management

### 📊 Provider Pattern

```dart
class ThemeProvider with ChangeNotifier {
  bool _isDarkMode = false;
  
  bool get isDarkMode => _isDarkMode;
  
  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }
  
  ThemeData get theme => _isDarkMode ? AppTheme.darkTheme : AppTheme.lightTheme;
}
```

## 🚀 Performance Optimizations

### ⚡ Lazy Loading

```dart
class LazyLoadingList extends StatefulWidget {
  final Future<List<Map<String, dynamic>>> Function() loadData;
  
  @override
  _LazyLoadingListState createState() => _LazyLoadingListState();
}

class _LazyLoadingListState extends State<LazyLoadingList> {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final data = await widget.loadData();
      setState(() {
        _items = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
```

### 🔄 Caching Strategy

```dart
class CacheManager {
  static final Map<String, dynamic> _cache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiration = Duration(minutes: 5);
  
  static void set(String key, dynamic value) {
    _cache[key] = value;
    _cacheTimestamps[key] = DateTime.now();
  }
  
  static dynamic get(String key) {
    final timestamp = _cacheTimestamps[key];
    if (timestamp == null) return null;
    
    if (DateTime.now().difference(timestamp) > _cacheExpiration) {
      _cache.remove(key);
      _cacheTimestamps.remove(key);
      return null;
    }
    
    return _cache[key];
  }
}
```

## 🧪 Testing Strategy

### 📝 Unit Tests

```dart
void main() {
  group('ApiService Tests', () {
    test('should return activities list', () async {
      // Arrange
      final apiService = ApiService();
      
      // Act
      final result = await apiService.getActividades();
      
      // Assert
      expect(result, isA<List<Map<String, dynamic>>>());
    });
  });
}
```

### 🎯 Widget Tests

```dart
void main() {
  testWidgets('ActivityCard displays correct information', (WidgetTester tester) async {
    // Arrange
    final actividad = {
      'nombre_labor': 'Test Labor',
      'nombre_unidad': 'Test Unit',
      'tarifa': '100',
    };
    
    // Act
    await tester.pumpWidget(
      MaterialApp(
        home: ActivityCard(
          actividad: actividad,
          onTap: () {},
        ),
      ),
    );
    
    // Assert
    expect(find.text('Test Labor'), findsOneWidget);
    expect(find.text('Test Unit'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
  });
}
```

## 📱 Platform Support

### 🤖 Android Configuration

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    
    <application
        android:label="LH Tarja"
        android:icon="@mipmap/ic_launcher">
        <!-- ... -->
    </application>
</manifest>
```

### 🍎 iOS Configuration

```xml
<!-- ios/Runner/Info.plist -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

## 🔧 Build Configuration

### 📦 Release Build

```bash
# Generar APK de release
flutter build apk --release

# Generar APK dividido por arquitectura
flutter build apk --split-per-abi --release

# Generar bundle para Play Store
flutter build appbundle --release
```

### 🔍 Debug Configuration

```yaml
# analysis_options.yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    prefer_const_constructors: true
    avoid_print: true
    use_key_in_widget_constructors: true
```

## 📊 Analytics and Monitoring

### 📈 Performance Monitoring

```dart
class PerformanceMonitor {
  static void logApiCall(String endpoint, Duration duration) {
    if (kDebugMode) {
      print('API Call: $endpoint took ${duration.inMilliseconds}ms');
    }
  }
  
  static void logUserAction(String action) {
    if (kDebugMode) {
      print('User Action: $action');
    }
  }
}
```

## 🔄 Deployment Pipeline

### 🚀 CI/CD Configuration

```yaml
# .github/workflows/flutter.yml
name: Flutter CI

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v2
    
    - uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.2.3'
    
    - run: flutter pub get
    - run: flutter analyze
    - run: flutter test
    - run: flutter build apk --release
```

---

## 📚 Referencias y Recursos

### 🔗 Enlaces Útiles
- [Flutter Documentation](https://docs.flutter.dev/)
- [Dart Language Tour](https://dart.dev/guides/language/language-tour)
- [Provider Package](https://pub.dev/packages/provider)
- [HTTP Package](https://pub.dev/packages/http)

### 📖 Mejores Prácticas
1. **Separación de responsabilidades**: Services, Pages, Widgets
2. **Gestión de estado**: Usar Provider para estado global
3. **Manejo de errores**: Implementar estrategias robustas
4. **Performance**: Lazy loading y caching
5. **Testing**: Unit tests y widget tests

---

**Documentación técnica actualizada: Enero 2025** 