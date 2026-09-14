import 'dart:convert';
import 'dart:html' as html;

Future<void> downloadTextReport({
  required String filename,
  required String content,
}) async {
  final bytes = utf8.encode(content);
  final blob = html.Blob([bytes], 'text/plain;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}

Future<void> printTextReport(String content) async {
  final escaped = const HtmlEscape().convert(content);
  final page =
      '''
<!doctype html>
<html>
  <head>
    <title>FlowSlot Report</title>
    <style>
      body { font-family: Arial, sans-serif; padding: 32px; color: #111827; }
      pre { white-space: pre-wrap; font-size: 13px; line-height: 1.55; }
    </style>
    <script>window.onload = function() { window.print(); };</script>
  </head>
  <body><pre>$escaped</pre></body>
</html>
''';
  final blob = html.Blob([page], 'text/html;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.window.open(url, '_blank');
}
