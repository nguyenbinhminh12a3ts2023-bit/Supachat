import 'notification_helper_stub.dart'
    if (dart.library.html) 'notification_helper_web.dart' as helper;

/// Yêu cầu quyền thông báo trình duyệt nếu chạy trên Web
void requestBrowserNotificationPermission() {
  helper.requestBrowserNotificationPermission();
}

/// Hiển thị thông báo trình duyệt HTML5 (kể cả khi người dùng đang ở tab khác)
void showBrowserNotification(String title, String body, {String? icon}) {
  helper.showBrowserNotification(title, body, icon: icon);
}

/// Phát âm thanh thông báo nhẹ nhàng
void playNotificationBeep() {
  helper.playNotificationBeep();
}

