import 'package:flutter/material.dart';
import 'package:doctor_portal/theme.dart';
import 'package:doctor_portal/bottom_nav_bar.dart';
import 'package:doctor_portal/patients_screen.dart';
import 'package:doctor_portal/appointments_screen.dart';
import 'package:doctor_portal/records_screen.dart';
import 'package:doctor_portal/profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    PatientsScreen(),
    AppointmentsScreen(),
    RecordsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppTheme.background,
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
      ),
    );
  }
}
