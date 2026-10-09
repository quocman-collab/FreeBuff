import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/room_model.dart';
import '../data/host_property.dart';

// Chủ trọ - Phiên Firebase - Luồng đi: Chỉ đọc dữ liệu khi Firebase đã
// khởi tạo và đã đăng nhập; chế độ preview không tự tạo tài khoản giả.
final hostSessionProvider = StreamProvider<String?>((ref) {
  if (Firebase.apps.isEmpty) return Stream.value(null);
  return FirebaseAuth.instance.authStateChanges().map((user) => user?.uid);
});
final hostRepositoryProvider = Provider<HostRepository>(
  (ref) => HostRepository(),
);
final hostPropertiesProvider = StreamProvider<List<HostProperty>>((ref) {
  final uid = ref.watch(hostSessionProvider).value;
  if (uid == null) return Stream.value([]);
  return ref.watch(hostRepositoryProvider).watchProperties(uid);
});
final hostRoomsProvider = StreamProvider<List<RoomModel>>((ref) {
  final uid = ref.watch(hostSessionProvider).value;
  if (uid == null) return Stream.value([]);
  return ref.watch(hostRepositoryProvider).watchRooms(uid);
});

// Chủ trọ - Ảnh đã chọn - Luồng đi: Giữ byte ảnh trong form để xem
// trước và tải bằng putData trên Chrome, Android và iOS.
class HostUpload {
  const HostUpload(this.bytes, this.contentType);
  final Uint8List bytes;
  final String contentType;
}

// Chủ trọ - Kho dữ liệu quản lý - Luồng đi: Lưu nhà vào properties,
// phòng vào rooms và ảnh vào đường dẫn riêng theo UID chủ trọ.
class HostRepository {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  FirebaseStorage get _storage => FirebaseStorage.instance;

