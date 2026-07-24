import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _storage = const FlutterSecureStorage();
  final TextEditingController _messageController = TextEditingController();
  List<dynamic> messages = [];
  late IO.Socket socket;
  bool isConnected = false;

  @override
  void initState() {
    super.initState();
    _initSocket();
  }

  Future<void> _initSocket() async {
    String? token = await _storage.read(key: 'jwt_token');

    if (!mounted) return;

    // Configuración robusta para mantener la conexión activa con Render
    socket = IO.io('https://ecohome-backend-main.onrender.com', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true, // Permitir conexión automática inmediata
      'reconnection': true, // Forzar reintentos si se pierde la conexión
      'reconnectionAttempts': 5,
      'reconnectionDelay': 1000,
      'auth': {'token': token},
    });

    socket.onConnect((_) {
      if (mounted) {
        setState(() {
          isConnected = true;
        });
      }
      print('[Socket.IO] Conectado exitosamente');
    });

    socket.onConnectError((data) {
      print('[Socket.IO] Error de conexión: $data');
      if (mounted) {
        setState(() {
          isConnected = false;
        });
      }
    });

    socket.on('history', (data) {
      if (mounted) {
        setState(() {
          messages = data;
        });
      }
    });

    socket.on('new-message', (data) {
      if (mounted) {
        setState(() {
          messages.add(data);
        });
      }
    });

    socket.onDisconnect((_) {
      if (mounted) {
        setState(() {
          isConnected = false;
        });
      }
      print('[Socket.IO] Desconectado');
    });
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;
    socket.emit('new-message', _messageController.text.trim());
    _messageController.clear();
  }

  @override
  void dispose() {
    socket.clearListeners();
    socket.disconnect();
    socket.destroy();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isConnected ? 'EcoHome Chat (En línea)' : 'EcoHome Chat (Conectando...)'),
        backgroundColor: isConnected ? Colors.green.shade700 : Colors.orange.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: ListTile(
                    title: Text(
                      msg['username'] ?? 'Anónimo',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green),
                    ),
                    subtitle: Text(msg['text'] ?? ''),
                    trailing: Text(
                      msg['created_at'] != null ? msg['created_at'].toString().substring(11, 16) : '',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8.0),
            color: Colors.grey.shade200,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Escribe un mensaje...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.green),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}