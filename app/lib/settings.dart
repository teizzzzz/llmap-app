/// backend URL の永続化と設定ダイアログ。
/// Android 実機/エミュからは PC の localhost に届かないため、ここで
/// PC の LAN IP（例 http://192.168.x.x:8000）やエミュ用 10.0.2.2 を設定する。
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kBaseUrl = 'backend_base_url';
const defaultBaseUrl = 'http://localhost:8000';

Future<String> loadBaseUrl() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_kBaseUrl) ?? defaultBaseUrl;
}

Future<void> saveBaseUrl(String url) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kBaseUrl, url.trim());
}

/// 現在の URL を編集するダイアログ。確定で新 URL を返す（取消は null）。
Future<String?> showBackendUrlDialog(
    BuildContext context, String current) async {
  final ctrl = TextEditingController(text: current);
  return showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('后端 URL'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              hintText: 'http://192.168.x.x:8000',
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Windows: http://localhost:8000\n'
            'Androidエミュ: http://10.0.2.2:8000\n'
            'Android実機: http://<PCのLAN IP>:8000',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消')),
        FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('保存')),
      ],
    ),
  );
}
