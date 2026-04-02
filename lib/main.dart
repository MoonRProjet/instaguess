import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';

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

// --- 2. COFFRE-FORT (Version Cliquable + Différent Dossiers) ---
class LinkManager extends StatefulWidget {
  @override
  _LinkManagerState createState() => _LinkManagerState();
}

class _LinkManagerState extends State<LinkManager> {
  // Structure : {"Humour": ["lien1", "lien2"], "Foot": ["lien3"]}
  Map<String, List<String>> folders = {"Général": []};
  String currentFolder = "Général";
  final TextEditingController _linkCtrl = TextEditingController();
  final TextEditingController _folderCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _loadData(); }

  // CHARGEMENT : On transforme le texte JSON en Map
  void _loadData() async {
    SharedPreferences p = await SharedPreferences.getInstance();
    String? jsonStr = p.getString('folders_data');
    if (jsonStr != null) {
      Map<String, dynamic> decoded = jsonDecode(jsonStr);
      setState(() {
        folders = decoded.map((key, value) => MapEntry(key, List<String>.from(value)));
      });
    }
  }

  // SAUVEGARDE : On transforme la Map en texte JSON
  void _saveData() async {
    SharedPreferences p = await SharedPreferences.getInstance();
    await p.setString('folders_data', jsonEncode(folders));
  }

  void _addFolder() {
    if (_folderCtrl.text.isNotEmpty && !folders.containsKey(_folderCtrl.text)) {
      setState(() {
        folders[_folderCtrl.text] = [];
        _folderCtrl.clear();
      });
      _saveData();
    }
  }

  @override
  Widget build(BuildContext context) {
    List<String> myLinks = folders[currentFolder] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text("Coffre : $currentFolder"),
        actions: [
          IconButton(
            icon: Icon(Icons.create_new_folder),
            onPressed: () => _showFolderDialog(),
          )
        ],
      ),
      body: Column(children: [
        // 1. Sélecteur de Dossier (Barre horizontale)
        Container(
          height: 50,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: folders.keys.map((name) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: ChoiceChip(
                label: Text(name),
                selected: currentFolder == name,
                onSelected: (s) => setState(() => currentFolder = name),
              ),
            )).toList(),
          ),
        ),
        
        // 2. Ajout de lien
        Padding(padding: EdgeInsets.all(10), child: Row(children: [
          Expanded(child: TextField(controller: _linkCtrl, decoration: InputDecoration(hintText: "Lien Instagram"))),
          IconButton(icon: Icon(Icons.add, color: Colors.green), onPressed: () {
            if (_linkCtrl.text.contains("insta")) {
              setState(() { folders[currentFolder]!.add(_linkCtrl.text.trim()); _linkCtrl.clear(); });
              _saveData();
            }
          })
        ])),

        // 3. Liste des liens du dossier actuel
        Expanded(
          child: ListView.builder(
            itemCount: myLinks.length,
            itemBuilder: (c, i) => ListTile(
              leading: Icon(Icons.play_circle_fill, color: Colors.purpleAccent),
              title: Text("Reel ${i+1}"),
              subtitle: Text(myLinks[i], maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => launchUrl(Uri.parse(myLinks[i]), mode: LaunchMode.externalApplication),
              trailing: IconButton(icon: Icon(Icons.delete, color: Colors.red), onPressed: () {
                setState(() => folders[currentFolder]!.removeAt(i));
                _saveData();
              }),
            ),
          ),
        )
      ]),
    );
  }

  void _showFolderDialog() {
    showDialog(context: context, builder: (c) => AlertDialog(
      title: Text("Nouveau Dossier"),
      content: TextField(controller: _folderCtrl, decoration: InputDecoration(hintText: "Nom (ex: Humour)")),
      actions: [TextButton(onPressed: () { _addFolder(); Navigator.pop(c); }, child: Text("Créer"))],
    ));
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
  
  // Nouveaux champs pour les dossiers
  Map<String, List<String>> myFolders = {};
  String? selectedFolder;

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  void _loadFolders() async {
    var f = await getFolders();
    setState(() {
      myFolders = f;
      selectedFolder = f.keys.first;
    });
  }

  void _create() async {
    String c = List.generate(4, (i) => 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'[Random().nextInt(32)]).join();
    await FirebaseFirestore.instance.collection('rooms').doc(c).set({
      'status': 'waiting',
      'videoLimit': 3,
      'currentVideoIndex': 0,
      'votesCount': 0,
      'officialPlaylist': []
    });
    setState(() => code = c);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Créer un Salon")),
      body: Center(
        child: code == null 
        ? ElevatedButton(onPressed: _create, child: Text("GÉNÉRER CODE")) 
        : Padding(
            padding: EdgeInsets.all(20),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text("CODE : $code", style: TextStyle(fontSize: 50, color: Colors.purpleAccent, fontWeight: FontWeight.bold)),
              if (!hostJoined) ...[
                // MENU DÉROULANT POUR CHOISIR LE DOSSIER
                DropdownButton<String>(
                  value: selectedFolder,
                  isExpanded: true,
                  items: myFolders.keys.map((f) => DropdownMenuItem(value: f, child: Text("Dossier : $f"))).toList(),
                  onChanged: (v) => setState(() => selectedFolder = v),
                ),
                TextField(controller: _name, decoration: InputDecoration(labelText: "Ton Pseudo")),
                ElevatedButton(onPressed: () async {
                  if (_name.text.isEmpty) return;
                  
                  // On récupère les liens du dossier choisi et on en prend 3 au hasard
                  List<String> links = List.from(myFolders[selectedFolder!] ?? []);
                  links.shuffle();
                  
                  await FirebaseFirestore.instance.collection('rooms').doc(code).collection('players').doc(_name.text).set({
                    'name': _name.text, 
                    'urls': links.take(3).toList(), 
                    'score': 0
                  });
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
                    for (var d in players.docs) { 
                      for (var u in d['urls']) { 
                        playlist.add({'name': d['name'], 'url': u}); 
                      } 
                    }
                    playlist.shuffle();
                    await FirebaseFirestore.instance.collection('rooms').doc(code).update({
                      'status': 'playing', 
                      'officialPlaylist': playlist
                    });
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
  
  // Nouveaux champs pour les dossiers
  Map<String, List<String>> myFolders = {};
  String? selectedFolder;

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  void _loadFolders() async {
    var f = await getFolders();
    setState(() {
      myFolders = f;
      selectedFolder = f.keys.first;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Rejoindre")),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          TextField(controller: _c, decoration: InputDecoration(labelText: "Code")),
          TextField(controller: _n, decoration: InputDecoration(labelText: "Pseudo")),
          SizedBox(height: 10),
          
          // MENU DÉROULANT POUR L'INVITÉ
          if (myFolders.isNotEmpty)
            DropdownButton<String>(
              value: selectedFolder,
              isExpanded: true,
              items: myFolders.keys.map((f) => DropdownMenuItem(value: f, child: Text("Dossier : $f"))).toList(),
              onChanged: (v) => setState(() => selectedFolder = v),
            ),
            
          SizedBox(height: 20),
          ElevatedButton(onPressed: () async {
            String code = _c.text.toUpperCase();
            String pseudo = _n.text.trim();
            if (code.isEmpty || pseudo.isEmpty) return;

            var room = await FirebaseFirestore.instance.collection('rooms').doc(code).get();
            if (!room.exists) {
               ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Salon introuvable")));
               return;
            }

            // On récupère les liens du dossier sélectionné
            List<String> links = List.from(myFolders[selectedFolder!] ?? []);
            links.shuffle();

            await FirebaseFirestore.instance.collection('rooms').doc(code).collection('players').doc(pseudo).set({
              'name': pseudo, 
              'urls': links.take(3).toList(), 
              'score': 0
            });
            
            Navigator.push(context, MaterialPageRoute(builder: (c) => WaitingScreen(roomCode: code, myName: pseudo)));
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

Future<Map<String, List<String>>> getFolders() async {
  SharedPreferences p = await SharedPreferences.getInstance();
  String? jsonStr = p.getString('folders_data');
  if (jsonStr != null) {
    Map<String, dynamic> decoded = jsonDecode(jsonStr);
    return decoded.map((k, v) => MapEntry(k, List<String>.from(v)));
  }
  // Si l'utilisateur n'a pas encore créé de dossiers, on récupère ses anciens liens
  List<String> oldLinks = p.getStringList('saved_reels') ?? [];
  return {"Général": oldLinks};
}