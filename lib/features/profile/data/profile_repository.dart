import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/user_profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(FirebaseDatabase.instance);
});

final userScansProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>(
      (ref, uid) => ref.watch(profileRepositoryProvider).watchScans(uid),
    );

final userProfileProvider = StreamProvider.family<UserProfile?, String>(
  (ref, uid) => ref.watch(profileRepositoryProvider).watchProfile(uid),
);

class ProfileRepository {
  final FirebaseDatabase _db;

  ProfileRepository(this._db);

  DatabaseReference _userRef(String uid) => _db.ref('users/$uid');

  // ─── Read ─────────────────────────────────────────────────────────────────
  Stream<UserProfile?> watchProfile(String uid) {
    return _userRef(uid).onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return null;
      return UserProfile.fromMap(uid, Map<String, dynamic>.from(data as Map));
    });
  }

  Future<UserProfile?> getProfile(String uid) async {
    final snapshot = await _userRef(uid).get();
    if (!snapshot.exists || snapshot.value == null) return null;
    return UserProfile.fromMap(
      uid,
      Map<String, dynamic>.from(snapshot.value as Map),
    );
  }

  // ─── Write ────────────────────────────────────────────────────────────────
  Future<void> createProfile(UserProfile profile) async {
    await _userRef(profile.uid).set(profile.toMap());
  }

  Future<void> updateProfile(String uid, Map<String, dynamic> updates) async {
    await _userRef(uid).update(updates);
  }

  // ─── Scan History ─────────────────────────────────────────────────────────
  Future<void> incrementScanCount(String uid) async {
    await _userRef(uid).child('scanCount').set(ServerValue.increment(1));
  }

  String createScanId(String uid) {
    final scanId = _db.ref('scans/$uid').push().key;
    if (scanId == null) {
      throw StateError('Could not allocate a scan history key.');
    }
    return scanId;
  }

  Future<void> saveScanResult({
    required String uid,
    required String scanId,
    required Map<String, dynamic> scanData,
  }) async {
    await _db.ref().update({
      'scans/$uid/$scanId': {...scanData, 'timestamp': ServerValue.timestamp},
      'users/$uid/scanCount': ServerValue.increment(1),
    });
  }

  Future<void> deleteScanResult({
    required String uid,
    required String scanId,
  }) async {
    await _db.ref().update({
      'scans/$uid/$scanId': null,
      'users/$uid/scanCount': ServerValue.increment(-1),
    });
  }

  Stream<List<Map<String, dynamic>>> watchScans(String uid) {
    return _db
        .ref('scans/$uid')
        .orderByChild('timestamp')
        .limitToLast(20)
        .onValue
        .map((event) {
          final data = event.snapshot.value;
          if (data == null) return [];
          final map = Map<String, dynamic>.from(data as Map);
          return map.entries
              .map(
                (e) => {
                  'id': e.key,
                  ...Map<String, dynamic>.from(e.value as Map),
                },
              )
              .toList()
              .reversed
              .toList();
        });
  }
}
