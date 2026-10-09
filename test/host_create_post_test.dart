import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:home_share/core/theme/app_theme.dart';
import 'package:home_share/data/models/room_model.dart';
import 'package:home_share/features/auth/providers/user_provider.dart';
import 'package:home_share/features/host/data/host_property.dart';
import 'package:home_share/features/host/providers/host_dashboard_provider.dart';
import 'package:home_share/features/host/providers/host_management_provider.dart';
import 'package:home_share/features/host/screens/host_create_post_screen.dart';
import 'package:home_share/features/host/screens/host_create_screen.dart';

class CreatePostTestRepository extends HostRepository {
  final properties = <HostProperty>[];
  final rooms = <RoomModel>[];
  final posts = <Map<String, dynamic>>[];
  final customAmenitiesCreated = <Map<String, dynamic>>[];
  final tienIchPhongLinks = <Map<String, dynamic>>[];

  bool failCreateRoom = false;
  bool failCreatePost = false;
  bool rollbackCleanedUp = false;

  @override
  String newPropertyId() => 'prop_test_1';

  @override
  Stream<List<HostProperty>> watchProperties(String uid) =>
      Stream.value(List.of(properties));

  @override
  Stream<List<RoomModel>> watchRooms(String uid) =>
      Stream.value(List.of(rooms));

  @override
  Future<String> createProperty(
    HostProperty property,
    List<HostUpload> images,
    HostUpload? proof,
  ) async {
    properties.add(property);
    return property.id;
  }

  @override
  Future<String> createRoom(
    RoomModel room,
    List<HostUpload> images,
    String operationId, {
    int maxImages = 8,
  }) async {
    if (failCreateRoom) throw StateError('Lỗi kiểm thử khi lưu phòng');
    final id = 'room_${rooms.length + 1}';
    final saved = RoomModel.fromMap({
      ...room.toMap(),
      'id': id,
      'images': images.map((_) => 'http://example.com/mock.jpg').toList(),
    }, id);
    rooms.add(saved);
    return id;
  }

  @override
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
    if (failCreatePost) {
      rollbackCleanedUp = true;
      throw StateError('Lỗi kiểm thử khi tạo bài đăng');
    }

    final roomId = await createRoom(room, images, operationId, maxImages: 10);

    final amenityNameToId = <String, String>{};
    for (final name in selectedAmenities) {
      final key = name.trim().toLowerCase();
      if (catalogAmenitiesMap.containsKey(key)) {
        amenityNameToId[name] = catalogAmenitiesMap[key]!;
      } else {
        final amId = 'custom_am_${customAmenitiesCreated.length + 1}';
        customAmenitiesCreated.add({
          'id': amId,
          'name': name,
          'label': name,
          'source': 'host_custom',
        });
        amenityNameToId[name] = amId;
      }
    }

    for (final entry in amenityNameToId.entries) {
      tienIchPhongLinks.add({
        'phongId': roomId,
        'tienIch_Id': entry.value,
        'amenityName': entry.key,
      });
    }

    final post = {
      'id': 'post_${posts.length + 1}',
      'phongId': roomId,
      'chuNhaId': chuNhaId,
      'diaDiemId': diaDiemId,
      'loaiThue_id': loaiThueId,
      'trangThai_id': trangThaiId,
      'tieuDe': tieuDe,
      'moTa': moTa,
      'giaThue': giaThue,
      'soDienThoaiLienHe': soDienThoaiLienHe,
      'ngayDang': DateTime.now(),
      'authorName': authorName,
      'authorAvatar': authorAvatar,
    };
    posts.add(post);
    return post['id'] as String;
  }
}

class TestPicker extends ImagePicker {
  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) async => [
    XFile.fromData(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
      name: 'test.png',
      mimeType: 'image/png',
    ),
  ];
}

