import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:rabbit_server/server.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'websocket_data.dart';

void main() {
  runApp(const MainApp());
}

@immutable
class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  final WebSocketServer _server = WebSocketServer();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        home: Scaffold(
      appBar: AppBar(
        title: const Text('Rabbit ServerSide App'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            MainPage(stream: _server.stream),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => {
          setState(
            () {},
          )
        },
        child: const Icon(Icons.refresh),
      ),
    ));
  }
}

@immutable
class MainPage extends StatefulWidget {
  const MainPage({super.key, required this.stream});
  final Stream<dynamic> stream;

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  String _text = "No Data";
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: widget.stream,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            _text = snapshot.data.toString();
          }
          return Text(_text);
        });
  }
}
