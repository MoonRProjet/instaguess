import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.purple, brightness: Brightness.dark, useMaterial3: true),
      home: HomeScreen(),
    ));
  } catch (e) {
    runApp(MaterialApp(home: Scaffold(body: Center(child: Text("Erreur Firebase : $e")))));
  }
}

// --- 1. ACCUEIL ---
class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("📸 InstaGuess", style: TextStyle(fontSize: 45, fontWeight: FontWeight.bold, color: Colors.purpleAccent)),
            SizedBox(height: 60),
            ElevatedButton.icon(
              icon: Icon(Icons.lock, color: Colors.white),
              style: ElevatedButton.styleFrom(minimumSize: Size(280, 60), backgroundColor: Colors.purpleAccent),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => LinkManager())),
              label: Text("MON COFFRE-FORT", style: TextStyle(color: Colors.white)),
            ),
            SizedBox(height: 20),
            ElevatedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => CreateRoom())), child: Text("CRÉER UN SALON")),
            SizedBox(height: 10),
            OutlinedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => JoinRoom())), child: Text("REJOINDRE")),
          ],
        ),
      ),
    );
  }
}

// --- 2. COFFRE-FORT (Version Cliquable) ---
class LinkManager extends StatefulWidget {
  @override
  _LinkManagerState createState() => _LinkManagerState();
}

class _LinkManagerState extends State<LinkManager> {
  List<String> myLinks = [];
  final TextEditingController _ctrl = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }
  
  void _load() async { 
    SharedPreferences p = await SharedPreferences.getInstance(); 
    setState(() => myLinks = p.getStringList('saved_reels') ?? []); 
  }
  
  void _save() async { 
    SharedPreferences p = await SharedPreferences.getInstance(); 
    p.setStringList('saved_reels', myLinks); 
  }

  // Fonction pour ouvrir le lien
  Future<void> _launchReel(String urlString) async {
    final Uri url = Uri.parse(urlString);
    // mode: LaunchMode.externalApplication permet d'ouvrir directement l'app Instagram
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Impossible d'ouvrir ce lien"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Mes Reels")),
      body: Column(children: [
        Padding(padding: EdgeInsets.all(10), child: Row(children: [
          Expanded(child: TextField(controller: _ctrl, decoration: InputDecoration(hintText: "Lien Instagram"))),
          IconButton(
            icon: Icon(Icons.add, color: Colors.green), 
            onPressed: () { 
              if(_ctrl.text.contains("insta")) { 
                setState(() => myLinks.add(_ctrl.text.trim())); 
                _ctrl.clear(); 
                _save(); 
              } 
            }
          )
        ])),
        Expanded(
          child: ListView.builder(
            itemCount: myLinks.length, 
            itemBuilder: (c, i) => ListTile(
              leading: Icon(Icons.play_circle_fill, color: Colors.purpleAccent),
              title: Text("Reel ${i+1}", style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(myLinks[i], maxLines: 1, overflow: TextOverflow.ellipsis),
              // --- ACTION CLIC ---
              onTap: () => _launchReel(myLinks[i]),
              // ------------------
              trailing: IconButton(
                icon: Icon(Icons.delete, color: Colors.red), 
                onPressed: () { 
                  setState(() => myLinks.removeAt(i)); 
                  _save(); 
                }
              )
            )
          )
        )
      ]),
    );
  }
}

// --- 3. CRÉATION DE SALON (VUE HÔTE) ---
class CreateRoom extends StatefulWidget {
  @override
  _CreateRoomState createState() => _CreateRoomState();
}

class _CreateRoomState extends State<CreateRoom> {
  String? code;
  final TextEditingController _name = TextEditingController();
  bool hostJoined = false;

