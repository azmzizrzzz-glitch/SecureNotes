import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

class CryptoService {
  static final CryptoService _instance = CryptoService._internal();
  factory CryptoService() => _instance;
  CryptoService._internal();

  String? _masterKey;

  void setMasterKey(String password) {
    final bytes = utf8.encode(password);
    final hash = sha256.convert(bytes);
    _masterKey = hash.toString().substring(0, 32);
  }

  String? get masterKey => _masterKey;

  String encryptData(String plainText) {
    if (_masterKey == null) throw Exception('Master key not set');
    
    final key = encrypt.Key.fromUtf8(_masterKey!);
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.cbc),
    );
    
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    final combined = '${iv.base64}:${encrypted.base64}';
    return base64.encode(utf8.encode(combined));
  }

  String decryptData(String encryptedText) {
    if (_masterKey == null) throw Exception('Master key not set');
    
    try {
      final decoded = utf8.decode(base64.decode(encryptedText));
      final parts = decoded.split(':');
      if (parts.length != 2) throw Exception('Invalid format');
      
      final iv = encrypt.IV.fromBase64(parts[0]);
      final encrypted = encrypt.Encrypted.fromBase64(parts[1]);
      
      final key = encrypt.Key.fromUtf8(_masterKey!);
      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.cbc),
      );
      
      return encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      throw Exception('Decryption failed');
    }
  }

  String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  Uint8List encryptBytes(Uint8List data) {
    if (_masterKey == null) throw Exception('Master key not set');
    
    final key = encrypt.Key.fromUtf8(_masterKey!);
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.cbc),
    );
    
    final encrypted = encrypter.encryptBytes(data, iv: iv);
    final result = Uint8List(16 + encrypted.bytes.length);
    result.setAll(0, iv.bytes);
    result.setAll(16, encrypted.bytes);
    return result;
  }

  Uint8List decryptBytes(Uint8List data) {
    if (_masterKey == null) throw Exception('Master key not set');
    
    final iv = encrypt.IV(data.sublist(0, 16));
    final encrypted = encrypt.Encrypted(data.sublist(16));
    
    final key = encrypt.Key.fromUtf8(_masterKey!);
    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.cbc),
    );
    
    return Uint8List.fromList(encrypter.decryptBytes(encrypted, iv: iv));
  }

  void clearKey() {
    _masterKey = null;
  }
}
