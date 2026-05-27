import 'package:file_picker/file_picker.dart';

class FilePickerService {
  Future<String?> pickNotesFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'docx', 'csv'],
    );
    return result?.files.single.path;
  }
}
