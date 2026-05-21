import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'services/messaging_service.dart';

final messagingServiceOverride = Provider<MessagingService>(
  (ref) => MessagingService(),
);
