import 'dart:math';

/// اتجاه القبلة بالدرجات من الشمال الحقيقي (دائرة عظمى نحو الكعبة).
double qiblaBearing(double lat, double lon) {
  const kaabaLat = 21.4225, kaabaLon = 39.8262;
  final p1 = lat * pi / 180, p2 = kaabaLat * pi / 180;
  final dl = (kaabaLon - lon) * pi / 180;
  final y = sin(dl) * cos(p2);
  final x = cos(p1) * sin(p2) - sin(p1) * cos(p2) * cos(dl);
  return (atan2(y, x) * 180 / pi + 360) % 360;
}
