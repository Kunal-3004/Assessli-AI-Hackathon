import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:audioplayers/audioplayers.dart';
import 'package:deepgram_speech_to_text/deepgram_speech_to_text.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';
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

  final Dio _dio = Dio();
  late SpeechToText _speechToText;
  late bool _speechEnabled;
  String _lastWords = '';
  late String onStatus;
  final player = AudioPlayer();

  late String sessionId;
  String generateRandomString(int len) {
    var r = Random();
    const chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
    return List.generate(len, (index) => chars[r.nextInt(chars.length)]).join();
  }

  clearChat(){
    setState(() {
      _messages.clear();
      _messages.add(
        Message(
          text: "Hi! I'm your AI assistant. How can I help you today?",
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
      sessionId = generateRandomString(10);
    });
  }

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      _showWelcomeDialog(context);
    });

    _speechToText = SpeechToText();
    _speechEnabled = false;

    sessionId = generateRandomString(10);

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

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _typingAnimationController.dispose();
    _buttonAnimationController.dispose();
    if (_speechToText.isListening) {
      _speechToText.stop();
    }
    player.dispose();
    super.dispose();
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

  void _handleSubmitted(String text,{bool voice=false}) {
    print("Handling submit: '$text'");
    if (text.trim().isEmpty) return;
    _textController.clear();
    setState(() {
      _messages.add(Message(text: text, isUser: true, timestamp: DateTime.now()));
      _isTyping = true;
    });
    _scrollToBottom();

    _generateResponse(text,voice: voice).then((response) async {

      if (voice) {
        Deepgram deepgramTTS = Deepgram(
            '70dc0c5e148d3a77b8c245985613b03562154c33',
            baseQueryParams: {
              'model': 'aura-asteria-en',
              'encoding': "linear16",
              'container': "wav",
            }
        );

        final res = await deepgramTTS.speak.text(response);
        await player.play(BytesSource(res.data!));
      }

      setState(() {
        _isTyping = false;
        _messages.add(Message(
          text: response,
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      _scrollToBottom();
    });
  }

  bool _isListening = false;
  Future<void> _handleMicPressed() async {
    if (_isListening) return;

    setState(() {
      _isListening = true;
      _lastWords = '';
    });

    Timer? timeoutTimer;
    bool dialogClosed = false;

    if (!_speechEnabled) {
      _speechEnabled = await _speechToText.initialize(
        onStatus: (val) => print('Status: $val'),
        onError: (val) => print('Error: $val'),
      );
    }

    if (!_speechEnabled) {
      setState(() => _isListening = false);
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        String tempTranscript = '';
        return StatefulBuilder(
          builder: (context, setStateDialog) {

            _speechToText.listen(
              onResult: (val) {
                if (val.recognizedWords != tempTranscript) {
                  tempTranscript = val.recognizedWords;
                  setStateDialog(() => _lastWords = val.recognizedWords);
                }

                if (val.finalResult && _lastWords.trim().isNotEmpty && !dialogClosed) {
                  dialogClosed = true;
                  timeoutTimer?.cancel();
                  _handleSubmitted(_lastWords, voice: true);
                  Navigator.pop(context);
                }
              },
              cancelOnError: true,
              listenMode: ListenMode.confirmation,
              listenFor: const Duration(seconds: 10),
              partialResults: true,
            );

            timeoutTimer = Timer(const Duration(seconds: 10), () {
              if (!dialogClosed) {
                dialogClosed = true;
                _speechToText.stop();
                Navigator.pop(context);
              }
            });

            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(15),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75,
                        maxHeight: MediaQuery.of(context).size.height * 0.4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Lottie.asset('assets/anim.json'),
                          Text(
                            _lastWords.isNotEmpty
                                ? _lastWords
                                : ('Listening...'),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 20,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      timeoutTimer?.cancel();
      if (_speechToText.isListening) {
        _speechToText.stop().then((_) {
          print('Speech recognition stopped');
        });
      }
      setState(() => _isListening = false);
    });
  }

  Future<String> _generateResponse(String msg,{bool voice=false}) async {
    try {
      print("Generating response for: '$msg'");
      final response = await _dio.post(
        'http://10.233.159.48:5002/chat',
        data: jsonEncode({'input': msg, 'session_id': sessionId}),
        options: Options(
          contentType: Headers.jsonContentType,
          responseType: ResponseType.json,
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      print("Response received: ${response.data}");

      if (response.statusCode == 200) {

        return response.data['output'] ?? "No response received";
      } else {
        return "Server error: ${response.statusCode}";
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        return "Connection timeout. Please check your network.";
      } else if (e.type == DioExceptionType.receiveTimeout) {
        return "Response timeout. The server is taking too long.";
      } else if (e.response?.statusCode == 500) {
        return e.response?.data['error'] ?? "Server error occurred";
      }
      return "Unable to contact the server";
    } catch (e) {
      return "Unexpected error: $e";
    }
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
                Text('Assessli AI', style: TextStyle(color: Colors.white, fontSize: 18)),
                Text('Online', style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
              ],
            )
          ],
        ),
        actions: [
          Builder(
            builder: (ctx) => IconButton(
              icon: Icon(Icons.more_vert, color: Colors.white),
              onPressed: () {
                if (_popupEntry != null) {
                  _popupEntry?.remove();
                  _popupEntry = null;
                } else {
                  _showClassicPopupOverlay(ctx,clearChat);
                }
              },
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
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
      ),
    );
  }
}
OverlayEntry? _popupEntry;

void _showClassicPopupOverlay(BuildContext context,VoidCallback clearChat) {
  _popupEntry = OverlayEntry(
    builder: (context) {
      return Positioned(
        top: kToolbarHeight + 5,
        right: 12,
        child: Material(
          elevation: 10,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 200,
            padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(2, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.account_circle, color: Colors.blueAccent),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'user@example.com',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Divider(color: Colors.grey.shade300),
                GestureDetector(
                  onTap: () async {
                    clearChat();
                  },
                  child: Row(
                    children: [
                      Icon(Icons.chat_bubble_outline, color: Colors.grey.shade800),
                      SizedBox(width: 10),
                      Text("New Chat", style: TextStyle(fontSize: 15)),
                    ],
                  ),
                ),
                SizedBox(height: 10),
                GestureDetector(
                  onTap: () async {
                    _popupEntry?.remove();
                    _popupEntry = null;

                    final prefs = await SharedPreferences.getInstance();
                    await prefs.clear();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => ChatScreen()),
                    );
                  },
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.red),
                      SizedBox(width: 10),
                      Text("Log out", style: TextStyle(fontSize: 15)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Overlay.of(context).insert(_popupEntry!);
}




