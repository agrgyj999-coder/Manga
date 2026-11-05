import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/ocr_service.dart';
import '../services/translation_service.dart';

class OverlayItem {
  OverlayItem(this.source, this.rect);

  final String source;
  final Rect rect;
  String translation = '';
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _picker = ImagePicker();
  final _translation = TranslationService();
  final _boundaryKey = GlobalKey();

  File? _photo;
  Size? _photoSize;

  final List<OverlayItem> _items = [];

  bool _busy = false;
  String? _status;
  String _lang = 'ja';

  final _scripts = <String, TextRecognitionScript>{
    'ja': TextRecognitionScript.japanese,
    'en': TextRecognitionScript.latin,
    'ko': TextRecognitionScript.korean,
    'zh-CN': TextRecognitionScript.chinese,
  };

  @override
  void dispose() {
    _translation.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
    );

    if (x == null) return;

    final decoded = img.decodeImage(
      await File(x.path).readAsBytes(),
    );

    if (decoded == null) {
      setState(() => _status = 'تصویر قابل خواندن نیست.');
      return;
    }

    setState(() {
      _photo = File(x.path);
      _photoSize = Size(
        decoded.width.toDouble(),
        decoded.height.toDouble(),
      );
      _items.clear();
      _status = 'عکس آماده است؛ تشخیص و ترجمه را بزن.';
    });
  }

  Future<void> _translateImage() async {
    if (_photo == null) {
      setState(() => _status = 'اول یک عکس انتخاب کن.');
      return;
    }

    setState(() {
      _busy = true;
      _status = 'در حال تشخیص متن...';
      _items.clear();
    });

    OcrService? ocr;

    try {
      ocr = OcrService(script: _scripts[_lang]!);

      final blocks = await ocr.recognize(_photo!.path);

      await ocr.dispose();
      ocr = null;

      if (blocks.isEmpty) {
        setState(() {
          _status = 'متنی پیدا نشد؛ زبان یا وضوح عکس را بررسی کن.';
        });
        return;
      }

      setState(() {
        _items.addAll(
          blocks.map(
            (b) => OverlayItem(
              b.text,
              Rect.fromLTRB(
                b.left,
                b.top,
                b.right,
                b.bottom,
              ),
            ),
          ),
        );

        _status = '${_items.length} بخش پیدا شد؛ ترجمه شروع شد...';
      });

      for (var i = 0; i < _items.length; i++) {
        final translated = await _translation.translate(
          _items[i].source,
          _lang,
        );

        if (!mounted) return;

        setState(() {
          _items[i].translation = translated;
          _status = 'ترجمه ${i + 1} از ${_items.length}';
        });

        await Future<void>.delayed(
          const Duration(milliseconds: 250),
        );
      }

      setState(() {
        _status = 'تمام شد! برای ویرایش، روی بخش ترجمه‌شده بزن.';
      });
    } catch (e) {
      setState(() {
        _status =
            'خطا: ${e.toString().replaceFirst('Exception: ', '')}';
      });
    } finally {
      await ocr?.dispose();

      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  int? _hit(Offset p, Size size) {
    if (_photoSize == null) return null;

    final s = math.min(
      size.width / _photoSize!.width,
      size.height / _photoSize!.height,
    );

    final dx = (size.width - _photoSize!.width * s) / 2;
    final dy = (size.height - _photoSize!.height * s) / 2;

    for (var i = _items.length - 1; i >= 0; i--) {
      final r = _items[i].rect;

      final mapped = Rect.fromLTRB(
        r.left * s + dx,
        r.top * s + dy,
        r.right * s + dx,
        r.bottom * s + dy,
      ).inflate(14);

      if (mapped.contains(p)) return i;
    }

    return null;
  }

  void _edit(int i) {
    final c = TextEditingController(
      text: _items[i].translation,
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          20,
          18,
          MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'ویرایش ترجمه',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: c,
              minLines: 2,
              maxLines: 5,
              textDirection: TextDirection.rtl,
              decoration: const InputDecoration(
                hintText: 'متن فارسی...',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                setState(() {
                  _items[i].translation = c.text;
                });
                Navigator.pop(ctx);
              },
              child: const Text('ذخیره'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _export() async {
    final boundary = _boundaryKey.currentContext
        ?.findRenderObject() as RenderRepaintBoundary?;

    if (boundary == null || _items.isEmpty) {
      setState(() => _status = 'اول عکس را ترجمه کن.');
      return;
    }

    try {
      final image = await boundary.toImage(pixelRatio: 3);

      final data = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (data == null) {
        throw Exception('ساخت تصویر ناموفق بود');
      }

      final dir = await getTemporaryDirectory();

      final file = File(
        '${dir.path}/manga_translation_${DateTime.now().millisecondsSinceEpoch}.png',
      );

      await file.writeAsBytes(
        data.buffer.asUint8List(),
      );

      await Share.shareXFiles(
        [
          XFile(
            file.path,
            mimeType: 'image/png',
          ),
        ],
        text: 'MangaTranslate',
      );
    } catch (e) {
      setState(() {
        _status = 'خروجی ناموفق بود: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MangaTranslate'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF30234B),
                    Color(0xFF1C1B2B),
                  ],
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ترجمه روی خود تصویر',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'عکس را انتخاب کن؛ نوشته‌ها تشخیص داده و ترجمه فارسی روی همان عکس نمایش داده می‌شوند.',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            FilledButton.icon(
              onPressed: _busy ? null : _pick,
              icon: const Icon(Icons.photo_library),
              label: const Text('انتخاب عکس مانگا'),
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              initialValue: _lang,
              decoration: const InputDecoration(
                labelText: 'زبان متن اصلی',
              ),
              items: const [
                DropdownMenuItem(
                  value: 'ja',
                  child: Text('ژاپنی'),
                ),
                DropdownMenuItem(
                  value: 'en',
                  child: Text('انگلیسی'),
                ),
                DropdownMenuItem(
                  value: 'ko',
                  child: Text('کره‌ای'),
                ),
                DropdownMenuItem(
                  value: 'zh-CN',
                  child: Text('چینی ساده‌شده'),
                ),
              ],
              onChanged: _busy
                  ? null
                  : (v) {
                      setState(() {
                        _lang = v ?? 'ja';
                      });
                    },
            ),

            const SizedBox(height: 12),

            FilledButton.tonalIcon(
              onPressed: _busy ? null : _translateImage,
              icon: const Icon(Icons.translate),
              label: const Text('تشخیص و ترجمه رایگان'),
            ),

            const SizedBox(height: 14),

            if (_photo != null && _photoSize != null)
              RepaintBoundary(
                key: _boundaryKey,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio:
                        _photoSize!.width / _photoSize!.height,
                    child: LayoutBuilder(
                      builder: (ctx, c) => Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(
                            _photo!,
                            fit: BoxFit.fill,
                          ),
                          if (_items.any(
                            (x) => x.translation.isNotEmpty,
                          ))
                            CustomPaint(
                              painter: TranslationPainter(
                                sourceSize: _photoSize!,
                                items: _items,
                              ),
                            ),
                          if (_items.isNotEmpty)
                            GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTapUp: (d) {
                                final i = _hit(
                                  d.localPosition,
                                  c.biggest,
                                );

                                if (i != null) _edit(i);
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else
              Container(
                height: 190,
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1B25),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text('پیش‌نمایش تصویر مانگا'),
                ),
              ),

            if (_items.isNotEmpty) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy ? null : _export,
                icon: const Icon(Icons.ios_share),
                label: const Text('خروجی تصویر ترجمه‌شده'),
              ),
              const Text(
                'برای اصلاح ترجمه روی متن آن در تصویر بزن.',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                ),
              ),
            ],

            if (_status != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _status!,
                  style: const TextStyle(
                    color: Color(0xFFCEB9FF),
                  ),
                ),
              ),

            if (_busy)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(),
              ),

            const SizedBox(height: 20),

            const Text(
              'ترجمه با سرویس عمومی MyMemory انجام می‌شود؛ اینترنت لازم است و سهمیه رایگان محدود است. متن OCR برای ترجمه به سرویس بیرونی ارسال می‌شود.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TranslationPainter extends CustomPainter {
  TranslationPainter({
    required this.sourceSize,
    required this.items,
  });

  final Size sourceSize;
  final List<OverlayItem> items;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(
      size.width / sourceSize.width,
      size.height / sourceSize.height,
    );

    final dx = (size.width - sourceSize.width * s) / 2;
    final dy = (size.height - sourceSize.height * s) / 2;

    final paint = Paint()
      ..color = const Color(0xFFFEFEFE);

    for (final item in items) {
      if (item.translation.trim().isEmpty) continue;

      final r = item.rect;

      final original = Rect.fromLTRB(
        r.left * s + dx,
        r.top * s + dy,
        r.right * s + dx,
        r.bottom * s + dy,
      );

      final w = math.min(
        size.width,
        math.max(original.width * 1.45, 48.0),
      );

      final h = math.max(
        original.height * 2.0,
        26.0,
      );

      final left = (original.center.dx - w / 2)
          .clamp(0.0, size.width - w);

      final top = (original.center.dy - h / 2)
          .clamp(0.0, size.height - h);

      final patch = Rect.fromLTWH(
        left,
        top,
        w,
        h,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          patch,
          const Radius.circular(3),
        ),
        paint,
      );

      final tp = TextPainter(
        text: TextSpan(
          text: item.translation,
          style: TextStyle(
            color: Colors.black,
            fontSize: (h * 0.48).clamp(9.0, 23.0),
            height: 1.05,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.center,
        maxLines: 4,
        ellipsis: '…',
      )..layout(
          maxWidth: math.max(10, patch.width - 6),
        );

      tp.paint(
        canvas,
        Offset(
          patch.center.dx - tp.width / 2,
          patch.center.dy - tp.height / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant TranslationPainter old,
  ) {
    return true;
  }
}
