// main.dart
// Flutter entry point.
// Before runApp:
//   1. WidgetsFlutterBinding.ensureInitialized()
//   2. Initialise Isar (open the database, register schemas)
//   3. Load flow_manifest.json via flow_index.dart into memory
//   4. Initialise cache_service with the open Isar instance
// Then: runApp(ProviderScope(child: App()))
// All subsequent initialisation (auth check, profile load) happens in splash_screen.