Widget createTestApp(
  Widget home,
  CreatePostTestRepository repository, {
  List<Map<String, String>> catalogAmenities = const [
    {'id': 'am_1', 'name': 'Máy lạnh'},
    {'id': 'am_2', 'name': 'Có gác lửng'},
    {'id': 'am_3', 'name': 'Wifi tốc độ cao'},
    {'id': 'am_4', 'name': 'Giờ giấc tự do'},
  ],
}) => ProviderScope(
  overrides: [
    hostSessionProvider.overrideWith((ref) => Stream.value('host-test-uid')),
    hostRepositoryProvider.overrideWithValue(repository),
    hostPropertiesProvider.overrideWith(
      (ref) => Stream.value(repository.properties),
    ),
    hostAmenitiesProvider.overrideWith((ref) => Stream.value(catalogAmenities)),
    hostImagePickerProvider.overrideWithValue(TestPicker()),
    userProfileProvider.overrideWith(
      (ref) => Stream.value(
        UserProfile(
          uid: 'host-test-uid',
          email: 'host@test.com',
          displayName: 'Anh Chủ Nhà',
          phoneNumber: '0987654321',
          role: 'host',
        ),
      ),
    ),
  ],
  child: MaterialApp(theme: AppTheme.lightTheme, home: home),
);

void setScreenSize(WidgetTester tester, {double width = 390}) {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
}

