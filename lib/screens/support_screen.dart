import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../account/identity.dart';
import '../config.dart';

/// صفحة المساعدة والدعم: تعريف سريع ونموذج يصل إلى ورقة «الدعم» في جدول Google.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  static const _types = ['استفسار', 'اقتراح', 'مشكلة في التطبيق'];

  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _message = TextEditingController();
  String _type = _types.first;
  bool _busy = false;
  String? _error;
  bool _sent = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() { _busy = true; _error = null; });
    try {
      final uri = Uri.parse(MosqueConfig.donorsUrl).replace(queryParameters: {
        'action': 'support',
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'type': _type,
        'message': _message.text.trim(),
        ...await Identity.instance.params(),
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 20));
      // النسخة القديمة من السكربت لا تعرف «support» وترجع قائمة المتبرعين دون حفظ الرسالة.
      if (res.statusCode != 200 || !res.body.contains('"ok":true')) {
        throw Exception('not saved');
      }
      if (mounted) {
        setState(() { _sent = true; _busy = false; });
        _name.clear(); _phone.clear(); _message.clear();
      }
    } catch (_) {
      if (mounted) setState(() { _busy = false; _error = 'تعذّر الإرسال. تحقّق من الإنترنت وأعد المحاولة.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSend = _name.text.trim().isNotEmpty && _message.text.trim().isNotEmpty && !_busy;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(MosqueConfig.name, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text('المساعدة والدعم', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'أوقات الأذان والقرآن تعمل بدون إنترنت. الاستماع للقرآن وقائمة المتبرعين يحتاجان إنترنت.\n'
              'إن لم يصلك تنبيه الأذان، اسمح للتطبيق بالإشعارات والتنبيهات الدقيقة من إعدادات الهاتف.',
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'الاسم'),
          onChanged: (_) => setState(() { _sent = false; }),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'رقم الهاتف (اختياري)'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _type,
          items: [for (final t in _types) DropdownMenuItem(value: t, child: Text(t))],
          onChanged: (v) => setState(() => _type = v!),
          decoration: const InputDecoration(labelText: 'نوع الرسالة'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _message,
          maxLines: 5,
          maxLength: 500,
          decoration: const InputDecoration(labelText: 'رسالتك'),
          onChanged: (_) => setState(() { _sent = false; }),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        if (_sent)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('وصلت رسالتك، جزاك الله خيرًا. تجد الرد في «حسابي» (الأيقونة أعلى الشاشة).'),
          ),
        const SizedBox(height: 12),
        FilledButton(onPressed: canSend ? _send : null, child: const Text('إرسال')),
      ],
    );
  }
}
