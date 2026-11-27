import 'package:flutter/material.dart';

import '../services/group_service.dart';
import '../services/user_service.dart';
import '../widgets/error_status_content.dart';

class AdviserHomeScreen extends StatefulWidget {
  const AdviserHomeScreen({
    super.key,
    required this.profile,
    required this.groupService,
    required this.onLogout,
  });

  final UserProfile profile;
  final GroupService groupService;
  final VoidCallback onLogout;

  @override
  State<AdviserHomeScreen> createState() => _AdviserHomeScreenState();
}

class _AdviserHomeScreenState extends State<AdviserHomeScreen> {
  late final Stream<List<StudyGroup>> _groupsStream;

  @override
  void initState() {
    super.initState();
    _groupsStream = widget.groupService.watchAdviserGroups(widget.profile.uid);
  }

  String _memberCountText(int count) {
    if (count == 1) {
      return '1 member';
    }
    return '$count members';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Adviser Home')),
      body: SafeArea(
        child: StreamBuilder<List<StudyGroup>>(
          stream: _groupsStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              debugPrint('Adviser groups stream error: ${snapshot.error}');
              return ErrorStatusContent(
                message: 'Something went wrong. Please try again.',
                onLogout: widget.onLogout,
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final groups = snapshot.data ?? const <StudyGroup>[];
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(widget.profile.name),
                const SizedBox(height: 8),
                Text(
                  'Your groups',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                if (groups.isEmpty)
                  const Text('No groups yet.')
                else
                  ...groups.map(
                    (group) => Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(group.name),
                        subtitle: Text(
                          _memberCountText(group.memberIds.length),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: widget.onLogout,
                  child: const Text('Logout'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
