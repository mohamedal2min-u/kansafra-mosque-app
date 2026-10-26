import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'khatma.dart';

/// آيات يحفظها المستخدم للرجوع إليها (غير علامة الختمة)، على هاتفه فقط.
class SavedVerses {
  SavedVerses._();
  static final instance = SavedVerses._();
  static const _key = 'saved_verses_v1';

  final items = ValueNotifier<List<Bookmark>>(const []);
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw != null) {
      try {
        items.value = [
          for (final e in jsonDecode(raw) as List)
            Bookmark((e as List)[0] as int, e[1] as int),
        ];
      } catch (_) {}
    }
    _loaded = true;
  }

  bool contains(int surah, int verse) =>
      items.value.any((b) => b.surah == surah && b.verse == verse);

  Future<void> _save() async =>
      (await SharedPreferences.getInstance()).setString(
          _key,
          jsonEncode([
            for (final b in items.value) [b.surah, b.verse]
          ]));

  /// يحفظ الآية إن لم تكن محفوظة، وإلا يزيلها.
  Future<bool> toggle(int surah, int verse) async {
    await load();
    final list = [...items.value];
    final i = list.indexWhere((b) => b.surah == surah && b.verse == verse);
    final added = i < 0;
    if (added) {
      list.insert(0, Bookmark(surah, verse));
    } else {
      list.removeAt(i);
    }
    items.value = list;
    await _save();
    return added;
  }
}
