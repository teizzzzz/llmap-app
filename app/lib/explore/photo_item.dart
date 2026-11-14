/// 探索・地図・我的で共通に扱う「1 枚の写真」。
/// 端末の記録（Sign）と探索データ（LlvRecord）を同じ形に揃え、
/// 瀑布流・地図・照片详情が出どころを意識せずに描けるようにする。
library;

import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme/tokens.dart';
import 'dataset.dart';
import 'lang_codes.dart';

/// 详情に並べる記述字段（正準キー）。探索データの短縮キーとの対応も兼ねる。
const List<(String key, String short)> kDetailFacts = [
  ('多言語関係', 'rel'),
  ('担体類型', 'car'),
  ('放置位置', 'pos'),
  ('時間性', 'tmp'),
  ('可読性', 'rd'),
  ('ディスコース類型', 'dis'),
  ('製作品質', 'q'),
];

class PhotoItem {
  final String key; // 'm:<SignID>' / 'e:<id>'（一覧・選択の同一性）
  final String label;
  final bool mine;
  final double? lat;
  final double? lng;
  final List<String> langs; // 主要言語コード
  final List<String> auxLangs; // 補助言語コード
  final String time;
  final String colorName; // 探索データのみ（端末記録は空）
  final Color placeholder; // 画像読込前の下地色
  final List<(String key, String value)> facts;
  final String note;
  final String dataStatus; // 端末記録の審核状態（raw/submitted/…）
  final ImageProvider? image;
  final Sign? sign;
  final LlvRecord? record;

  const PhotoItem({
    required this.key,
    required this.label,
    required this.mine,
    required this.lat,
    required this.lng,
    required this.langs,
    required this.auxLangs,
    required this.time,
    required this.colorName,
    required this.placeholder,
    required this.facts,
    required this.note,
    required this.dataStatus,
    required this.image,
    this.sign,
    this.record,
  });

  bool get hasLocation => lat != null && lng != null;

  factory PhotoItem.fromSign(Sign s) {
    final file = s.fileName;
    return PhotoItem(
      key: 'm:${s.id}',
      label: s.shortLabel,
      mine: true,
      lat: s.lat,
      lng: s.lng,
      langs: splitMulti(s.mainLang).map(langCodeOf).toSet().toList(),
      auxLangs: splitMulti(s.get('補助言語')).map(langCodeOf).toSet().toList(),
      time: s.get('採集日時'),
      colorName: '',
      placeholder: AppColors.muted,
      facts: [
        for (final (k, _) in kDetailFacts)
          if (s.get(k).isNotEmpty) (k, s.get(k)),
      ],
      note: s.get('備考'),
      dataStatus: s.get('DataStatus'),
      image: file.isEmpty
          ? null
          : LocalStore.instance.photoImage(file),
      sign: s,
    );
  }

  factory PhotoItem.fromRecord(ExploreDataset ds, LlvRecord r) => PhotoItem(
    key: 'e:${r.id}',
    label: r.displayId,
    mine: false,
    lat: r.lat,
    lng: r.lng,
    langs: r.main,
    auxLangs: r.aux,
    time: r.time,
    colorName: r.colorName,
    placeholder: parseHexColor(r.repColor),
    facts: [
      for (final (k, short) in kDetailFacts)
        if ((r.fields[short] ?? '').isNotEmpty) (k, r.fields[short]!),
    ],
    note: r.note,
    dataStatus: '',
    image: r.photo.isEmpty ? null : NetworkImage(ds.thumbUrl(r)),
    record: r,
  );
}
