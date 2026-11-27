import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

class AdviserUser {
  const AdviserUser({
    required this.uid,
    required this.name,
    required this.email,
  });

  final String uid;
  final String name;
  final String email;
}

class StudyGroup {
  const StudyGroup({
    required this.id,
    required this.name,
    required this.code,
    required this.adviserId,
    required this.memberIds,
  });

  final String id;
  final String name;
  final String code;
  final String adviserId;
  final List<String> memberIds;
}

class ChapterSummary {
  const ChapterSummary({
    required this.id,
    required this.number,
    required this.status,
    required this.versionCount,
  });

  final String id;
  final int number;
  final String status;
  final int versionCount;
}

class GroupCodeNotFoundException implements Exception {
  const GroupCodeNotFoundException();
}

class GroupService {
  GroupService({FirebaseFirestore? firestore, Random? random})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _random = random ?? Random.secure();

  static const _codeCharacters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  final FirebaseFirestore _firestore;
  final Random _random;

  Stream<List<AdviserUser>> watchAdvisers() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'adviser')
        .snapshots()
        .map((snapshot) {
          final advisers = <AdviserUser>[];

          for (final document in snapshot.docs) {
            final data = document.data();
            final name = data['name'];
            final email = data['email'];

            if (name is String && email is String) {
              advisers.add(
                AdviserUser(uid: document.id, name: name, email: email),
              );
            }
          }

          advisers.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
          return advisers;
        });
  }

  Stream<StudyGroup?> watchStudentGroup(String uid) {
    return _firestore
        .collection('groups')
        .where('memberIds', arrayContains: uid)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) {
            return null;
          }
          return _groupFromDocument(snapshot.docs.first);
        });
  }

  Stream<List<StudyGroup>> watchAdviserGroups(String uid) {
    return _firestore
        .collection('groups')
        .where('adviserId', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
          final groups = snapshot.docs
              .map(_groupFromDocument)
              .whereType<StudyGroup>()
              .toList();

          groups.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
          return groups;
        });
  }

  Stream<List<ChapterSummary>> watchChapters(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('chapters')
        .orderBy('number')
        .snapshots()
        .map((snapshot) {
          final chapters = <ChapterSummary>[];

          for (final document in snapshot.docs) {
            final data = document.data();
            final number = data['number'];
            final status = data['status'];
            final versionCount = data['versionCount'];

            if (number is int && status is String && versionCount is int) {
              chapters.add(
                ChapterSummary(
                  id: document.id,
                  number: number,
                  status: status,
                  versionCount: versionCount,
                ),
              );
            }
          }

          return chapters;
        });
  }

  Future<StudyGroup> createGroup({
    required String name,
    required String adviserId,
    required String creatorUid,
  }) async {
    final existingMembership = await _firestore
        .collection('groups')
        .where('memberIds', arrayContains: creatorUid)
        .limit(1)
        .get();

    if (existingMembership.docs.isNotEmpty) {
      final existingGroup = _groupFromDocument(existingMembership.docs.first);
      if (existingGroup != null) {
        return existingGroup;
      }
    }

    final cleanedName = name.trim();

    for (var attempt = 0; attempt < 5; attempt++) {
      final code = _generateCode();
      final codeSnapshot = await _firestore
          .collection('groups')
          .where('code', isEqualTo: code)
          .limit(1)
          .get();

      if (codeSnapshot.docs.isNotEmpty) {
        continue;
      }

      final groupReference = _firestore.collection('groups').doc();
      final batch = _firestore.batch();

      batch.set(groupReference, {
        'name': cleanedName,
        'code': code,
        'adviserId': adviserId,
        'memberIds': [creatorUid],
      });

      for (var number = 1; number <= 5; number++) {
        batch.set(groupReference.collection('chapters').doc('chapter$number'), {
          'number': number,
          'status': 'pending',
          'versionCount': 0,
        });
      }

      await batch.commit();

      return StudyGroup(
        id: groupReference.id,
        name: cleanedName,
        code: code,
        adviserId: adviserId,
        memberIds: [creatorUid],
      );
    }

    throw StateError('Could not generate a unique group code.');
  }

  Future<void> joinGroup({
    required String code,
    required String studentUid,
  }) async {
    final existingMembership = await _firestore
        .collection('groups')
        .where('memberIds', arrayContains: studentUid)
        .limit(1)
        .get();

    if (existingMembership.docs.isNotEmpty) {
      return;
    }

    final cleanedCode = code.trim().toUpperCase();
    final codeSnapshot = await _firestore
        .collection('groups')
        .where('code', isEqualTo: cleanedCode)
        .limit(1)
        .get();

    if (codeSnapshot.docs.isEmpty) {
      throw const GroupCodeNotFoundException();
    }

    await codeSnapshot.docs.first.reference.update({
      'memberIds': FieldValue.arrayUnion([studentUid]),
    });
  }

  String _generateCode() {
    return List.generate(
      6,
      (_) => _codeCharacters[_random.nextInt(_codeCharacters.length)],
    ).join();
  }

  StudyGroup? _groupFromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    if (data == null) {
      return null;
    }

    final name = data['name'];
    final code = data['code'];
    final adviserId = data['adviserId'];
    final rawMemberIds = data['memberIds'];

    if (name is! String || code is! String || adviserId is! String) {
      return null;
    }

    final memberIds = <String>[];
    if (rawMemberIds is List) {
      for (final memberId in rawMemberIds) {
        if (memberId is String) {
          memberIds.add(memberId);
        }
      }
    }

    return StudyGroup(
      id: document.id,
      name: name,
      code: code,
      adviserId: adviserId,
      memberIds: memberIds,
    );
  }
}
