import 'dart:ui';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../GoogleDriveHelper.dart';
import '../model/message.dart';
import '../widgets/BuildMessage.dart';
import '../widgets/BuildOptionCard.dart';
import '../widgets/MessageInput.dart';
import '../widgets/TypingIndicator.dart';
import '../widgets/appColors.dart';
import 'Login.dart';
import 'SignUp.dart';

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final List<Message> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;
  bool _hasText = false;

  late AnimationController _typingAnimationController;
  late Animation<double> _typingAnimation;
  late AnimationController _buttonAnimationController;
  late Animation<double> _buttonAnimation;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      _showWelcomeDialog(context);
    });

    _typingAnimationController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _typingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _typingAnimationController, curve: Curves.easeInOut),
    );

    _buttonAnimationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );

    _buttonAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _buttonAnimationController, curve: Curves.easeInOut),
    );

    _textController.addListener(_onTextChanged);

    _messages.add(
      Message(
        text: "Hi! I'm your AI assistant. How can I help you today?",
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> _pickImageFromGallery() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _messages.add(
          Message(
            imagePath: pickedFile.path,
            isUser: true,
            timestamp: DateTime.now(),
          ),
        );
      });
      _scrollToBottom();
    }
  }

  void _showWelcomeDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.all(24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Welcome back",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      "Log in or sign up to get smarter responses, upload files and images, and more.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                    SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        _navigateToLogin();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        minimumSize: Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: Text("Log in"),
                    ),
                    SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () {
                        _navigateToSignup();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white70),
                        minimumSize: Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: Text("Sign up for free"),
                    ),
                    SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        "Stay logged out",
                        style: TextStyle(color: Colors.white60),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _navigateToLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }

  void _navigateToSignup() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SignUpScreen()),
    );
  }

  void _onTextChanged() {
    final hasText = _textController.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
      hasText ? _buttonAnimationController.forward() : _buttonAnimationController.reverse();
    }
  }

  void _pickLocalFile() => _pickImageFromGallery();
  void _pickFromOneDrive() => _showNotImplemented("OneDrive");

  void _showNotImplemented(String source) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text("$source picker not implemented yet."),
      backgroundColor: Colors.grey[800],
    ));
  }

  void _pickFromGoogleDrive() async {
    try {
      final driveHelper = GoogleDriveHelper();
      final files = await driveHelper.pickDriveFiles();

      if (files.isNotEmpty) {
        final selectedFile = files.first;
        setState(() {
          _messages.add(
            Message(
              text: "Picked from Google Drive:\n${selectedFile.name}\n${selectedFile.webViewLink}",
              isUser: true,
              timestamp: DateTime.now(),
            ),
          );
        });
      } else {
        _showSnack("No files found.");
      }
    } catch (e) {
      _showSnack("Failed to pick file: $e");
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.redAccent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _showAttachmentOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (context) {
        return Container(
          padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
                margin: EdgeInsets.only(bottom: 20),
              ),
              Text(
                "Attach From",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OptionCard(
                    icon: Icons.insert_drive_file,
                    label: "Files / Photos",
                    onTap: () {
                      Navigator.pop(context);
                      _pickLocalFile();
                    },
                  ),
                  OptionCard(
                    icon: Icons.cloud_download,
                    label: "Google Drive",
                    onTap: () {
                      Navigator.pop(context);
                      _pickFromGoogleDrive();
                    },
                  ),
                  OptionCard(
                    icon: Icons.cloud_upload,
                    label: "OneDrive",
                    onTap: () {
                      Navigator.pop(context);
                      _pickFromOneDrive();
                    },
                  ),
                ],
              ),
              SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _handleSubmitted(String text) {
    if (text.trim().isEmpty) return;
    _textController.clear();
    setState(() {
      _messages.add(Message(text: text, isUser: true, timestamp: DateTime.now()));
      _isTyping = true;
    });
    _scrollToBottom();

    Future.delayed(Duration(milliseconds: 1200 + (text.length * 50)), () {
      setState(() {
        _isTyping = false;
        _messages.add(Message(
          text: _generateResponse(text),
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      _scrollToBottom();
    });
  }

  void _handleMicPressed() {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Voice input feature coming soon!'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _generateResponse(String msg) {
    final responses = [
      "I am watching Porn videos of Cumtozz."
      "That's an interesting question! Let me think about that.",
      "I see. Here's what I know about it.",
      "Let me help you with that.",
      "I'm here for your queries. Let's go!",
      "Thanks for asking. Let me answer that.",
    ];
    return responses[DateTime.now().millisecond % responses.length];
  }

  void _scrollToBottom() {
    Future.delayed(Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundGradient[0],
      appBar: AppBar(
        backgroundColor: AppColors.backgroundGradient[1],
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: AppColors.botGradient),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.smart_toy_outlined, color: Colors.white),
            ),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AGENT AI', style: TextStyle(color: Colors.white, fontSize: 18)),
                Text('Online', style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
              ],
            )
          ],
        ),
        actions: [Icon(Icons.more_vert, color: Colors.white)],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: Image.asset(AppColors.backgroundImage, fit: BoxFit.cover)),
          Positioned.fill(child: Container(color: Colors.black.withOpacity(0.6))),
          Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.all(16),
                  itemCount: _messages.length + (_isTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (_isTyping && index == _messages.length) {
                      return TypingIndicator(animation: _typingAnimation);

                    }
                    return ChatBubble(message: _messages[index]);
                  },
                ),
              ),
              MessageInputBar(
                controller: _textController,
                hasText: _hasText,
                buttonAnimation: _buttonAnimation,
                onMicTap: _handleMicPressed,
                onSendTap: () => _handleSubmitted(_textController.text),
                onAttachTap: () => _showAttachmentOptions(context),
                onSubmitted: _handleSubmitted,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
