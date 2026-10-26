import 'dart:ui' as ui;

import 'package:adhan/adhan.dart' show Prayer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../launcher.dart';
import '../services/adhan_service.dart';
import '../services/diag_log.dart';
import '../services/prayer_calc.dart';
import '../settings.dart';

/// تشخيص التطبيق: يبيّن لماذا قد لا يصلك الأذان، ويجمع الأخطاء ليسهل إرسالها للدعم.
class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  AdhanPermissions? _perm;
  int? _pending;
  String _lastOk = '—';
  String _sound = '—';
  String _next = '—';
  List<String> _log = const [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final svc = AdhanService.instance;
    AdhanPermissions? perm;
    int? pending;
    try {
      perm = await svc.permissions();
      pending = await svc.pendingCount();
    } catch (e) {
      await DiagLog.add('تعذّر قراءة حالة الإشعارات: $e');
    }
    final p = await SharedPreferences.getInstance();
    final ok = p.getString('sched_last_ok');
    final sound = await AppSettings.adhanChoice();
    final now = DateTime.now();
    final times = PrayerCalc.forDate(now);
    String next = '—';
    final nextPrayer = times.nextPrayer();
    if (nextPrayer != Prayer.none) {
      final t = times.timeForPrayer(nextPrayer)!;
      next = '${_name(nextPrayer)} ${DateFormat.jm('ar').format(t)}';
    }
    final log = await DiagLog.list();
    if (!mounted) return;
    setState(() {
      _perm = perm;
      _pending = pending;
      _lastOk = ok == null
          ? 'لم تنجح بعد'
          : DateFormat.yMMMd('ar').add_jm().format(DateTime.parse(ok));
      _sound = sound.label;
      _next = next;
      _log = log;
    });
  }

  static String _name(Prayer p) => switch (p) {
        Prayer.fajr => 'الفجر',
        Prayer.sunrise => 'الشروق',
        Prayer.dhuhr => 'الظهر',
        Prayer.asr => 'العصر',
        Prayer.maghrib => 'المغرب',
        Prayer.isha => 'العشاء',
        _ => '—',
      };

  void _msg(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _run(Future<void> Function() job, String ok) async {
    setState(() => _busy = true);
    try {
      await job();
      if (mounted) _msg(ok);
    } catch (e) {
      await DiagLog.add('$e');
      if (mounted) _msg('فشل: ${'$e'.split('\n').first}');
    }
    if (mounted) setState(() => _busy = false);
    await _load();
  }

  String _report() {
    final perm = _perm;
    return [
      'تقرير تشخيص: ${MosqueConfig.name}',
      'الإشعارات: ${perm == null ? '؟' : perm.notifications ? 'مسموحة' : 'غير مسموحة'}',
      'التنبيه الدقيق: ${perm == null ? '؟' : perm.exactAlarms ? 'مسموح' : 'غير مسموح'}',
      'المجدول: ${_pending ?? '؟'} | آخر جدولة ناجحة: $_lastOk',
      'الصوت: $_sound',
      'أقرب صلاة: $_next',
      '--- آخر الأخطاء ---',
      if (_log.isEmpty) 'لا أخطاء' else ..._log.take(10),
    ].join('\n');
  }

  Widget _row(IconData icon, String label, String value,
      {bool? ok, Widget? action}) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(
          ok == null
              ? icon
              : (ok ? Icons.check_circle_rounded : Icons.error_rounded),
          color: ok == null ? cs.primary : (ok ? cs.primary : cs.error)),
      title: Text(label),
      subtitle: Text(value),
      trailing: action,
    );
  }

  @override
  Widget build(BuildContext context) {
    final perm = _perm;
    return Scaffold(
      appBar: AppBar(title: const Text('تشخيص التطبيق')),
      body: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
        _row(
            Icons.notifications_rounded,
            'الإشعارات',
            perm == null
                ? 'غير معروف'
                : perm.notifications
                    ? 'مسموحة'
                    : 'غير مسموحة. بدونها لا يُسمع الأذان',
            ok: perm?.notifications,
            action: perm != null && !perm.notifications
                ? TextButton(
                    onPressed: () =>
                        _run(AdhanService.instance.enableNotifications, 'تم'),
                    child: const Text('تفعيل'))
                : null),
        _row(
            Icons.alarm_rounded,
            'التنبيه في الوقت الدقيق',
            perm == null
                ? 'غير معروف'
                : perm.exactAlarms
                    ? 'مسموح'
                    : 'غير مسموح: قد يتأخر الأذان دقائق',
            ok: perm?.exactAlarms,
            action: perm != null && !perm.exactAlarms
                ? TextButton(
                    onPressed: () =>
                        _run(AdhanService.instance.enableExactAlarms, 'تم'),
                    child: const Text('تفعيل'))
                : null),
        _row(Icons.event_available_rounded, 'الأذان المجدول',
            '${_pending ?? '؟'} تنبيه (المتوقع نحو 35)\nآخر جدولة ناجحة: $_lastOk',
            ok: _pending == null ? null : _pending! > 0),
        _row(Icons.access_time_rounded, 'أقرب صلاة', _next),
        _row(Icons.music_note_rounded, 'الصوت المختار', _sound),
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: _busy
                  ? null
                  : () => _run(
                      () => AdhanService.instance.scheduleAll(force: true),
                      'أُعيدت جدولة الأذان'),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة جدولة الأذان'),
            ),
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: _busy
                  ? null
                  : () => _run(() => AdhanService.instance.scheduleTest(),
                      'سيصلك تنبيه تجريبي بعد 10 ثوانٍ. أغلق الشاشة وانتظر'),
              icon: const Icon(Icons.volume_up_rounded),
              label: const Text('تجربة الأذان بعد 10 ثوانٍ'),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            'إن لم يصلك الأذان على هاتف سامسونج أو شاومي أو هواوي: افتح إعدادات التطبيق ← البطارية، واختر «غير مقيّد» أو «بدون قيود»، واسمح بالتشغيل التلقائي.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TextButton.icon(
                onPressed: openAppSettings,
                icon: const Icon(Icons.settings_applications_rounded),
                label: const Text('فتح إعدادات التطبيق')),
          ),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Text('آخر الأخطاء',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ),
        if (_log.isEmpty)
          const Padding(
              padding: EdgeInsets.all(16),
              child: Text('لا توجد أخطاء مسجَّلة.'))
        else
          for (final l in _log.take(15))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: SelectableText(l,
                  style: Theme.of(context).textTheme.bodySmall,
                  textDirection: ui.TextDirection.ltr),
            ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: _report()));
                if (mounted) _msg('نُسخ التقرير');
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('نسخ التقرير'),
            ),
            if (Launcher.supported)
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: _report()));
                  if (mounted) _msg('نُسخ التقرير. الصقه في محادثة ماسنجر');
                  await Launcher.openUrl(MosqueConfig.messengerUrl,
                      packages: MosqueConfig.messengerPackages);
                },
                icon: const Icon(Icons.send_rounded),
                label: const Text('إرسال للدعم عبر ماسنجر'),
              ),
            if (_log.isNotEmpty)
              TextButton(
                onPressed: () async {
                  await DiagLog.clear();
                  await _load();
                },
                child: const Text('مسح السجل'),
              ),
          ]),
        ),
      ]),
    );
  }
}
