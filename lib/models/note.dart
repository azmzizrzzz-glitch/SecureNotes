import 'dart:convert';

enum NoteType { text, image, audio, file, location }

class Note {
  final String id;
  final NoteType type;
  final String content;
  final Map<String, dynamic>? metadata;
  final DateTime timestamp;
  final bool isEncrypted;

  Note({
    required this.id,
    required this.type,
    required this.content,
    this.metadata,
    required this.timestamp,
    this.isEncrypted = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'content': content,
      'metadata': metadata != null ? jsonEncode(metadata) : null,
      'timestamp': timestamp.toIso8601String(),
      'isEncrypted': isEncrypted ? 1 : 0,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] as String,
      type: NoteType.values.firstWhere((e) => e.name == map['type']),
      content: map['content'] as String,
      metadata: map['metadata'] != null 
          ? jsonDecode(map['metadata'] as String) 
          : null,
      timestamp: DateTime.parse(map['timestamp'] as String),
      isEncrypted: map['isEncrypted'] == 1,
    );
  }

  Note copyWith({
    String? id,
    NoteType? type,
    String? content,
    Map<String, dynamic>? metadata,
    DateTime? timestamp,
    bool? isEncrypted,
  }) {
    return Note(
      id: id ?? this.id,
      type: type ?? this.type,
      content: content ?? this.content,
      metadata: metadata ?? this.metadata,
      timestamp: timestamp ?? this.timestamp,
      isEncrypted: isEncrypted ?? this.isEncrypted,
    );
  }
}
