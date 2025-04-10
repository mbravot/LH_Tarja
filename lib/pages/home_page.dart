import 'package:flutter/material.dart';
import 'actividades_page.dart';
import 'rendimientos_page.dart';
import 'contratistas_page.dart';
import 'trabajadores_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_page.dart';
import 'cambiar_clave_page.dart';
import 'cambiar_sucursal_page.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  String userName = "Usuario";
  String userSucursal = "Sucursal";
  bool _isLoading = false;
  late AnimationController _animationController;
  
  Key _actividadesKey = UniqueKey();
  Key _rendimientosKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _cargarNombreUsuario();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _forzarRecargaPantallas() {
    setState(() {
      _actividadesKey = UniqueKey();
      _rendimientosKey = UniqueKey();
    });
  }

  Future<void> _cargarNombreUsuario() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        userName = prefs.getString('user_name') ?? "Usuario";
        userSucursal = prefs.getString('user_sucursal') ?? "Sucursal";
        _isLoading = false;
      });
      print("🏠 Sucursal activa cargada: $userSucursal");
      _forzarRecargaPantallas();
    } catch (e) {
      print("❌ Error cargando datos de usuario: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _recargarPagina() async {
    _animationController.forward(from: 0);
    await _cargarNombreUsuario();
  }

  Future<void> _cerrarSesion() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Row(
            children: [
              Icon(Icons.logout, color: Colors.red),
              SizedBox(width: 10),
              Text("Cerrar Sesión"),
            ],
          ),
          content: Text("¿Está seguro que desea cerrar sesión?"),
          actions: [
            TextButton(
              child: Text("Cancelar"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text("Cerrar Sesión"),
              onPressed: () async {
                Navigator.of(context).pop();
                setState(() => _isLoading = true);
                try {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('token');
                  await prefs.remove('user_name');
                  await prefs.remove('user_sucursal');
                  await prefs.remove('id_sucursal');
                  if (mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => LoginPage()),
                    );
                  }
                } finally {
                  if (mounted) {
                    setState(() => _isLoading = false);
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String titulo = (_selectedIndex == 0) ? "Actividades" : "Rendimientos";

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.green,
            elevation: 0,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text(
                            userName,
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_on, color: Colors.white70, size: 14),
                          SizedBox(width: 4),
                          Text(
                            userSucursal,
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              RotationTransition(
                turns: Tween(begin: 0.0, end: 1.0).animate(_animationController),
                child: IconButton(
                  icon: Icon(Icons.refresh, color: Colors.white),
                  onPressed: _recargarPagina,
                ),
              ),
            ],
          ),
          drawer: _buildDrawer(),
          body: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                child: _buildTabBar(),
              ),
              Expanded(
                child: _selectedIndex == 0
                    ? ActividadesPage(
                        key: _actividadesKey,
                        onRefresh: _forzarRecargaPantallas,
                      )
                    : RendimientosPage(
                        key: _rendimientosKey,
                        onRefresh: _forzarRecargaPantallas,
                      ),
              ),
            ],
          ),
          bottomNavigationBar: _buildBottomNavigationBar(),
        ),
        if (_isLoading)
          Container(
            color: Colors.black54,
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: FutureBuilder<SharedPreferences>(
        future: SharedPreferences.getInstance(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
              ),
            );
          }

          final prefs = snapshot.data!;
          final esAdmin = prefs.getString('id_rol') == '1';

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.green.shade700,
                  Colors.green.shade500,
                ],
              ),
            ),
            child: Column(
              children: [
                _buildDrawerHeader(),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        SizedBox(height: 20),
                        if (esAdmin) _buildDrawerItem(
                          icon: Icons.people,
                          title: "Usuarios",
                          onTap: () => Navigator.pushNamed(context, '/usuarios'),
                          color: Colors.green,
                        ),
                        _buildDrawerItem(
                          icon: Icons.group,
                          title: "Contratistas",
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => ContratistasPage()),
                            );
                          },
                          color: Colors.green,
                        ),
                        _buildDrawerItem(
                          icon: Icons.people,
                          title: "Trabajadores",
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => TrabajadoresPage()),
                            );
                          },
                          color: Colors.green,
                        ),
                        Divider(height: 30),
                        _buildDrawerItem(
                          icon: Icons.change_circle,
                          title: "Cambiar Sucursal Activa",
                          onTap: () async {
                            Navigator.pop(context);
                            final resultado = await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => CambiarSucursalPage()),
                            );
                            if (resultado == true) {
                              _cargarNombreUsuario();
                              _forzarRecargaPantallas();
                            }
                          },
                          color: Colors.blue,
                        ),
                        _buildDrawerItem(
                          icon: Icons.lock,
                          title: "Cambiar Clave",
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => CambiarClavePage()),
                            );
                          },
                          color: Colors.amber,
                        ),
                        _buildDrawerItem(
                          icon: Icons.logout,
                          title: "Cerrar Sesión",
                          onTap: () {
                            Navigator.pop(context);
                            _cerrarSesion();
                          },
                          color: Colors.red,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 60, 16, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person, color: Colors.green, size: 40),
          ),
          SizedBox(height: 16),
          Text(
            "Bienvenido,",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          Text(
            userName,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on, color: Colors.white70, size: 16),
                SizedBox(width: 4),
                Text(
                  userSucursal,
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildTab(0, "Actividades", Icons.assignment),
          _buildTab(1, "Rendimientos", Icons.trending_up),
        ],
      ),
    );
  }

  Widget _buildTab(int index, String title, IconData icon) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.green : Colors.white,
            ),
            SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.green : Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'Actividades',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.trending_up),
            label: 'Rendimientos',
          ),
        ],
      ),
    );
  }
}
