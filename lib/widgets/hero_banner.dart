import 'dart:async';

import 'package:flutter/material.dart';

import '../config.dart';

/// صور المسجد. ضع الملفين في assets/photos/ بهذين الاسمين (JPG بعرض حوالي 1200 بكسل).
const mosquePhotos = ['assets/photos/mosque1.jpg', 'assets/photos/mosque2.jpg'];

/// شريط صور المسجد أعلى الشاشة الرئيسية: يتبدّل كل 6 ثوانٍ، ويعرض الشعار والاسم فوق تدرّج.
class HeroBanner extends StatefulWidget {
  const HeroBanner({super.key});

  @override
  State<HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<HeroBanner> {
  final _controller = PageController();
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!_controller.hasClients) return;
      final next = (_page + 1) % mosquePhotos.length;
      _controller.animateToPage(next, duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: Stack(fit: StackFit.expand, children: [
          PageView(
            controller: _controller,
            onPageChanged: (i) => setState(() => _page = i),
            children: [
              for (final p in mosquePhotos)
                Image.asset(
                  p,
                  fit: BoxFit.cover,
                  cacheWidth: 1000, // يقلّل استهلاك الذاكرة على الهواتف الضعيفة
                  errorBuilder: (_, __, ___) => Container(color: scheme.primary),
                ),
            ],
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00000000), Color(0xB3000000)],
                stops: [0.45, 1],
              ),
            ),
          ),
          Positioned(
            right: 14,
            left: 14,
            bottom: 12,
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset('assets/logo/icon.png', width: 44, height: 44),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  MosqueConfig.name,
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              Row(children: [
                for (var i = 0; i < mosquePhotos.length; i++)
                  Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _page ? Colors.white : Colors.white54,
                    ),
                  ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}
