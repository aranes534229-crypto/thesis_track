import 'package:flutter/material.dart';

import '../services/group_service.dart';
import '../services/user_service.dart';
import '../widgets/error_status_content.dart';

class CreateOrJoinGroupScreen extends StatefulWidget {
  const CreateOrJoinGroupScreen({
    super.key,
    required this.profile,
    required this.groupService,
    required this.onLogout,
  });

  final UserProfile profile;
  final GroupService groupService;
  final VoidCallback onLogout;

  @override
  State<CreateOrJoinGroupScreen> createState() =>
      _CreateOrJoinGroupScreenState();
}

class _CreateOrJoinGroupScreenState extends State<CreateOrJoinGroupScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _groupCodeController = TextEditingController();

  late final Stream<List<AdviserUser>> _advisersStream;
  String? _adviserId;
  String? _errorMessage;
  bool _isCreating = false;
  bool _isJoining = false;

  bool get _isBusy => _isCreating || _isJoining;

  @override
  void initState() {
    super.initState();
    _advisersStream = widget.groupService.watchAdvisers();
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _groupCodeController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
    });
  }

  Future<void> _createGroup() async {
    if (_isBusy) {
      return;
    }

    final name = _groupNameController.text.trim();
    if (name.isEmpty) {
      _showError('Please enter a group name.');
      return;
    }

    if (_adviserId == null) {
      _showError('Please choose an adviser.');
      return;
    }

    setState(() {
      _errorMessage = null;
      _isCreating = true;
    });

    try {
      await widget.groupService.createGroup(
        name: name,
        adviserId: _adviserId!,
        creatorUid: widget.profile.uid,
      );
    } catch (_) {
      if (mounted) {
        _showError('Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  Future<void> _joinGroup() async {
    if (_isBusy) {
      return;
    }

    final code = _groupCodeController.text.trim();
    if (code.isEmpty) {
      _showError('Please enter the group code.');
      return;
    }

    setState(() {
      _errorMessage = null;
      _isJoining = true;
    });

    try {
      await widget.groupService.joinGroup(
        code: code,
        studentUid: widget.profile.uid,
      );
    } catch (error) {
      if (mounted) {
        final message = error is GroupCodeNotFoundException
            ? 'Group code not found.'
            : 'Something went wrong. Please try again.';
        _showError(message);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isJoining = false;
        });
      }
    }
  }

  Widget _buildAdviserPicker(List<AdviserUser> advisers) {
    if (advisers.isEmpty) {
      return const Text(
        'No advisers registered yet. Ask your adviser to register first.',
      );
    }

    return DropdownButtonFormField<String>(
      initialValue: _adviserId,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Adviser'),
      items: advisers
          .map(
            (adviser) => DropdownMenuItem(
              value: adviser.uid,
              child: Text(
                '${adviser.name} (${adviser.email})',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: _isBusy
          ? null
          : (value) {
              if (value != null) {
                setState(() {
                  _adviserId = value;
                  _errorMessage = null;
                });
              }
            },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create or Join Group')),
      body: SafeArea(
        child: StreamBuilder<List<AdviserUser>>(
          stream: _advisersStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              debugPrint('Adviser list stream error: ${snapshot.error}');
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

            final advisers = snapshot.data ?? const <AdviserUser>[];
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Welcome, ${widget.profile.name}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 20),
                  if (_errorMessage != null) ...[
                    Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Create a group',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _groupNameController,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            enabled: !_isBusy,
                            decoration: const InputDecoration(
                              labelText: 'Group name',
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildAdviserPicker(advisers),
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: _isBusy ? null : _createGroup,
                            child: _isCreating
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Create Group'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Join a group',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _groupCodeController,
                            textCapitalization: TextCapitalization.characters,
                            textInputAction: TextInputAction.done,
                            enabled: !_isBusy,
                            onSubmitted: (_) {
                              if (!_isBusy) {
                                _joinGroup();
                              }
                            },
                            decoration: const InputDecoration(
                              labelText: 'Group code',
                            ),
                          ),
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: _isBusy ? null : _joinGroup,
                            child: _isJoining
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Join Group'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: _isBusy ? null : widget.onLogout,
                    child: const Text('Logout'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
