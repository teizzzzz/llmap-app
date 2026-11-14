// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get retry => '重试';

  @override
  String get settings => '设置';

  @override
  String get cancel => '取消';

  @override
  String get confirm => '确定';

  @override
  String get ok => '好的';

  @override
  String get delete => '删除';

  @override
  String get all => '全部';

  @override
  String get done => '完成';

  @override
  String get processing => '处理中…';

  @override
  String get untitled => '(未填写名称)';

  @override
  String get appTagline => '语言景观采集';

  @override
  String get bootOfflineTitle => '暂时无法读取配置';

  @override
  String get bootOfflineBody => '已使用本地默认设置，可正常采集。';

  @override
  String get newCollection => '新增采集';

  @override
  String get takePhoto => '拍照';

  @override
  String get chooseFromGallery => '从相册选择';

  @override
  String get recordsTitle => '采集记录';

  @override
  String recordsCount(int count) {
    return '共 $count 条记录';
  }

  @override
  String get archiveTooltip => '采集档案';

  @override
  String get areaCodeTooltip => '地区代码';

  @override
  String get emptyTitle => '还没有采集记录';

  @override
  String get emptyBody => '点击\"新增采集\"，开始记录你身边的语言景观。';

  @override
  String get savedTitle => '已保存到本地项目';

  @override
  String get savedBody => '照片记录已保存到当前项目中。你可以稍后导出 CSV 和照片压缩包，用于整理、备份或进一步分析。';

  @override
  String get backToMap => '返回地图';

  @override
  String get exporting => '正在导出数据…';

  @override
  String get unitPhotos => ' 张照片';

  @override
  String exportedTo(String path) {
    return '已导出：$path';
  }

  @override
  String exportFailed(String error) {
    return '导出失败：$error';
  }

  @override
  String get currentLocation => '当前位置';

  @override
  String get layerMap => '地图';

  @override
  String get layerSatellite => '卫星';

  @override
  String get areaDialogTitle => '地区代码（3 字符）';

  @override
  String get deleteRecordTitle => '删除记录';

  @override
  String deleteRecordConfirm(String id) {
    return '确定删除 $id 吗？';
  }

  @override
  String get settingsSaved => '设置已保存（URL 变更将在下次启动生效）';

  @override
  String get menu => '菜单';

  @override
  String get aboutApp => '关于 LLMap';

  @override
  String get tutorial => '使用教程';

  @override
  String get tips => '采集技巧';

  @override
  String get projectSettings => '项目设置';

  @override
  String get exportData => '导出数据';

  @override
  String aboutBody(String version) {
    return '语言景观采集工具 · $version\n本地优先：照片与记录都保存在本机，可随时导出 CSV 和照片压缩包。云端同步为未来计划。';
  }

  @override
  String get comingSoon => '功能开发中，敬请期待。';

  @override
  String cropTitle(int count) {
    return '框选标志 ($count)';
  }

  @override
  String get undoLastBox => '撤销最后一个框';

  @override
  String get clearAll => '清空';

  @override
  String get cropHintEmpty => '拖动框选每个标志；不框选则整张作为一条记录。';

  @override
  String cropHintBoxed(String list) {
    return '已框选：$list';
  }

  @override
  String get nextFillFields => '下一步：填写字段';

  @override
  String get nextWholeImage => '整张作为一条记录 · 下一步';

  @override
  String get gpsLocating => '正在获取当前位置…';

  @override
  String get gpsGot => '已获取当前位置';

  @override
  String get gpsFailed => '无法获取当前位置，请手动选择拍摄地点';

  @override
  String get gpsAdjust => '位置不准确？手动调整';

  @override
  String get gpsManual => '手动选择';

  @override
  String get gpsAdjusted => '已手动调整位置';

  @override
  String get gpsReadjust => '重新调整';

  @override
  String fieldsTitle(String suffix, int index, int total) {
    return '填写字段 · $suffix ($index/$total)';
  }

  @override
  String get reRecognize => '重新识别';

  @override
  String get recognizing => '识别中…';

  @override
  String aiFailed(String error) {
    return 'AI 识别失败：$error';
  }

  @override
  String get stashDone => '暂存并完成';

  @override
  String get stashNext => '暂存，稍后填写';

  @override
  String get saveDone => '保存本次采集 · 完成';

  @override
  String get saveNext => '保存并继续';

  @override
  String get editTitle => '编辑记录';

  @override
  String deleteRecordConfirmIrreversible(String id) {
    return '确定删除 $id 吗？此操作不可撤销。';
  }

  @override
  String get saveChanges => '保存修改';

  @override
  String get aiAuto => 'AI 识别';

  @override
  String get aiAutoSub => '让 AI 辅助识别字段，结果可以修改。目前在专家模式中生效，默认模式等 OCR 方案确定后接入。';

  @override
  String get provider => '服务商';

  @override
  String get apiKey => 'API 密钥';

  @override
  String get apiKeyNote => '密钥仅保存在本机，识别时直接发送给各家 AI（Claude / Gemini），无需 PC。';

  @override
  String get backendOptional => '后端地址（可选）';

  @override
  String get backendNote => '日常采集无需后端。仅在使用旧版后端流程时填写。';

  @override
  String get backendUrl => '后端 URL';

  @override
  String get backendHint =>
      'Windows: http://localhost:8000 / 模拟器: http://10.0.2.2:8000 / 真机: http://<PC 局域网 IP>:8000';

  @override
  String get saveSettings => '保存设置';

  @override
  String get language => '语言';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get collectorId => '采集者 ID';

  @override
  String get collectorIdNote =>
      '对应采集者，会写入 SignID 的「采集者」位，多人协作时防止编号撞车。默认已自动生成（NanoID 8 位，去除易混字符 0/O/1/l/I），可自定义。';

  @override
  String get collectorIdLabel => '采集者 ID';

  @override
  String get collectorIdRegenerate => '重新生成';

  @override
  String get galleryTitle => '采集档案';

  @override
  String get langFilter => '语言';

  @override
  String get sourceFilter => '设置';

  @override
  String get noMatch => '没有符合条件的记录';

  @override
  String get selectLocTitle => '确认拍摄位置';

  @override
  String get selectLocBody1 => '系统已自动获取当前位置。';

  @override
  String get selectLocBody2 => '如果位置不准确，拖动地图以调整照片的拍摄地点。';

  @override
  String coords(String lat, String lng) {
    return '坐标：$lat, $lng';
  }

  @override
  String get relocate => '重新定位';

  @override
  String get gpsUnavailable => '无法获取当前位置';

  @override
  String get useThisLocation => '使用此位置';

  @override
  String get restoreAuto => '恢复自动定位';

  @override
  String get mapPreview => '地图预览';

  @override
  String get fitAll => '全体显示';

  @override
  String noCoords(int count) {
    return '无坐标 $count 条未显示';
  }

  @override
  String get mainLanguage => '主要语言';

  @override
  String get subLanguage => '辅助语言';

  @override
  String get operator => '设置主体';

  @override
  String get carrier => '载体类型';

  @override
  String get sourceType => '话语类型';

  @override
  String get multilingual => '多语关系';

  @override
  String noteLabel(String note) {
    return '备注：$note';
  }

  @override
  String signMeta(String lat, String lng, String time) {
    return 'GPS：$lat, $lng · 采集：$time';
  }

  @override
  String get captureMode => '采集模式';

  @override
  String get captureModeNote => '决定拍照后的填写流程。两种模式共用同一套数据，可随时切换。';

  @override
  String get modeQuick => '默认模式';

  @override
  String get modeQuickDesc => '优先记录照片和地点；可以框选标志，语言可选填';

  @override
  String get modeStandard => '标准模式';

  @override
  String get modeStandardDesc => '只需选择标识上出现的语言（默认）';

  @override
  String get modeResearch => '专家模式';

  @override
  String get modeResearchDesc => '框选每个标志，填写完整研究字段';

  @override
  String get fieldScheme => '字段方案';

  @override
  String get fieldSchemeOfficial => '官方字段';

  @override
  String get fieldSchemeCustom => '自定义字段';

  @override
  String get savedQuick => '已保存。详细信息可以之后在「我的」里补充。';

  @override
  String get savedStandard => '记录已提交。';

  @override
  String get savedResearch => '研究记录已保存。';

  @override
  String get stdLangPrompt => '选择标识中出现的语言';

  @override
  String get stdMoreInfo => '＋ 添加更多信息';

  @override
  String get fieldScript => '文字体系';

  @override
  String get fieldNote => '备注（可选）';

  @override
  String get datasetExported => 'Dataset Package 已导出';

  @override
  String get select => '选择';

  @override
  String selectedCount(int count) {
    return '已选择 $count 项';
  }

  @override
  String get selectAll => '全选';

  @override
  String get deselectAll => '取消全选';

  @override
  String deleteMultipleTitle(int count) {
    return '删除 $count 条记录？';
  }

  @override
  String get deleteIrreversibleBody => '此操作无法撤销。';

  @override
  String deletedCount(int count) {
    return '已删除 $count 条记录';
  }

  @override
  String get sortTitle => '排序';

  @override
  String get sortNewestFirst => '最新优先';

  @override
  String get sortOldestFirst => '最旧优先';

  @override
  String get sortIdAsc => 'ID 升序';

  @override
  String get sortIdDesc => 'ID 降序';

  @override
  String get filterTitle => '筛选';

  @override
  String get clearFilters => '清除筛选';

  @override
  String resultsCount(int count) {
    return '显示 $count 条';
  }

  @override
  String get filterMode => '模式';

  @override
  String get filterStatus => '状态';

  @override
  String get filterArea => '地区';

  @override
  String get filterCollector => '采集者';

  @override
  String get filterGps => 'GPS';

  @override
  String get filterPhoto => '照片';

  @override
  String get filterSource => '原图';

  @override
  String get yes => '有';

  @override
  String get no => '无';

  @override
  String get allRecords => '全部记录';

  @override
  String get newAlbum => '新建相册';

  @override
  String get albumNameHint => '相册名称';

  @override
  String get renameAlbum => '重命名相册';

  @override
  String get deleteAlbum => '删除相册';

  @override
  String deleteAlbumTitle(String name) {
    return '删除“$name”？';
  }

  @override
  String get deleteAlbumBody => '相册中的记录不会被删除。';

  @override
  String get addToAlbum => '加入相册';

  @override
  String get removeFromAlbum => '从相册移除';

  @override
  String addedToAlbum(int count, String name) {
    return '已将 $count 条加入“$name”';
  }

  @override
  String removedFromAlbum(int count) {
    return '已从相册移除 $count 条';
  }

  @override
  String get albumEmpty => '该相册还没有记录。';

  @override
  String get unfiled => '未归纳';

  @override
  String get filed => '已归纳';

  @override
  String get noUnfiledRecords => '没有未归纳的记录';

  @override
  String get allRecordsFiled => '所有记录都已经整理到相册中';

  @override
  String get noFiledRecords => '没有已归纳的记录';

  @override
  String get recordsAddedToAlbumsAppearHere => '将记录加入相册后会显示在这里';

  @override
  String get exportDataset => '导出数据集包';

  @override
  String get exportScopeCurrentView => '当前显示结果';

  @override
  String get exportScopeSelected => '已选择记录';

  @override
  String get exportScopeAlbum => '当前相册';

  @override
  String exportConfirmTitle(int count) {
    return '要导出 $count 条记录吗？';
  }

  @override
  String get exportConfirmBody => '将创建一个只包含所选记录及其所需照片的数据集包。';

  @override
  String get noRecordsToExport => '没有可导出的记录。';

  @override
  String get exportAction => '导出';

  @override
  String get exportSelected => '导出已选';

  @override
  String get exportPickAlbum => '按相册选择…';

  @override
  String get permissionDeniedTitle => '需要权限';

  @override
  String get cameraDeniedBody => '相机权限已关闭。请在 设置 → LLMap → 相机 中开启后再拍照。';

  @override
  String get photoDeniedBody => '相册权限已关闭。请在 设置 → LLMap → 照片 中开启后再导入。';

  @override
  String get openSettings => '打开设置';

  @override
  String get discardTitle => '有未保存的更改';

  @override
  String get discardEditBody => '要放弃更改并关闭吗？';

  @override
  String get discardCaptureBody => '要放弃本次采集吗？已输入的内容和裁剪的照片都不会保存。';

  @override
  String get discard => '放弃';

  @override
  String processFailed(String error) {
    return '处理失败: $error';
  }

  @override
  String get customAddHint => '+ 自定义添加';

  @override
  String get add => '添加';

  @override
  String get fieldName => '名称';

  @override
  String get fieldTextuality => '文字性';

  @override
  String get fieldDecorLang => '装饰性语言';

  @override
  String get fieldSpatial => '空间层级';

  @override
  String get fieldTemporality => '时间性';

  @override
  String get fieldLegibility => '可读性';

  @override
  String get fieldOverwrite => '覆盖书写';

  @override
  String get fieldDiscourse => '话语类型';

  @override
  String get fieldQuality => '制作质量';

  @override
  String get statusPending => '待处理';

  @override
  String get statusAi => 'AI草稿';

  @override
  String get statusHumanReviewed => '已确认';

  @override
  String get statusFinal => '最终确定';

  @override
  String get fieldPlacement => '放置位置';

  @override
  String get navExplore => '探索';

  @override
  String get navMap => '地图';

  @override
  String get navMine => '我的';

  @override
  String get tabFeed => '图片流';

  @override
  String get tabThemes => '主题';

  @override
  String get toolLanguage => '语言';

  @override
  String get toolColor => '颜色';

  @override
  String get searchHint => '搜索 ID 或备注';

  @override
  String photosCount(int count) {
    return '$count 张';
  }

  @override
  String get exploreNoSourceTitle => '尚未连接探索数据';

  @override
  String get exploreNoSourceBody => '在设置里填写探索数据地址后，就能浏览共享照片库。现在先显示你自己的记录。';

  @override
  String get exploreLoading => '正在加载探索数据…';

  @override
  String exploreLoadFailed(String error) {
    return '探索数据加载失败：$error';
  }

  @override
  String get goToSettings => '去设置';

  @override
  String get themesNeedSource => '主题来自探索数据，请先在设置里填写探索数据地址。';

  @override
  String mapInView(int count) {
    return '当前地图范围内 · $count 张';
  }

  @override
  String mapInViewCapped(int count) {
    return '仅显示前 $count 张，放大地图可看到更多';
  }

  @override
  String get mapInViewEmpty => '这片区域还没有照片，移动或缩小地图看看。';

  @override
  String get backToList => '返回列表';

  @override
  String get showOnMap => '在地图上看';

  @override
  String get editRecord => '补充记录信息';

  @override
  String get sourceMine => '我的';

  @override
  String get sourceShared => '共享';

  @override
  String get capturedAt => '采集时间';

  @override
  String get locationLabel => '地点';

  @override
  String get noLocation => '没有位置信息';

  @override
  String get languagesLabel => '语言';

  @override
  String get myRecordsTitle => '我的记录';

  @override
  String get manageArchive => '相册与批量管理';

  @override
  String get moreActions => '更多';

  @override
  String get exploreDataUrl => '探索数据地址';

  @override
  String get exploreDataUrlNote =>
      'llmap-view 文件夹的网址（放在 NAS 或电脑上）。留空则只探索自己的记录。';

  @override
  String get advanced => '高级';

  @override
  String get aboutUs => '关于我们';

  @override
  String aboutUsBody(String version) {
    return 'LLMap · $version\n以东京新大久保的语言景观为对象的毕业设计。让普通人轻松发现、记录街头文字，同时为研究者保留完整的采集流程。\n照片与记录保存在本机，可随时导出。';
  }

  @override
  String get quickLangPrompt => '出现了哪些语言？（可选）';

  @override
  String get quickHint => '有照片和地点就够了，详细信息可以之后在「我的」里补充。';

  @override
  String get quickSave => '保存';

  @override
  String get statusRawTag => '待补充';

  @override
  String get statusSubmittedTag => '已提交';

  @override
  String get colorRed => '红';

  @override
  String get colorOrange => '橙';

  @override
  String get colorYellow => '黄';

  @override
  String get colorGreen => '绿';

  @override
  String get colorBlue => '蓝';

  @override
  String get colorPurple => '紫';

  @override
  String get colorPink => '粉';

  @override
  String get colorBrown => '棕';

  @override
  String get colorWhite => '白';

  @override
  String get colorGray => '灰';

  @override
  String get colorBlack => '黑';

  @override
  String get langJa => '日语';

  @override
  String get langEn => '英语';

  @override
  String get langZh => '中文';

  @override
  String get langKo => '韩语';

  @override
  String get langVi => '越南语';

  @override
  String get langNe => '尼泊尔语';

  @override
  String get langOther => '其他';

  @override
  String get langNone => '无语言';

  @override
  String get theme1Title => '中文招牌的红';

  @override
  String get theme1Sub => '中文为主、以红色为代表色';

  @override
  String get theme2Title => '手写的街道';

  @override
  String get theme2Sub => '手作的告示与招牌';

  @override
  String get theme3Title => '临时与季节';

  @override
  String get theme3Sub => '限时出现的海报和旗帜';

  @override
  String get theme4Title => '规约与禁止';

  @override
  String get theme4Sub => '「请勿」「禁止」的语言';

  @override
  String get theme5Title => '逐字逐句的翻译';

  @override
  String get theme5Sub => '复制型多语招牌';

  @override
  String get theme6Title => '越南语与尼泊尔语';

  @override
  String get theme6Sub => '新大久保的另一些声音';

  @override
  String get theme7Title => '最鲜艳的招牌';

  @override
  String get theme7Sub => '鲜艳度最高的一群';

  @override
  String get theme8Title => '黑底的招牌';

  @override
  String get theme8Sub => '深色背景上的文字';

  @override
  String get theme9Title => '贴纸与便签';

  @override
  String get theme9Sub => '贴在任何地方的小纸片';

  @override
  String get viewFeed => '瀑布流';

  @override
  String get viewCanvas => '漫游';

  @override
  String get layoutWall => '照片墙';

  @override
  String get layoutGroup => '分组';

  @override
  String get layoutWheel => '色轮';

  @override
  String get layoutHueLight => '色相×明度';

  @override
  String get groupBy => '分组依据';

  @override
  String get canvasHint => '双指缩放 · 拖动漫游 · 点照片查看详情';

  @override
  String get exploreNext => '接下来探索什么？';

  @override
  String get relColorName => '颜色相近';

  @override
  String get relSceneName => '同一画面';

  @override
  String get relNearName => '就在附近';

  @override
  String get relLangName => '相同语言组合';

  @override
  String get relTypeName => '相同话语与载体';

  @override
  String get relContrastName => '颜色反差';

  @override
  String relColorSub(int count) {
    return '色板最接近的 $count 张';
  }

  @override
  String relSceneSub(int count) {
    return '同一张街景里的另外 $count 块';
  }

  @override
  String relNearSub(int meters, int count) {
    return '方圆 $meters 米内的 $count 张';
  }

  @override
  String relLangTitle(String langs) {
    return '同为 $langs';
  }

  @override
  String relLangSub(int count) {
    return '语言组合完全相同的 $count 张';
  }

  @override
  String relTypeSub(int count) {
    return '同类话语、同种载体的 $count 张';
  }

  @override
  String relContrastSub(String lang) {
    return '同样是$lang，颜色截然不同';
  }

  @override
  String get nextChooseLangs => '下一步：选择语言';

  @override
  String get manageShort => '管理';
}
