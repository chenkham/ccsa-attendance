import 'export_helper_stub.dart'
    if (dart.library.html) 'export_helper_web.dart'
    if (dart.library.io) 'export_helper_io.dart';

class AppExportHelper {
  static Future<bool> saveOrShareFile({
    required String fileName,
    required String fileContent,
    required String mimeType,
    required String shareSubject,
  }) {
    return ExportHelper.saveOrShareFile(
      fileName: fileName,
      fileContent: fileContent,
      mimeType: mimeType,
      shareSubject: shareSubject,
    );
  }
}
