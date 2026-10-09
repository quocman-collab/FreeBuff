import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:home_share/core/theme/app_theme.dart';
import 'package:home_share/data/models/room_model.dart';
import 'package:home_share/features/auth/providers/user_provider.dart';
import 'package:home_share/features/host/data/host_property.dart';
import 'package:home_share/features/host/providers/host_management_provider.dart';
import 'package:home_share/features/host/screens/host_create_screen.dart';
import 'package:home_share/features/host/screens/host_property_management_screen.dart';

const house = HostProperty(
  id: 'house-1',
  name: 'Nhà trọ kiểm thử',
  address: '48 Đặng Văn Bi',
  city: 'TP. Hồ Chí Minh',
  ward: 'Phường Thủ Đức',
  hostId: 'host-test',
  plannedRooms: 3,
  floors: 2,
);
RoomModel makeRoom(
  String code, {
  String status = 'available',
  String propertyId = 'house-1',
  double price = 2500000,
}) => RoomModel(
  id: code,
  propertyId: propertyId,
  roomCode: code,
  status: status,
  title: 'Phòng $code',
  description: '',
  price: price,
  deposit: 0,
  address: house.fullAddress,
  district: house.ward,
  city: house.city,
  area: 25,
  roomType: 'Phòng trọ',
  amenities: [],
  images: [],
  hostId: 'host-test',
  hostName: 'Chủ trọ',
  hostPhone: '',
  isAvailable: status == 'available',
  createdAt: DateTime(2026),
);

// Chủ trọ - Repository kiểm thử - Luồng đi: Cập nhật stream trong bộ
// nhớ để kiểm tra giao diện, không ghi dữ liệu vào Firebase sản xuất.
class TestRepository extends HostRepository {
  final propertyEvents = StreamController<List<HostProperty>>.broadcast();
  final roomEvents = StreamController<List<RoomModel>>.broadcast();
  final properties = <HostProperty>[];
  final rooms = <RoomModel>[];
  HostProperty? savedHouse;
  RoomModel? savedRoom;
  int houseWrites = 0;
  int roomWrites = 0;
  bool failRoom = false;
  @override
  String newPropertyId() => 'new-house';
  @override
  Stream<List<HostProperty>> watchProperties(String uid) async* {
    yield List.of(properties);
    yield* propertyEvents.stream;
  }

  @override
  Stream<List<RoomModel>> watchRooms(String uid) async* {
    yield List.of(rooms);
    yield* roomEvents.stream;
  }

  @override
  Future<String> createProperty(
    HostProperty property,
    List<HostUpload> images,
    HostUpload? proof,
  ) async {
    expect(images.length, 1);
    savedHouse = property;
    houseWrites++;
    properties.add(property);
    propertyEvents.add(List.of(properties));
    return property.id;
  }

  @override
  Future<String> createRoom(
    RoomModel room,
    List<HostUpload> images,
    String operationId, {
    int maxImages = 8,
  }) async {
    expect(images.length, 1);
    roomWrites++;
    if (failRoom) throw StateError('Kiểm thử lỗi lưu phòng');
    savedRoom = room;
    rooms.add(room);
    roomEvents.add(List.of(rooms));
    return room.id.isEmpty ? 'room-test-id' : room.id;
  }

