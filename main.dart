import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:encrypt/encrypt.dart';

// ---------- MAIN ----------
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(LifeLockApp());
}

// ---------- APP ----------
class LifeLockApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LIFELOCK',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: HomeScreen(),
    );
  }
}

// ---------- HOME ----------
class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    FirebaseAuth.instance.signInAnonymously();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("LIFELOCK")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              child: Text("Secure Chat"),
              onPressed: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => ChatScreen()));
              },
            ),
            ElevatedButton(
              child: Text("Personal Diary"),
              onPressed: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => DiaryScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- ENCRYPTION ----------
class CryptoService {
  static final key =
      Key.fromUtf8("32charslongsecretkey123456789012");
  static final iv = IV.fromLength(16);
  static final encrypter = Encrypter(AES(key));

  static String encryptText(String text) {
    return encrypter.encrypt(text, iv: iv).base64;
  }

  static String decryptText(String text) {
    return encrypter.decrypt64(text, iv: iv);
  }
}

// ---------- CHAT ----------
class ChatScreen extends StatefulWidget {
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  TextEditingController controller = TextEditingController();
  final uid = FirebaseAuth.instance.currentUser!.uid;

  void sendMessage() async {
    if (controller.text.isEmpty) return;
    await FirebaseFirestore.instance.collection("messages").add({
      "uid": uid,
      "text": CryptoService.encryptText(controller.text),
      "time": FieldValue.serverTimestamp(),
    });
    controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Encrypted Chat")),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance
                  .collection("messages")
                  .orderBy("time", descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
                return ListView(
                  reverse: true,
                  children: snapshot.data!.docs.map((doc) {
                    return ListTile(
                      title: Text(
                        CryptoService.decryptText(doc["text"]),
                      ),
                      subtitle: Text(doc["uid"]),
                    );
                  }).toList(),
                );
              },
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(hintText: "Type message"),
                ),
              ),
              IconButton(
                icon: Icon(Icons.send),
                onPressed: sendMessage,
              )
            ],
          )
        ],
      ),
    );
  }
}

// ---------- DIARY ----------
class DiaryScreen extends StatefulWidget {
  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  TextEditingController diaryController = TextEditingController();
  final uid = FirebaseAuth.instance.currentUser!.uid;

  void saveDiary() async {
    await FirebaseFirestore.instance
        .collection("diary")
        .doc(uid)
        .set({
      "note": CryptoService.encryptText(diaryController.text),
      "time": FieldValue.serverTimestamp(),
    });
    diaryController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Personal Diary")),
      body: Column(
        children: [
          TextField(
            controller: diaryController,
            maxLines: 5,
            decoration: InputDecoration(
                hintText: "Write your private memory"),
          ),
          ElevatedButton(
            onPressed: saveDiary,
            child: Text("Save"),
          ),
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance
                  .collection("diary")
                  .doc(uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || !snapshot.data!.exists)
                  return Text("No diary saved");
                return Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    CryptoService.decryptText(snapshot.data!["note"]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
