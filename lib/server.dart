import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:rabbit_server/websocket_data.dart';
import 'package:usbcan_plugins/usbcan.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'motor.dart';
import 'package:network_info_plus/network_info_plus.dart';

class WebSocketServer {
  UsbCan usbCan = UsbCan();
  final StreamController<String> _statusOutput = StreamController<String>();
  Future<HttpServer>? _server;
  final List<WebSocketChannel> _channels = [];
  final StreamController<Map> _statusServeStream = StreamController<Map>();
  late Timer _updateTimer;

  List<double> _motorPositions = List.filled(6, 0);
  bool _isUpdate = false;

  final List<Motor> motors = const [
    Motor(0x01 << 2, "Front Left", mode: MotorMode.position),
    Motor(0x02 << 2, "Front Right", mode: MotorMode.position),
    Motor(0x03 << 2, "Rear Left", mode: MotorMode.position, direction: false),
    Motor(0x04 << 2, "Rear Right", mode: MotorMode.position, direction: false),
    Motor(
      0x05 << 2,
      "Lift 1",
      mode: MotorMode.interlockPosition,
      interlockGroupId: 1,
      direction: false,
    ),
    Motor(
      0x06 << 2,
      "Lift 2",
      mode: MotorMode.interlockPosition,
      interlockGroupId: 1,
      direction: false,
    ),
  ];

  Stream<String> get stream => _statusOutput.stream;

  WebSocketServer() {
    var handler = webSocketHandler((channel) {
      _channels.add(channel);
      channel.stream.listen((message) async {
        _statusOutput.add(message);
        var decoded = jsonDecode(message);
        if (decoded["type"] == DataTypes.buttons.index) {
          var data = decoded["data"];
          if (data == "ActivateAll") {
            _motorPositions = List.filled(6, 0);
            for (var motor in motors) {
              motor.motorActivate(usbCan);
              await Future.delayed(const Duration(milliseconds: 10));
            }
          } else if (data == "StopAll") {
            usbCan.sendFrame(
                CANFrame.fromIdAndData(0x00, Uint8List.fromList([0x00])));
          } else if (data == "LiftReset") {
            _liftReset();
          } else if (data == "ConnectionReflesh") {
            _connectionrefrash();
          }
        }
        if (decoded["type"] == DataTypes.motorRotation.index) {
          _motorPositions = (decoded["data"] as List).cast<double>();
          _isUpdate = true;
        }
      });
    });
    final info = NetworkInfo();
    info.getWifiIP().then((value) {
      value ??= "0.0.0.0";
      _server = shelf_io.serve(handler, InternetAddress(value), 8080);
      _server?.then((server) {
        _statusOutput
            .add('Serving at ws://${server.address.host}:${server.port}');
      });
    });

    _statusServeStream.stream.listen((event) {
      for (var element in _channels) {
        if (element.closeReason == null) {
          element.sink.add(jsonEncode(event));
        } else {
          _channels.remove(element);
        }
      }
    });
    usbCan.connectUSB();
    usbCan.stream.listen(_serveMotorStatus);

    _updateTimer = Timer.periodic(const Duration(milliseconds: 10), (_) {
      if (!_isUpdate) {
        return;
      }
      for (int i = 0; i < 6; i++) {
        _sendTaget(motors[i], _motorPositions[i]);
      }
    });
  }

  void dispose() {
    _statusOutput.close();
    _updateTimer.cancel();
  }

  void _serveMotorStatus(CANFrame frame) {
    var motor =
        motors.where((element) => element.canBaseId == frame.canId).first;
    _statusOutput.add(
        "${motor.discription} ${frame.data[0]} ${frame.data[1]} ${frame.data[2]} ${frame.data[3]}");
    _statusServeStream.add(getFormattedData(
        DataTypes.motorModeChenge, [motor.mode, motor.direction]));
  }

  void _connectionrefrash() async {
    await usbCan.device?.port?.close();
    usbCan = UsbCan();
    usbCan.connectUSB();
  }

  void _sendTaget(Motor motor, double target) {
    usbCan.sendFrame(
        CANFrame.fromIdAndData(motor.canBaseId, _toUint8List(target)));
  }

  Uint8List _toUint8List(double value) {
    var buffer = Float32List(1);
    buffer[0] = value;
    return buffer.buffer.asUint8List(0, 4);
  }

  void _liftReset() {
    //stop lift
    usbCan.sendFrame(CANFrame.fromIdAndData(
        motors[4].canBaseId + 1, Uint8List.fromList([0])));
    usbCan.sendFrame(CANFrame.fromIdAndData(
        motors[5].canBaseId + 1, Uint8List.fromList([0])));
    _motorPositions[4] = 0;
    _motorPositions[5] = 0;

    motors[4].motorActivate(usbCan);
    motors[5].motorActivate(usbCan);
  }
}
