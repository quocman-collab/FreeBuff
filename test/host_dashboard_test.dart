import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_share/features/host/providers/host_management_provider.dart';
import 'package:home_share/features/host/screens/host_main_screen.dart';
import 'package:home_share/core/theme/app_theme.dart';

// Chủ trọ - Kiểm tra điều hướng Dashboard - Luồng đi: Chuyển qua các tab
// tạm rồi về Trang chủ; xác nhận Dashboard giữ trạng thái panel khu vực.
void main() {
  testWidgets('Host navigation switches tabs and preserves dashboard state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hostSessionProvider.overrideWith((ref) => Stream.value('host-test')),
          hostPropertiesProvider.overrideWith((ref) => Stream.value([])),
          hostRoomsProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const HostMainScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('HomeShare'), findsOneWidget);
    expect(
      find.text('Chưa có khu vực trong dữ liệu bài đăng.'),
      findsOneWidget,
    );

    for (final label in ['Tin nhắn', 'Cá nhân']) {
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      expect(find.text('Màn hình sẽ được bổ sung sau.'), findsOneWidget);
    }

    await tester.tap(find.text('Quản lý').last);
    await tester.pumpAndSettle();
    expect(find.text('Quản lý phòng trọ'), findsOneWidget);
    expect(find.text('Danh sách cơ sở (0)'), findsOneWidget);
    expect(find.text('Thông tin chung'), findsOneWidget);
    expect(find.text('Trang chủ'), findsNothing);
    for (final label in ['Người thuê', 'Tiền tệ']) {
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      expect(find.text('Màn hình sẽ được bổ sung sau.'), findsOneWidget);
    }
    await tester.tap(find.byIcon(Icons.add).last);
    await tester.pumpAndSettle();
    expect(find.text('Tạo cơ sở (Nhà)'), findsNWidgets(2));
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thông tin chung'));
    await tester.pumpAndSettle();
    expect(find.text('Quản lý phòng trọ'), findsOneWidget);
    await tester.tap(find.text('Quay lại'));
    await tester.pumpAndSettle();
    expect(find.text('HomeShare'), findsOneWidget);
    expect(find.text('Bỏ chọn tất cả'), findsNothing);
  });
}
