/// Tên collection Firestore dùng chung trong ứng dụng.
///
/// `rooms` là dữ liệu công khai cho luồng khách thuê. Kho phòng vận hành của
/// chủ trọ phải dùng `host_rooms` để hai vai trò không ghi chung một nơi.
abstract final class FirestoreCollections {
  static const publicRooms = 'rooms';
  static const hostRooms = 'host_rooms';
  static const hostProperties = 'properties';
}
