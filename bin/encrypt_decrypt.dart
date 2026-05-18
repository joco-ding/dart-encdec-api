import '../lib/server.dart';
import '../lib/env_config.dart';

void main(List<String> arguments) async {
  // Load configuration from .env file
  EnvConfig.load();
  
  print('=== RSA Key Generation API Server ===');
  print('Loading configuration from .env file...');
  print('Port: ${EnvConfig.port}');
  print('Keys Directory: ${EnvConfig.keysDir}');
  print('');
  
  final server = RsaApiServer(
    port: EnvConfig.port,
    keysDir: EnvConfig.keysDir,
  );
  
  await server.start();
}