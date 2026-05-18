# RSA Encryption/Decryption API

A Dart-based REST API server for RSA key generation, encryption, and decryption operations.

## Features

- **RSA Key Generation**: Generate RSA key pairs (supports 512-4096 bit key lengths)
- **Encryption**: Encrypt plaintext using RSA public key (OAEP and PKCS1 v1.5 padding)
- **Decryption**: Decrypt ciphertext using RSA private key
- **Key Management**: Automatic key storage to files
- **CORS Support**: Cross-origin requests enabled
- **Health Check**: Service health monitoring endpoint

## Installation

1. Ensure Dart SDK 3.9+ is installed
2. Clone the repository
3. Install dependencies:

```bash
dart pub get
```

4. Copy and configure environment file:

```bash
cp .env.example .env
```

## Configuration

Edit `.env` file to configure:

| Variable | Description | Default |
|----------|-------------|---------|
| `PORT` | Server port | `8080` |
| `KEYS_DIR` | Directory for storing RSA keys | `./keys` |

## Usage

### Start the server

```bash
dart run bin/encrypt_decrypt.dart
```

### API Endpoints

#### Health Check

```http
GET /health
```

Response:
```json
{
  "status": "ok",
  "service": "RSA Key Generator"
}
```

#### Generate RSA Keys

```http
POST /api/generate-keys
Content-Type: application/json

{
  "bitLength": 2048
}
```

Response:
```json
{
  "success": true,
  "publicKey": "-----BEGIN PUBLIC KEY-----\n...",
  "privateKey": "-----BEGIN RSA PRIVATE KEY-----\n...",
  "bitLength": 2048,
  "files": {
    "publicKey": "./keys/rsa-public.pem",
    "privateKey": "./keys/rsa-private.pem"
  }
}
```

#### Get Existing Keys

```http
GET /api/get-keys
```

Response:
```json
{
  "success": true,
  "publicKey": "-----BEGIN PUBLIC KEY-----\n...",
  "privateKey": "-----BEGIN RSA PRIVATE KEY-----\n...",
  "message": "Keys loaded from files"
}
```

#### Encrypt Data

```http
POST /api/encrypt
Content-Type: application/json

{
  "plaintext": "Your secret message"
}
```

Response:
```json
{
  "success": true,
  "encryptedData": "base64_encoded_ciphertext..."
}
```

#### Decrypt Data

```http
POST /api/decrypt
Content-Type: application/json

{
  "encryptedData": "base64_encoded_ciphertext...",
  "padding": "oaep"
}
```

Options for `padding`:
- `oaep` - RSA OAEP padding (recommended)
- `pkcs1` - RSA PKCS1 v1.5 padding (default)

Response:
```json
{
  "success": true,
  "decryptedData": "Your secret message"
}
```

## Example Usage with cURL

```bash
# Generate keys
curl -X POST http://localhost:8080/api/generate-keys \
  -H "Content-Type: application/json" \
  -d '{"bitLength": 2048}'

# Encrypt
curl -X POST http://localhost:8080/api/encrypt \
  -H "Content-Type: application/json" \
  -d '{"plaintext": "Hello, World!"}'

# Decrypt
curl -X POST http://localhost:8080/api/decrypt \
  -H "Content-Type: application/json" \
  -d '{"encryptedData": "...", "padding": "oaep"}'
```

## Dependencies

- [pointycastle](https://pub.dev/packages/pointycastle) - Cryptographic operations
- [shelf](https://pub.dev/packages/shelf) - HTTP server framework
- [envied](https://pub.dev/packages/envied) - Environment variable management

## License

MIT