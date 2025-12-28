import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Central place for Firebase instances used across the app.
class Fb {
  Fb._();

  static FirebaseAuth get auth => FirebaseAuth.instance;
  static FirebaseFirestore get db => FirebaseFirestore.instance;

  static User? get user => auth.currentUser;
  static String? get uid => auth.currentUser?.uid;
}

class FbUserProfile {
  final String uid;
  final String email;
  final String name;
  final String empCode;
  final String? locationId;
  final String? locationName;
  final double allowedLat;
  final double allowedLng;
  final double allowedRadiusMeters;

  const FbUserProfile({
    required this.uid,
    required this.email,
    required this.name,
    required this.empCode,
    this.locationId,
    this.locationName,
    required this.allowedLat,
    required this.allowedLng,
    required this.allowedRadiusMeters,
  });

  static FbUserProfile fromDoc(String uid, Map<String, dynamic> d) {
    final gp = d['allowedLocation'];
    double lat = 0;
    double lng = 0;
    if (gp is GeoPoint) {
      lat = gp.latitude;
      lng = gp.longitude;
    } else if (gp is Map) {
      lat = (gp['lat'] as num?)?.toDouble() ?? 0;
      lng = (gp['lng'] as num?)?.toDouble() ?? 0;
    }

    return FbUserProfile(
      uid: uid,
      email: (d['email'] ?? '').toString(),
      name: (d['name'] ?? 'User').toString(),
      empCode: (d['empCode'] ?? '--').toString(),
      locationId: d['locationId']?.toString(),
      locationName: d['locationName']?.toString(),
      allowedLat: lat,
      allowedLng: lng,
      allowedRadiusMeters: (d['allowedRadiusMeters'] as num?)?.toDouble() ?? 100,
    );
  }
}

class FbUserRepo {
  static CollectionReference<Map<String, dynamic>> get _col =>
      Fb.db.collection('users');

  /// Reads the user profile from Firestore.
  /// If it doesn't exist, creates a minimal one (admin can update location later).
  static Future<FbUserProfile> getOrCreateProfile({
    required User user,
  }) async {
    final ref = _col.doc(user.uid);
    final snap = await ref.get();

    if (!snap.exists) {
      await ref.set({
        'email': user.email ?? '',
        'name': user.displayName ?? 'User',
        'empCode': user.email ?? user.uid,
        // Default allowedLocation is (0,0). Admin must set correct coords.
        'allowedLocation': const GeoPoint(0, 0),
        'allowedRadiusMeters': 100,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    final snap2 = await ref.get();
    final data = snap2.data() ?? <String, dynamic>{};
    return FbUserProfile.fromDoc(user.uid, data);
  }
}

class FbAttendanceRepo {
  static Future<void> addAttendance({
    required String uid,
    required String action, // IN / OUT
    required double lat,
    required double lng,
    required double distanceMeters,
    required bool withinAllowed,
    required String deviceId,
  }) async {
    await Fb.db
        .collection('users')
        .doc(uid)
        .collection('attendance')
        .add({
      'action': action,
      'lat': lat,
      'lng': lng,
      'distanceMeters': distanceMeters,
      'withinAllowed': withinAllowed,
      'deviceId': deviceId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

class FbSalesRepo {
  static Future<void> addOrder({
    required String uid,
    required Map<String, dynamic> orderJson,
  }) async {
    await Fb.db.collection('users').doc(uid).collection('sales').add({
      ...orderJson,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

/// Simple admin check using a Firestore document.
///
/// If a document exists at `admins/{uid}`, that account is treated as an admin.
/// This avoids needing Cloud Functions / custom claims.
class FbAdminRepo {
  static Future<bool> isAdmin(String uid) async {
    try {
      // We only need to check whether /admins/{uid} exists.
      // If Firestore rules block this read, the app must NOT crash.
      final doc = await Fb.db.collection('admins').doc(uid).get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }
}

class FbLocation {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final double radiusMeters;

  const FbLocation({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.radiusMeters,
  });

  static FbLocation fromDoc(String id, Map<String, dynamic> d) {
    final gp = d['allowedLocation'];
    double lat = 0;
    double lng = 0;
    if (gp is GeoPoint) {
      lat = gp.latitude;
      lng = gp.longitude;
    } else if (gp is Map) {
      lat = (gp['lat'] as num?)?.toDouble() ?? 0;
      lng = (gp['lng'] as num?)?.toDouble() ?? 0;
    }
    return FbLocation(
      id: id,
      name: (d['name'] ?? '').toString(),
      lat: lat,
      lng: lng,
      radiusMeters: (d['allowedRadiusMeters'] as num?)?.toDouble() ?? 100,
    );
  }
}

/// Master locations configured by admin.
///
/// Collection: locations/{locationId}
class FbLocationRepo {
  static CollectionReference<Map<String, dynamic>> get _col =>
      Fb.db.collection('locations');

  /// Raw snapshots stream for screens that use `StreamBuilder<QuerySnapshot<...>>`.
  /// (Kept to avoid changing existing UI code.)
  static Stream<QuerySnapshot<Map<String, dynamic>>> streamLocations() {
    return _col.orderBy('name').snapshots();
  }

  static Stream<List<FbLocation>> watchLocations() {
    return _col.orderBy('name').snapshots().map((q) {
      return q.docs
          .map((d) => FbLocation.fromDoc(d.id, d.data()))
          .toList(growable: false);
    });
  }

  static Future<List<FbLocation>> fetchLocationsOnce() async {
    final q = await _col.orderBy('name').get();
    return q.docs
        .map((d) => FbLocation.fromDoc(d.id, d.data()))
        .toList(growable: false);
  }

  static Future<void> upsertLocation({
    String? id,
    required String name,
    required double lat,
    required double lng,
    required double radiusMeters,
  }) async {
    final ref = (id == null || id.isEmpty) ? _col.doc() : _col.doc(id);
    await ref.set({
      'name': name.trim(),
      'allowedLocation': GeoPoint(lat, lng),
      'allowedRadiusMeters': radiusMeters,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> deleteLocation(String id) async {
    await _col.doc(id).delete();
  }

  /// Helper for user-side location selection screen:
  /// - reads locations/{locationId}
  /// - writes locationId/locationName/allowedLocation/allowedRadiusMeters to users/{uid}
  static Future<void> setCurrentUserLocationFromLocation(String locationId) async {
    final uid = Fb.uid;
    if (uid == null) {
      throw Exception('No active session. Please login again.');
    }

    final snap = await _col.doc(locationId).get();
    if (!snap.exists) {
      throw Exception('Selected location not found');
    }

    final data = snap.data() ?? <String, dynamic>{};
    final loc = FbLocation.fromDoc(snap.id, data);
    await applyLocationToUser(uid: uid, location: loc);
  }

  /// Saves the selected master location onto the user's profile.
  static Future<void> applyLocationToUser({
    required String uid,
    required FbLocation location,
  }) async {
    await Fb.db.collection('users').doc(uid).set({
      'locationId': location.id,
      'locationName': location.name,
      'allowedLocation': GeoPoint(location.lat, location.lng),
      'allowedRadiusMeters': location.radiusMeters,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
