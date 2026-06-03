import 'dart:convert';

/// 将 JPEG 字节转为可在 [Image.network] 显示的 data URL（Web 免 Storage CORS）。
String bytesToJpegDataUrl(List<int> bytes) =>
    'data:image/jpeg;base64,${base64Encode(bytes)}';

bool isDataImageUrl(String? url) =>
    url != null && url.startsWith('data:image');
