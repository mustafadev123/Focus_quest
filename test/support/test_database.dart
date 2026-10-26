import 'package:focus_quest/data/database/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Opens a fresh database on the host machine using the FFI SQLite driver.
///
/// Pass [path] to reopen a file and test persistence; otherwise the database
/// lives in memory and is discarded when closed.
Future<Database> openTestDatabase({String? path}) {
  sqfliteFfiInit();
  return AppDatabase.open(
    factory: databaseFactoryFfi,
    path: path ?? inMemoryDatabasePath,
  );
}
