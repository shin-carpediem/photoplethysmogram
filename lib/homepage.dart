// ignore_for_file: use_key_in_widget_constructors, prefer_final_fields, prefer_const_constructors
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:photoplethysmogram/main.dart';
import 'package:wakelock/wakelock.dart';
import 'chart.dart';

class HomePage extends StatefulWidget {
  @override
  HomePageView createState() => HomePageView();
}

class HomePageView extends State<HomePage> {
  bool _toggled = false;
  bool _processing = false;
  List<SensorValue> _data = [];
  CameraController _controller = CameraController(
    cameras.first, // 利用可能なカメラの一覧から、指定のカメラを取得。
    // 使用する解像度を設定
    // low : 352x288 on iOS, 240p (320x240) on Android
    // medium : 480p (640x480 on iOS, 720x480 on Android)
    // high : 720p (1280x720)
    // veryHigh : 1080p (1920x1080)
    // ultraHigh : 2160p (3840x2160)
    ResolutionPreset.low, // low : 利用可能な最小の解像度
  ); // デバイスのカメラを制御するコントローラ
  double _alpha = 0.3;
  int _bpm = 0;

  _toggle() {
    _initController().then((onValue) {
      Wakelock.enable();

      setState(() {
        _toggled = true;
        _processing = false;
      });
      _updateBPM();
    });
  }

  _untoggle() {
    _disposeController();
    Wakelock.disable();

    setState(() {
      _toggled = false;
      _processing = false;
    });
  }

  Future<void> _initController() async {
    try {
      // コントローラーに設定されたカメラを初期化。
      await _controller.initialize();
      // カメラのフラッシュをアクティブにしてから、ImageStreamを開始。
      Future.delayed(Duration(microseconds: 500)).then((onValue) {
        // _controller.flash(true);
      });
      _controller.startImageStream((CameraImage image) {
        if (!_processing) {
          setState(() {
            _processing = true;
          });
          _scanImage(image);
        }
      });
    } catch (e) {
      print(e);
    }
  }

  _updateBPM() async {
    List<SensorValue> _values;
    double _avg;
    int _n;
    double _m;
    double _threshold;
    double _bpm;
    int _counter;
    int _previous;

    while (_toggled) {
      _values = List.from(_data);
      _avg = 0;
      _n = _values.length;
      _m = 0;
      for (var value in _values) {
        _avg += value.value / _n;
        if (value.value > _m) _m = value.value;
      }
      _threshold = (_m + _avg) / 2;
      _bpm = 0;
      _counter = 0;
      _previous = 0;

      for (int i = 1; i < _n; i++) {
        if (_values[i - 1].value < _threshold &&
            _values[i].value > _threshold) {
          if (_previous != 0) {
            _counter++;
            _bpm +=
                60000 / (_values[i].time.millisecondsSinceEpoch - _previous);
          }
          _previous = _values[i].time.millisecondsSinceEpoch;
        }
      }

      if (_counter > 0) {
        _bpm = _bpm / _counter;
        setState(() {
          _bpm = (1 - _alpha) * _bpm + _alpha * _bpm;
        });
      }

      await Future.delayed(Duration(milliseconds: (1009 * 50 / 30).round()));
    }
  }

  _scanImage(CameraImage image) {
    double _avg =
        image.planes.first.bytes.reduce((value, element) => value + element) /
            image.planes.first.bytes.length;

    if (_data.length >= 50) {
      _data.removeAt(0);
    }

    setState(() {
      _data.add(SensorValue(DateTime.now(), _avg));
    });
    Future.delayed(Duration(microseconds: 1000 ~/ 30)).then((onvalue) {
      setState(() {
        _processing = false;
      });
    });
  }

  _disposeController() {
    _controller.dispose();
    // _controller = null;
  }

  @override
  void dispose() {
    // ウィジェットが破棄されたタイミングで、カメラのコントローラを破棄。
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Center(
                      child: _controller == null
                          ? Container()
                          : CameraPreview(_controller),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        (_bpm > 30 && _bpm < 150
                            ? _bpm.round().toString()
                            : "--"),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: IconButton(
                  icon: Icon(
                    _toggled ? Icons.favorite : Icons.favorite_border,
                  ),
                  color: Colors.red,
                  iconSize: 128,
                  onPressed: () {
                    if (_toggled) {
                      _untoggle();
                    } else {
                      _toggle();
                    }
                  },
                ),
              ),
            ),
            Expanded(
              child: Container(
                margin: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(
                    Radius.circular(18),
                  ),
                  color: Colors.black,
                ),
                child: Chart(_data),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
