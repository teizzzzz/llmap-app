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
  String get takePhoto => '写真を撮る';

  @override
  String get chooseFromGallery => 'アルバムから選ぶ';

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
  String get emptyBody => '下のカメラボタンから、街で見つけた文字を記録してみましょう。';

  @override
  String get savedTitle => '保存しました';

  @override
  String get savedBody =>
      '写真と記録をこの端末に保存しました。あとで CSV と写真の ZIP を書き出して、整理・バックアップ・分析に使えます。';

  @override
  String get backToMap => '地図に戻る';

  @override
  String get exporting => '書き出し中…';

  @override
  String get unitPhotos => ' 枚';

  @override
  String exportedTo(String path) {
    return '書き出し先：$path';
  }

  @override
  String exportFailed(String error) {
    return '書き出しに失敗しました：$error';
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
  String get settingsSaved => '設定を保存しました';

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
    return '言語景観の採集ツール · $version\n写真と記録はこの端末に保存され、いつでも CSV と写真の ZIP を書き出せます。クラウド同期は今後対応予定です。';
  }

  @override
  String get comingSoon => '開発中です。お楽しみに。';

  @override
  String cropTitle(int count) {
    return '標識を囲む（$count）';
  }

  @override
  String get undoLastBox => '最後の枠を取り消し';

  @override
  String get clearAll => 'すべて消去';

  @override
  String get cropHintEmpty => 'ドラッグして標識を囲んでください。囲まない場合は、写真全体を 1 件として登録します。';

  @override
  String cropHintBoxed(String list) {
    return '選択中：$list';
  }

  @override
  String get nextFillFields => '次へ：項目を入力';

  @override
  String get nextWholeImage => '写真全体を 1 件として次へ';

  @override
  String get gpsLocating => '現在地を取得中…';

  @override
  String get gpsGot => '現在地を取得しました';

  @override
  String get gpsFailed => '現在地を取得できません。撮影した場所を手動で選んでください。';

  @override
  String get gpsAdjust => '位置を手動で調整';

  @override
  String get gpsManual => '手動で選択';

  @override
  String get gpsAdjusted => '位置を手動で調整しました';

  @override
  String get gpsReadjust => '再調整';

  @override
  String fieldsTitle(String suffix, int index, int total) {
    return '項目の入力 · $suffix（$index/$total）';
  }

  @override
  String get reRecognize => 'もう一度認識';

  @override
  String get recognizing => '認識中…';

  @override
  String aiFailed(String error) {
    return 'AI 認識に失敗しました：$error';
  }

  @override
  String get stashDone => '一時保存して完了';

  @override
  String get stashNext => '一時保存して次へ';

  @override
  String get saveDone => '保存して完了';

  @override
  String get saveNext => '保存して次へ';

  @override
  String get editTitle => '編集';

  @override
  String deleteRecordConfirmIrreversible(String id) {
    return '$id を削除しますか？元に戻せません。';
  }

  @override
  String get saveChanges => '保存';

  @override
  String get aiAuto => 'AI 認識';

  @override
  String get aiAutoSub =>
      'AI が項目を提案します。結果はあとから修正できます。現在はエキスパートモードでのみ使えます（かんたんモードは OCR の方式が決まり次第対応します）。';

  @override
  String get provider => 'プロバイダ';

  @override
  String get apiKey => 'APIキー';

  @override
  String get apiKeyNote =>
      'キーはこの端末にのみ保存され、認識のときに各社の AI（Claude / Gemini）へ直接送信されます。PC は不要です。';

  @override
  String get backendOptional => 'バックエンドのアドレス（任意）';

  @override
  String get backendNote => '通常の採集にバックエンドは不要です。';

  @override
  String get backendUrl => 'バックエンド URL';

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
      '採集者を見分けるための ID です。SignID に含まれ、複数人で採集しても番号が重ならないようにします。初期値は自動で作成済みです（8 桁。見間違えやすい 0/O/1/l/I は使いません）。自由に変更できます。';

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
  String get selectLocBody2 => 'ずれている場合は、地図をドラッグして撮影した場所に合わせてください。';

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
    return '座標のない $count 件は表示していません';
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
      '撮影後の入力の流れを選べます。どちらのモードも同じデータ形式なので、いつでも切り替えられます。';

  @override
  String get modeQuick => 'かんたんモード';

  @override
  String get modeQuickDesc => '写真と場所の記録を優先。標識を囲むこともでき、言語の入力は任意です';

  @override
  String get modeStandard => '標準モード';

  @override
  String get modeStandardDesc => '標識に使われている言語を選ぶだけ';

  @override
  String get modeResearch => 'エキスパートモード';

  @override
  String get modeResearchDesc => '標識ごとに枠で囲み、研究用のすべての項目を入力します';

  @override
  String get fieldScheme => '項目の構成';

  @override
  String get fieldSchemeOfficial => '公式の項目';

  @override
  String get fieldSchemeCustom => 'カスタム項目';

  @override
  String get savedQuick => '保存しました。詳しい情報は、あとで「自分の記録」から追加できます。';

  @override
  String get savedStandard => '記録を提出しました。';

  @override
  String get savedResearch => '研究記録を保存しました。';

  @override
  String get stdLangPrompt => '標識に使われている言語を選択';

  @override
  String get stdMoreInfo => '＋ 情報を追加';

  @override
  String get fieldScript => '文字体系';

  @override
  String get fieldNote => '備考（任意）';

  @override
  String get datasetExported => 'データセットパッケージを書き出しました';

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

  @override
  String get exportDataset => 'データセットパッケージを書き出す';

  @override
  String get exportScopeCurrentView => '現在の表示';

  @override
  String get exportScopeSelected => '選択中の記録';

  @override
  String get exportScopeAlbum => '現在のアルバム';

  @override
  String exportConfirmTitle(int count) {
    return '$count 件の記録を書き出しますか？';
  }

  @override
  String get exportConfirmBody => '選択された記録と必要な写真のみを含むデータセットパッケージを作成します。';

  @override
  String get noRecordsToExport => '書き出す記録がありません。';

  @override
  String get exportAction => '書き出す';

  @override
  String get exportSelected => '選択中を書き出す';

  @override
  String get exportPickAlbum => 'アルバムから選ぶ…';

  @override
  String get permissionDeniedTitle => '権限が必要です';

  @override
  String get cameraDeniedBody =>
      'カメラへのアクセスがオフです。撮影するには 設定 → LLMap → カメラ を有効にしてください。';

  @override
  String get photoDeniedBody =>
      '写真へのアクセスがオフです。取り込むには 設定 → LLMap → 写真 を有効にしてください。';

  @override
  String get openSettings => '設定を開く';

  @override
  String get discardTitle => '未保存の変更があります';

  @override
  String get discardEditBody => '変更を破棄して閉じますか？';

  @override
  String get discardCaptureBody => 'この採集を中止しますか？入力内容と切り出した写真は保存されません。';

  @override
  String get discard => '破棄する';

  @override
  String processFailed(String error) {
    return '処理に失敗しました：$error';
  }

  @override
  String get customAddHint => '＋ 自由に追加';

  @override
  String get add => '追加';

  @override
  String get fieldName => '名称';

  @override
  String get fieldTextuality => '文字性';

  @override
  String get fieldDecorLang => '装飾の言語';

  @override
  String get fieldSpatial => '空間階層';

  @override
  String get fieldTemporality => '時間性';

  @override
  String get fieldLegibility => '可読性';

  @override
  String get fieldOverwrite => '重ね書き';

  @override
  String get fieldDiscourse => 'ディスコース類型';

  @override
  String get fieldQuality => '製作品質';

  @override
  String get statusPending => '未処理';

  @override
  String get statusAi => 'AI下書き';

  @override
  String get statusHumanReviewed => '確認済み';

  @override
  String get statusFinal => '確定';

  @override
  String get fieldPlacement => '設置場所';

  @override
  String get navExplore => '探索';

  @override
  String get navMap => '地図';

  @override
  String get navMine => '自分の記録';

  @override
  String get tabFeed => 'フィード';

  @override
  String get tabThemes => 'テーマ';

  @override
  String get toolLanguage => '言語';

  @override
  String get toolColor => '色';

  @override
  String get searchHint => 'ID・備考で検索';

  @override
  String photosCount(int count) {
    return '$count 枚';
  }

  @override
  String get exploreNoSourceTitle => '探索データにまだ接続していません';

  @override
  String get exploreNoSourceBody =>
      '設定で探索データのアドレスを入力すると、共有の写真コレクションを見られます。いまは自分の記録を表示しています。';

  @override
  String get exploreLoading => '探索データを読み込み中…';

  @override
  String exploreLoadFailed(String error) {
    return '探索データを読み込めませんでした：$error';
  }

  @override
  String get goToSettings => '設定を開く';

  @override
  String get themesNeedSource => 'テーマは探索データから作られます。設定でアドレスを入力してください。';

  @override
  String mapInView(int count) {
    return 'この範囲の写真 · $count 枚';
  }

  @override
  String mapInViewCapped(int count) {
    return '最初の $count 枚を表示しています。地図を拡大すると、ほかの写真も見られます';
  }

  @override
  String get mapInViewEmpty => 'この範囲には写真がありません。地図を動かすか、縮小してみてください。';

  @override
  String get backToList => '一覧に戻る';

  @override
  String get showOnMap => '地図で見る';

  @override
  String get editRecord => '情報を追加';

  @override
  String get sourceMine => '自分';

  @override
  String get sourceShared => '共有';

  @override
  String get capturedAt => '採集日時';

  @override
  String get locationLabel => '場所';

  @override
  String get noLocation => '位置情報なし';

  @override
  String get languagesLabel => '言語';

  @override
  String get myRecordsTitle => '自分の記録';

  @override
  String get manageArchive => 'アルバムとまとめて操作';

  @override
  String get moreActions => 'その他';

  @override
  String get exploreDataUrl => '探索データのアドレス';

  @override
  String get exploreDataUrlNote =>
      'llmap-view フォルダのアドレス（NAS や PC 上）。空欄の場合は、自分の記録だけを探索します。';

  @override
  String get advanced => '詳細設定';

  @override
  String get aboutUs => 'このアプリについて';

  @override
  String aboutUsBody(String version) {
    return 'LLMap · $version\n東京・新大久保の言語景観をテーマにした卒業制作です。誰でも街の文字を気軽に見つけて記録でき、研究者向けの本格的な採集機能も備えています。\n写真と記録はこの端末に保存され、いつでも書き出せます。';
  }

  @override
  String get quickLangPrompt => 'どの言語が使われていますか？（任意）';

  @override
  String get quickHint => '写真と場所だけで大丈夫です。詳しい情報は、あとで「自分の記録」から追加できます。';

  @override
  String get quickSave => '保存';

  @override
  String get statusRawTag => '未完了';

  @override
  String get statusSubmittedTag => '提出済み';

  @override
  String get colorRed => '赤';

  @override
  String get colorOrange => 'オレンジ';

  @override
  String get colorYellow => '黄';

  @override
  String get colorGreen => '緑';

  @override
  String get colorBlue => '青';

  @override
  String get colorPurple => '紫';

  @override
  String get colorPink => 'ピンク';

  @override
  String get colorBrown => '茶';

  @override
  String get colorWhite => '白';

  @override
  String get colorGray => 'グレー';

  @override
  String get colorBlack => '黒';

  @override
  String get langJa => '日本語';

  @override
  String get langEn => '英語';

  @override
  String get langZh => '中国語';

  @override
  String get langKo => '韓国語';

  @override
  String get langVi => 'ベトナム語';

  @override
  String get langNe => 'ネパール語';

  @override
  String get langOther => 'その他';

  @override
  String get langNone => '言語なし';

  @override
  String get theme1Title => '中国語看板の赤';

  @override
  String get theme1Sub => '中国語が主で、代表色が赤';

  @override
  String get theme2Title => '手書きの街';

  @override
  String get theme2Sub => '手作りの貼り紙と看板';

  @override
  String get theme3Title => '臨時と季節';

  @override
  String get theme3Sub => '期間限定のポスターやのぼり';

  @override
  String get theme4Title => '規約と禁止';

  @override
  String get theme4Sub => '「〜しないで」「禁止」のことば';

  @override
  String get theme5Title => '一語一句の翻訳';

  @override
  String get theme5Sub => '複製型の多言語看板';

  @override
  String get theme6Title => 'ベトナム語とネパール語';

  @override
  String get theme6Sub => '新大久保のもうひとつの声';

  @override
  String get theme7Title => 'いちばん鮮やかな看板';

  @override
  String get theme7Sub => '鮮やかさ上位のグループ';

  @override
  String get theme8Title => '黒地の看板';

  @override
  String get theme8Sub => '暗い背景に書かれた文字';

  @override
  String get theme9Title => 'ステッカーと貼り紙';

  @override
  String get theme9Sub => 'どこにでも貼られる小さな紙';

  @override
  String get viewFeed => '一覧';

  @override
  String get viewCanvas => 'キャンバス';

  @override
  String get layoutWall => '写真ウォール';

  @override
  String get layoutGroup => 'グループ別';

  @override
  String get layoutWheel => 'カラーホイール';

  @override
  String get layoutHueLight => '色相×明度';

  @override
  String get groupBy => 'グループ分けの基準';

  @override
  String get canvasHint => 'ピンチで拡大・縮小、ドラッグで移動、写真をタップで詳細';

  @override
  String get exploreNext => '関連する写真';

  @override
  String get relColorName => '色が近い';

  @override
  String get relSceneName => '同じ写真から';

  @override
  String get relNearName => 'この近く';

  @override
  String get relLangName => '同じ言語の組み合わせ';

  @override
  String get relTypeName => '同じ種類・媒体';

  @override
  String get relContrastName => '色の対比';

  @override
  String relColorSub(int count) {
    return 'パレットが最も近い $count 枚';
  }

  @override
  String relSceneSub(int count) {
    return '同じ写真に写っている、ほかの $count 枚';
  }

  @override
  String relNearSub(int meters, int count) {
    return '半径 $meters m 以内の $count 枚';
  }

  @override
  String relLangTitle(String langs) {
    return '同じく $langs';
  }

  @override
  String relLangSub(int count) {
    return '言語の組み合わせが同じ $count 枚';
  }

  @override
  String relTypeSub(int count) {
    return '話の種類と媒体が同じ $count 枚';
  }

  @override
  String relContrastSub(String lang) {
    return '同じ$langでも、色はまったく違う';
  }

  @override
  String get nextChooseLangs => '次へ：言語を選ぶ';

  @override
  String get manageShort => '管理';
}
