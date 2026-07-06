// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get retry => '再試行';

  @override
  String get settings => '設定';

  @override
  String get cancel => 'キャンセル';

  @override
  String get confirm => '確定';

  @override
  String get ok => 'OK';

  @override
  String get delete => '削除';

  @override
  String get all => 'すべて';

  @override
  String get done => '完了';

  @override
  String get processing => '処理中…';

  @override
  String get untitled => '(名称未入力)';

  @override
  String get appTagline => '言語景観の採集';

  @override
  String get bootOfflineTitle => '設定を読み込めません';

  @override
  String get bootOfflineBody => '端末の既定設定で動作します。採集は可能です。';

  @override
  String get newCollection => '新規採集';

  @override
  String get takePhoto => '撮影';

  @override
  String get chooseFromGallery => 'ギャラリーから選択';

  @override
  String get recordsTitle => '採集記録';

  @override
  String recordsCount(int count) {
    return '$count 件';
  }

  @override
  String get archiveTooltip => '採集アーカイブ';

  @override
  String get areaCodeTooltip => '地区コード';

  @override
  String get emptyTitle => 'まだ記録がありません';

  @override
  String get emptyBody => '「新規採集」から、身の回りの言語景観を記録しましょう。';

  @override
  String get savedTitle => 'ローカルプロジェクトに保存しました';

  @override
  String get savedBody =>
      '写真記録を現在のプロジェクトに保存しました。後で CSV と写真の ZIP を書き出して整理・バックアップ・分析に使えます。';

  @override
  String get backToMap => '地図に戻る';

  @override
  String get exporting => '書き出し中…';

  @override
  String get unitPhotos => ' 枚';

  @override
  String exportedTo(String path) {
    return '書き出し: $path';
  }

  @override
  String exportFailed(String error) {
    return '書き出し失敗: $error';
  }

  @override
  String get currentLocation => '現在地';

  @override
  String get layerMap => '地図';

  @override
  String get layerSatellite => '衛星';

  @override
  String get areaDialogTitle => '地区コード（3文字）';

  @override
  String get deleteRecordTitle => '記録を削除';

  @override
  String deleteRecordConfirm(String id) {
    return '$id を削除しますか？';
  }

  @override
  String get settingsSaved => '設定を保存しました（URL変更は次回起動から）';

  @override
  String get menu => 'メニュー';

  @override
  String get aboutApp => 'LLMap について';

  @override
  String get tutorial => 'チュートリアル';

  @override
  String get tips => '採集のコツ';

  @override
  String get projectSettings => 'プロジェクト設定';

  @override
  String get exportData => 'データを書き出す';

  @override
  String aboutBody(String version) {
    return '言語景観の採集ツール · $version\nローカル優先：写真と記録は端末内に保存。いつでも CSV と写真 ZIP を書き出せます。クラウド同期は今後対応。';
  }

  @override
  String get comingSoon => '開発中です。お楽しみに。';

  @override
  String cropTitle(int count) {
    return '框选標識 ($count)';
  }

  @override
  String get undoLastBox => '最後の枠を取り消し';

  @override
  String get clearAll => '全消去';

  @override
  String get cropHintEmpty => 'ドラッグで各標識を囲む。囲まなければ全景を1件として登録。';

  @override
  String cropHintBoxed(String list) {
    return '枠: $list';
  }

  @override
  String get nextFillFields => '次へ：字段入力';

  @override
  String get nextWholeImage => '全景を1件として次へ';

  @override
  String get gpsLocating => '現在地を取得中…';

  @override
  String get gpsGot => '現在地を取得しました';

  @override
  String get gpsFailed => '現在地を取得できません。撮影地点を手動で選んでください';

  @override
  String get gpsAdjust => '位置がずれている？手動調整';

  @override
  String get gpsManual => '手動で選択';

  @override
  String get gpsAdjusted => '位置を手動調整しました';

  @override
  String get gpsReadjust => '再調整';

  @override
  String fieldsTitle(String suffix, int index, int total) {
    return '字段入力 · $suffix ($index/$total)';
  }

  @override
  String get reRecognize => '再識別';

  @override
  String get recognizing => '識別中…';

  @override
  String aiFailed(String error) {
    return 'AI識別に失敗: $error';
  }

  @override
  String get stashDone => '暂存して完了';

  @override
  String get stashNext => '暂存して次へ';

  @override
  String get saveDone => '入力して保存・完了';

  @override
  String get saveNext => '入力して保存・次へ';

  @override
  String get editTitle => '編集';

  @override
  String deleteRecordConfirmIrreversible(String id) {
    return '$id を削除しますか？元に戻せません。';
  }

  @override
  String get saveChanges => '保存';

  @override
  String get aiAuto => 'AI自動識別';

  @override
  String get aiAutoSub => 'オンにすると、框选した各標識に入ると自動で字段を識別します。';

  @override
  String get provider => 'プロバイダ';

  @override
  String get apiKey => 'APIキー';

  @override
  String get apiKeyNote =>
      'キーは端末内にのみ保存され、判定時に各社AI（Claude/Gemini）へ直接送信されます（PC不要）。';

  @override
  String get backendOptional => '後端アドレス（任意）';

  @override
  String get backendNote => '日常の採集に後端は不要。旧版後端を使う場合のみ入力。';

  @override
  String get backendUrl => '後端 URL';

  @override
  String get backendHint =>
      'Windows: http://localhost:8000 / エミュ: http://10.0.2.2:8000 / 実機: http://<PCのLAN IP>:8000';

  @override
  String get saveSettings => '設定を保存';

  @override
  String get language => '言語';

  @override
  String get languageSystem => 'システムに従う';

  @override
  String get collectorId => '採集者 ID';

  @override
  String get collectorIdNote =>
      '採集者の識別子。SignID の「採集者」位に入り、多人協作時の採番衝突を防ぐ。既定で自動生成済み（NanoID 8桁・易混字 0/O/1/l/I を除外）。自由に変更可。';

  @override
  String get collectorIdLabel => '採集者 ID';

  @override
  String get collectorIdRegenerate => '再生成';

  @override
  String get galleryTitle => '採集アーカイブ';

  @override
  String get langFilter => '言語';

  @override
  String get sourceFilter => '設置';

  @override
  String get noMatch => '条件に合う記録がありません';

  @override
  String get selectLocTitle => '撮影位置を確認';

  @override
  String get selectLocBody1 => '現在地を自動取得しました。';

  @override
  String get selectLocBody2 => 'ずれている場合は地図をドラッグして撮影地点を調整。';

  @override
  String coords(String lat, String lng) {
    return '座標: $lat, $lng';
  }

  @override
  String get relocate => '再取得';

  @override
  String get gpsUnavailable => '現在地を取得できません';

  @override
  String get useThisLocation => 'この位置を使う';

  @override
  String get restoreAuto => '自動位置に戻す';

  @override
  String get mapPreview => '地図プレビュー';

  @override
  String get fitAll => '全体表示';

  @override
  String noCoords(int count) {
    return '座標なし $count 件は非表示';
  }

  @override
  String get mainLanguage => '主要言語';

  @override
  String get subLanguage => '補助言語';

  @override
  String get operator => '設置主体';

  @override
  String get carrier => '担体類型';

  @override
  String get sourceType => 'ディスコース類型';

  @override
  String get multilingual => '多言語関係';

  @override
  String noteLabel(String note) {
    return '備考: $note';
  }

  @override
  String signMeta(String lat, String lng, String time) {
    return 'GPS：$lat, $lng · 採集：$time';
  }

  @override
  String get captureMode => '採集モード';

  @override
  String get captureModeNote =>
      '撮影・框選後の入力フローを決めます。3モードは同じデータ構造を共用し、いつでも切り替えられます。';

  @override
  String get modeQuick => 'クイックモード';

  @override
  String get modeQuickDesc => '框選後すぐ保存。フィールドは後で補完';

  @override
  String get modeStandard => '標準モード';

  @override
  String get modeStandardDesc => '標識に現れる言語を選ぶだけ（既定）';

  @override
  String get modeResearch => '研究モード';

  @override
  String get modeResearchDesc => '完全な研究フィールド表単で正式に採集・標注';

  @override
  String get fieldScheme => 'フィールド構成';

  @override
  String get fieldSchemeOfficial => '公式フィールド';

  @override
  String get fieldSchemeCustom => 'カスタムフィールド';

  @override
  String get savedQuick => '記録を保存しました。フィールドは後から補完できます。';

  @override
  String get savedStandard => '記録を提出しました。';

  @override
  String get savedResearch => '研究記録を保存しました。';

  @override
  String get stdLangPrompt => '標識に現れる言語を選択';

  @override
  String get stdMoreInfo => '＋ 情報を追加';

  @override
  String get fieldScript => '文字体系';

  @override
  String get fieldNote => '備考（任意）';

  @override
  String get datasetExported => 'Dataset Package を書き出しました';

  @override
  String get select => '選択';

  @override
  String selectedCount(int count) {
    return '$count 件選択中';
  }

  @override
  String get selectAll => 'すべて選択';

  @override
  String get deselectAll => '選択解除';

  @override
  String deleteMultipleTitle(int count) {
    return '$count 件の記録を削除しますか？';
  }

  @override
  String get deleteIrreversibleBody => 'この操作は取り消せません。';

  @override
  String deletedCount(int count) {
    return '$count 件削除しました';
  }

  @override
  String get sortTitle => '並べ替え';

  @override
  String get sortNewestFirst => '新しい順';

  @override
  String get sortOldestFirst => '古い順';

  @override
  String get sortIdAsc => 'ID 昇順';

  @override
  String get sortIdDesc => 'ID 降順';

  @override
  String get filterTitle => '絞り込み';

  @override
  String get clearFilters => '絞り込みをクリア';

  @override
  String resultsCount(int count) {
    return '$count 件を表示';
  }

  @override
  String get filterMode => 'モード';

  @override
  String get filterStatus => '状態';

  @override
  String get filterArea => '地区';

  @override
  String get filterCollector => '採集者';

  @override
  String get filterGps => 'GPS';

  @override
  String get filterPhoto => '写真';

  @override
  String get filterSource => '元写真';

  @override
  String get yes => 'あり';

  @override
  String get no => 'なし';

  @override
  String get allRecords => 'すべての記録';

  @override
  String get newAlbum => '新規アルバム';

  @override
  String get albumNameHint => 'アルバム名';

  @override
  String get renameAlbum => 'アルバム名を変更';

  @override
  String get deleteAlbum => 'アルバムを削除';

  @override
  String deleteAlbumTitle(String name) {
    return '「$name」を削除しますか？';
  }

  @override
  String get deleteAlbumBody => 'アルバム内の記録は削除されません。';

  @override
  String get addToAlbum => 'アルバムに追加';

  @override
  String get removeFromAlbum => 'アルバムから外す';

  @override
  String addedToAlbum(int count, String name) {
    return '「$name」に $count 件追加しました';
  }

  @override
  String removedFromAlbum(int count) {
    return 'アルバムから $count 件外しました';
  }

  @override
  String get albumEmpty => 'このアルバムにはまだ記録がありません。';

  @override
  String get unfiled => '未分類';

  @override
  String get filed => '分類済み';

  @override
  String get noUnfiledRecords => '未分類の記録はありません';

  @override
  String get allRecordsFiled => 'すべての記録がアルバムに整理されています';

  @override
  String get noFiledRecords => '分類済みの記録はありません';

  @override
  String get recordsAddedToAlbumsAppearHere => '記録をアルバムに追加すると、ここに表示されます';
}