  // Chủ trọ - Theo dõi nhà và phòng - Luồng đi: Lọc hostId ở truy vấn;
  // sắp xếp tại ứng dụng để không yêu cầu composite index mới.
  Stream<List<HostProperty>> watchProperties(String uid) => _db
      .collection('properties')
      .where('hostId', isEqualTo: uid)
      .snapshots()
      .map((snapshot) {
        final list = snapshot.docs
            .map((doc) => HostProperty.fromMap(doc.id, doc.data()))
            .toList();
        list.sort(
          (a, b) => (b.createdAt ?? DateTime(1970)).compareTo(
            a.createdAt ?? DateTime(1970),
          ),
        );
        return list;
      });
  Stream<List<RoomModel>> watchRooms(String uid) => _db
      .collection('rooms')
      .where('hostId', isEqualTo: uid)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map(RoomModel.fromFirestore)
            .where((room) => room.status != 'deleted')
            .toList(),
      );
  String newPropertyId() => _db.collection('properties').doc().id;

  // Chủ trọ - Kiểm tra phiên lưu - Luồng đi: Trước khi ghi nhà/phòng,
  // xác nhận UID hiện tại vẫn là người đã mở form và có vai trò chủ trọ.
  Future<void> _requireHost(String uid) async {
    if (FirebaseAuth.instance.currentUser?.uid != uid) {
      throw StateError('Phiên đăng nhập đã thay đổi. Vui lòng đăng nhập lại.');
    }
    final profile = await _db.collection('users').doc(uid).get();
    final data = profile.data();
    if ((data?['role'] ?? data?['vaiTro']) != 'host') {
      throw StateError('Bạn cần tài khoản Chủ trọ để tạo nhà/phòng.');
    }
  }

  // Chủ trọ - Tải ảnh thực - Luồng đi: Kiểm tra định dạng và dung
  // lượng trước khi upload; lỗi Storage được báo, không thay bằng ảnh mẫu.
  Future<List<String>> _upload(
    List<HostUpload> images,
    String folder,
    int max,
  ) async {
    if (images.isEmpty || images.length > max) {
      throw StateError('Chọn từ 1 đến $max ảnh.');
    }
    final urls = <String>[];
    for (var i = 0; i < images.length; i++) {
      final image = images[i];
      if (!['image/jpeg', 'image/png'].contains(image.contentType) ||
          image.bytes.length > 5 * 1024 * 1024) {
        throw StateError('Mỗi ảnh phải là JPG/PNG và không quá 5 MB.');
      }
      final object = _storage.ref('$folder/$i');
      await object.putData(
        image.bytes,
        SettableMetadata(contentType: image.contentType),
      );
      urls.add(await object.getDownloadURL());
    }
    return urls;
  }

  // Chủ trọ - Tạo nhà - Luồng đi: Upload ảnh và giấy tờ tùy chọn, rồi
  // ghi cơ sở bằng ID giữ cố định khi thử lại; không tự tạo phòng giả.
  Future<String> createProperty(
    HostProperty property,
    List<HostUpload> images,
    HostUpload? proof,
  ) async {
    await _requireHost(property.hostId);
    final document = _db.collection('properties').doc(property.id);
    if ((await document.get()).exists) return property.id;
    final urls = await _upload(
      images,
      'host_media/${property.hostId}/properties/${property.id}',
      5,
    );
    String? proofPath;
    if (proof != null) {
      if (!['image/jpeg', 'image/png'].contains(proof.contentType) ||
          proof.bytes.length > 15 * 1024 * 1024) {
        throw StateError('Giấy tờ phải là JPG/PNG và không quá 15 MB.');
      }
      proofPath = 'host_private/${property.hostId}/${property.id}/proof';
      await _storage
          .ref(proofPath)
          .putData(
            proof.bytes,
            SettableMetadata(contentType: proof.contentType),
          );
    }
    await _db.runTransaction((transaction) async {
      final existing = await transaction.get(document);
      if (!existing.exists) {
        transaction.set(document, {
          ...property.toMap(),
          'images': urls,
          'roomCount': 0,
          'roomCodes': <String, String>{},
          'proofPath': ?proofPath,
          'verificationStatus': 'unverified',
        });
      }
    });
    return property.id;
  }

  // Chủ trọ - Mã phòng duy nhất - Luồng đi: Cùng cơ sở và mã phòng
  // tạo cùng ID; transaction ngăn trùng mã cả khi hai thiết bị lưu cùng lúc.
  static String roomDocumentId(String propertyId, String code) =>
      '${propertyId}_${base64Url.encode(utf8.encode(code.trim().toUpperCase())).replaceAll('=', '')}';

  // Chủ trọ - Khóa mã phòng trong cơ sở - Luồng đi: Lưu bảng mã trên
  // properties để đổi số phòng vẫn giữ ID và liên kết đơn thuê cũ.
  static String _codeKey(String code) => base64Url
      .encode(utf8.encode(code.trim().toUpperCase()))
      .replaceAll('=', '');
  Map<String, dynamic> _codes(Map<String, dynamic> property) =>
      Map<String, dynamic>.from(property['roomCodes'] as Map? ?? {});
  void _checkRevision(Map<String, dynamic> current, RoomModel base) {
    final stamp = current['updatedAt'];
    final date = stamp is Timestamp ? stamp.toDate() : null;
    if (date != base.updatedAt) {
      throw StateError(
        'Phòng vừa được thay đổi trên thiết bị khác. Quay lại chi tiết rồi mở chỉnh sửa để tải dữ liệu mới.',
      );
    }
  }

  // Chủ trọ - Tạo phòng có mã duy nhất - Luồng đi: Giữ ID theo thao
  // tác khi thử lại; khóa mã và tăng số phòng cùng một transaction.
  Future<String> createRoom(
    RoomModel room,
    List<HostUpload> images,
    String operationId, {
    int maxImages = 8,
  }) async {
    await _requireHost(room.hostId);
    final propertyRef = _db.collection('properties').doc(room.propertyId);
    final legacyRef = _db
        .collection('rooms')
        .doc(roomDocumentId(room.propertyId, room.roomCode));
    final roomRef = _db
        .collection('rooms')
        .doc('${roomDocumentId(room.propertyId, room.roomCode)}_$operationId');
    final existing = await roomRef.get();
    if (existing.exists && existing.data()?['operationId'] == operationId) {
      return roomRef.id;
    }
    final urls = await _upload(
      images,
      'host_media/${room.hostId}/rooms/${roomRef.id}/$operationId',
      maxImages,
    );
    await _db.runTransaction((transaction) async {
      final property = await transaction.get(propertyRef);
      final current = await transaction.get(roomRef);
      final legacy = await transaction.get(legacyRef);
      if (current.exists) {
        if (current.data()?['operationId'] == operationId) return;
        throw StateError('Phòng đã tồn tại.');
      }
      final data = property.data();
      if (data == null || data['hostId'] != room.hostId) {
        throw StateError('Cơ sở không thuộc tài khoản này.');
      }
      final codes = _codes(data);
      final key = _codeKey(room.roomCode);
      final legacyData = legacy.data();
      if (codes.containsKey(key) ||
          (legacyData != null &&
              legacyData['status'] != 'deleted' &&
              _codeKey(legacyData['roomCode'] as String? ?? '') == key)) {
        throw StateError('Mã phòng đã tồn tại trong cơ sở này.');
      }
      final count = (data['roomCount'] as num?)?.toInt() ?? 0;
      if (count >= (data['plannedRooms'] as num).toInt()) {
        throw StateError('Đã đủ số phòng theo quy mô cơ sở.');
      }
      codes[key] = roomRef.id;
      transaction.set(roomRef, {
        ...room.toMap(),
        'images': urls,
        'anhPhong': urls,
        'operationId': operationId,
        'createdAt': FieldValue.serverTimestamp(),
        'ngayTao': FieldValue.serverTimestamp(),
      });
      transaction.update(propertyRef, {
        'roomCount': count + 1,
        'roomCodes': codes,
      });
    });
    return roomRef.id;
  }

  // Chủ trọ - Tạo bài đăng cùng phòng & tiện ích theo schema SDS - Luồng đi:
  // Tiện ích tùy chọn được persist; tạo liên kết TienIch_Phong; lưu bài đăng
  // posts/BaiDang; rollback tất cả nếu xảy ra lỗi giữa chừng để tránh dữ liệu mồ côi.
  Future<String> createPostWithAmenities({
    required RoomModel room,
    required List<HostUpload> images,
    required String operationId,
    required Set<String> selectedAmenities,
    required List<String> customAmenities,
    required Map<String, String> catalogAmenitiesMap,
    required String chuNhaId,
    required String diaDiemId,
    required String loaiThueId,
    required String trangThaiId,
    required String tieuDe,
    required String moTa,
    required double giaThue,
    required String soDienThoaiLienHe,
    required String authorName,
    required String authorAvatar,
  }) async {
    final createdAmenityIds = <String>[];
    final createdLinkDocRefs = <DocumentReference>[];
    DocumentReference? createdPostRef;
    String? createdRoomId;

    try {
      // 1. Tiện ích tùy chọn lúc này mới tạo document danh mục:
      final amenityNameToId = <String, String>{};
      for (final name in selectedAmenities) {
        final key = name.trim().toLowerCase();
        if (catalogAmenitiesMap.containsKey(key)) {
          amenityNameToId[name] = catalogAmenitiesMap[key]!;
        } else {
          final docRef = _db.collection('amenities').doc();
          await docRef.set({
            'name': name.trim(),
            'label': name.trim(),
            'ten': name.trim(),
            'tenTienIch': name.trim(),
            'source': 'host_custom',
            'createdAt': FieldValue.serverTimestamp(),
          });
          createdAmenityIds.add(docRef.id);
          amenityNameToId[name] = docRef.id;
        }
      }

      // 2. Lưu phòng theo schema SDS:
      final roomId = await createRoom(room, images, operationId, maxImages: 10);
      createdRoomId = roomId;

      // 3. Tạo liên kết TienIch_Phong với phongId và tienIch_Id:
      if (amenityNameToId.isNotEmpty) {
        final batch = _db.batch();
        for (final entry in amenityNameToId.entries) {
          final tienIchId = entry.value;
          final linkRef = _db
              .collection('TienIch_Phong')
              .doc('${roomId}_$tienIchId');
          batch.set(linkRef, {
            'phongId': roomId,
            'tienIch_Id': tienIchId,
            'createdAt': FieldValue.serverTimestamp(),
          });
          createdLinkDocRefs.add(linkRef);
        }
        await batch.commit();
      }

      // 4. Lưu bài đăng theo schema SDS:
      final postRef = _db.collection('posts').doc();
      createdPostRef = postRef;

      await postRef.set({
        // SDS Schema fields
        'phongId': roomId,
        'chuNhaId': chuNhaId,
        'diaDiemId': diaDiemId,
        'loaiThue_id': loaiThueId,
        'trangThai_id': trangThaiId,
        'tieuDe': tieuDe,
        'moTa': moTa,
        'giaThue': giaThue,
        'soDienThoaiLienHe': soDienThoaiLienHe,
        'ngayDang': FieldValue.serverTimestamp(),

        // Compatibility fields for home & dashboard feed
        'authorId': chuNhaId,
        'authorName': authorName,
        'authorAvatar': authorAvatar,
        'title': tieuDe,
        'description': moTa,
        'postType': 'timNguoiOGhep',
        'propertyType': room.roomType,
        'pricePerPerson': giaThue,
        'budgetMin': giaThue,
        'budgetMax': giaThue,
        'address': room.address,
        'district': room.district,
        'city': room.city,
        'targetGender': 'Tất cả',
        'habits': selectedAmenities.toList(),
        'purposeTags': selectedAmenities.toList(),
        'images': room.images,
        'hasRoom': true,
        'status': 'dangMo',
        'contactPhone': soDienThoaiLienHe,
        'interestedCount': 0,
        'replyCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return postRef.id;
    } catch (error) {
      // Rollback error handling để không tạo dữ liệu mồ côi:
      try {
        if (createdPostRef != null) {
          await createdPostRef.delete();
        }
        if (createdLinkDocRefs.isNotEmpty) {
          final rbBatch = _db.batch();
          for (final ref in createdLinkDocRefs) {
            rbBatch.delete(ref);
          }
          await rbBatch.commit();
        }
        if (createdRoomId != null) {
          await _db.collection('rooms').doc(createdRoomId).delete();
        }
        for (final amId in createdAmenityIds) {
          await _db.collection('amenities').doc(amId).delete();
        }
      } catch (_) {
        // Ignored to rethrow original error
      }
      rethrow;
    }
  }

  // Chủ trọ - Lưu chỉnh sửa phòng - Luồng đi: Upload ảnh mới, kiểm
  // tra phiên/bản sửa, giữ ID và chỉ cập nhật thông tin phòng được phép.
  Future<void> updateRoom(
    RoomModel base,
    Map<String, dynamic> patch,
    List<String> keptImages,
    List<HostUpload> newImages,
    String operationId,
  ) async {
    await _requireHost(base.hostId);
    const allowed = {
      'roomCode',
      'floor',
      'area',
      'capacity',
      'price',
      'deposit',
      'electricityRate',
      'waterRate',
      'serviceFee',
      'amenities',
      'description',
    };
    if (patch.keys.any((key) => !allowed.contains(key))) {
      throw StateError('Thông tin chỉnh sửa không hợp lệ.');
    }
    if (keptImages.length + newImages.length < 1 ||
        keptImages.length + newImages.length > 8 ||
        keptImages.any((url) => !base.images.contains(url))) {
      throw StateError('Giữ từ 1 đến 8 ảnh phòng hợp lệ.');
    }
    final code = (patch['roomCode'] as String).trim().toUpperCase();
    for (final key in [
      'price',
      'deposit',
      'area',
      'electricityRate',
      'waterRate',
      'serviceFee',
    ]) {
      final value = patch[key] as num?;
      if (value != null &&
          (!value.isFinite || value < 0 || value > 1000000000)) {
        throw StateError('Giá thuê và phí phòng không hợp lệ.');
      }
    }
    if (code.isEmpty ||
        code.length > 30 ||
        (patch['price'] as num) <= 0 ||
        (patch['deposit'] as num) < 0 ||
        (patch['area'] as num) <= 0 ||
        (patch['capacity'] as num) < 1) {
      throw StateError('Kiểm tra mã, diện tích, sức chứa và giá thuê.');
    }
    final roomRef = _db.collection('rooms').doc(base.id);
    final propertyRef = _db.collection('properties').doc(base.propertyId);
    final legacyRef = _db
        .collection('rooms')
        .doc(roomDocumentId(base.propertyId, code));
    final uploaded = newImages.isEmpty
        ? <String>[]
        : await _upload(
            newImages,
            'host_media/${base.hostId}/rooms/${base.id}/edits/$operationId',
            8,
          );
    final images = [...keptImages, ...uploaded];
    await _db.runTransaction((transaction) async {
      final current = await transaction.get(roomRef);
      final property = await transaction.get(propertyRef);
      final legacy = await transaction.get(legacyRef);
      final data = current.data();
      final parent = property.data();
      if (data == null || data['status'] == 'deleted') {
        throw StateError('Phòng không còn tồn tại.');
      }
      if (data['hostId'] != base.hostId ||
          data['propertyId'] != base.propertyId ||
          parent?['hostId'] != base.hostId) {
        throw StateError('Bạn không có quyền chỉnh sửa phòng này.');
      }
      if (data['lastEditOperation'] == operationId) return;
      _checkRevision(data, base);
      if ((patch['floor'] as num) < 1 ||
          (patch['floor'] as num) > (parent!['floors'] as num)) {
        throw StateError('Tầng phòng vượt quá số tầng của cơ sở.');
      }
      final codes = _codes(parent);
      final key = _codeKey(code);
      final legacyData = legacy.data();
      if ((codes.containsKey(key) && codes[key] != base.id) ||
          (legacy.id != base.id &&
              legacyData != null &&
              legacyData['status'] != 'deleted' &&
              _codeKey(legacyData['roomCode'] as String? ?? '') == key)) {
        throw StateError('Mã phòng đã tồn tại trong cơ sở này.');
      }
      final oldKey = _codeKey(data['roomCode'] as String? ?? '');
      if (oldKey != key && codes[oldKey] == base.id) codes.remove(oldKey);
      codes[key] = base.id;
      final title = 'Phòng $code • ${parent['name']}';
      transaction.update(roomRef, {
        ...patch,
        'roomCode': code,
        'title': title,
        'tieuDe': title,
        'gia': patch['price'],
        'giaThue': patch['price'],
        'giaThueThang': patch['price'],
        'tienCoc': patch['deposit'],
        'dienTich': patch['area'],
        'dienTichM2': patch['area'],
        'sucChua': patch['capacity'],
        'tang': patch['floor'],
        'tienIch': patch['amenities'],
        'moTa': patch['description'],
        'noiDung': patch['description'],
        'images': images,
        'anhPhong': images,
        'lastEditOperation': operationId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(propertyRef, {'roomCodes': codes});
    });
  }

  // Chủ trọ - Xóa phòng khỏi quản lý - Luồng đi: Sau xác nhận, đánh
  // dấu deleted và giảm số phòng; giữ bản ghi/ảnh để đơn thuê cũ còn liên kết.
  Future<void> deleteRoom(RoomModel base) async {
    await _requireHost(base.hostId);
    final roomRef = _db.collection('rooms').doc(base.id);
    final propertyRef = _db.collection('properties').doc(base.propertyId);
    await _db.runTransaction((transaction) async {
      final current = await transaction.get(roomRef);
      final property = await transaction.get(propertyRef);
      final data = current.data();
      final parent = property.data();
      if (data == null || data['status'] == 'deleted') return;
      if (data['hostId'] != base.hostId || parent?['hostId'] != base.hostId) {
        throw StateError('Bạn không có quyền xóa phòng này.');
      }
      _checkRevision(data, base);
      if (data['status'] == 'occupied' ||
          data['status'] == 'reserved' ||
          (data['tenantName'] as String? ?? '').isNotEmpty ||
          (data['contractId'] as String? ?? '').isNotEmpty) {
        throw StateError(
          'Phòng còn khách thuê hoặc hợp đồng. Hãy kết thúc hợp đồng trước khi xóa.',
        );
      }
      final codes = _codes(parent!);
      final key = _codeKey(data['roomCode'] as String? ?? '');
      if (codes[key] == base.id) codes.remove(key);
      final count = (parent['roomCount'] as num?)?.toInt() ?? 0;
      transaction.update(roomRef, {
        'status': 'deleted',
        'isAvailable': false,
        'deletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(propertyRef, {
        'roomCount': count > 0 ? count - 1 : 0,
        'roomCodes': codes,
      });
    });
  }
}

// Chủ trọ - Thông báo lỗi Firebase - Luồng đi: Hiển thị nguyên nhân
// lưu/tải thất bại bằng tiếng Việt để người dùng có thể sửa và thử lại.
String hostErrorMessage(Object error) {
  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
      case 'unauthorized':
        return 'Chưa có quyền truy cập. Kiểm tra tài khoản Chủ trọ và Firebase Rules.';
      case 'unauthenticated':
        return 'Vui lòng đăng nhập lại để lưu nhà/phòng.';
      case 'unavailable':
      case 'network-request-failed':
      case 'retry-limit-exceeded':
        return 'Không kết nối được Firebase. Kiểm tra mạng rồi thử lại.';
      case 'bucket-not-found':
      case 'object-not-found':
        return 'Chưa truy cập được Storage. Kiểm tra bucket trong Firebase Console.';
      default:
        return 'Firebase báo lỗi ${error.code}. Vui lòng kiểm tra cấu hình rồi thử lại.';
    }
  }
  return error is StateError
      ? error.message.toString()
      : 'Không thể hoàn tất thao tác. Vui lòng thử lại.';
}
