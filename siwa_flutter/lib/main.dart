import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_signin_button/button_list.dart';
import 'package:flutter_signin_button/button_view.dart';
import 'package:nonce/nonce.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:simple_logger/simple_logger.dart';

final logger = SimpleLogger()
  ..setLevel(
    Level.ALL,
    includeCallerInfo: true,
  );

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.from(
        colorScheme: const ColorScheme.light(),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  var _signedIn = false;
  String? _id;
  String? _email;
  String? _name;

  @override
  void initState() {
    super.initState();
    _updateUserInfo();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign in with Apple'),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _signedIn
                ? ElevatedButton(
                    onPressed: _signOut,
                    child: const Text('Sign out'),
                  )
                : SignInButton(
                    Buttons.AppleDark,
                    onPressed: _signIn,
                  ),
            ListTile(
              title: Text(_id ?? '-'),
              subtitle: const Text('ID'),
            ),
            ListTile(
              title: Text(_email ?? '-'),
              subtitle: const Text('Email'),
            ),
            ListTile(
              title: Text(_name ?? '-'),
              subtitle: const Text('Name'),
            ),
          ],
        ),
      ),
    );
  }

  void _updateUserInfo() {
    final user = FirebaseAuth.instance.currentUser;
    setState(() {
      _signedIn = user != null;
      _id = user?.uid;
      _email = user?.email;
      _name = user?.displayName;
    });
  }

  Future<void> _signIn() async {
    try {
      final rawNonce = Nonce.generate();
      final state = Nonce.generate();
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        webAuthenticationOptions: WebAuthenticationOptions(
          clientId: 'com.mono0926.siwa.service',
          redirectUri: Uri.parse(
            'https://us-central1-mono-firebase.cloudfunctions.net/siwa',
          ),
        ),
        nonce: sha256.convert(utf8.encode(rawNonce)).toString(),
        state: state,
      );
      logger.info(appleCredential);
      if (state != appleCredential.state) {
        throw AssertionError('state not matched!');
      }
      final credential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
        rawNonce: rawNonce,
      );
      final auth = FirebaseAuth.instance;
      final userCredential = await auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (appleCredential.givenName != null && user != null) {
        await user.updateDisplayName(
          '${appleCredential.givenName} ${appleCredential.familyName}',
        );
      }
      _updateUserInfo();
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        logger.info('cancelled');
        return;
      }
      rethrow;
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    _updateUserInfo();
  }
}
