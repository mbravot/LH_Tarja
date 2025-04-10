import 'package:flutter/material.dart';
import '../services/api_service.dart';

class UsersPage extends StatefulWidget {
  @override
  _UsersPageState createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final ApiService apiService = ApiService();
  Future<List<dynamic>>? _futureUsers;

  @override
  void initState() {
    super.initState();
    _futureUsers = apiService.getUsuarios();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Usuarios')),
      body: FutureBuilder<List<dynamic>>(
        future: _futureUsers,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else {
            final users = snapshot.data!;
            return ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                return ListTile(
                  title: Text(user['nombre'] ?? 'Sin nombre'),
                  subtitle: Text('ID: ${user['id']}'),
                );
              },
            );
          }
        },
      ),
    );
  }
}
