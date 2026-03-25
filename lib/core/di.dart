import 'package:get_it/get_it.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

final sl = GetIt.instance;

void setupServiceLocator() {
  // Services (singletons)
  sl.registerLazySingleton<ApiService>(() => ApiService());
  sl.registerLazySingleton<SocketService>(() => SocketService());
}
