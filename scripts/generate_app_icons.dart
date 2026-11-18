import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final src = img.decodePng(File('assets/images/app_icon_source.png').readAsBytesSync())!;

  // Analyze: opaque background luminance vs foreground luminance
  int transparent = 0, dark = 0, light = 0;
  double bgLumSum = 0, fgLumSum = 0;
  int bgCount = 0, fgCount = 0;
  for (var y = 0; y < src.height; y += 4) {
    for (var x = 0; x < src.width; x += 4) {
      final p = src.getPixel(x, y);
      final lum = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
      if (p.a < 20) {
        transparent++;
      } else if (lum < 60) {
        dark++;
        bgLumSum += lum;
        bgCount++;
      } else {
        light++;
        fgLumSum += lum;
        fgCount++;
      }
    }
  }
  print('transparent:$transparent dark:$dark light:$light');
  print('avgDarkLum:${(bgLumSum / (bgCount == 0 ? 1 : bgCount)).toStringAsFixed(1)} avgLightLum:${(fgLumSum / (fgCount == 0 ? 1 : fgCount)).toStringAsFixed(1)}');

  // Decide canvas: if the artwork (majority non-transparent) is LIGHT, use dark
  // navy canvas; if it is DARK, use white canvas for contrast.
  final bool artIsLight = light > dark;
  final int canvasColor = artIsLight ? 0xFF0F2942 : 0xFFFFFFFF;
  print('artIsLight:$artIsLight → canvas: ${artIsLight ? "navy" : "white"}');

  // Main icon: 512 white/navy canvas + full icon
  final main = img.Image(width: 512, height: 512, numChannels: 4);
  img.fill(main, color: img.ColorRgba8((canvasColor >> 16) & 0xFF, (canvasColor >> 8) & 0xFF, canvasColor & 0xFF, 255));
  img.compositeImage(main, src);
  Directory('assets/icons').createSync(recursive: true);
  File('assets/icons/app_icon_main.png').writeAsBytesSync(img.encodePng(main));

  // Adaptive foreground: 1024 canvas + icon at 66% (safe zone for masks)
  final fg = img.Image(width: 1024, height: 1024, numChannels: 4);
  img.fill(fg, color: img.ColorRgba8((canvasColor >> 16) & 0xFF, (canvasColor >> 8) & 0xFF, canvasColor & 0xFF, 255));
  final scaled = img.copyResize(src, width: 676, height: 676);
  img.compositeImage(fg, scaled, center: true);
  File('assets/icons/app_icon_fg.png').writeAsBytesSync(img.encodePng(fg));

  print('icons written: assets/icons/app_icon_main.png + app_icon_fg.png');
}
