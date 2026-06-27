import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/asset_model.dart';
import '../services/asset_service.dart';

final assetServiceProvider = Provider<AssetService>((ref) => AssetService());

/// All company assets (newest first).
final assetsProvider = StreamProvider<List<AssetModel>>((ref) {
  return ref.watch(assetServiceProvider).watchAll();
});
