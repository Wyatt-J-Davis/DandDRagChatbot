import 'package:file_picker/file_picker.dart';

class FilePickerService {
  Future<String?> pickNotesFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'docx', 'csv'],
    );
    return result?.files.single.path;
  }

  Future<String?> pickSavePath({required String fileName}) async {
    final ext = fileName.split('.').last;
    return FilePicker.saveFile(
      dialogTitle: 'Save notes as...',
      fileName: fileName,
      allowedExtensions: [ext],
      type: FileType.custom,
    );
  }
}
