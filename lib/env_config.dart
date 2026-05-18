import 'dart:io';

/// Configuration loaded from .env file
class EnvConfig {
  static int port = 8080;
  static String keysDir = 'keys';
  
  static void load() {
    try {
      final envFile = File('.env');
      if (envFile.existsSync()) {
        final lines = envFile.readAsLinesSync();
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
          
          final parts = trimmed.split('=');
          if (parts.length == 2) {
            final key = parts[0].trim();
            final value = parts[1].trim();
            
            switch (key) {
              case 'PORT':
                port = int.tryParse(value) ?? 8080;
                break;
              case 'KEYS_DIR':
                keysDir = value;
                break;
            }
          }
        }
      }
    } catch (e) {
      print('Warning: Could not load .env file: $e');
    }
  }
}