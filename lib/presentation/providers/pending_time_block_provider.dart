import 'package:flutter/foundation.dart';

class PendingTimeBlockProvider extends ChangeNotifier {
  final Set<String> _pendingEventIds = {};

  bool isPending(String eventId) => _pendingEventIds.contains(eventId);

  void markPending(String eventId) {
    if (_pendingEventIds.add(eventId)) {
      notifyListeners();
    }
  }

  void clearPending(String eventId) {
    if (_pendingEventIds.remove(eventId)) {
      notifyListeners();
    }
  }
}