  void _create() async {
    String c = List.generate(4, (i) => 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'[Random().nextInt(32)]).join();
    await FirebaseFirestore.instance.collection('rooms').doc(c).set({'status': 'waiting', 'videoLimit': 3, 'currentVideoIndex': 0, 'votesCount': 0, 'officialPlaylist': []});
    setState(() => code = c);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Créer un Salon")),
      body: Center(child: code == null 
        ? ElevatedButton(onPressed: _create, child: Text("GÉNÉRER CODE")) 
        : Padding(
            padding: EdgeInsets.all(20),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text("CODE : $code", style: TextStyle(fontSize: 50, color: Colors.purpleAccent, fontWeight: FontWeight.bold)),
              if (!hostJoined) ...[
                TextField(controller: _name, decoration: InputDecoration(labelText: "Ton Pseudo")),
                ElevatedButton(onPressed: () async {
                  SharedPreferences p = await SharedPreferences.getInstance();
                  List<String> links = (p.getStringList('saved_reels') ?? []).take(3).toList();
                  await FirebaseFirestore.instance.collection('rooms').doc(code).collection('players').doc(_name.text).set({'name': _name.text, 'urls': links, 'score': 0});
                  setState(() => hostJoined = true);
                }, child: Text("REJOINDRE MON SALON")),
              ] else ...[
                Text("Joueurs connectés :", style: TextStyle(fontSize: 18, color: Colors.grey)),
                Expanded(child: PlayersList(roomCode: code!)),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: Size(double.infinity, 50)),
                  onPressed: () async {
                    var players = await FirebaseFirestore.instance.collection('rooms').doc(code).collection('players').get();
                    List<Map<String, dynamic>> playlist = [];
                    for (var d in players.docs) { for (var u in d['urls']) { playlist.add({'name': d['name'], 'url': u}); } }
                    playlist.shuffle();
                    await FirebaseFirestore.instance.collection('rooms').doc(code).update({'status': 'playing', 'officialPlaylist': playlist});
                    Navigator.push(context, MaterialPageRoute(builder: (c) => GameScreen(roomCode: code!, myName: _name.text)));
                  }, 
                  child: Text("LANCER LA PARTIE", style: TextStyle(color: Colors.white))
                ),
              ]
            ]),
          )
      ),
    );
  }
}

// --- 4. REJOINDRE SALON (VUE INVITÉ) ---
class JoinRoom extends StatefulWidget {
  @override
  _JoinRoomState createState() => _JoinRoomState();
}

class _JoinRoomState extends State<JoinRoom> {
  final TextEditingController _c = TextEditingController();
  final TextEditingController _n = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Rejoindre")),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          TextField(controller: _c, decoration: InputDecoration(labelText: "Code")),
          TextField(controller: _n, decoration: InputDecoration(labelText: "Pseudo")),
          SizedBox(height: 20),
          ElevatedButton(onPressed: () async {
            String code = _c.text.toUpperCase();
            var room = await FirebaseFirestore.instance.collection('rooms').doc(code).get();
            if (!room.exists) return;
            SharedPreferences p = await SharedPreferences.getInstance();
            List<String> links = (p.getStringList('saved_reels') ?? []).take(3).toList();
            await FirebaseFirestore.instance.collection('rooms').doc(code).collection('players').doc(_n.text).set({'name': _n.text, 'urls': links, 'score': 0});
            Navigator.push(context, MaterialPageRoute(builder: (c) => WaitingScreen(roomCode: code, myName: _n.text)));
          }, child: Text("REJOINDRE LE GROUPE"))
        ]),
      ),
    );
  }
}

// --- 5. SALLE D'ATTENTE (VUE INVITÉ) ---
class WaitingScreen extends StatelessWidget {
  final String roomCode, myName;
  WaitingScreen({required this.roomCode, required this.myName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Salle d'attente")),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('rooms').doc(roomCode).snapshots(),
        builder: (context, snap) {
          if (snap.hasData && snap.data!['status'] == 'playing') {
            Future.delayed(Duration.zero, () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => GameScreen(roomCode: roomCode, myName: myName))));
          }
          return Column(children: [
            SizedBox(height: 30),
            Text("Salon : $roomCode", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text("Attente de l'hôte...", style: TextStyle(color: Colors.amber)),
            Divider(height: 40),
            Expanded(child: PlayersList(roomCode: roomCode)),
          ]);
        },
      ),
    );
  }
}

