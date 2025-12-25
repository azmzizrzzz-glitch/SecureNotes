import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';

import '../models/note.dart';
import '../services/database_service.dart';
import '../services/crypto_service.dart';
import '../widgets/message_bubble.dart';
import '../widgets/attachment_sheet.dart';
import 'lock_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _textController = TextEditingController();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _db = DatabaseService();
  final _crypto = CryptoService();
  final _uuid = const Uuid();
  
  List<Note> _notes = [];
  List<Note> _filteredNotes = [];
  bool _isLoading = true;
  bool _isSearching = false;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadNotes();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _lockApp();
    }
  }

  Future<void> _loadNotes() async {
    setState(() => _isLoading = true);
    
    try {
      final notes = await _db.getAllNotes();
      final decryptedNotes = notes.map((note) {
        if (note.isEncrypted) {
          try {
            final decryptedContent = _crypto.decryptData(note.content);
            return note.copyWith(content: decryptedContent);
          } catch (e) {
            return note;
          }
        }
        return note;
      }).toList();
      
      setState(() {
        _notes = decryptedNotes;
        _filteredNotes = decryptedNotes;
        _isLoading = false;
      });
      
      _scrollToBottom();
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to load notes');
    }
  }

  Future<void> _addNote(NoteType type, String content, {Map<String, dynamic>? metadata}) async {
    final encryptedContent = _crypto.encryptData(content);
    
    final note = Note(
      id: _uuid.v4(),
      type: type,
      content: encryptedContent,
      metadata: metadata,
      timestamp: DateTime.now(),
    );
    
    await _db.insertNote(note);
    
    setState(() {
      _notes.add(note.copyWith(content: content));
      _filteredNotes = _notes;
    });
    
    _scrollToBottom();
  }

  Future<void> _deleteNote(String id) async {
    await _db.deleteNote(id);
    setState(() {
      _notes.removeWhere((n) => n.id == id);
      _filteredNotes = _notes;
    });
  }

  void _sendTextNote() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    
    _addNote(NoteType.text, text);
    _textController.clear();
  }

  Future<void> _pickImage(ImageSource source) async {
    final permission = source == ImageSource.camera 
        ? Permission.camera 
        : Permission.photos;
    
    if (await permission.request().isDenied) {
      _showError('Permission denied');
      return;
    }

    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: source,
      imageQuality: 80,
    );
    
    if (image != null) {
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);
      await _addNote(
        NoteType.image, 
        base64Image,
        metadata: {'fileName': image.name},
      );
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final bytes = await file.readAsBytes();
      final base64File = base64Encode(bytes);
      
      await _addNote(
        NoteType.file,
        base64File,
        metadata: {
          'fileName': result.files.single.name,
          'size': result.files.single.size,
        },
      );
    }
  }

  Future<void> _getLocation() async {
    if (await Permission.location.request().isDenied) {
      _showError('Location permission denied');
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition();
      await _addNote(
        NoteType.location,
        '${position.latitude},${position.longitude}',
        metadata: {
          'accuracy': position.accuracy,
          'altitude': position.altitude,
        },
      );
    } catch (e) {
      _showError('Failed to get location');
    }
  }

  Future<void> _exportToHtml() async {
    final buffer = StringBuffer();
    buffer.writeln('<!DOCTYPE html>');
    buffer.writeln('<html><head>');
    buffer.writeln('<meta charset="UTF-8">');
    buffer.writeln('<meta name="viewport" content="width=device-width, initial-scale=1.0">');
    buffer.writeln('<title>SecureNotes Export</title>');
    buffer.writeln('<style>');
    buffer.writeln('body{font-family:system-ui;background:#0a0a0f;color:#fff;padding:20px;max-width:600px;margin:0 auto}');
    buffer.writeln('.msg{background:#1a1a2e;padding:15px;border-radius:15px;margin:10px 0}');
    buffer.writeln('.time{font-size:12px;color:#666;margin-top:8px}');
    buffer.writeln('.date{text-align:center;color:#888;padding:10px}');
    buffer.writeln('img{max-width:100%;border-radius:10px}');
    buffer.writeln('</style></head><body>');
    buffer.writeln('<h1>📝 SecureNotes Export</h1>');
    
    String? lastDate;
    final dateFormat = DateFormat('MMMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');
    
    for (final note in _notes) {
      final date = dateFormat.format(note.timestamp);
      if (date != lastDate) {
        buffer.writeln('<div class="date">$date</div>');
        lastDate = date;
      }
      
      buffer.writeln('<div class="msg">');
      
      switch (note.type) {
        case NoteType.text:
          buffer.writeln('<p>${_escapeHtml(note.content)}</p>');
          break;
        case NoteType.image:
          buffer.writeln('<img src="data:image/jpeg;base64,${note.content}">');
          break;
        case NoteType.location:
          final coords = note.content.split(',');
          buffer.writeln('<a href="https://maps.google.com/?q=${coords[0]},${coords[1]}" style="color:#6c63ff">📍 Location</a>');
          break;
        case NoteType.file:
          buffer.writeln('<p>📎 ${note.metadata?['fileName'] ?? 'File'}</p>');
          break;
        default:
          buffer.writeln('<p>${note.content}</p>');
      }
      
      buffer.writeln('<div class="time">${timeFormat.format(note.timestamp)}</div>');
      buffer.writeln('</div>');
    }
    
    buffer.writeln('</body></html>');
    
    final directory = await getExternalStorageDirectory();
    final file = File('${directory!.path}/SecureNotes_Export_${DateTime.now().millisecondsSinceEpoch}.html');
    await file.writeAsString(buffer.toString());
    
    await Share.shareXFiles([XFile(file.path)], text: 'SecureNotes Export');
  }

  Future<void> _createBackup() async {
    final notes = await _db.getAllNotes();
    final backup = {
      'version': 1,
      'timestamp': DateTime.now().toIso8601String(),
      'notes': notes.map((n) => n.toMap()).toList(),
    };
    
    final jsonStr = jsonEncode(backup);
    final encrypted = _crypto.encryptData(jsonStr);
    
    final directory = await getExternalStorageDirectory();
    final file = File('${directory!.path}/SecureNotes_Backup_${DateTime.now().millisecondsSinceEpoch}.snbak');
    await file.writeAsString(encrypted);
    
    await Share.shareXFiles([XFile(file.path)], text: 'SecureNotes Backup');
    
    _showSuccess('Backup created successfully');
  }

  Future<void> _restoreBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );
    
    if (result != null && result.files.single.path != null) {
      try {
        final file = File(result.files.single.path!);
        final encrypted = await file.readAsString();
        final decrypted = _crypto.decryptData(encrypted);
        final backup = jsonDecode(decrypted);
        
        final notesList = (backup['notes'] as List)
            .map((n) => Note.fromMap(n))
            .toList();
        
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            title: const Text('Restore Backup'),
            content: Text('Restore ${notesList.length} notes? Current notes will be replaced.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Restore'),
              ),
            ],
          ),
        );
        
        if (confirm == true) {
          await _db.clearAllData();
          for (final note in notesList) {
            await _db.insertNote(note);
          }
          await _loadNotes();
          _showSuccess('Backup restored successfully');
        }
      } catch (e) {
        _showError('Invalid backup file or wrong password');
      }
    }
  }

  void _search(String query) {
    if (query.isEmpty) {
      setState(() => _filteredNotes = _notes);
      return;
    }
    
    setState(() {
      _filteredNotes = _notes.where((n) => 
        n.type == NoteType.text && 
        n.content.toLowerCase().contains(query.toLowerCase())
      ).toList();
    });
  }

  void _lockApp() {
    _crypto.clearKey();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LockScreen()),
      (route) => false,
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFFF6B6B),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF4CAF50),
      ),
    );
  }

  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll('\n', '<br>');
  }

  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AttachmentSheet(
        onCamera: () {
          Navigator.pop(ctx);
          _pickImage(ImageSource.camera);
        },
        onGallery: () {
          Navigator.pop(ctx);
          _pickImage(ImageSource.gallery);
        },
        onFile: () {
          Navigator.pop(ctx);
          _pickFile();
        },
        onLocation: () {
          Navigator.pop(ctx);
          _getLocation();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Search...',
                  hintStyle: TextStyle(color: Colors.white38),
                  border: InputBorder.none,
                ),
                onChanged: _search,
              )
            : const Row(
                children: [
                  Icon(Icons.note_alt_rounded, color: Color(0xFF6C63FF)),
                  SizedBox(width: 10),
                  Text('SecureNotes'),
                ],
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _filteredNotes = _notes;
                }
              });
            },
          ),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            color: const Color(0xFF1A1A2E),
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.html, size: 20),
                    SizedBox(width: 10),
                    Text('Export HTML'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'backup',
                child: Row(
                  children: [
                    Icon(Icons.backup, size: 20),
                    SizedBox(width: 10),
                    Text('Create Backup'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'restore',
                child: Row(
                  children: [
                    Icon(Icons.restore, size: 20),
                    SizedBox(width: 10),
                    Text('Restore Backup'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'lock',
                child: Row(
                  children: [
                    Icon(Icons.lock, size: 20, color: Color(0xFFFF6B6B)),
                    SizedBox(width: 10),
                    Text('Lock App', style: TextStyle(color: Color(0xFFFF6B6B))),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              switch (value) {
                case 'export':
                  _exportToHtml();
                  break;
                case 'backup':
                  _createBackup();
                  break;
                case 'restore':
                  _restoreBackup();
                  break;
                case 'lock':
                  _lockApp();
                  break;
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredNotes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.note_add_rounded,
                              size: 80,
                              color: Colors.white.withOpacity(0.1),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No notes yet',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.3),
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Start typing to add your first note',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.2),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredNotes.length,
                        itemBuilder: (ctx, index) {
                          final note = _filteredNotes[index];
                          final showDate = index == 0 ||
                              !_isSameDay(
                                _filteredNotes[index - 1].timestamp,
                                note.timestamp,
                              );
                          
                          return Column(
                            children: [
                              if (showDate)
                                _buildDateSeparator(note.timestamp),
                              MessageBubble(
                                note: note,
                                onDelete: () => _deleteNote(note.id),
                              ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.1),
                            ],
                          );
                        },
                      ),
          ),
          
          // Input Area
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Attachment Button
                  IconButton(
                    onPressed: _showAttachmentSheet,
                    icon: const Icon(Icons.attach_file_rounded),
                    color: const Color(0xFF6C63FF),
                  ),
                  
                  // Text Input
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _textController,
                        maxLines: 4,
                        minLines: 1,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(color: Colors.white38),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: (_) => _sendTextNote(),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Send Button
                  Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF6C63FF),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: _sendTextNote,
                      icon: const Icon(Icons.send_rounded),
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              DateFormat('MMMM d, yyyy').format(date),
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 12,
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _textController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
