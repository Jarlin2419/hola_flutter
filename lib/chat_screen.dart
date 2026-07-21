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
    // 1. Recuperar el token JWT almacenado en el login
    String? token = await _storage.read(key: 'jwt_token');

    // 2. Configurar la conexión con Socket.IO enviando el token en el handshake (auth)
    socket = IO.io('http://127.0.0.1:3000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'auth': {'token': token}, // Coincide con el middleware authSocket de tu backend
    });

    socket.connect();

    // 3. Escuchar evento de conexión exitosa
    socket.onConnect((_) {
      setState(() {
        isConnected = true;
      });
      print('[Socket.IO] Conectado exitosamente al servidor');
    });

    // 4. Recibir el historial inicial de los últimos mensajes desde la BD
    socket.on('history', (data) {
      setState(() {
        messages = data;
      });
    });

    // 5. Escuchar nuevos mensajes enviados en tiempo real por cualquier usuario
    socket.on('new-message', (data) {
      setState(() {
        messages.add(data); // Añade el mensaje en tiempo real a la lista
      });
    });

    socket.onDisconnect((_) {
      setState(() {
        isConnected = false;
      });
      print('[Socket.IO] Desconectado del servidor');
    });
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    // Emitir el mensaje al evento 'new-message' que escucha tu servidor Node.js
    socket.emit('new-message', _messageController.text.trim());
    _messageController.clear();
  }

  @override
  void dispose() {
    socket.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isConnected ? 'EcoHome Chat (En línea)' : 'EcoHome Chat (Conectando...)'),
        backgroundColor: isConnected ? Colors.green.shade700 : Colors.orange.shade700,
      ),
      body: Column(
        children: [
          // Lista de mensajes en tiempo real
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
          // Caja de texto para redactar el mensaje
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