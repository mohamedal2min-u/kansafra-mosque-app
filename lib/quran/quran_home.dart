import 'package:flutter/material.dart';

import 'listen_screen.dart';
import 'radio_screen.dart';
import 'quran_data.dart';
import 'reader_screen.dart';

class QuranHome extends StatelessWidget {
  const QuranHome({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: QuranData.load(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        return _tabs();
      },
    );
  }

  Widget _tabs() {
    return const DefaultTabController(
      length: 3,
      child: Column(children: [
        TabBar(tabs: [
          Tab(text: 'استماع'),
          Tab(text: 'قراءة'),
          Tab(text: 'بث مباشر')
        ]),
        Expanded(
            child: TabBarView(
                children: [ListenScreen(), SurahListScreen(), RadioScreen()])),
      ]),
    );
  }
}
