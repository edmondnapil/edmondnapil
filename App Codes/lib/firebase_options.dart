import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are only defined for Android in this project.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDKWE0HZvYdxNVNf2NdWU27yamX7yFvwK4',
    appId: '1:366913547770:android:09bd18dae26c3be1050843',
    messagingSenderId: '366913547770',
    projectId: 'fashion-accesories',
    storageBucket: 'Fashion-accesories.appspot.com',
  );
}