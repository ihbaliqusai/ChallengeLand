import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import '../core/constants/app_config.dart';
import '../core/constants/firestore_collections.dart';
import '../models/user_profile.dart';
import 'mock_data_service.dart';

class AuthService {
  AuthService({
    MockDataService? mockDataService,
    firebase_auth.FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  }) : _mockDataService = mockDataService ?? MockDataService(),
       _firebaseAuth = firebaseAuth,
       _firestore = firestore;

  final MockDataService _mockDataService;
  final firebase_auth.FirebaseAuth? _firebaseAuth;
  final FirebaseFirestore? _firestore;
  final _mockAuthController = StreamController<UserProfile?>.broadcast();
  UserProfile? _mockUser;

  firebase_auth.FirebaseAuth get _auth =>
      _firebaseAuth ?? firebase_auth.FirebaseAuth.instance;
  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  Stream<UserProfile?> authStateChanges() {
    if (AppConfig.useMockData) {
      return _mockAuthController.stream;
    }
    return _auth.authStateChanges().asyncMap((user) async {
      if (user == null) return null;
      return createOrUpdateUserProfile(
        uid: user.uid,
        username: user.displayName ?? 'لاعب جديد',
        email: user.email,
        photoUrl: user.photoURL,
        isGuest: user.isAnonymous,
      );
    });
  }

  UserProfile? get currentUser => _mockUser;

  Future<UserProfile> signInWithGoogle() async {
    if (AppConfig.useMockData) {
      _mockUser = _mockDataService.getMockUser(username: 'لاعب Google');
      _mockAuthController.add(_mockUser);
      return _mockUser!;
    }
    // TODO: Configure GoogleSignIn client IDs and exchange credentials here.
    throw StateError('Google Sign-In يحتاج إعداد Firebase و GoogleSignIn.');
  }

  Future<UserProfile> signInAnonymously() async {
    if (AppConfig.useMockData) {
      _mockUser = _mockDataService.getMockUser();
      _mockAuthController.add(_mockUser);
      return _mockUser!;
    }
    final credential = await _auth.signInAnonymously();
    final user = credential.user;
    if (user == null) {
      throw StateError('تعذر تسجيل الدخول');
    }
    return createOrUpdateUserProfile(
      uid: user.uid,
      username: 'ضيف ${user.uid.substring(0, 4)}',
      isGuest: true,
    );
  }

  Future<void> signOut() async {
    if (AppConfig.useMockData) {
      _mockUser = null;
      _mockAuthController.add(null);
      return;
    }
    await _auth.signOut();
  }

  Future<UserProfile> createOrUpdateUserProfile({
    required String uid,
    required String username,
    String? email,
    String? photoUrl,
    bool isGuest = false,
  }) async {
    final now = DateTime.now();
    final profile = UserProfile(
      uid: uid,
      username: username,
      usernameLower: username.toLowerCase(),
      photoUrl: photoUrl,
      email: email,
      isGuest: isGuest,
      level: 1,
      xp: 0,
      coins: 120,
      trophies: 0,
      energy: 100,
      rating: 1000,
      wins: 0,
      losses: 0,
      totalGames: 0,
      correctAnswers: 0,
      wrongAnswers: 0,
      createdAt: now,
      updatedAt: now,
      lastSeenAt: now,
    );

    if (AppConfig.useMockData) {
      _mockUser = profile;
      _mockAuthController.add(profile);
      return profile;
    }

    await _db
        .collection(FirestoreCollections.users)
        .doc(uid)
        .set(profile.toJson(), SetOptions(merge: true));
    await _db
        .collection(FirestoreCollections.publicProfiles)
        .doc(uid)
        .set(profile.toJson(), SetOptions(merge: true));
    return profile;
  }

  void dispose() {
    _mockAuthController.close();
  }
}
