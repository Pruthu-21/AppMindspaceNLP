import 'package:flutter/material.dart';
// Add basic web stubs

Widget buildPlatformVideo(String url) {
  return Center(child: Text('Web Video Player: $url'));
}

Widget buildPlatformPdf(String url) {
  return Center(child: Text('Web PDF Player: $url'));
}

Widget buildPlatformAudio(String url) {
  return Center(child: Text('Web Audio Player: $url'));
}

Widget buildPlatformImage(String url) {
  return Center(child: Text('Web Image: $url'));
}
