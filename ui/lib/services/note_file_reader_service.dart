import 'dart:io';

class NoteFileReaderService {
  const NoteFileReaderService();

  Future<String> readFile(String path) => File(path).readAsString();
}
