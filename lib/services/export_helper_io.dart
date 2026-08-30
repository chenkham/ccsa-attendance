import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ExportHelper {
  static Future<bool> saveOrShareFile({
    required String fileName,
    required String fileContent,
    required String mimeType,
    required String shareSubject,
  }) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(fileContent);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: mimeType)],
        subject: shareSubject,
      );
      return true;
    } catch (e) {
      return false;
    }
  }
}
