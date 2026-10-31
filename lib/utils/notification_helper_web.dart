// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:js' as js;

void requestBrowserNotificationPermission() {
  try {
    if (html.Notification.permission == 'default') {
      html.Notification.requestPermission();
    }
  } catch (_) {}
}

void showBrowserNotification(String title, String body, {String? icon}) {
  try {
    if (html.Notification.permission == 'granted') {
      html.Notification(
        title,
        body: body,
        icon: icon ?? '/favicon.png',
      );
    }
  } catch (_) {}
}

void playNotificationBeep() {
  try {
    js.context.callMethod('eval', [
      '''
      (function() {
        try {
          var AudioCtx = window.AudioContext || window.webkitAudioContext;
          if (!AudioCtx) return;
          var ctx = new AudioCtx();
          var osc = ctx.createOscillator();
          var gain = ctx.createGain();
          osc.connect(gain);
          gain.connect(ctx.destination);
          osc.type = 'sine';
          var t = ctx.currentTime;
          osc.frequency.setValueAtTime(659.25, t);
          gain.gain.setValueAtTime(0.12, t);
          gain.gain.exponentialRampToValueAtTime(0.001, t + 0.3);
          osc.start(t);
          osc.stop(t + 0.35);
        } catch(e) {}
      })()
      '''
    ]);
  } catch (_) {}
}
