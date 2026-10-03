import 'package:flutter/foundation.dart';

import 'message_service.dart';

Future<void> setupFirebase(MessageService messageService, String? userToken) async {
  debugPrint('Firebase is disabled on Web to avoid compilation errors.');
}
