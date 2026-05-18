import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import 'package:pointycastle/asn1.dart';

/// Service for generating RSA key pairs
class RsaService {
  /// Generates an RSA key pair with specified bit length
  /// Returns a map with 'publicKey' and 'privateKey' as PEM strings
  static Map<String, String> generateKeyPair({int bitLength = 2048}) {
    final secureRandom = _getSecureRandom();
    
    final params = RSAKeyGeneratorParameters(
      BigInt.parse('65537'),
      bitLength,
      64,
    );
    
    final keyGen = RSAKeyGenerator();
    keyGen.init(ParametersWithRandom(params, secureRandom));
    
    final pair = keyGen.generateKeyPair();
    final publicKey = pair.publicKey as RSAPublicKey;
    final privateKey = pair.privateKey as RSAPrivateKey;
    
    return {
      'publicKey': _encodePublicKeyToPem(publicKey),
      'privateKey': _encodePrivateKeyToPem(privateKey),
    };
  }
  
  static SecureRandom _getSecureRandom() {
    final secureRandom = FortunaRandom();
    final seedSource = Random.secure();
    final seeds = List<int>.generate(32, (_) => seedSource.nextInt(256));
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));
    return secureRandom;
  }
  
  /// Encodes RSA public key to PEM format
  static String _encodePublicKeyToPem(RSAPublicKey publicKey) {
    final algorithmSeq = ASN1Sequence();
    algorithmSeq.add(ASN1ObjectIdentifier.fromName('rsaEncryption'));
    algorithmSeq.add(ASN1Null());
    
    final publicKeySeq = ASN1Sequence();
    publicKeySeq.add(ASN1Integer(publicKey.modulus!));
    publicKeySeq.add(ASN1Integer(publicKey.exponent!));
    
    final publicKeyBitString = ASN1BitString(
      stringValues: Uint8List.fromList(publicKeySeq.encode()),
    );
    
    final topLevelSeq = ASN1Sequence();
    topLevelSeq.add(algorithmSeq);
    topLevelSeq.add(publicKeyBitString);
    
    final dataBase64 = base64.encode(topLevelSeq.encode());
    final lines = _splitBase64(dataBase64);
    
    return '-----BEGIN PUBLIC KEY-----\n${lines.join('\n')}\n-----END PUBLIC KEY-----';
  }
  
  /// Encodes RSA private key to PEM format
  static String _encodePrivateKeyToPem(RSAPrivateKey privateKey) {
    final version = ASN1Integer(BigInt.zero);
    final modulus = ASN1Integer(privateKey.n!);
    final publicExponent = ASN1Integer(privateKey.publicExponent!);
    final privateExponent = ASN1Integer(privateKey.privateExponent!);
    final p = ASN1Integer(privateKey.p!);
    final q = ASN1Integer(privateKey.q!);
    final dP = ASN1Integer(privateKey.privateExponent! % (privateKey.p! - BigInt.one));
    final dQ = ASN1Integer(privateKey.privateExponent! % (privateKey.q! - BigInt.one));
    final qInv = ASN1Integer(privateKey.q!.modInverse(privateKey.p!));
    
    final privateKeySeq = ASN1Sequence();
    privateKeySeq.add(version);
    privateKeySeq.add(modulus);
    privateKeySeq.add(publicExponent);
    privateKeySeq.add(privateExponent);
    privateKeySeq.add(p);
    privateKeySeq.add(q);
    privateKeySeq.add(dP);
    privateKeySeq.add(dQ);
    privateKeySeq.add(qInv);
    
    final dataBase64 = base64.encode(privateKeySeq.encode());
    final lines = _splitBase64(dataBase64);
    
    return '-----BEGIN RSA PRIVATE KEY-----\n${lines.join('\n')}\n-----END RSA PRIVATE KEY-----';
  }
  
  /// Splits base64 string into 64-character lines
  static List<String> _splitBase64(String base64String) {
    final List<String> lines = [];
    for (var i = 0; i < base64String.length; i += 64) {
      lines.add(base64String.substring(
        i,
        i + 64 > base64String.length ? base64String.length : i + 64,
      ));
    }
    return lines;
  }
  
  /// Loads RSA private key from PEM string
  /// Supports both PKCS#1 (-----BEGIN RSA PRIVATE KEY-----) and
  /// PKCS#8 (-----BEGIN PRIVATE KEY-----) formats
  static RSAPrivateKey _loadPrivateKeyFromPem(String pem) {
    final rows = pem.split('\n');
    final base64String = rows
        .where((row) => !row.startsWith('-----'))
        .join('');
    final bytes = base64.decode(base64String);
    
    final topLevelSeq = ASN1Parser(Uint8List.fromList(bytes)).nextObject() as ASN1Sequence;
    
    BigInt modulus;
    BigInt privateExponent;
    BigInt p;
    BigInt q;
    
    // Check if this is PKCS#8 format (has algorithm identifier at elements[0])
    // PKCS#8: SEQUENCE { AlgorithmIdentifier, PrivateKey OCTET STRING }
    // where PrivateKey is a PKCS#1 RSAPrivateKey
    if (topLevelSeq.elements![0] is ASN1Sequence) {
      // PKCS#8 format: elements[0] is AlgorithmIdentifier, elements[1] is PrivateKey OCTET STRING
      final privateKeyOctetString = topLevelSeq.elements![1] as ASN1OctetString;
      final privateKeyBytes = Uint8List.fromList(privateKeyOctetString.octets ?? []);
      final privateKeySeq = ASN1Parser(privateKeyBytes).nextObject() as ASN1Sequence;
      
      modulus = (privateKeySeq.elements![1] as ASN1Integer).integer!;
      privateExponent = (privateKeySeq.elements![3] as ASN1Integer).integer!;
      p = (privateKeySeq.elements![4] as ASN1Integer).integer!;
      q = (privateKeySeq.elements![5] as ASN1Integer).integer!;
    } else {
      // PKCS#1 format: RSAPrivateKey directly
      // RSAPrivateKey ::= SEQUENCE {
      //   version           Version,
      //   modulus           INTEGER,  -- n
      //   publicExponent   INTEGER,  -- e
      //   privateExponent  INTEGER,  -- d
      //   prime1           INTEGER,  -- p
      //   prime2           INTEGER,  -- q
      //   exponent1        INTEGER,  -- d mod (p-1)
      //   exponent2        INTEGER,  -- d mod (q-1)
      //   coefficient      INTEGER,  -- (inverse of q) mod p
      // }
      modulus = (topLevelSeq.elements![1] as ASN1Integer).integer!;
      privateExponent = (topLevelSeq.elements![3] as ASN1Integer).integer!;
      p = (topLevelSeq.elements![4] as ASN1Integer).integer!;
      q = (topLevelSeq.elements![5] as ASN1Integer).integer!;
    }
    
    return RSAPrivateKey(modulus, privateExponent, p, q);
  }
  
  /// Loads RSA public key from PEM string
  static RSAPublicKey _loadPublicKeyFromPem(String pem) {
    final rows = pem.split('\n');
    final base64String = rows
        .where((row) => !row.startsWith('-----'))
        .join('');
    final bytes = base64.decode(base64String);
    
    final topLevelSeq = ASN1Parser(Uint8List.fromList(bytes)).nextObject() as ASN1Sequence;
    final publicKeyBitString = topLevelSeq.elements![1] as ASN1BitString;
    final publicKeySeq = ASN1Parser(Uint8List.fromList(publicKeyBitString.stringValues!)).nextObject() as ASN1Sequence;
    
    final modulus = (publicKeySeq.elements![0] as ASN1Integer).integer!;
    final exponent = (publicKeySeq.elements![1] as ASN1Integer).integer!;
    
    return RSAPublicKey(modulus, exponent);
  }
  
  /// Encrypts data using RSA with public key (OAEP padding)
  /// Takes plaintext string and returns base64 encoded ciphertext
  static String encrypt(String plaintext, String publicKeyPem) {
    final publicKey = _loadPublicKeyFromPem(publicKeyPem);
    
    final engine = RSAEngine()..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));
    final encryptor = OAEPEncoding(engine)..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));
    
    final bytes = utf8.encode(plaintext);
    final blockSize = encryptor.inputBlockSize;
    
    final cipherText = StringBuffer();
    for (var offset = 0; offset < bytes.length; offset += blockSize) {
      final blockEnd = (offset + blockSize < bytes.length) 
          ? offset + blockSize 
          : bytes.length;
      final block = Uint8List.fromList(bytes.sublist(offset, blockEnd));
      final out = Uint8List(encryptor.outputBlockSize);
      final len = encryptor.processBlock(block, 0, block.length, out, 0);
      cipherText.write(base64.encode(out.sublist(0, len)));
    }
    
    return cipherText.toString();
  }
  
  /// Decrypts data using RSA with private key (OAEP padding)
  /// Takes base64 encoded ciphertext and returns plaintext string
  static String decrypt(String encryptedBase64, String privateKeyPem) {
    final privateKey = _loadPrivateKeyFromPem(privateKeyPem);
    
    final engine = RSAEngine()..init(false, PrivateKeyParameter<RSAPrivateKey>(privateKey));
    final decryptor = OAEPEncoding(engine)..init(false, PrivateKeyParameter<RSAPrivateKey>(privateKey));
    
    final encryptedBytes = base64.decode(encryptedBase64);
    final blockSize = decryptor.inputBlockSize;
    
    final plainText = StringBuffer();
    for (var offset = 0; offset < encryptedBytes.length; offset += blockSize) {
      final blockEnd = (offset + blockSize < encryptedBytes.length) 
          ? offset + blockSize 
          : encryptedBytes.length;
      final block = Uint8List.fromList(encryptedBytes.sublist(offset, blockEnd));
      final out = Uint8List(decryptor.outputBlockSize);
      final len = decryptor.processBlock(block, 0, block.length, out, 0);
      plainText.write(utf8.decode(out.sublist(0, len)));
    }
    
    return plainText.toString();
  }
  
  /// Encrypts data using RSA with public key (PKCS1 v1.5 padding)
  /// Takes plaintext string and returns base64 encoded ciphertext
  static String encryptPKCS1(String plaintext, String publicKeyPem) {
    final publicKey = _loadPublicKeyFromPem(publicKeyPem);
    
    final engine = RSAEngine()..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));
    final encryptor = PKCS1Encoding(engine)..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));
    
    final bytes = utf8.encode(plaintext);
    final blockSize = encryptor.inputBlockSize;
    
    final cipherText = StringBuffer();
    for (var offset = 0; offset < bytes.length; offset += blockSize) {
      final blockEnd = (offset + blockSize < bytes.length) 
          ? offset + blockSize 
          : bytes.length;
      final block = Uint8List.fromList(bytes.sublist(offset, blockEnd));
      final out = Uint8List(encryptor.outputBlockSize);
      final len = encryptor.processBlock(block, 0, block.length, out, 0);
      cipherText.write(base64.encode(out.sublist(0, len)));
    }
    
    return cipherText.toString();
  }
  
  /// Decrypts data using RSA with private key (PKCS1 v1.5 padding)
  /// Takes base64 encoded ciphertext and returns plaintext string
  static String decryptPKCS1(String encryptedBase64, String privateKeyPem) {
    final privateKey = _loadPrivateKeyFromPem(privateKeyPem);
    
    final engine = RSAEngine()..init(false, PrivateKeyParameter<RSAPrivateKey>(privateKey));
    final decryptor = PKCS1Encoding(engine)..init(false, PrivateKeyParameter<RSAPrivateKey>(privateKey));
    
    final encryptedBytes = base64.decode(encryptedBase64);
    final blockSize = decryptor.inputBlockSize;
    
    final plainText = StringBuffer();
    for (var offset = 0; offset < encryptedBytes.length; offset += blockSize) {
      final blockEnd = (offset + blockSize < encryptedBytes.length) 
          ? offset + blockSize 
          : encryptedBytes.length;
      final block = Uint8List.fromList(encryptedBytes.sublist(offset, blockEnd));
      final out = Uint8List(decryptor.outputBlockSize);
      final len = decryptor.processBlock(block, 0, block.length, out, 0);
      plainText.write(utf8.decode(out.sublist(0, len)));
    }
    
    return plainText.toString();
  }
}
