import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:flutter_clipboard_manager/flutter_clipboard_manager.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PassMass',
      theme: ThemeData(        
        primarySwatch: Colors.lime,        
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(title: 'PassMass'),
    );
  }
}

class MyHomePage extends StatefulWidget {  
  MyHomePage({Key key, this.title}) : super(key: key);  
  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final minPassphraseLen = 8;
  final passphraseStoreKey = 'passphrase';

  String _hostName = '';
  String _password = '';  
  BuildContext context;

  StreamSubscription _intentDataStreamSubscription;
  List<SharedMediaFile> _sharedFiles;
  Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  void initState() {
    super.initState();
    
    // For sharing or opening urls/text coming from outside the app while the app is in the memory
    _intentDataStreamSubscription =
      ReceiveSharingIntent.getTextStream().listen((String value) {
      restorePassphrase().then((passphrase) {
        if(passphrase == null || passphrase == '') {
          _showErrorToast('please set your master passphrase first');
          return;
        }

        String url = value ?? '';
        String hostName = _getHostName(url);
        String password = _genPassword(value, hostName);
        _saveToClipboard(password);
        _showMessageToast('password is copied to clipboard');
        setState(() {
          _hostName = hostName;
          _password = password;
        });        
      });
    }, onError: (err) {
      _showErrorToast(err);      
    });

    // For sharing or opening urls/text coming from outside the app while the app is closed
    ReceiveSharingIntent.getInitialText().then((String value) {
      restorePassphrase().then((passphrase) {
        if(passphrase == null || passphrase == '') {
          _showErrorToast('please set your master passphrase first');
          return;
        }

        String url = value ?? '';
        String hostName = _getHostName(url);
        String password = _genPassword(value, hostName);
        _saveToClipboard(password);
        setState(() {
          _hostName = hostName;
          _password = password;
        });
      });
    });
  }

  void _showErrorToast(String msg) {    
    Scaffold.of(context).showSnackBar(SnackBar(
      backgroundColor: Colors.redAccent,
      content: Text(msg)
    ));
  }

  void _showMessageToast(String msg) {    
    Scaffold.of(context).showSnackBar(SnackBar(
      backgroundColor: Colors.green,
      content: Text(msg)
    ));
  }

  String _getHostName(String url) {
    var uri = Uri.parse(url);    
    return uri.host;
  }

  void _saveToClipboard(String text) {
    FlutterClipboardManager.copyToClipBoard(text).then((result) {
      if(result){
        _showMessageToast('password copied into clipboard');
      }
    }).catchError((err) {
      _showErrorToast(err);
    });
  }

  String _genPassword(String passphrase, String hostname) {
    var key = utf8.encode(passphrase);
    var bytes = utf8.encode(hostname);

    var hmacSha256 = new Hmac(sha256, key); // HMAC-SHA256
    var digest = hmacSha256.convert(bytes);

    return digest.toString();
  }

  void _showDialog() {    
    var textField = DialogTextField(hintText: 'set your master passphrase here', obscureText: true);
    showTextInputDialog(context: this.context, textFields: [textField]).then((List<String> res) {
      if(res == null || res.length <= 0) {
        _showErrorToast('invalid passphrse, change rejected');
        return;
      }

      if(res[0].length < minPassphraseLen) {
        _showErrorToast('passphrse length must be at least $minPassphraseLen characters, change rejected');
        return;
      }

      storePassphrase(res[0]);
    });  
  }

  Future<void> storePassphrase(String passphrase) async {
    final SharedPreferences prefs = await _prefs;
    prefs.setString(passphraseStoreKey, passphrase)
    .then((value) {
      _showMessageToast('passphrase set successfully');
      setState(() {
      });
    })
    .catchError((err) => _showErrorToast('failed to set passphrase'));   
  }

  Future<String> restorePassphrase() async {
    final SharedPreferences prefs = await _prefs;
    return prefs.getString(passphraseStoreKey);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(        
        title: Text(widget.title),
      ),
      body: Builder(
        builder: (BuildContext context) {
          this.context = context;
          return Center(
            child: Column(        
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(_hostName, style: TextStyle(
                  fontSize: 30
                ),),
                // Text(_password)              
              ],
            ),
          );
        }
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showDialog,
        tooltip: 'set passphrase',
        child: Icon(Icons.fingerprint),
      ),
    );
  }
}