// --- COMPOSANT : LISTE DES JOUEURS ---
class PlayersList extends StatelessWidget {
  final String roomCode;
  PlayersList({required this.roomCode});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('rooms').doc(roomCode).collection('players').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
        return ListView(
          children: snapshot.data!.docs.map((d) => ListTile(
            leading: Icon(Icons.person, color: Colors.purpleAccent),
            title: Text(d['name'], style: TextStyle(fontSize: 18)),
            trailing: Icon(Icons.check_circle, color: Colors.green),
          )).toList(),
        );
      },
    );
  }
}

// --- 6. ÉCRAN DE JEU ---
class GameScreen extends StatefulWidget {
  final String roomCode, myName;
  GameScreen({required this.roomCode, required this.myName});
  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  WebViewController? _controller;
  bool hasVoted = false;

  void _load(String url) {
    String clean = url.split('?').first;
    if (!clean.endsWith('/')) clean += '/';
    _controller?.loadRequest(Uri.parse("${clean}embed/"));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('rooms').doc(widget.roomCode).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Scaffold(body: Center(child: CircularProgressIndicator()));
        var data = snapshot.data!;
        List playlist = data['officialPlaylist'];
        int idx = data['currentVideoIndex'];

        if (idx >= playlist.length) return ScoreBoard(roomCode: widget.roomCode);

        if (_controller == null) {
          _controller = WebViewController()..setJavaScriptMode(JavaScriptMode.unrestricted)..setUserAgent("Mozilla/5.0")..setBackgroundColor(Colors.black);
          _load(playlist[idx]['url']);
        }

        return Scaffold(
          appBar: AppBar(title: Text("Vidéos ${idx + 1}/${playlist.length}")),
          body: Column(children: [
            Expanded(child: WebViewWidget(controller: _controller!)),
            Padding(padding: EdgeInsets.all(10), child: Text("À QUI EST CE REEL ?", style: TextStyle(fontWeight: FontWeight.bold))),
            Wrap(alignment: WrapAlignment.center, children: playlist.map((p) => p['name'] as String).toSet().map((name) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: hasVoted ? Colors.grey : Colors.purple),
                onPressed: hasVoted ? null : () async {
                  setState(() => hasVoted = true);
                  if (name == playlist[idx]['name']) {
                    await FirebaseFirestore.instance.collection('rooms').doc(widget.roomCode).collection('players').doc(widget.myName).update({'score': FieldValue.increment(1)});
                  }
                  await FirebaseFirestore.instance.collection('rooms').doc(widget.roomCode).update({'votesCount': FieldValue.increment(1)});
                },
                child: Text(name),
              ),
            )).toList()),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('rooms').doc(widget.roomCode).collection('players').snapshots(),
              builder: (c, pSnap) {
                int count = pSnap.data?.docs.length ?? 1;
                if (data['votesCount'] >= count) {
                  Future.delayed(Duration(seconds: 2), () {
                    if (idx < playlist.length) {
                      FirebaseFirestore.instance.collection('rooms').doc(widget.roomCode).update({'currentVideoIndex': idx + 1, 'votesCount': 0});
                      _controller = null; setState(() => hasVoted = false);
                    }
                  });
                }
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text("Votes : ${data['votesCount']} / $count", style: TextStyle(color: Colors.amber)),
                );
              },
            )
          ]),
        );
      },
    );
  }
}

// --- 7. SCOREBOARD ---
class ScoreBoard extends StatelessWidget {
  final String roomCode;
  ScoreBoard({required this.roomCode});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("🏆 CLASSEMENT FINAL"), automaticallyImplyLeading: false),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('rooms').doc(roomCode).collection('players').orderBy('score', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
          var players = snapshot.data!.docs;
          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: players.length,
                  itemBuilder: (c, i) => ListTile(
                    leading: Text("${i + 1}", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    title: Text(players[i]['name'], style: TextStyle(fontSize: 20)),
                    trailing: Text("${players[i]['score']} pts", style: TextStyle(fontSize: 20, color: Colors.amber)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(30.0),
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                  child: Text("RETOURNER AU MENU"),
                  style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50)),
                ),
              )
            ],
          );
        },
      ),
    );
  }
}