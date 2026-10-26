/// Saves the study summary as a local text file and reads it back.
abstract interface class ReportFileService {
  /// Writes [content], replacing any earlier report; returns where it was
  /// saved. Throws if the device refuses the write.
  Future<String> write(String content);

  /// Reads the saved report. Throws if it is missing or unreadable.
  Future<String> read();
}
