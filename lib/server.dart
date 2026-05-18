import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'rsa_service.dart';
import 'env_config.dart';

/// API Server for RSA key generation
class RsaApiServer {
  final int port;
  final String keysDir;
  
  RsaApiServer({required this.port, required this.keysDir});
  
  Handler get handler => _router;
  
  Future<void> start() async {
    // Ensure keys directory exists
    final dir = Directory(keysDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
      print('Created keys directory: $keysDir');
    }
    
    final server = await shelf_io.serve(_router, '0.0.0.0', port);
    print('RSA Key Generation API running at http://${server.address.host}:${server.port}');
    print('Keys will be saved to: $keysDir');
    print('Available endpoints:');
    print('  POST /api/generate-keys - Generate RSA key pair (saves to files)');
    print('  GET  /api/get-keys      - Get existing keys from files');
    print('  POST /api/decrypt       - Decrypt base64 encoded ciphertext');
    print('  POST /api/encrypt       - Encrypt plaintext');
    print('  GET  /health           - Health check');
  }
  
  Handler get _router => Pipeline()
      .addMiddleware(_corsMiddleware())
      .addMiddleware(_jsonMiddleware())
      .addHandler(_handleRequest);
}

Middleware _corsMiddleware() => (Handler innerHandler) {
  return (Request request) async {
    if (request.method == 'OPTIONS') {
      return Response.ok('', headers: _corsHeaders);
    }
    final response = await innerHandler(request);
    return response.change(headers: _corsHeaders);
  };
};

Middleware _jsonMiddleware() => (Handler innerHandler) {
  return (Request request) async {
    final response = await innerHandler(request);
    return response.change(headers: {'Content-Type': 'application/json'});
  };
};

final Map<String, String> _corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept, Authorization',
};

/// Main request handler
Future<Response> _handleRequest(Request request) async {
  final path = request.url.path;
  
  // Health check endpoint
  if (path == 'health' && request.method == 'GET') {
    return Response.ok(
      jsonEncode({'status': 'ok', 'service': 'RSA Key Generator'}),
    );
  }
  
  // Get existing keys from files
  if (path == 'api/get-keys' && request.method == 'GET') {
    return _handleGetKeys();
  }
  
  // Generate RSA keys endpoint
  if (path == 'api/generate-keys' && request.method == 'POST') {
    return await _handleGenerateKeys(request);
  }
  
  // Decrypt endpoint
  if (path == 'api/decrypt' && request.method == 'POST') {
    return await _handleDecrypt(request);
  }
  
  // Encrypt endpoint
  if (path == 'api/encrypt' && request.method == 'POST') {
    return await _handleEncrypt(request);
  }
  
  // 404 for unknown paths
  return Response.notFound(
    jsonEncode({'error': 'Not found', 'path': path}),
  );
}

/// Handle get keys from files
Response _handleGetKeys() {
  final keysDir = EnvConfig.keysDir;
  final publicKeyFile = File('$keysDir/rsa-public.pem');
  final privateKeyFile = File('$keysDir/rsa-private.pem');
  
  try {
    if (!publicKeyFile.existsSync() || !privateKeyFile.existsSync()) {
      return Response.notFound(
        jsonEncode({'error': 'Keys not found. Generate keys first.'}),
      );
    }
    
    return Response.ok(
      jsonEncode({
        'success': true,
        'publicKey': publicKeyFile.readAsStringSync(),
        'privateKey': privateKeyFile.readAsStringSync(),
        'message': 'Keys loaded from files',
      }),
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({
        'error': 'Failed to read keys',
        'message': e.toString(),
      }),
    );
  }
}