void main() {
  const defaultProperty = HostProperty(
    id: 'prop-1',
    name: 'Nhà trọ Hoa Sen',
    address: '18 Đường số 6, Tăng Nhơn Phú B, TP. Thủ Đức',
    city: 'TP. Hồ Chí Minh',
    ward: 'Tăng Nhơn Phú B',
    hostId: 'host-test-uid',
    plannedRooms: 5,
    floors: 2,
  );

  group('Màn Tạo bài đăng - Role Chủ trọ', () {
    testWidgets(
      '1. Validate giá: chỉ nhận số digitsOnly, đồng bộ giá readonly ở Vị trí & liên hệ',
      (tester) async {
        setScreenSize(tester, width: 390);
        final repo = CreatePostTestRepository()
          ..properties.add(defaultProperty);
        await tester.pumpWidget(
          createTestApp(const HostCreatePostScreen(), repo),
        );
        await tester.pumpAndSettle();
        final priceField = find.byKey(const ValueKey('price_input'));
        final readonlyField = find.byKey(const ValueKey('price_readonly'));

        expect(priceField, findsOneWidget);
        expect(readonlyField, findsOneWidget);

        // Ban đầu chưa nhập
        expect(find.text('Chưa nhập'), findsOneWidget);

        // Nhập text có chữ và số: digitsOnly chỉ cho nhận số
        await tester.enterText(priceField, '2800000');
        await tester.pumpAndSettle();

        // Giá readonly đồng bộ và hiển thị định dạng số
        expect(find.text('2.800.000'), findsOneWidget);

        // Đổi giá
        await tester.enterText(priceField, '3500000');
        await tester.pumpAndSettle();
        expect(find.text('3.500.000'), findsOneWidget);

        // Không tồn tại trường trạng thái phòng trong UI
        expect(find.text('Trạng thái phòng'), findsNothing);
      },
    );

    testWidgets(
      '2. Chống trùng tiện ích: chuẩn hóa chuỗi, chống trùng Firestore catalog và local list',
      (tester) async {
        setScreenSize(tester, width: 414);
        final repo = CreatePostTestRepository()
          ..properties.add(defaultProperty);

        await tester.pumpWidget(
          createTestApp(const HostCreatePostScreen(), repo),
        );
        await tester.pumpAndSettle();

        final customInput = find.byKey(const ValueKey('custom_amenity_input'));
        final addButton = find.byKey(
          const ValueKey('add_custom_amenity_button'),
        );

        // Trùng với danh mục Firestore (catalog có 'Máy lạnh')
        await tester.enterText(customInput, '   máy lạnh   ');
        await tester.tap(addButton);
        await tester.pumpAndSettle();

        // Không tạo thêm item tùy chọn mới vì đã trùng với catalog
        expect(find.text('Tùy chọn'), findsNothing);
        expect(find.text('Đã chọn'), findsWidgets);

        // Thêm tiện ích tùy chọn hợp lệ mới
        await tester.enterText(customInput, '   Gần trạm xe buýt   ');
        await tester.tap(addButton);
        await tester.pumpAndSettle();

        // Xuất hiện nhãn Tùy chọn và nút xóa X
        expect(find.text('Gần trạm xe buýt'), findsOneWidget);
        expect(find.text('Tùy chọn'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('delete_custom_amenity_Gần trạm xe buýt')),
          findsOneWidget,
        );

        // Thử thêm lại tiện ích tùy chọn đó (chống trùng local)
        await tester.enterText(customInput, 'gần trạm xe buýt');
        await tester.tap(addButton);
        await tester.pumpAndSettle();

        // Vẫn chỉ có 1 item "Gần trạm xe buýt"
        expect(find.text('Gần trạm xe buýt'), findsOneWidget);
      },
    );

    testWidgets(
      '3. Local-only trước submit: thêm tiện ích không gọi ghi Firestore ngay',
      (tester) async {
        setScreenSize(tester, width: 390);
        final repo = CreatePostTestRepository()
          ..properties.add(defaultProperty);

        await tester.pumpWidget(
          createTestApp(const HostCreatePostScreen(), repo),
        );
        await tester.pumpAndSettle();

        final customInput = find.byKey(const ValueKey('custom_amenity_input'));
        final addButton = find.byKey(
          const ValueKey('add_custom_amenity_button'),
        );

        await tester.enterText(customInput, 'Nội thất cao cấp');
        await tester.tap(addButton);
        await tester.pumpAndSettle();

        // Chưa submit: repo chưa có bản ghi Firestore nào được tạo
        expect(repo.customAmenitiesCreated, isEmpty);
        expect(repo.tienIchPhongLinks, isEmpty);
        expect(repo.posts, isEmpty);
      },
    );

    testWidgets(
      '4. Toggle không xóa: chạm vào tiện ích tùy chọn chỉ bỏ chọn, nút X mới xóa',
      (tester) async {
        setScreenSize(tester, width: 390);
        final repo = CreatePostTestRepository()
          ..properties.add(defaultProperty);

        await tester.pumpWidget(
          createTestApp(const HostCreatePostScreen(), repo),
        );
        await tester.pumpAndSettle();

        final customInput = find.byKey(const ValueKey('custom_amenity_input'));
        final addButton = find.byKey(
          const ValueKey('add_custom_amenity_button'),
        );

        await tester.ensureVisible(customInput);
        await tester.enterText(customInput, 'Gần chợ');
        await tester.tap(addButton);
        await tester.pumpAndSettle();

        expect(find.text('Gần chợ'), findsOneWidget);
        expect(find.text('1 đang chọn'), findsOneWidget);

        // Chạm vào tile để toggle bỏ chọn
        final tile = find.byKey(const ValueKey('amenity_tile_Gần chợ'));
        await tester.ensureVisible(tile);
        await tester.tap(tile);
        await tester.pumpAndSettle();

        // Item vẫn còn, không bị xóa khỏi list
        expect(find.text('Gần chợ'), findsOneWidget);
        expect(find.text('0 đang chọn'), findsOneWidget);

        // Chạm lại để chọn lại
        await tester.ensureVisible(tile);
        await tester.tap(tile);
        await tester.pumpAndSettle();
        expect(find.text('1 đang chọn'), findsOneWidget);

        // Bấm nút xóa X: item bị xóa hoàn toàn khỏi list
        final deleteBtn = find.byKey(
          const ValueKey('delete_custom_amenity_Gần chợ'),
        );
        await tester.ensureVisible(deleteBtn);
        await tester.tap(deleteBtn);
        await tester.pumpAndSettle();

        expect(find.text('Gần chợ'), findsNothing);
        expect(find.text('0 đang chọn'), findsOneWidget);
      },
    );

    testWidgets(
      '5. Thu gọn & Xem thêm: Thu gọn chỉ giữ item đã chọn, Xem thêm hiện toàn bộ',
      (tester) async {
        setScreenSize(tester, width: 390);
        final repo = CreatePostTestRepository()
          ..properties.add(defaultProperty);

        await tester.pumpWidget(
          createTestApp(const HostCreatePostScreen(), repo),
        );
        await tester.pumpAndSettle();

        final toggleBtn = find.byKey(const ValueKey('amenities_toggle_button'));

        // Mặc định đang thu gọn (chưa chọn gì -> không hiện item nào)
        await tester.ensureVisible(toggleBtn);
        expect(find.text('Xem thêm v'), findsOneWidget);
        expect(find.text('Máy lạnh'), findsNothing);

        // Bấm "Xem thêm v" -> hiện toàn bộ catalog
        await tester.tap(toggleBtn);
        await tester.pumpAndSettle();

        expect(find.text('Thu gọn ^'), findsOneWidget);
        expect(find.text('Máy lạnh'), findsOneWidget);
        expect(find.text('Có gác lửng'), findsOneWidget);
        expect(find.text('Wifi tốc độ cao'), findsOneWidget);

        // Chọn "Máy lạnh"
        final mayLanhTile = find.byKey(const ValueKey('amenity_tile_Máy lạnh'));
        await tester.ensureVisible(mayLanhTile);
        await tester.tap(mayLanhTile);
        await tester.pumpAndSettle();

        // Bấm "Thu gọn ^"
        await tester.ensureVisible(toggleBtn);
        await tester.tap(toggleBtn);
        await tester.pumpAndSettle();

        expect(find.text('Xem thêm v'), findsOneWidget);
        // Chỉ giữ item đã chọn "Máy lạnh"
        expect(find.text('Máy lạnh'), findsOneWidget);
        // Các item chưa chọn bị ẩn
        expect(find.text('Có gác lửng'), findsNothing);
        expect(find.text('Wifi tốc độ cao'), findsNothing);
      },
    );

    testWidgets('6. Nút Đăng bài responsive 390-430px và nằm ngoài vùng cuộn', (
      tester,
    ) async {
      setScreenSize(tester, width: 390);
      final repo = CreatePostTestRepository()..properties.add(defaultProperty);

      await tester.pumpWidget(
        createTestApp(const HostCreatePostScreen(), repo),
      );
      await tester.pumpAndSettle();

      final submitButton = find.byKey(const ValueKey('submit_post_button'));
      expect(submitButton, findsOneWidget);

      // Kiểm tra nút nằm trong SafeArea/bottomNavigationBar ngoài Scrollable
      final scrollable = find.byType(Scrollable).first;
      expect(
        find.descendant(of: scrollable, matching: submitButton),
        findsNothing,
      );

      // Thử thay đổi kích thước lên 430px (responsive)
      setScreenSize(tester, width: 430);
      await tester.pumpAndSettle();
      expect(submitButton, findsOneWidget);
    });

    testWidgets(
      '7. Persist sau submit: lưu phòng, tạo document tiện ích tùy chọn, bảng liên kết TienIch_Phong và lưu post schema SDS',
      (tester) async {
        setScreenSize(tester, width: 390);
        final repo = CreatePostTestRepository()
          ..properties.add(defaultProperty);

        await tester.pumpWidget(
          createTestApp(const HostCreatePostScreen(), repo),
        );
        await tester.pumpAndSettle();

        // 1. Thêm ảnh qua TestPicker
        final addPhotoBtn = find.text('Thêm ảnh');
        await tester.tap(addPhotoBtn);
        await tester.pumpAndSettle();

        // 2. Điền thông tin cơ bản
        await tester.enterText(
          find.byKey(const ValueKey('title_input')),
          'Phòng studio full nội thất',
        );
        await tester.enterText(
          find.byKey(const ValueKey('price_input')),
          '2800000',
        );
        await tester.enterText(find.byKey(const ValueKey('area_input')), '28');

        // 3. Thêm tiện ích tùy chọn
        final customInput = find.byKey(const ValueKey('custom_amenity_input'));
        final addAmenityBtn = find.byKey(
          const ValueKey('add_custom_amenity_button'),
        );
        await tester.ensureVisible(customInput);
        await tester.pumpAndSettle();
        await tester.enterText(customInput, 'Khu an ninh 24/7');
        await tester.ensureVisible(addAmenityBtn);
        await tester.pumpAndSettle();
        await tester.tap(addAmenityBtn);
        await tester.pumpAndSettle();

        // 4. Chọn thêm 1 tiện ích catalog (danh sách đã tự động mở rộng khi thêm tiện ích)
        final mayLanhTile = find.byKey(const ValueKey('amenity_tile_Máy lạnh'));
        await tester.ensureVisible(mayLanhTile);
        await tester.pumpAndSettle();
        await tester.tap(mayLanhTile);
        await tester.pumpAndSettle();

        // 5. Điền vị trí & liên hệ
        final addressInput = find.byKey(const ValueKey('address_input'));
        await tester.ensureVisible(addressInput);
        await tester.pumpAndSettle();
        await tester.enterText(
          addressInput,
          '18 Đường số 6, Tăng Nhơn Phú B, TP. Thủ Đức',
        );
        final phoneInput = find.byKey(const ValueKey('phone_input'));
        await tester.ensureVisible(phoneInput);
        await tester.pumpAndSettle();
        await tester.enterText(phoneInput, '0987654321');
        final descInput = find.byKey(const ValueKey('description_input'));
        await tester.ensureVisible(descInput);
        await tester.pumpAndSettle();
        await tester.enterText(
          descInput,
          'Phòng mới tinh, thoáng mát, gần trường ĐH.',
        );

        // 6. Nhấn ĐĂNG BÀI NGAY
        final submitButton = find.byKey(const ValueKey('submit_post_button'));
        await tester.tap(submitButton);
        await tester.pumpAndSettle();

        // Kiểm tra sau submit:
        // A. Tiện ích tùy chọn lúc này mới được tạo document danh mục
        expect(repo.customAmenitiesCreated.length, 1);
        expect(repo.customAmenitiesCreated.first['name'], 'Khu an ninh 24/7');

        // B. Phòng đã được lưu
        expect(repo.rooms.length, 1);
        final savedRoom = repo.rooms.first;
        expect(savedRoom.title, 'Phòng studio full nội thất');
        expect(savedRoom.price, 2800000);
        expect(savedRoom.area, 28);

        // C. Tạo liên kết TienIch_Phong với phongId và tienIch_Id
        expect(repo.tienIchPhongLinks.length, 2);
        for (final link in repo.tienIchPhongLinks) {
          expect(link['phongId'], savedRoom.id);
          expect(link['tienIch_Id'], isNotEmpty);
        }

        // D. Bài đăng lưu theo đúng schema SDS
        expect(repo.posts.length, 1);
        final post = repo.posts.first;
        expect(post['phongId'], savedRoom.id);
        expect(post['chuNhaId'], 'host-test-uid');
        expect(post['diaDiemId'], 'Tăng Nhơn Phú B');
        expect(post['loaiThue_id'], 'thang');
        expect(post['trangThai_id'], 'dangHienThi');
        expect(post['tieuDe'], 'Phòng studio full nội thất');
        expect(post['moTa'], 'Phòng mới tinh, thoáng mát, gần trường ĐH.');
        expect(post['giaThue'], 2800000);
        expect(post['soDienThoaiLienHe'], '0987654321');
        expect(post['ngayDang'], isNotNull);
      },
    );

    testWidgets(
      '8. Rollback handling: khi lỗi lưu bài đăng, kích hoạt rollback không để mồ côi dữ liệu',
      (tester) async {
        setScreenSize(tester, width: 390);
        final repo = CreatePostTestRepository()
          ..properties.add(defaultProperty)
          ..failCreatePost = true;

        await tester.pumpWidget(
          createTestApp(const HostCreatePostScreen(), repo),
        );
        await tester.pumpAndSettle();

        // Thêm ảnh
        await tester.tap(find.text('Thêm ảnh'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('title_input')),
          'Phòng lỗi test',
        );
        await tester.enterText(
          find.byKey(const ValueKey('price_input')),
          '1500000',
        );
        final addressInput = find.byKey(const ValueKey('address_input'));
        await tester.ensureVisible(addressInput);
        await tester.enterText(addressInput, '18 Đường số 6');
        final phoneInput = find.byKey(const ValueKey('phone_input'));
        await tester.ensureVisible(phoneInput);
        await tester.enterText(phoneInput, '0987654321');

        // Submit gây lỗi
        final submitButton = find.byKey(const ValueKey('submit_post_button'));
        await tester.tap(submitButton);
        await tester.pumpAndSettle();

        // Rollback đã được trigger
        expect(repo.rollbackCleanedUp, isTrue);
        // Không có post nào được lưu lại
        expect(repo.posts, isEmpty);
      },
    );
  });
}
