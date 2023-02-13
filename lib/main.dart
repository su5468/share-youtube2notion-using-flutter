import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

// action.SEND in flutter

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  TextEditingController _notionKeyController = TextEditingController();
  TextEditingController _DBIDController = TextEditingController();
  String _notionKey = '';
  String _DBID = '';
  String _url = '';
  String _title = '';
  String _author = '';
  String t = 'test';

  late StreamSubscription _intentDataStreamSubscription;

  @override
  void initState() {
    super.initState();
    _loadSP();

    // For sharing or opening urls/text coming from outside the app while the app is in the memory
    _intentDataStreamSubscription =
        ReceiveSharingIntent.getTextStream().listen((String value) {
      setState(() {
        _url = value;
        _shareLink(_url);
      });
    }, onError: (err) {
      print("getLinkStream error: $err");
    });

    // For sharing or opening urls/text coming from outside the app while the app is closed
    ReceiveSharingIntent.getInitialText().then((String? value) {
      setState(() {
        _url = value ?? '';
        _shareLink(_url);
      });
    });
  }

  @override
  void dispose() {
    _intentDataStreamSubscription.cancel();
    super.dispose();
  }

  _loadSP() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _notionKeyController =
          TextEditingController(text: prefs.getString('notionKey'));
      _DBIDController = TextEditingController(text: prefs.getString('DBID'));
      _notionKey = (prefs.getString('notionKey') ?? '');
      _DBID = (prefs.getString('DBID') ?? '');
    });
  }

  _shareLink(url) async {
    http.Response response = await http.get(Uri.parse(url));
    String txt = response.body;
    String title =
        txt.substring(txt.indexOf("<title>") + 7, txt.indexOf(" - YouTube"));

    int aut_start = txt.indexOf('<link itemprop="name"') + 31;
    String author = txt.substring(aut_start, txt.indexOf('">', aut_start));
    setState(() {
      _author = author;
      _title = title;
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String key = prefs.getString('notionKey') ?? '';
    String dbid = prefs.getString('DBID') ?? '';
    try {
      http.Response response = await http.post(
        Uri.https('api.notion.com', '/v1/pages'),
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Authorization': 'Bearer ' + key,
          'Content-Type': 'application/json',
          'Notion-Version': '2021-08-16',
          'Accept': '*/*'
        },
        body: jsonEncode({
          'parent': {'database_id': dbid},
          'properties': {
            'title': {
              'title': [
                {
                  'text': {'content': title}
                },
              ],
            },
            '채널': {
              'rich_text': [
                {
                  'text': {'content': author}
                }
              ]
            },
            '주소': {'url': url},
          }
        }),
      );

      setState(() {
        t = '${response.statusCode}, ${response.body}';
      });

      return response;
    } catch (e) {
      print(e.toString());

      setState(() {
        t = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Share Text into Notion'),
        ),
        body: Center(
          child: Column(
            children: [
              Text('${t} ${_url} ${_title} ${_author}'),
              Padding(
                child: TextField(
                  controller: _notionKeyController,
                  decoration: InputDecoration(
                    labelText: 'Notion Key',
                  ),
                ),
                padding: EdgeInsets.fromLTRB(20.0, 0.0, 20.0, 10.0),
              ),
              Padding(
                child: TextField(
                  controller: _DBIDController,
                  decoration: InputDecoration(
                    labelText: 'Database ID',
                  ),
                ),
                padding: EdgeInsets.fromLTRB(20.0, 0.0, 20.0, 10.0),
              ),
              OutlinedButton(
                onPressed: () async {
                  SharedPreferences prefs =
                      await SharedPreferences.getInstance();
                  _notionKey = _notionKeyController.text;
                  _DBID = _DBIDController.text;
                  prefs.setString('notionKey', _notionKey);
                  prefs.setString('DBID', _DBID);
                },
                child: Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
