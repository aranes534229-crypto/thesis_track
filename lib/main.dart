import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/adviser_home_screen.dart';
import 'screens/create_join_group_screen.dart';
import 'screens/login_screen.dart';
import 'screens/student_home_screen.dart';
import 'services/group_service.dart';
import 'services/user_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ThesisTrackApp());
}

class ThesisTrackApp extends StatelessWidget {
  const ThesisTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ThesisTrack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      builder: (context, child) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  late final UserService _userService;
  late final GroupService _groupService;

  @override
  void initState() {
    super.initState();
    _userService = UserService();
    _groupService = GroupService();
  }

  Future<void> _logout() async {
    try {
      await _userService.signOut();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(authErrorMessage(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('Authentication state stream error: ${snapshot.error}');
          return _StatusScreen(
            message: 'Something went wrong. Please try again.',
            onLogout: () {
              _logout();
            },
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        final user = snapshot.data;
        if (user == null) {
          return LoginScreen(userService: _userService);
        }

        return _ProfileGate(
          key: ValueKey(user.uid),
          uid: user.uid,
          userService: _userService,
          groupService: _groupService,
          onLogout: () {
            _logout();
          },
        );
      },
    );
  }
}

class _ProfileGate extends StatefulWidget {
  const _ProfileGate({
    super.key,
    required this.uid,
    required this.userService,
    required this.groupService,
    required this.onLogout,
  });

  final String uid;
  final UserService userService;
  final GroupService groupService;
  final VoidCallback onLogout;

  @override
  State<_ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<_ProfileGate> {
  late final Stream<UserProfile?> _profileStream;

  @override
  void initState() {
    super.initState();
    _profileStream = widget.userService.watchProfile(widget.uid);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserProfile?>(
      stream: _profileStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('User profile stream error: ${snapshot.error}');
          return _StatusScreen(
            message: 'Something went wrong. Please try again.',
            onLogout: widget.onLogout,
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        final profile = snapshot.data;
        if (profile != null) {
          if (profile.role == 'student') {
            return _StudentGroupGate(
              key: ValueKey('student-${profile.uid}'),
              profile: profile,
              groupService: widget.groupService,
              onLogout: widget.onLogout,
            );
          }

          return AdviserHomeScreen(
            profile: profile,
            groupService: widget.groupService,
            onLogout: widget.onLogout,
          );
        }

        return _StatusScreen(
          message: 'User profile not found',
          onLogout: widget.onLogout,
        );
      },
    );
  }
}

class _StudentGroupGate extends StatefulWidget {
  const _StudentGroupGate({
    super.key,
    required this.profile,
    required this.groupService,
    required this.onLogout,
  });

  final UserProfile profile;
  final GroupService groupService;
  final VoidCallback onLogout;

  @override
  State<_StudentGroupGate> createState() => _StudentGroupGateState();
}

class _StudentGroupGateState extends State<_StudentGroupGate> {
  late final Stream<StudyGroup?> _groupStream;

  @override
  void initState() {
    super.initState();
    _groupStream = widget.groupService.watchStudentGroup(widget.profile.uid);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<StudyGroup?>(
      stream: _groupStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('Student group stream error: ${snapshot.error}');
          return _StatusScreen(
            message: 'Something went wrong. Please try again.',
            onLogout: widget.onLogout,
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        final group = snapshot.data;
        if (group != null) {
          return StudentHomeScreen(
            profile: widget.profile,
            group: group,
            groupService: widget.groupService,
            onLogout: widget.onLogout,
          );
        }

        return CreateOrJoinGroupScreen(
          profile: widget.profile,
          groupService: widget.groupService,
          onLogout: widget.onLogout,
        );
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(child: Center(child: CircularProgressIndicator())),
    );
  }
}

class _StatusScreen extends StatelessWidget {
  const _StatusScreen({required this.message, required this.onLogout});

  final String message;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ThesisTrack')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
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
