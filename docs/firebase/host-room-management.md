# Quản lý phòng chủ trọ

Luồng: Quản lý nhà → Quản lý phòng → Chi tiết → Chỉnh sửa.

- Danh sách và chi tiết đọc stream `properties`/`rooms` của UID đang đăng nhập.
- Form sửa cập nhật mã phòng, tầng, diện tích, sức chứa, giá/cọc, phí, tiện ích, mô tả và ảnh. ID phòng không đổi; trạng thái, khách thuê và hợp đồng không bị form ghi đè.
- Các phí mới: `electricityRate`, `waterRate`, `serviceFee`. Phòng cũ thiếu phí hiển thị “Chưa thiết lập”.
- Thông tin khách thuê dùng các trường `tenantName`, `tenantPhone`, `contractId`, `contractStart`, `contractEnd`; chưa có dữ liệu thì hiển thị trống. Luồng gán khách/hợp đồng cần được module hợp đồng của nhóm cập nhật, không tự suy ra từ đơn đặt phòng.
- `properties.roomCodes` giữ mã phòng duy nhất. Tài liệu phòng mới dùng ID có mã thao tác; phòng cũ vẫn đọc và sửa được.
- Lưu kiểm tra `updatedAt` để tránh ghi đè bản sửa từ thiết bị khác.
- Xóa sau xác nhận đánh dấu `status: deleted`, giảm `roomCount`, bỏ mã phòng khỏi `roomCodes`. Bản ghi và ảnh cũ giữ lại cho lịch sử. Không cho xóa phòng đang thuê, giữ chỗ hoặc còn khách/hợp đồng.

Không triển khai hay thay đổi Firebase Rules trong lần này. Các file Rules draft/snippet cũ chưa cập nhật cho `roomCodes` và thao tác xóa mềm; không dùng chúng để thay thế Rules đang chạy mà chưa đối chiếu lại.

Kiểm thử giao diện dùng repository giả, không chứng minh quyền truy cập trên Firebase thật. Việc tải ảnh và ghi dữ liệu thật phụ thuộc tài khoản đăng nhập và Rules Firestore/Storage của dự án.
