import 'dart:convert';
import 'package:http/http.dart' as http;

/// Public MyMemory endpoint: no key needed, but subject to free-tier limits.
class TranslationService {
  final http.Client _client = http.Client();
  Future<String> translate(String text, String source) async {
    if (text.trim().isEmpty) return '';
    final uri = Uri.https('api.mymemory.translated.net', '/get',
      {'q': text, 'langpair': '$source|fa'});
    final response = await _client.get(uri).timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) throw Exception('سرویس ترجمه پاسخ نداد (${response.statusCode})');
    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (data['responseStatus'] != 200) throw Exception(data['responseDetails']?.toString() ?? 'خطای ترجمه');
    final result = (data['responseData'] as Map<String, dynamic>?)?['translatedText'];
    if (result is! String || result.trim().isEmpty) throw Exception('ترجمه خالی دریافت شد');
    return result;
  }
  void dispose() => _client.close();
}