/// Handle key generation request
Future<Response> _handleGenerateKeys(Request request) async {
  try {
    // Parse request body
    String body = await request.readAsString();
    Map<String, dynamic> requestData = {};
    
    if (body.isNotEmpty) {
      requestData = jsonDecode(body) as Map<String, dynamic>;
    }
    
    // Get bit length from request, default to 2048
    int bitLength = requestData['bitLength'] as int? ?? 2048;
    
    // Validate bit length
    if (bitLength < 512 || bitLength > 4096) {
      return Response.badRequest(
        body: jsonEncode({
          'error': 'Invalid bit length. Must be between 512 and 4096.',
        }),
      );
    }
    
    // Generate RSA key pair
    print('Generating RSA key pair with bitLength: $bitLength...');
    final keys = RsaService.generateKeyPair(bitLength: bitLength);
    print('Key pair generated successfully!');
    
    // Save keys to files
    final keysDir = EnvConfig.keysDir;
    final publicKeyFile = File('$keysDir/rsa-public.pem');
    final privateKeyFile = File('$keysDir/rsa-private.pem');
    
    // Ensure directory exists
    final dir = Directory(keysDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    
    // Write keys to files
    await publicKeyFile.writeAsString(keys['publicKey']!);
    await privateKeyFile.writeAsString(keys['privateKey']!);
    
    print('Keys saved to:');
    print('  - $keysDir/rsa-public.pem');
    print('  - $keysDir/rsa-private.pem');
    
    // Return response
    return Response.ok(
      jsonEncode({
        'success': true,
        'publicKey': keys['publicKey'],
        'privateKey': keys['privateKey'],
        'bitLength': bitLength,
        'files': {
          'publicKey': '$keysDir/rsa-public.pem',
          'privateKey': '$keysDir/rsa-private.pem',
        },
      }),
    );
  } catch (e) {
    print('Error generating keys: $e');
    return Response.internalServerError(
      body: jsonEncode({
        'error': 'Failed to generate keys',
        'message': e.toString(),
      }),
    );
  }
}

/// Handle decrypt request
Future<Response> _handleDecrypt(Request request) async {
  try {
    // Parse request body
    String body = await request.readAsString();
    Map<String, dynamic> requestData = {};
    
    if (body.isEmpty) {
      return Response.badRequest(
        body: jsonEncode({
          'error': 'Request body is required',
        }),
      );
    }
    
    requestData = jsonDecode(body) as Map<String, dynamic>;
    
    // Get encrypted data from request
    String encryptedData = requestData['encryptedData'] as String? ?? '';
    if (encryptedData.isEmpty) {
      return Response.badRequest(
        body: jsonEncode({
          'error': 'encryptedData is required',
        }),
      );
    }
    
    // Get padding method from request (default to PKCS1 for backwards compatibility)
    String padding = (requestData['padding'] as String? ?? 'pkcs1').toLowerCase();
    
    // Get private key from file
    final keysDir = EnvConfig.keysDir;
    final privateKeyFile = File('$keysDir/rsa-private.pem');
    
    if (!privateKeyFile.existsSync()) {
      return Response.notFound(
        jsonEncode({
          'error': 'Private key not found. Generate keys first.',
        }),
      );
    }
    
    final privateKey = privateKeyFile.readAsStringSync();
    
    // Decrypt the data
    print('Decrypting data with $padding padding...');
    String decrypted;
    try {
      if (padding == 'oaep') {
        decrypted = RsaService.decrypt(encryptedData, privateKey);
      } else {
        // Default to PKCS1 v1.5
        decrypted = RsaService.decryptPKCS1(encryptedData, privateKey);
      }
      print('Decryption successful!');
    } catch (e) {
      // If the requested padding fails, try the other one as a fallback
      print('Decryption with $padding failed, trying other padding method...');
      if (padding == 'oaep') {
        decrypted = RsaService.decryptPKCS1(encryptedData, privateKey);
      } else {
        decrypted = RsaService.decrypt(encryptedData, privateKey);
      }
    }
    
    return Response.ok(
      jsonEncode({
        'success': true,
        'decryptedData': decrypted,
      }),
    );
  } catch (e) {
    print('Error decrypting data: $e');
    return Response.internalServerError(
      body: jsonEncode({
        'error': 'Failed to decrypt data',
        'message': e.toString(),
      }),
    );
  }
}

/// Handle encrypt request
Future<Response> _handleEncrypt(Request request) async {
  try {
    // Parse request body
    String body = await request.readAsString();
    Map<String, dynamic> requestData = {};
    
    if (body.isEmpty) {
      return Response.badRequest(
        body: jsonEncode({
          'error': 'Request body is required',
        }),
      );
    }
    
    requestData = jsonDecode(body) as Map<String, dynamic>;
    
    // Get plaintext from request
    String plaintext = requestData['plaintext'] as String? ?? '';
    if (plaintext.isEmpty) {
      return Response.badRequest(
        body: jsonEncode({
          'error': 'plaintext is required',
        }),
      );
    }
    
    // Get public key from file
    final keysDir = EnvConfig.keysDir;
    final publicKeyFile = File('$keysDir/rsa-public.pem');
    
    if (!publicKeyFile.existsSync()) {
      return Response.notFound(
        jsonEncode({
          'error': 'Public key not found. Generate keys first.',
        }),
      );
    }
    
    final publicKey = publicKeyFile.readAsStringSync();
    
    // Encrypt the data
    print('Encrypting data...');
    final encrypted = RsaService.encrypt(plaintext, publicKey);
    print('Encryption successful!');
    
    return Response.ok(
      jsonEncode({
        'success': true,
        'encryptedData': encrypted,
      }),
    );
  } catch (e) {
    print('Error encrypting data: $e');
    return Response.internalServerError(
      body: jsonEncode({
        'error': 'Failed to encrypt data',
        'message': e.toString(),
      }),
    );
  }
}
