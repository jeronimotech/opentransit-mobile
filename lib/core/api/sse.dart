import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

/// Payloads above this size are decoded on a helper isolate so a 6,000-vehicle
/// full frame (~1 MB) does not stall the UI thread.
const int _isolateThresholdBytes = 64 * 1024;

/// Top-level so the closure sent to the isolate captures only [text] (a
/// closure created inside [parseSse] would drag the StreamController along
/// and fail to be sent).
Future<Object?> _decodeOffThread(String text) => Isolate.run(() => jsonDecode(text));

/// Turns a raw byte stream of `text/event-stream` into decoded JSON events.
///
/// Only `data:` lines are used (multi-line data is joined with `\n`);
/// comment lines (`: keep-alive`) and other fields are ignored. Events are
/// delivered in order even when decoding happens off-thread.
Stream<Map<String, dynamic>> parseSse(Stream<List<int>> bytes) {
  final controller = StreamController<Map<String, dynamic>>();
  final data = <String>[];
  var chain = Future<void>.value();
  late StreamSubscription<String> sub;

  Future<void> decode(String text) async {
    try {
      final decoded = text.length > _isolateThresholdBytes
          ? await _decodeOffThread(text)
          : jsonDecode(text);
      if (decoded is Map && !controller.isClosed) {
        controller.add(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      // Malformed frame: skip it rather than killing the stream.
    }
  }

  void flush() {
    if (data.isEmpty) return;
    final text = data.join('\n');
    data.clear();
    chain = chain.then((_) => decode(text));
  }

  sub = bytes
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen(
    (line) {
      if (line.isEmpty) {
        flush();
      } else if (line.startsWith('data:')) {
        data.add(line.substring(5).trimLeft());
      }
      // ':' comments, 'event:', 'id:' and 'retry:' are ignored.
    },
    onError: controller.addError,
    onDone: () {
      flush();
      chain.whenComplete(controller.close);
    },
    cancelOnError: false,
  );

  controller.onCancel = () => sub.cancel();
  return controller.stream;
}
