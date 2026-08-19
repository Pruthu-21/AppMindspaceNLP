import 'dart:html' as html;

Future<bool> startPlatformDownload(String url, String fileName, {Function(double progress)? onProgress}) async {
  try {
    if (onProgress != null) onProgress(0.5);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..setAttribute('target', '_blank')
      ..style.display = 'none';
    html.document.body?.children.add(anchor);
    anchor.click();
    anchor.remove();
    if (onProgress != null) onProgress(1.0);
    return true;
  } catch (e) {
    return false;
  }
}
