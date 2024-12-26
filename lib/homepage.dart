import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final Gemini gemini = Gemini.instance;
  final TextEditingController _commandController = TextEditingController();
  final FlutterTts flutterTts = FlutterTts();
  final SpeechToText _speechToText = SpeechToText();
  late AnimationController _floatingButtonController;
  bool _isSpeaking = false;
  bool _isListening = false;
  bool _isDarkMode = true;
  String? _selectedLanguage;

  List<ChatMessage> messages = [];
  List<String> conversationHistory = [];

  ChatUser currentUser = ChatUser(
    id: "0",
    profileImage:
        "https://img.freepik.com/free-psd/3d-illustration-human-avatar-profile_23-2150671116.jpg",
  );

  ChatUser geminiUser = ChatUser(
    id: "1",
    profileImage:
        "https://img.freepik.com/free-photo/close-up-metallic-robot_23-2151113108.jpg",
  );

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
    _loadConversationHistory();
    _initializeSpeech();
    _floatingButtonController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _floatingButtonController.dispose();
    super.dispose();
  }

  Future<void> _initializeSpeech() async {
    await _speechToText.initialize();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? true;
    });
  }

  Future<void> _toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = !_isDarkMode;
      prefs.setBool('isDarkMode', _isDarkMode);
    });
  }

  Future<void> _loadConversationHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      conversationHistory = prefs.getStringList('chatHistory') ?? [];
      // Convert history to messages
      messages = conversationHistory.map((String messageStr) {
        final parts = messageStr.split('|');
        return ChatMessage(
          text: parts[1],
          user: parts[0] == '0' ? currentUser : geminiUser,
          createdAt: DateTime.now(),
        );
      }).toList();
    });
  }

  Future<void> _saveConversationHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final history =
        messages.map((msg) => '${msg.user.id}|${msg.text}').toList();
    await prefs.setStringList('chatHistory', history);
  }

  Future<void> _exportChat() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/chat_export.txt');

    String export = messages
        .map((msg) => '${msg.user.id == '0' ? 'You' : 'AI'}: ${msg.text}\n')
        .join('\n');

    await file.writeAsString(export);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Chat exported to ${file.path}')),
    );
  }

  Future<void> _speakMessage(String message) async {
    if (_isSpeaking) {
      await flutterTts.stop();
      setState(() => _isSpeaking = false);
      return;
    }

    setState(() => _isSpeaking = true);
    await flutterTts.setLanguage(_selectedLanguage ?? 'en-US');
    await flutterTts.speak(message);
    flutterTts.setCompletionHandler(() {
      setState(() => _isSpeaking = false);
    });
  }

  Future<void> _startListening() async {
    if (!_isListening) {
      bool available = await _speechToText.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speechToText.listen(
          onResult: (result) {
            if (result.finalResult) {
              _sendMessage(ChatMessage(
                text: result.recognizedWords,
                user: currentUser,
                createdAt: DateTime.now(),
              ));
              setState(() => _isListening = false);
            }
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      _speechToText.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        backgroundColor: _isDarkMode
            ? Colors.black.withOpacity(0.7)
            : Colors.white.withOpacity(0.7),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              color: _isDarkMode ? Colors.indigo[300] : Colors.indigo,
              size: 28,
            ),
            SizedBox(width: 10),
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: _isDarkMode
                    ? [Colors.indigo[300]!, Colors.white]
                    : [Colors.indigo, Colors.indigo[800]!],
              ).createShader(bounds),
              child: Text(
                "ChatterBox",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                  fontSize: 24,
                ),
              ),
            ),
          ],
        ),
        actions: [
          Theme(
            data: Theme.of(context).copyWith(
              popupMenuTheme: PopupMenuThemeData(
                color: _isDarkMode ? Colors.grey[900] : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
            child: PopupMenuButton(
              icon: Icon(
                Icons.more_vert,
                color: _isDarkMode ? Colors.white : Colors.black,
              ),
              itemBuilder: (context) => [
                PopupMenuItem(
                  child: ListTile(
                    leading: Icon(
                      _isDarkMode ? Icons.light_mode : Icons.dark_mode,
                      color: _isDarkMode ? Colors.white : Colors.black,
                    ),
                    title: Text(
                      'Toggle Theme',
                      style: TextStyle(
                        color: _isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  onTap: _toggleTheme,
                ),
                PopupMenuItem(
                  child: ListTile(
                    leading: Icon(
                      Icons.download,
                      color: _isDarkMode ? Colors.white : Colors.black,
                    ),
                    title: Text(
                      'Export Chat',
                      style: TextStyle(
                        color: _isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  onTap: _exportChat,
                ),
                PopupMenuItem(
                  child: ListTile(
                    leading: Icon(
                      Icons.delete,
                      color: _isDarkMode ? Colors.white : Colors.black,
                    ),
                    title: Text(
                      'Clear History',
                      style: TextStyle(
                        color: _isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  onTap: () async {
                    setState(() => messages.clear());
                    await _saveConversationHistory();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _isDarkMode
                ? [
                    Colors.black,
                    Colors.indigo[900]!.withOpacity(0.8),
                    Colors.black87,
                  ]
                : [
                    Colors.white,
                    Colors.indigo[50]!,
                    Colors.white70,
                  ],
          ),
        ),
        child: _buildUI(),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ScaleTransition(
            scale: Tween<double>(begin: 0, end: 1).animate(
              CurvedAnimation(
                parent: _floatingButtonController,
                curve: Curves.easeOut,
              ),
            ),
            child: FloatingActionButton(
              heroTag: "speech",
              onPressed: () => _startListening(),
              child: Icon(_isListening ? Icons.mic_off : Icons.mic),
              backgroundColor: _isListening
                  ? Colors.red.withOpacity(0.9)
                  : Colors.indigo.withOpacity(0.9),
              elevation: 4,
            ),
          ),
          SizedBox(height: 16),
          ScaleTransition(
            scale: Tween<double>(begin: 0, end: 1).animate(
              CurvedAnimation(
                parent: _floatingButtonController,
                curve: Curves.easeOut,
              ),
            ),
            child: FloatingActionButton(
              heroTag: "tts",
              onPressed: () => messages.isNotEmpty
                  ? _speakMessage(messages.first.text)
                  : null,
              child: Icon(_isSpeaking ? Icons.stop : Icons.volume_up),
              backgroundColor: Colors.indigo.withOpacity(0.9),
              elevation: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUI() {
    return DashChat(
      messageOptions: MessageOptions(
        currentUserContainerColor:
            _isDarkMode ? Colors.indigo.withOpacity(0.7) : Colors.indigo[100],
        currentUserTextColor: _isDarkMode ? Colors.white : Colors.black87,
        showCurrentUserAvatar: true,
        borderRadius: 20,
        containerColor: _isDarkMode
            ? Colors.grey[900]!.withOpacity(0.7)
            : Colors.white.withOpacity(0.9),
        textColor: _isDarkMode ? Colors.white : Colors.black87,
        messagePadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        messageDecorationBuilder: (message, previousMessage, nextMessage) {
          return BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 5,
                offset: Offset(0, 2),
              ),
            ],
          );
        },
        messageTextBuilder: (message, previousMessage, nextMessage) {
          return Text(
            message.text,
            style: TextStyle(
              color: message.user.id == currentUser.id
                  ? (_isDarkMode ? Colors.white : Colors.black87)
                  : (_isDarkMode ? Colors.lightBlueAccent : Colors.indigo[700]),
              fontSize: 16,
              height: 1.4,
            ),
          );
        },
      ),
      inputOptions: InputOptions(
        inputDecoration: InputDecoration(
          hintText: 'Type a message...',
          hintStyle: TextStyle(
            color: _isDarkMode ? Colors.white60 : Colors.black54,
            fontFamily: 'Poppins',
            fontSize: 17,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(
              color: _isDarkMode ? Colors.white24 : Colors.black12,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(
              color: _isDarkMode ? Colors.white24 : Colors.black12,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(
              color: Colors.indigo,
              width: 2,
            ),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          filled: true,
          fillColor: _isDarkMode
              ? Colors.grey[900]!.withOpacity(0.5)
              : Colors.white.withOpacity(0.9),
        ),
        inputTextStyle: TextStyle(
          color: _isDarkMode ? Colors.white : Colors.black87,
          fontSize: 16,
        ),
        trailing: [
          SizedBox(width: 5),
          Container(
            decoration: BoxDecoration(
              color: Colors.indigo.withOpacity(0.9),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              onPressed: _sendMediaMessage,
              icon: const Icon(
                Icons.image,
                color: Colors.white,
              ),
              tooltip: 'Send an image',
            ),
          ),
        ],
      ),
      currentUser: currentUser,
      onSend: _sendMessage,
      messages: messages,
    );
  }

  void _sendMessage(ChatMessage chatMessage) {
    setState(() {
      messages = [chatMessage, ...messages];
    });
    _saveConversationHistory(); // Save after each message

    try {
      String question = chatMessage.text;
      List<Uint8List>? images;
      if (chatMessage.medias?.isNotEmpty ?? false) {
        images = [
          File(chatMessage.medias!.first.url).readAsBytesSync(),
        ];
      }

      gemini
          .streamGenerateContent(
        question,
        images: images,
      )
          .listen((event) {
        ChatMessage? lastMessage = messages.firstOrNull;
        if (lastMessage != null && lastMessage.user == geminiUser) {
          lastMessage = messages.removeAt(0);
          String response = event.content?.parts?.fold(
                  "", (previous, current) => "$previous ${current.text}") ??
              "";
          lastMessage.text += response;
          setState(() {
            messages = [lastMessage!, ...messages];
          });
        } else {
          String response = event.content?.parts?.fold(
                  "", (previous, current) => "$previous ${current.text}") ??
              "";
          ChatMessage message = ChatMessage(
            user: geminiUser,
            createdAt: DateTime.now(),
            text: response,
          );
          setState(() {
            messages = [message, ...messages];
          });
        }
        _saveConversationHistory(); // Save after AI response
      });
    } catch (e) {
      print(e);
    }
  }

  void _sendMediaMessage() async {
    print("Image button pressed");
    ImagePicker picker = ImagePicker();
    XFile? file = await picker.pickImage(
      source: ImageSource.gallery,
    );
    if (file != null) {
      print("Image selected: ${file.path}");
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            title: Text(
              "Enter Media Command",
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.indigo,
              ),
            ),
            content: TextField(
              controller: _commandController,
              decoration: InputDecoration(
                //filled: true,
                //fillColor: Colors.white24,
                hintText: "Type a command...",
                hintStyle: TextStyle(color: Colors.white),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(),
                ),
              ),
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.black,
            actions: [
              TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  "Send",
                  style: TextStyle(color: Colors.black, fontSize: 16),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  String command = _commandController.text.trim();
                  if (command.isNotEmpty) {
                    ChatMessage chatMessage = ChatMessage(
                      user: currentUser,
                      createdAt: DateTime.now(),
                      text: command,
                      medias: [
                        ChatMedia(
                          url: file.path,
                          fileName: "",
                          type: MediaType.image,
                        )
                      ],
                    );
                    _sendMessage(chatMessage);
                  }
                  _commandController.clear();
                },
              ),
            ],
          );
        },
      );
    } else {
      print("No image selected.");
    }
  }
}
