# 📸 InstaGuess

**InstaGuess** est une application mobile de divertissement social développée avec **Flutter** et **Firebase**. Le concept est simple : défiez vos amis dans un jeu de devinettes basé sur vos Reels Instagram préférés.

---

## 🎮 Le Concept
Chaque joueur prépare son "Coffre-fort" de Reels. Une fois dans un salon multi-joueurs, l'application mélange les vidéos de tous les participants. À chaque vidéo diffusée, vous devez deviner : **À qui appartient ce Reel ?**

---

## ✨ Fonctionnalités Actuelles

* **🔒 Coffre-fort Personnel** : Sauvegardez vos pépites Instagram localement sur votre téléphone.
* **🏠 Système de Salons (Lobby)** : Créez ou rejoignez une partie avec un code unique à 4 lettres.
* **⚡ Synchronisation en Temps Réel** : Grâce à Firestore, tous les joueurs voient la même vidéo et les mêmes scores au même moment.
* **🏆 Classement Final** : Un tableau des scores automatique s'affiche à la fin de la playlist pour désigner le vainqueur.
* **🌐 Intégration WebView** : Lecture directe des contenus Instagram via un navigateur embarqué optimisé.

---

## 🛠️ Stack Technique

* **Framework** : [Flutter](https://flutter.dev/) (Dart)
* **Backend** : [Firebase](https://firebase.google.com/)
    * **Firestore** : Gestion des salons, des joueurs et des scores.
    * **Core** : Initialisation et liaison du projet.
* **Stockage Local** : `shared_preferences` pour le coffre-fort.
* **Navigation Web** : `webview_flutter` pour l'affichage des Reels.

---

## 🚀 Installation & Lancement

1.  **Cloner le projet** :
    ```bash
    git clone [https://github.com/](https://github.com/)[TON_PSEUDO]/instaguess.git
    cd instaguess
    ```

2.  **Installer les dépendances** :
    ```bash
    flutter pub get
    ```

3.  **Configuration Firebase** :
    * Ajouter votre fichier `google-services.json` dans `android/app/`.
    * (Optionnel) Ajouter `GoogleService-Info.plist` pour iOS.

4.  **Lancer l'application** :
    ```bash
    flutter run
    ```

---

## 📈 Évolutions à venir (Roadmap)

- [ ] **Multi-Coffres** : Création de dossiers thématiques (Humour, Sport, etc.).
- [ ] **Lecteur MP4 Direct** : Intégration d'une API pour s'affranchir de la connexion Instagram.
- [ ] **Timer** : Ajouter une limite de temps de 15s pour voter.
- [ ] **Liens Cliquables** : Possibilité de prévisualiser ses liens dans le coffre-fort.

---

## 👤 Auteur

* **MoonRiise** - *Développeur Principal* - [@MoonRProjet](https://github.com/MoonRProjet)

---
📦 *Projet réalisé dans le cadre d'un apprentissage sur le développement mobile hybride et le temps réel.*
