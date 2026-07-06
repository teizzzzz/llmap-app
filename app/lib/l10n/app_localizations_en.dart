// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get retry => 'Retry';

  @override
  String get settings => 'Settings';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get ok => 'OK';

  @override
  String get delete => 'Delete';

  @override
  String get all => 'All';

  @override
  String get done => 'Done';

  @override
  String get processing => 'Processing…';

  @override
  String get untitled => '(Untitled)';

  @override
  String get appTagline => 'Linguistic landscape survey';

  @override
  String get bootOfflineTitle => 'Couldn\'t load config';

  @override
  String get bootOfflineBody =>
      'Using local defaults; you can keep collecting.';

  @override
  String get newCollection => 'New record';

  @override
  String get takePhoto => 'Take photo';

  @override
  String get chooseFromGallery => 'Choose from gallery';

  @override
  String get recordsTitle => 'Records';

  @override
  String recordsCount(int count) {
    return '$count records';
  }

  @override
  String get archiveTooltip => 'Archive';

  @override
  String get areaCodeTooltip => 'Area code';

  @override
  String get emptyTitle => 'No records yet';

  @override
  String get emptyBody =>
      'Tap \"New record\" to start documenting the linguistic landscape around you.';

  @override
  String get savedTitle => 'Saved to local project';

  @override
  String get savedBody =>
      'The photo record has been saved to the current project. You can export CSV and a photo archive later for organizing, backup, or analysis.';

  @override
  String get backToMap => 'Back to map';

  @override
  String get exporting => 'Exporting data…';

  @override
  String get unitPhotos => ' photos';

  @override
  String exportedTo(String path) {
    return 'Exported: $path';
  }

  @override
  String exportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get currentLocation => 'Current location';

  @override
  String get layerMap => 'Map';

  @override
  String get layerSatellite => 'Satellite';

  @override
  String get areaDialogTitle => 'Area code (3 chars)';

  @override
  String get deleteRecordTitle => 'Delete record';

  @override
  String deleteRecordConfirm(String id) {
    return 'Delete $id?';
  }

  @override
  String get settingsSaved => 'Settings saved (URL change applies next launch)';

  @override
  String get menu => 'Menu';

  @override
  String get aboutApp => 'About LLMap';

  @override
  String get tutorial => 'Tutorial';

  @override
  String get tips => 'Tips';

  @override
  String get projectSettings => 'Project settings';

  @override
  String get exportData => 'Export data';

  @override
  String aboutBody(String version) {
    return 'A linguistic landscape tool · $version\nLocal-first: photos and records stay on your device; export CSV and a photo archive anytime. Cloud sync is planned.';
  }

  @override
  String get comingSoon => 'Coming soon.';

  @override
  String cropTitle(int count) {
    return 'Select signs ($count)';
  }

  @override
  String get undoLastBox => 'Undo last box';

  @override
  String get clearAll => 'Clear';

  @override
  String get cropHintEmpty =>
      'Drag to box each sign; if none, the whole photo becomes one record.';

  @override
  String cropHintBoxed(String list) {
    return 'Boxed: $list';
  }

  @override
  String get nextFillFields => 'Next: fill fields';

  @override
  String get nextWholeImage => 'Whole photo as one record · Next';

  @override
  String get gpsLocating => 'Getting current location…';

  @override
  String get gpsGot => 'Location acquired';

  @override
  String get gpsFailed =>
      'Couldn\'t get location; please pick the spot manually';

  @override
  String get gpsAdjust => 'Location off? Adjust manually';

  @override
  String get gpsManual => 'Pick manually';

  @override
  String get gpsAdjusted => 'Location adjusted manually';

  @override
  String get gpsReadjust => 'Re-adjust';

  @override
  String fieldsTitle(String suffix, int index, int total) {
    return 'Fields · $suffix ($index/$total)';
  }

  @override
  String get reRecognize => 'Re-recognize';

  @override
  String get recognizing => 'Recognizing…';

  @override
  String aiFailed(String error) {
    return 'AI recognition failed: $error';
  }

  @override
  String get stashDone => 'Stash & finish';

  @override
  String get stashNext => 'Stash, fill later';

  @override
  String get saveDone => 'Save this record · Finish';

  @override
  String get saveNext => 'Save & continue';

  @override
  String get editTitle => 'Edit record';

  @override
  String deleteRecordConfirmIrreversible(String id) {
    return 'Delete $id? This can\'t be undone.';
  }

  @override
  String get saveChanges => 'Save changes';

  @override
  String get aiAuto => 'AI auto-recognition';

  @override
  String get aiAutoSub =>
      'When on, fields are auto-recognized as you open each boxed sign.';

  @override
  String get provider => 'Provider';

  @override
  String get apiKey => 'API key';

  @override
  String get apiKeyNote =>
      'The key is stored only on your device and sent directly to the AI provider (Claude / Gemini), no PC needed.';

  @override
  String get backendOptional => 'Backend URL (optional)';

  @override
  String get backendNote =>
      'No backend needed for daily collection. Only fill this for the legacy backend flow.';

  @override
  String get backendUrl => 'Backend URL';

  @override
  String get backendHint =>
      'Windows: http://localhost:8000 / Emulator: http://10.0.2.2:8000 / Device: http://<PC LAN IP>:8000';

  @override
  String get saveSettings => 'Save settings';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'Follow system';

  @override
  String get collectorId => 'Collector ID';

  @override
  String get collectorIdNote =>
      'Identifies the collector. Written into the \'collector\' slot of each SignID to prevent numbering collisions in multi-person collection. Auto-generated by default (NanoID, 8 chars, excluding look-alike 0/O/1/l/I). Editable.';

  @override
  String get collectorIdLabel => 'Collector ID';

  @override
  String get collectorIdRegenerate => 'Regenerate';

  @override
  String get galleryTitle => 'Archive';

  @override
  String get langFilter => 'Language';

  @override
  String get sourceFilter => 'Agent';

  @override
  String get noMatch => 'No matching records';

  @override
  String get selectLocTitle => 'Confirm photo location';

  @override
  String get selectLocBody1 =>
      'Your current location was detected automatically.';

  @override
  String get selectLocBody2 =>
      'If it\'s off, drag the map to adjust where the photo was taken.';

  @override
  String coords(String lat, String lng) {
    return 'Coords: $lat, $lng';
  }

  @override
  String get relocate => 'Relocate';

  @override
  String get gpsUnavailable => 'Couldn\'t get current location';

  @override
  String get useThisLocation => 'Use this location';

  @override
  String get restoreAuto => 'Restore auto location';

  @override
  String get mapPreview => 'Map preview';

  @override
  String get fitAll => 'Fit all';

  @override
  String noCoords(int count) {
    return '$count without coordinates not shown';
  }

  @override
  String get mainLanguage => 'Main language';

  @override
  String get subLanguage => 'Sub language';

  @override
  String get operator => 'Operator';

  @override
  String get carrier => 'Carrier type';

  @override
  String get sourceType => 'Discourse type';

  @override
  String get multilingual => 'Multilingual relation';

  @override
  String noteLabel(String note) {
    return 'Note: $note';
  }

  @override
  String signMeta(String lat, String lng, String time) {
    return 'GPS: $lat, $lng · Collected: $time';
  }

  @override
  String get captureMode => 'Capture mode';

  @override
  String get captureModeNote =>
      'Controls the flow after photo & box selection. All modes share the same data structure and can be switched anytime.';

  @override
  String get modeQuick => 'Quick mode';

  @override
  String get modeQuickDesc => 'Save right after boxing; fill fields later';

  @override
  String get modeStandard => 'Standard mode';

  @override
  String get modeStandardDesc =>
      'Just pick the languages on the sign (default)';

  @override
  String get modeResearch => 'Research mode';

  @override
  String get modeResearchDesc =>
      'Full research field form for formal annotation';

  @override
  String get fieldScheme => 'Field scheme';

  @override
  String get fieldSchemeOfficial => 'Official fields';

  @override
  String get fieldSchemeCustom => 'Custom fields';

  @override
  String get savedQuick => 'Record saved. You can add fields later.';

  @override
  String get savedStandard => 'Record submitted.';

  @override
  String get savedResearch => 'Research record saved.';

  @override
  String get stdLangPrompt => 'Select the languages on this sign';

  @override
  String get stdMoreInfo => '+ Add more info';

  @override
  String get fieldScript => 'Script';

  @override
  String get fieldNote => 'Note (optional)';

  @override
  String get datasetExported => 'Dataset Package exported';

  @override
  String get select => 'Select';

  @override
  String selectedCount(int count) {
    return '$count selected';
  }

  @override
  String get selectAll => 'Select all';

  @override
  String get deselectAll => 'Deselect all';

  @override
  String deleteMultipleTitle(int count) {
    return 'Delete $count records?';
  }

  @override
  String get deleteIrreversibleBody => 'This action cannot be undone.';

  @override
  String deletedCount(int count) {
    return 'Deleted $count records';
  }

  @override
  String get sortTitle => 'Sort';

  @override
  String get sortNewestFirst => 'Newest first';

  @override
  String get sortOldestFirst => 'Oldest first';

  @override
  String get sortIdAsc => 'ID ascending';

  @override
  String get sortIdDesc => 'ID descending';

  @override
  String get filterTitle => 'Filters';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String resultsCount(int count) {
    return '$count shown';
  }

  @override
  String get filterMode => 'Mode';

  @override
  String get filterStatus => 'Status';

  @override
  String get filterArea => 'Area';

  @override
  String get filterCollector => 'Collector';

  @override
  String get filterGps => 'GPS';

  @override
  String get filterPhoto => 'Photo';

  @override
  String get filterSource => 'Source photo';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get allRecords => 'All records';

  @override
  String get newAlbum => 'New album';

  @override
  String get albumNameHint => 'Album name';

  @override
  String get renameAlbum => 'Rename album';

  @override
  String get deleteAlbum => 'Delete album';

  @override
  String deleteAlbumTitle(String name) {
    return 'Delete “$name”?';
  }

  @override
  String get deleteAlbumBody => 'Records in this album are not deleted.';

  @override
  String get addToAlbum => 'Add to album';

  @override
  String get removeFromAlbum => 'Remove from album';

  @override
  String addedToAlbum(int count, String name) {
    return 'Added $count to “$name”';
  }

  @override
  String removedFromAlbum(int count) {
    return 'Removed $count from album';
  }

  @override
  String get albumEmpty => 'No records in this album yet.';

  @override
  String get unfiled => 'Unfiled';

  @override
  String get filed => 'Filed';

  @override
  String get noUnfiledRecords => 'No unfiled records';

  @override
  String get allRecordsFiled => 'All records have been organized into albums';

  @override
  String get noFiledRecords => 'No filed records';

  @override
  String get recordsAddedToAlbumsAppearHere =>
      'Records added to albums will appear here';
}
