import 'dart:io';

import 'package:appflowy/plugins/document/application/prelude.dart';
import 'package:appflowy/shared/custom_image_cache_manager.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/workspace/application/settings/application_data_storage.dart';
import 'package:appflowy_backend/log.dart';
import 'package:flowy_infra/uuid.dart';
import 'package:path/path.dart' as p;

Future<String?> saveImageToLocalStorage(String localImagePath) async {
  final path = await getIt<ApplicationDataStorage>().getPath();
  final imagePath = p.join(
    path,
    'images',
  );
  try {
    // create the directory if not exists
    final directory = Directory(imagePath);
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    final copyToPath = p.join(
      imagePath,
      '${uuid()}${p.extension(localImagePath)}',
    );
    await File(localImagePath).copy(
      copyToPath,
    );
    return copyToPath;
  } catch (e) {
    Log.error('cannot save image file', e);
    return null;
  }
}

Future<String?> saveImageToCloudStorage(String localImagePath) async {
  final documentService = DocumentService();
  final result = await documentService.uploadFile(
    localFilePath: localImagePath,
  );
  return result.fold(
    (l) => null,
    (r) async {
      await CustomImageCacheManager().putFile(
        r.url,
        File(localImagePath).readAsBytesSync(),
      );
      return r.url;
    },
  );
}
