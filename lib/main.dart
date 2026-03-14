import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pages/main_menu.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: "https://mhmvzqgubfrmwglkxrna.supabase.co",
    anonKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1obXZ6cWd1YmZybXdnbGt4cm5hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg3ODUzMDQsImV4cCI6MjA4NDM2MTMwNH0.hfesH6w6oYET5n8R9zJFfwV4Up0tfGeACPJFIqtjoK4",
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Store App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MainMenu(),
    );
  }
}