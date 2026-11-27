import 'package:flutter/material.dart';

import '../services/user_service.dart';

class StudentHomeScreen extends StatelessWidget {
  const StudentHomeScreen({
    super.key,
    required this.profile,
    required this.onLogout,
  });

  final UserProfile profile;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Student Home')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Student Home',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                Text(profile.name),
                const SizedBox(height: 24),
                FilledButton(onPressed: onLogout, child: const Text('Logout')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
