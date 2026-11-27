import 'package:flutter/material.dart';

import '../services/group_service.dart';
import '../services/user_service.dart';
import '../widgets/error_status_content.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({
    super.key,
    required this.profile,
    required this.group,
    required this.groupService,
    required this.onLogout,
  });

  final UserProfile profile;
  final StudyGroup group;
  final GroupService groupService;
  final VoidCallback onLogout;

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  late final Stream<List<ChapterSummary>> _chaptersStream;

  @override
  void initState() {
    super.initState();
    _chaptersStream = widget.groupService.watchChapters(widget.group.id);
  }

  String _uploadText(int versionCount) {
    if (versionCount == 0) {
      return 'No upload yet';
    }
    if (versionCount == 1) {
      return '1 upload';
    }
    return '$versionCount uploads';
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'for_revision':
        return 'For Revision';
      case 'approved':
        return 'Approved';
      default:
        return status;
    }
  }

  Widget _buildChapterCard(ChapterSummary chapter) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(child: Text('${chapter.number}')),
        title: Text('Chapter ${chapter.number}'),
        subtitle: Text(_uploadText(chapter.versionCount)),
        trailing: Chip(label: Text(_statusLabel(chapter.status))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Student Home')),
      body: SafeArea(
        child: StreamBuilder<List<ChapterSummary>>(
          stream: _chaptersStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              debugPrint('Chapters stream error: ${snapshot.error}');
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

            final chapters = snapshot.data ?? const <ChapterSummary>[];
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(widget.profile.name),
                const SizedBox(height: 8),
                Text(
                  widget.group.name,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text('Group code: ${widget.group.code}'),
                const SizedBox(height: 20),
                const Card(
                  child: ListTile(
                    title: Text('Defense'),
                    subtitle: Text('No defense scheduled'),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Chapters', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                ...chapters.map(_buildChapterCard),
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
