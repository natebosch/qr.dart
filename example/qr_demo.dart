import 'dart:async';
import 'dart:html';
import 'dart:math' as math;

import 'package:qr/qr.dart';
import 'package:stream_transform/stream_transform.dart';

import 'src/affine_transform.dart';
import 'src/bot.dart';

void main() {
  final canvas = querySelector('#content') as CanvasElement;
  final typeDiv = querySelector('#type-div') as DivElement;
  final errorDiv = querySelector('#error-div') as DivElement;
  final input = querySelector('#input') as InputElement;

  final inputValues = input.onKeyUp.map((_) => input.value);

  final typeNumbers = _setupTypeNumber(typeDiv);
  final errorCorrectLevels = _setupErrorCorrectLevel(errorDiv);

  final grids = typeNumbers
      .cast<dynamic>()
      .transform(combineLatestAll([errorCorrectLevels, inputValues]))
      .transform(startWith([10, QrErrorCorrectLevel.M, input.value]))
      .transform(asyncMapSample(_calc))
      .transform(tap((_) {
        input.style.background = '';
      }, onError: (error, _) {
        input.style.background = 'red';
        print(error);
      }));

  QrDemo(canvas, grids);
}

Stream<int> _setupTypeNumber(DivElement typeDiv) {
  const _typeRadioIdKey = 'type-value';
  final controller = StreamController<int>.broadcast();
  void _levelClick(Event args) {
    final source = args.target as InputElement;

    final typeNumber = int.parse(source.dataset[_typeRadioIdKey]);
    controller.add(typeNumber);
  }

  for (var i = 1; i <= 10; i++) {
    var radio = InputElement(type: 'radio')
      ..id = 'type_$i'
      ..name = 'type'
      ..onChange.listen(_levelClick)
      ..dataset[_typeRadioIdKey] = i.toString();
    if (i == 10) {
      radio.attributes['checked'] = 'checked';
    }
    typeDiv.children.add(radio);

    var label = LabelElement()
      ..innerHtml = '$i'
      ..htmlFor = radio.id
      ..classes.add('btn');
    typeDiv.children.add(label);
  }
  return controller.stream;
}

Stream<int> _setupErrorCorrectLevel(DivElement errorDiv) {
  const _errorLevelIdKey = 'error-value';
  final controller = StreamController<int>.broadcast();
  void _errorClick(Event args) {
    final source = args.target as InputElement;
    final errorCorrectLevel = int.parse(source.dataset[_errorLevelIdKey]);
    controller.add(errorCorrectLevel);
  }

  for (final v in QrErrorCorrectLevel.levels) {
    var radio = InputElement(type: 'radio')
      ..id = 'error_$v'
      ..name = 'error-level'
      ..onChange.listen(_errorClick)
      ..dataset[_errorLevelIdKey] = v.toString();
    if (v == QrErrorCorrectLevel.M) {
      radio.attributes['checked'] = 'checked';
    }
    errorDiv.children.add(radio);

    var label = LabelElement()
      ..innerHtml = QrErrorCorrectLevel.getName(v)
      ..htmlFor = radio.id
      ..classes.add('btn');
    errorDiv.children.add(label);
  }
  return controller.stream;
}

class QrDemo {
  final BungeeNum _scale;
  final CanvasElement _canvas;
  final CanvasRenderingContext2D _ctx;

  List<bool> _squares;

  bool _frameRequested = false;

  QrDemo(CanvasElement canvas, Stream<List<bool>> grids)
      : _canvas = canvas,
        _ctx = canvas.context2D,
        _scale = BungeeNum(1) {
    _ctx.fillStyle = 'black';

    grids.listen((squares) {
      _squares = squares;
      requestFrame();
    });
  }

  void requestFrame() {
    if (!_frameRequested) {
      _frameRequested = true;
      window.requestAnimationFrame(_onFrame);
    }
  }

  void _onFrame(num highResTime) {
    _frameRequested = false;

    _ctx.clearRect(0, 0, _canvas.width, _canvas.height);

    final size = math.sqrt(_squares.length).toInt();
    final minDimension = math.min(_canvas.width, _canvas.height);
    final scale = minDimension ~/ (1.1 * size);

    _scale.target = scale;

    if (_scale.update()) {
      requestFrame();
    }

    final tx = AffineTransform()
      ..translate(0.5 * _canvas.width, 0.5 * _canvas.height)
      ..scale(_scale.current, _scale.current)
      ..translate(-0.5 * size, -0.5 * size);

    _ctx.save();
    _setTransform(_ctx, tx);

    if (_squares.isNotEmpty) {
      assert(_squares.length == size * size);
      for (var x = 0; x < size; x++) {
        for (var y = 0; y < size; y++) {
          if (_squares[x * size + y]) {
            _ctx.fillRect(x, y, 1, 1);
          }
        }
      }
    }
    _ctx.restore();
  }
}

Future<List<bool>> _calc(List input) async {
  final code = QrCode(input[0] as int, input[1] as int)
    ..addData(input[2] as String)
    ..make();

  final squares = <bool>[];

  for (var x = 0; x < code.moduleCount; x++) {
    for (var y = 0; y < code.moduleCount; y++) {
      squares.add(code.isDark(y, x));
    }
  }

  return squares;
}

void _setTransform(CanvasRenderingContext2D ctx, AffineTransform tx) {
  ctx.setTransform(
      tx.scaleX, tx.shearY, tx.shearX, tx.scaleY, tx.translateX, tx.translateY);
}
