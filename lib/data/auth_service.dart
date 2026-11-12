import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 1. Đăng ký tài khoản
  Future<UserCredential> register(String email, String password) async {
    try {
      // Gọi Firebase Auth tạo tài khoản
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      // Khởi tạo Document tương ứng bên collection `users` trong Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'email': email,
        'fullName': '',
        'phoneNumber': '',
        'avatarUrl': '',
        'role': 'user',
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return userCredential;
    } catch (e) {
      rethrow; // Bắn lỗi ra ngoài UI để xử lý (hiển thị thông báo)
    }
  }

  // 2. Đăng nhập
  Future<UserCredential> login(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Kiểm tra trạng thái tài khoản (nếu bị khóa thì từ chối và logout)
      final profile = await getUserProfile(userCredential.user!.uid);
      if (profile != null && profile['status'] == 'blocked') {
        await _auth.signOut();
        throw Exception('Tài khoản của bạn đã bị khóa bởi Quản trị viên!');
      }

      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  // 3. Đăng xuất
  Future<void> logout() async {
    await _auth.signOut();
  }

  // 4. Quên mật khẩu
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      rethrow;
    }
  }

  // 5. Lấy thông tin User Profile từ Firestore
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.data();
    } catch (_) {
      return null;
    }
  }

  // 6. Cập nhật hồ sơ cá nhân (Firestore + Firebase Auth)
  Future<void> updateUserProfile({
    required String uid,
    required String fullName,
    required String phoneNumber,
    String? avatarUrl,
  }) async {
    final Map<String, dynamic> updates = {
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (avatarUrl != null) {
      updates['avatarUrl'] = avatarUrl;
    }

    await _firestore.collection('users').doc(uid).set(
      updates,
      SetOptions(merge: true),
    );

    // Cập nhật Firebase Auth currentUser an toàn
    try {
      final current = _auth.currentUser;
      if (current != null) {
        if (fullName.isNotEmpty) {
          await current.updateDisplayName(fullName);
        }
        // Firebase Auth updatePhotoURL chỉ chấp nhận HTTP/HTTPS URL hợp lệ (< 2048 ký tự)
        if (avatarUrl != null &&
            avatarUrl.isNotEmpty &&
            (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://')) &&
            avatarUrl.length < 2048) {
          await current.updatePhotoURL(avatarUrl);
        }
        await current.reload();
      }
    } catch (_) {
      // Bỏ qua lỗi cập nhật photoURL phía Auth nếu URL không được Auth provider hỗ trợ
    }
  }

  // 7. Kiểm tra người dùng hiện tại có phải Admin không
  Future<bool> isAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final profile = await getUserProfile(user.uid);
    return profile != null && profile['role'] == 'admin';
  }

  // 8. Lấy role hiện tại
  Future<String> getCurrentUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return 'user';
    final profile = await getUserProfile(user.uid);
    return (profile?['role'] as String?) ?? 'user';
  }

  // 9. Stream profile người dùng hiện tại
  Stream<DocumentSnapshot<Map<String, dynamic>>>? getCurrentUserProfileStream() {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _firestore.collection('users').doc(user.uid).snapshots();
  }
}

