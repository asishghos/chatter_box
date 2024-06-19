import 'dart:io';
import 'dart:typed_data';

import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:image_picker/image_picker.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Gemini gemini = Gemini.instance;

  List<ChatMessage> messages = [];

  ChatUser currentUser = ChatUser(
      id: "0",
      //firstName: "User",
      profileImage:
          "https://img.freepik.com/free-psd/3d-illustration-human-avatar-profile_23-2150671116.jpg?t=st=1718793649~exp=1718797249~hmac=64391d87178fea36a82917aeffb73f425dc7043efd348cb9f5b39c6a89162139&w=1060");
  ChatUser geminiUser = ChatUser(
    id: "1",
    //firstName: "Gemini",
    profileImage:
        "https://img.freepik.com/free-photo/close-up-metallic-robot_23-2151113108.jpg?t=st=1718793144~exp=1718796744~hmac=c81e773b3840a06902f4874792106e3c7e5920356f997310656f9907c12b5832&w=1060",
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Column(
          children: [
            Row(
              children: [
                Text(
                  "Chatter",
                  style: TextStyle(
                    color: Colors.indigo,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  "Box",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.black,
        elevation: 8,
      ),
      body: Container(
        child: Stack(
          children: [
            // Background
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black, Colors.indigo[900]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            // Chat UI
            _buildUI(),
          ],
        ),
      ),
    );
  }

  Widget _buildUI() {
    return DashChat(
      messageOptions: MessageOptions(
        currentUserContainerColor: Colors.black,
        currentUserTextColor: Colors.white,
        showCurrentUserAvatar: true,
        borderRadius: 20,
        containerColor: Colors.black,
        textColor: Colors.white,
        messagePadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      ),
      inputOptions: InputOptions(
        inputDecoration: InputDecoration(
          filled: true,
          fillColor: Colors.white24,
          hintText: 'Type a message...',
          hintStyle: TextStyle(
            color: Colors.white,
            fontFamily: 'Poppins',
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        ),
        inputTextStyle: TextStyle(color: Colors.white),
        trailing: [
          IconButton(
            onPressed: _sendMediaMessage,
            icon: const Icon(
              Icons.image,
              color: Colors.white,
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
          setState(
            () {
              messages = [lastMessage!, ...messages];
            },
          );
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
      ChatMessage chatMessage = ChatMessage(
        user: currentUser,
        createdAt: DateTime.now(),
        text: "Describe this picture ?",
        medias: [
          ChatMedia(
            url: file.path,
            fileName: "",
            type: MediaType.image,
          )
        ],
      );
      _sendMessage(chatMessage);
    } else {
      print("No image selected.");
    }
  }
}
