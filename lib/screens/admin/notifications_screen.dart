import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/admin_notification.dart';
import '../../services/notification_service.dart';
import 'assessment_detail_screen.dart';

/// Admin's notification inbox -- currently only ever "a grooming
/// assessment failed" notifications (see
/// FirebaseService.saveAssessment/NotificationService), newest first,
/// via a live Firestore stream so a new failure appears without a
/// manual refresh. Reachable only from DashboardScreen's notification
/// bell, which is itself only ever shown once DashboardScreen has
/// already confirmed the viewer is a signed-in Admin -- this screen
/// still reads [FirebaseAuth.instance.currentUser] itself rather than
/// trusting that, since [_markRead] needs the real signed-in uid either
/// way to know whose [AdminNotification.readBy] entry to set.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();

  String? get _adminUid => FirebaseAuth.instance.currentUser?.uid;

  /// Marks [notification] read for the current Admin (best-effort --
  /// see NotificationService.markAsRead, never blocks/fails the
  /// navigation below), then opens the exact failed assessment via the
  /// existing AssessmentDetailScreen -- never a second, duplicate
  /// result view.
  Future<void> _openNotification(AdminNotification notification) async {
    final adminUid = _adminUid;

    if (adminUid != null && !notification.isReadBy(adminUid)) {
      unawaited(
        _notificationService.markAsRead(
          notificationId: notification.id,
          adminUid: adminUid,
        ),
      );
    }

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AssessmentDetailScreen(assessmentId: notification.assessmentId),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return "-";
    return "${date.day}/${date.month}/${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    final adminUid = _adminUid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text("Notifications"),
        backgroundColor: const Color(0xFF1F3D73),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<AdminNotification>>(
        stream: _notificationService.streamNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  "Could not load notifications: ${snapshot.error}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return const Center(child: Text("No notifications yet."));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              final isRead =
                  adminUid != null && notification.isReadBy(adminUid);

              return Card(
                elevation: isRead ? 0 : 2,
                color: isRead ? Colors.white : const Color(0xFFEFF3FA),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: isRead
                        ? Colors.grey.shade200
                        : const Color(0xFF1F3D73).withValues(alpha: 0.3),
                  ),
                ),
                child: ListTile(
                  onTap: () => _openNotification(notification),
                  leading: CircleAvatar(
                    backgroundColor: Colors.red.withValues(alpha: 0.1),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.red,
                    ),
                  ),
                  title: Text(
                    notification.title,
                    style: TextStyle(
                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      "${notification.message}\n"
                      "Score: ${notification.totalScore}  •  "
                      "${_formatDate(notification.assessmentDate)}",
                    ),
                  ),
                  isThreeLine: true,
                  trailing: isRead
                      ? null
                      : Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Color(0xFF1F3D73),
                            shape: BoxShape.circle,
                          ),
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
