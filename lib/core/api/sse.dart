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

  // `cast`: dio hands out Stream<Uint8List>, and Dart's stream transform is
  // invariant, so utf8.decoder (a Converter<List<int>, String>) is rejected
  // at runtime without it.
  sub = bytes
      .cast<List<int>>()
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

/// One raw SSE frame: the `event:` name (when present) and the joined `data:`.
class SseFrame {
  const SseFrame(this.event, this.data);
  final String? event;
  final String data;
}

/// Like [parseSse], but keeps the `event:` name.
///
/// The chat stream carries the frame's type there rather than inside the JSON
/// (`event: token` + `data: {"text":"…"}`), so a decoder that only reads
/// `data:` — as [parseSse] does for the vehicle feed — cannot tell a token from
/// a card. Frames are emitted in order; a malformed one is skipped rather than
/// killing the stream, and a body split across chunk boundaries is buffered
/// until its blank line arrives.
Stream<SseFrame> parseSseFrames(Stream<List<int>> bytes) {
  final controller = StreamController<SseFrame>();
  final data = <String>[];
  String? event;
  late StreamSubscription<String> sub;

  void flush() {
    if (data.isEmpty && event == null) return;
    final text = data.join('\n');
    final name = event;
    data.clear();
    event = null;
    if (text.isEmpty && name == null) return;
    if (!controller.isClosed) controller.add(SseFrame(name, text));
  }

  sub = bytes
      .cast<List<int>>()
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen(
    (line) {
      if (line.isEmpty) {
        flush();
      } else if (line.startsWith(':')) {
        // keep-alive comment
      } else if (line.startsWith('data:')) {
        data.add(line.substring(5).trimLeft());
      } else if (line.startsWith('event:')) {
        event = line.substring(6).trim();
      }
      // 'id:' and 'retry:' are ignored.
    },
    onError: controller.addError,
    onDone: () {
      flush();
      controller.close();
    },
    cancelOnError: false,
  );

  controller.onCancel = () => sub.cancel();
  return controller.stream;
}
