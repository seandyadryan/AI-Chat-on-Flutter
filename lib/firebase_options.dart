import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => android;

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDyap3vqSwYxPhc5xEcp6DRmI336pDMuoY',
    appId: '1:669760327632:android:84b903d4e9e0e25a0433d5',
    messagingSenderId: '669760327632',
    projectId: 'ai-app-flutter-4763f',
    storageBucket: 'ai-app-flutter-4763f.firebasestorage.app',
  );
}