  void close() {
    unawaited(propertyEvents.close());
    unawaited(roomEvents.close());
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

Widget app(
  Widget home,
  TestRepository repository, {
  String? uid = 'host-test',
}) => ProviderScope(
  overrides: [
    hostSessionProvider.overrideWith((ref) => Stream.value(uid)),
    hostRepositoryProvider.overrideWithValue(repository),
    hostImagePickerProvider.overrideWithValue(TestPicker()),
    userProfileProvider.overrideWith(
      (ref) => Stream.value(
        UserProfile(
          uid: 'host-test',
          email: 'host@example.com',
          displayName: 'Chủ trọ kiểm thử',
          phoneNumber: '0901234567',
          role: 'host',
        ),
      ),
    ),
  ],
  child: MaterialApp(theme: AppTheme.lightTheme, home: home),
);
void phone(WidgetTester tester, {double width = 390}) {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> enter(WidgetTester tester, String key, String text) async {
  final field = find.byKey(ValueKey('host_field_$key'));
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.enterText(field, text);
  await tester.pumpAndSettle();
}

// Chủ trọ - Kiểm thử quản lý và tạo - Luồng đi: Kiểm tra stream thay
// đổi, ràng buộc form, lưu thành công/lỗi và chế độ chưa đăng nhập.
void main() {
  test('Summary counts real linked rooms and separates other statuses', () {
    final summary = PropertySummary(house, [
      makeRoom('A1'),
      makeRoom('A2', status: 'occupied'),
      makeRoom('A3', status: 'reserved'),
      makeRoom('X', propertyId: ''),
    ]);
    expect(summary.rooms.length, 3);
    expect(summary.rented, 1);
    expect(summary.vacant, 1);
    expect(summary.other, 1);
    expect(summary.expectedRevenue, 2500000);
    expect(PropertySummary(house, []).occupancy, 0);
    expect(
      HostRepository.roomDocumentId('house', ' a101 '),
      HostRepository.roomDocumentId('house', 'A101'),
    );
    expect(
      HostRepository.roomDocumentId('house', 'A101'),
      isNot(HostRepository.roomDocumentId('other', 'A101')),
    );
    expect(
      RoomModel.fromMap({'isAvailable': false}, 'old').status,
      'unavailable',
    );
  });

  testWidgets('Management responds to property and room stream changes', (
    tester,
  ) async {
    phone(tester);
    final repo = TestRepository();
    addTearDown(repo.close);
    await tester.pumpWidget(app(const HostPropertyManagementScreen(), repo));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có cơ sở'), findsOneWidget);
    repo.properties.add(house);
    repo.propertyEvents.add(List.of(repo.properties));
    await tester.pumpAndSettle();
    expect(find.text('Danh sách cơ sở (1)'), findsOneWidget);
    expect(find.text('0/3 phòng đã tạo'), findsOneWidget);
    repo.rooms.addAll([makeRoom('A101'), makeRoom('A102', status: 'occupied')]);
    repo.roomEvents.add(List.of(repo.rooms));
    await tester.pumpAndSettle();
    expect(find.text('2/3 phòng đã tạo'), findsOneWidget);
    expect(find.text('50% lấp đầy'), findsOneWidget);
    await tester.tap(find.text('Quản lý phòng'));
    await tester.pumpAndSettle();
    expect(find.text('Phòng A101'), findsOneWidget);
    expect(find.text('Phòng A102'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Create house then room uploads selected photos and saves fields',
    (tester) async {
      phone(tester);
      final repo = TestRepository();
      addTearDown(repo.close);
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const HostCreateScreen(),
                    ),
                  ),
                  child: const Text('Mở form'),
                ),
              ),
            ),
          ),
          repo,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mở form'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thêm ảnh'));
      await tester.pumpAndSettle();
      await enter(tester, 'name', 'Nhà thử nghiệm');
      await enter(tester, 'address', '48 Đặng Văn Bi');
      await enter(tester, 'ward', 'Phường Thủ Đức');
      await enter(tester, 'planned', '3');
      await tester.tap(find.text('Lưu & tạo phòng'));
      await tester.pumpAndSettle();
      expect(repo.houseWrites, 1);
      expect(repo.savedHouse!.name, 'Nhà thử nghiệm');
      expect(repo.savedHouse!.plannedRooms, 3);
      expect(find.text('Lưu phòng'), findsOneWidget);
      final photos = find.text('Thêm ảnh');
      await tester.ensureVisible(photos);
      await tester.pumpAndSettle();
      await tester.tap(photos);
      await tester.pumpAndSettle();
      await enter(tester, 'code', 'a101');
      await enter(tester, 'price', '2500000');
      await tester.tap(find.text('Lưu phòng'));
      await tester.pumpAndSettle();
      expect(repo.roomWrites, 1);
      expect(repo.savedRoom!.propertyId, 'new-house');
      expect(repo.savedRoom!.roomCode, 'A101');
      expect(repo.savedRoom!.price, 2500000);
      expect(repo.savedRoom!.hostId, 'host-test');
      expect(repo.savedRoom!.status, 'available');
      expect(find.text('Mở form'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Failed room save retains form and allows retry', (tester) async {
    phone(tester, width: 320);
    final repo = TestRepository()
      ..properties.add(house)
      ..failRoom = true;
    addTearDown(repo.close);
    await tester.pumpWidget(
      app(
        const HostCreateScreen(propertyId: 'house-1', startWithRoom: true),
        repo,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thêm ảnh'));
    await tester.pumpAndSettle();
    await enter(tester, 'code', 'A101');
    await enter(tester, 'price', '2500000');
    await tester.tap(find.text('Lưu phòng'));
    await tester.pumpAndSettle();
    expect(find.text('Kiểm thử lỗi lưu phòng'), findsOneWidget);
    expect(repo.savedRoom, isNull);
    expect(repo.roomWrites, 1);
    final input = tester.widget<TextFormField>(
      find.byKey(const ValueKey('host_field_code')),
    );
    expect(input.controller!.text, 'A101');
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Lưu phòng'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('No session disables save on narrow screen', (tester) async {
    phone(tester);
    final repo = TestRepository();
    addTearDown(repo.close);
    await tester.pumpWidget(app(const HostCreateScreen(), repo, uid: null));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Lưu & tạo phòng'),
          )
          .onPressed,
      isNull,
    );
    expect(repo.houseWrites, 0);
    expect(tester.takeException(), isNull);
  });
}
