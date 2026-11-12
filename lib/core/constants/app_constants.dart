class AppConstants {
  // Roles
  static const String roleUser = 'user';
  static const String roleAdmin = 'admin';

  // User Account Status
  static const String userStatusActive = 'active';
  static const String userStatusBlocked = 'blocked';

  // Room Statuses
  static const String roomStatusAvailable = 'available';       // Đang hoạt động / Còn trống
  static const String roomStatusPending = 'pending_approval'; // Đang chờ duyệt
  static const String roomStatusRented = 'rented';             // Đã cho thuê
  static const String roomStatusHidden = 'hidden';             // Tạm ẩn / Vi phạm
  static const String roomStatusRejected = 'rejected';         // Bị từ chối duyệt

  // Report Statuses
  static const String reportStatusPending = 'pending';
  static const String reportStatusResolved = 'resolved';
  static const String reportStatusDismissed = 'dismissed';

  // Notification Types
  static const String notifTypeSystem = 'system';
  static const String notifTypeRoomApproved = 'room_approved';
  static const String notifTypeRoomRejected = 'room_rejected';
  static const String notifTypeBooking = 'booking';
}

