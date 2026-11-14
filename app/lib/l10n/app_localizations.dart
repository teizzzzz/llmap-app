import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale('zh'),
  ];

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @processing.
  ///
  /// In en, this message translates to:
  /// **'Processing…'**
  String get processing;

  /// No description provided for @untitled.
  ///
  /// In en, this message translates to:
  /// **'(Untitled)'**
  String get untitled;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Linguistic landscape survey'**
  String get appTagline;

  /// No description provided for @bootOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load config'**
  String get bootOfflineTitle;

  /// No description provided for @bootOfflineBody.
  ///
  /// In en, this message translates to:
  /// **'Using local defaults; you can keep collecting.'**
  String get bootOfflineBody;

  /// No description provided for @newCollection.
  ///
  /// In en, this message translates to:
  /// **'New record'**
  String get newCollection;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get takePhoto;

  /// No description provided for @chooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get chooseFromGallery;

  /// No description provided for @recordsTitle.
  ///
  /// In en, this message translates to:
  /// **'Records'**
  String get recordsTitle;

  /// No description provided for @recordsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} records'**
  String recordsCount(int count);

  /// No description provided for @archiveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archiveTooltip;

  /// No description provided for @areaCodeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Area code'**
  String get areaCodeTooltip;

  /// No description provided for @emptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No records yet'**
  String get emptyTitle;

  /// No description provided for @emptyBody.
  ///
  /// In en, this message translates to:
  /// **'Tap \"New record\" to start documenting the linguistic landscape around you.'**
  String get emptyBody;

  /// No description provided for @savedTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved to local project'**
  String get savedTitle;

  /// No description provided for @savedBody.
  ///
  /// In en, this message translates to:
  /// **'The photo record has been saved to the current project. You can export CSV and a photo archive later for organizing, backup, or analysis.'**
  String get savedBody;

  /// No description provided for @backToMap.
  ///
  /// In en, this message translates to:
  /// **'Back to map'**
  String get backToMap;

  /// No description provided for @exporting.
  ///
  /// In en, this message translates to:
  /// **'Exporting data…'**
  String get exporting;

  /// No description provided for @unitPhotos.
  ///
  /// In en, this message translates to:
  /// **' photos'**
  String get unitPhotos;

  /// No description provided for @exportedTo.
  ///
  /// In en, this message translates to:
  /// **'Exported: {path}'**
  String exportedTo(String path);

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String exportFailed(String error);

  /// No description provided for @currentLocation.
  ///
  /// In en, this message translates to:
  /// **'Current location'**
  String get currentLocation;

  /// No description provided for @layerMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get layerMap;

  /// No description provided for @layerSatellite.
  ///
  /// In en, this message translates to:
  /// **'Satellite'**
  String get layerSatellite;

  /// No description provided for @areaDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Area code (3 chars)'**
  String get areaDialogTitle;

  /// No description provided for @deleteRecordTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete record'**
  String get deleteRecordTitle;

  /// No description provided for @deleteRecordConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete {id}?'**
  String deleteRecordConfirm(String id);

  /// No description provided for @settingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Settings saved (URL change applies next launch)'**
  String get settingsSaved;

  /// No description provided for @menu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menu;

  /// No description provided for @aboutApp.
  ///
  /// In en, this message translates to:
  /// **'About LLMap'**
  String get aboutApp;

  /// No description provided for @tutorial.
  ///
  /// In en, this message translates to:
  /// **'Tutorial'**
  String get tutorial;

  /// No description provided for @tips.
  ///
  /// In en, this message translates to:
  /// **'Tips'**
  String get tips;

  /// No description provided for @projectSettings.
  ///
  /// In en, this message translates to:
  /// **'Project settings'**
  String get projectSettings;

  /// No description provided for @exportData.
  ///
  /// In en, this message translates to:
  /// **'Export data'**
  String get exportData;

  /// No description provided for @aboutBody.
  ///
  /// In en, this message translates to:
  /// **'A linguistic landscape tool · {version}\nLocal-first: photos and records stay on your device; export CSV and a photo archive anytime. Cloud sync is planned.'**
  String aboutBody(String version);

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon.'**
  String get comingSoon;

  /// No description provided for @cropTitle.
  ///
  /// In en, this message translates to:
  /// **'Select signs ({count})'**
  String cropTitle(int count);

  /// No description provided for @undoLastBox.
  ///
  /// In en, this message translates to:
  /// **'Undo last box'**
  String get undoLastBox;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearAll;

  /// No description provided for @cropHintEmpty.
  ///
  /// In en, this message translates to:
  /// **'Drag to box each sign; if none, the whole photo becomes one record.'**
  String get cropHintEmpty;

  /// No description provided for @cropHintBoxed.
  ///
  /// In en, this message translates to:
  /// **'Boxed: {list}'**
  String cropHintBoxed(String list);

  /// No description provided for @nextFillFields.
  ///
  /// In en, this message translates to:
  /// **'Next: fill fields'**
  String get nextFillFields;

  /// No description provided for @nextWholeImage.
  ///
  /// In en, this message translates to:
  /// **'Whole photo as one record · Next'**
  String get nextWholeImage;

  /// No description provided for @gpsLocating.
  ///
  /// In en, this message translates to:
  /// **'Getting current location…'**
  String get gpsLocating;

  /// No description provided for @gpsGot.
  ///
  /// In en, this message translates to:
  /// **'Location acquired'**
  String get gpsGot;

  /// No description provided for @gpsFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t get location; please pick the spot manually'**
  String get gpsFailed;

  /// No description provided for @gpsAdjust.
  ///
  /// In en, this message translates to:
  /// **'Location off? Adjust manually'**
  String get gpsAdjust;

  /// No description provided for @gpsManual.
  ///
  /// In en, this message translates to:
  /// **'Pick manually'**
  String get gpsManual;

  /// No description provided for @gpsAdjusted.
  ///
  /// In en, this message translates to:
  /// **'Location adjusted manually'**
  String get gpsAdjusted;

  /// No description provided for @gpsReadjust.
  ///
  /// In en, this message translates to:
  /// **'Re-adjust'**
  String get gpsReadjust;

  /// No description provided for @fieldsTitle.
  ///
  /// In en, this message translates to:
  /// **'Fields · {suffix} ({index}/{total})'**
  String fieldsTitle(String suffix, int index, int total);

  /// No description provided for @reRecognize.
  ///
  /// In en, this message translates to:
  /// **'Re-recognize'**
  String get reRecognize;

  /// No description provided for @recognizing.
  ///
  /// In en, this message translates to:
  /// **'Recognizing…'**
  String get recognizing;

  /// No description provided for @aiFailed.
  ///
  /// In en, this message translates to:
  /// **'AI recognition failed: {error}'**
  String aiFailed(String error);

  /// No description provided for @stashDone.
  ///
  /// In en, this message translates to:
  /// **'Stash & finish'**
  String get stashDone;

  /// No description provided for @stashNext.
  ///
  /// In en, this message translates to:
  /// **'Stash, fill later'**
  String get stashNext;

  /// No description provided for @saveDone.
  ///
  /// In en, this message translates to:
  /// **'Save this record · Finish'**
  String get saveDone;

  /// No description provided for @saveNext.
  ///
  /// In en, this message translates to:
  /// **'Save & continue'**
  String get saveNext;

  /// No description provided for @editTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit record'**
  String get editTitle;

  /// No description provided for @deleteRecordConfirmIrreversible.
  ///
  /// In en, this message translates to:
  /// **'Delete {id}? This can\'t be undone.'**
  String deleteRecordConfirmIrreversible(String id);

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get saveChanges;

  /// No description provided for @aiAuto.
  ///
  /// In en, this message translates to:
  /// **'AI recognition'**
  String get aiAuto;

  /// No description provided for @aiAutoSub.
  ///
  /// In en, this message translates to:
  /// **'Lets AI suggest fields; you can edit the results. Works in expert mode for now; default mode will follow once the OCR approach is decided.'**
  String get aiAutoSub;

  /// No description provided for @provider.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get provider;

  /// No description provided for @apiKey.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get apiKey;

  /// No description provided for @apiKeyNote.
  ///
  /// In en, this message translates to:
  /// **'The key is stored only on your device and sent directly to the AI provider (Claude / Gemini), no PC needed.'**
  String get apiKeyNote;

  /// No description provided for @backendOptional.
  ///
  /// In en, this message translates to:
  /// **'Backend URL (optional)'**
  String get backendOptional;

  /// No description provided for @backendNote.
  ///
  /// In en, this message translates to:
  /// **'No backend needed for daily collection. Only fill this for the legacy backend flow.'**
  String get backendNote;

  /// No description provided for @backendUrl.
  ///
  /// In en, this message translates to:
  /// **'Backend URL'**
  String get backendUrl;

  /// No description provided for @backendHint.
  ///
  /// In en, this message translates to:
  /// **'Windows: http://localhost:8000 / Emulator: http://10.0.2.2:8000 / Device: http://<PC LAN IP>:8000'**
  String get backendHint;

  /// No description provided for @saveSettings.
  ///
  /// In en, this message translates to:
  /// **'Save settings'**
  String get saveSettings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get languageSystem;

  /// No description provided for @collectorId.
  ///
  /// In en, this message translates to:
  /// **'Collector ID'**
  String get collectorId;

  /// No description provided for @collectorIdNote.
  ///
  /// In en, this message translates to:
  /// **'Identifies the collector. Written into the \'collector\' slot of each SignID to prevent numbering collisions in multi-person collection. Auto-generated by default (NanoID, 8 chars, excluding look-alike 0/O/1/l/I). Editable.'**
  String get collectorIdNote;

  /// No description provided for @collectorIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Collector ID'**
  String get collectorIdLabel;

  /// No description provided for @collectorIdRegenerate.
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get collectorIdRegenerate;

  /// No description provided for @galleryTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get galleryTitle;

  /// No description provided for @langFilter.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get langFilter;

  /// No description provided for @sourceFilter.
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get sourceFilter;

  /// No description provided for @noMatch.
  ///
  /// In en, this message translates to:
  /// **'No matching records'**
  String get noMatch;

  /// No description provided for @selectLocTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm photo location'**
  String get selectLocTitle;

  /// No description provided for @selectLocBody1.
  ///
  /// In en, this message translates to:
  /// **'Your current location was detected automatically.'**
  String get selectLocBody1;

  /// No description provided for @selectLocBody2.
  ///
  /// In en, this message translates to:
  /// **'If it\'s off, drag the map to adjust where the photo was taken.'**
  String get selectLocBody2;

  /// No description provided for @coords.
  ///
  /// In en, this message translates to:
  /// **'Coords: {lat}, {lng}'**
  String coords(String lat, String lng);

  /// No description provided for @relocate.
  ///
  /// In en, this message translates to:
  /// **'Relocate'**
  String get relocate;

  /// No description provided for @gpsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t get current location'**
  String get gpsUnavailable;

  /// No description provided for @useThisLocation.
  ///
  /// In en, this message translates to:
  /// **'Use this location'**
  String get useThisLocation;

  /// No description provided for @restoreAuto.
  ///
  /// In en, this message translates to:
  /// **'Restore auto location'**
  String get restoreAuto;

  /// No description provided for @mapPreview.
  ///
  /// In en, this message translates to:
  /// **'Map preview'**
  String get mapPreview;

  /// No description provided for @fitAll.
  ///
  /// In en, this message translates to:
  /// **'Fit all'**
  String get fitAll;

  /// No description provided for @noCoords.
  ///
  /// In en, this message translates to:
  /// **'{count} without coordinates not shown'**
  String noCoords(int count);

  /// No description provided for @mainLanguage.
  ///
  /// In en, this message translates to:
  /// **'Main language'**
  String get mainLanguage;

  /// No description provided for @subLanguage.
  ///
  /// In en, this message translates to:
  /// **'Sub language'**
  String get subLanguage;

  /// No description provided for @operator.
  ///
  /// In en, this message translates to:
  /// **'Operator'**
  String get operator;

  /// No description provided for @carrier.
  ///
  /// In en, this message translates to:
  /// **'Carrier type'**
  String get carrier;

  /// No description provided for @sourceType.
  ///
  /// In en, this message translates to:
  /// **'Discourse type'**
  String get sourceType;

  /// No description provided for @multilingual.
  ///
  /// In en, this message translates to:
  /// **'Multilingual relation'**
  String get multilingual;

  /// No description provided for @noteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note: {note}'**
  String noteLabel(String note);

  /// No description provided for @signMeta.
  ///
  /// In en, this message translates to:
  /// **'GPS: {lat}, {lng} · Collected: {time}'**
  String signMeta(String lat, String lng, String time);

  /// No description provided for @captureMode.
  ///
  /// In en, this message translates to:
  /// **'Capture mode'**
  String get captureMode;

  /// No description provided for @captureModeNote.
  ///
  /// In en, this message translates to:
  /// **'Decides what you fill in after taking a photo. Both modes share the same data and can be switched anytime.'**
  String get captureModeNote;

  /// No description provided for @modeQuick.
  ///
  /// In en, this message translates to:
  /// **'Default mode'**
  String get modeQuick;

  /// No description provided for @modeQuickDesc.
  ///
  /// In en, this message translates to:
  /// **'Photo and location first; box signs if you like, languages are optional'**
  String get modeQuickDesc;

  /// No description provided for @modeStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard mode'**
  String get modeStandard;

  /// No description provided for @modeStandardDesc.
  ///
  /// In en, this message translates to:
  /// **'Just pick the languages on the sign (default)'**
  String get modeStandardDesc;

  /// No description provided for @modeResearch.
  ///
  /// In en, this message translates to:
  /// **'Expert mode'**
  String get modeResearch;

  /// No description provided for @modeResearchDesc.
  ///
  /// In en, this message translates to:
  /// **'Box each sign and fill in the full research fields'**
  String get modeResearchDesc;

  /// No description provided for @fieldScheme.
  ///
  /// In en, this message translates to:
  /// **'Field scheme'**
  String get fieldScheme;

  /// No description provided for @fieldSchemeOfficial.
  ///
  /// In en, this message translates to:
  /// **'Official fields'**
  String get fieldSchemeOfficial;

  /// No description provided for @fieldSchemeCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom fields'**
  String get fieldSchemeCustom;

  /// No description provided for @savedQuick.
  ///
  /// In en, this message translates to:
  /// **'Saved. You can add details later in Mine.'**
  String get savedQuick;

  /// No description provided for @savedStandard.
  ///
  /// In en, this message translates to:
  /// **'Record submitted.'**
  String get savedStandard;

  /// No description provided for @savedResearch.
  ///
  /// In en, this message translates to:
  /// **'Research record saved.'**
  String get savedResearch;

  /// No description provided for @stdLangPrompt.
  ///
  /// In en, this message translates to:
  /// **'Select the languages on this sign'**
  String get stdLangPrompt;

  /// No description provided for @stdMoreInfo.
  ///
  /// In en, this message translates to:
  /// **'+ Add more info'**
  String get stdMoreInfo;

  /// No description provided for @fieldScript.
  ///
  /// In en, this message translates to:
  /// **'Script'**
  String get fieldScript;

  /// No description provided for @fieldNote.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get fieldNote;

  /// No description provided for @datasetExported.
  ///
  /// In en, this message translates to:
  /// **'Dataset Package exported'**
  String get datasetExported;

  /// No description provided for @select.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get select;

  /// No description provided for @selectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selectedCount(int count);

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selectAll;

  /// No description provided for @deselectAll.
  ///
  /// In en, this message translates to:
  /// **'Deselect all'**
  String get deselectAll;

  /// No description provided for @deleteMultipleTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} records?'**
  String deleteMultipleTitle(int count);

  /// No description provided for @deleteIrreversibleBody.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get deleteIrreversibleBody;

  /// No description provided for @deletedCount.
  ///
  /// In en, this message translates to:
  /// **'Deleted {count} records'**
  String deletedCount(int count);

  /// No description provided for @sortTitle.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sortTitle;

  /// No description provided for @sortNewestFirst.
  ///
  /// In en, this message translates to:
  /// **'Newest first'**
  String get sortNewestFirst;

  /// No description provided for @sortOldestFirst.
  ///
  /// In en, this message translates to:
  /// **'Oldest first'**
  String get sortOldestFirst;

  /// No description provided for @sortIdAsc.
  ///
  /// In en, this message translates to:
  /// **'ID ascending'**
  String get sortIdAsc;

  /// No description provided for @sortIdDesc.
  ///
  /// In en, this message translates to:
  /// **'ID descending'**
  String get sortIdDesc;

  /// No description provided for @filterTitle.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filterTitle;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get clearFilters;

  /// No description provided for @resultsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} shown'**
  String resultsCount(int count);

  /// No description provided for @filterMode.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get filterMode;

  /// No description provided for @filterStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get filterStatus;

  /// No description provided for @filterArea.
  ///
  /// In en, this message translates to:
  /// **'Area'**
  String get filterArea;

  /// No description provided for @filterCollector.
  ///
  /// In en, this message translates to:
  /// **'Collector'**
  String get filterCollector;

  /// No description provided for @filterGps.
  ///
  /// In en, this message translates to:
  /// **'GPS'**
  String get filterGps;

  /// No description provided for @filterPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get filterPhoto;

  /// No description provided for @filterSource.
  ///
  /// In en, this message translates to:
  /// **'Source photo'**
  String get filterSource;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @allRecords.
  ///
  /// In en, this message translates to:
  /// **'All records'**
  String get allRecords;

  /// No description provided for @newAlbum.
  ///
  /// In en, this message translates to:
  /// **'New album'**
  String get newAlbum;

  /// No description provided for @albumNameHint.
  ///
  /// In en, this message translates to:
  /// **'Album name'**
  String get albumNameHint;

  /// No description provided for @renameAlbum.
  ///
  /// In en, this message translates to:
  /// **'Rename album'**
  String get renameAlbum;

  /// No description provided for @deleteAlbum.
  ///
  /// In en, this message translates to:
  /// **'Delete album'**
  String get deleteAlbum;

  /// No description provided for @deleteAlbumTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete “{name}”?'**
  String deleteAlbumTitle(String name);

  /// No description provided for @deleteAlbumBody.
  ///
  /// In en, this message translates to:
  /// **'Records in this album are not deleted.'**
  String get deleteAlbumBody;

  /// No description provided for @addToAlbum.
  ///
  /// In en, this message translates to:
  /// **'Add to album'**
  String get addToAlbum;

  /// No description provided for @removeFromAlbum.
  ///
  /// In en, this message translates to:
  /// **'Remove from album'**
  String get removeFromAlbum;

  /// No description provided for @addedToAlbum.
  ///
  /// In en, this message translates to:
  /// **'Added {count} to “{name}”'**
  String addedToAlbum(int count, String name);

  /// No description provided for @removedFromAlbum.
  ///
  /// In en, this message translates to:
  /// **'Removed {count} from album'**
  String removedFromAlbum(int count);

  /// No description provided for @albumEmpty.
  ///
  /// In en, this message translates to:
  /// **'No records in this album yet.'**
  String get albumEmpty;

  /// No description provided for @unfiled.
  ///
  /// In en, this message translates to:
  /// **'Unfiled'**
  String get unfiled;

  /// No description provided for @filed.
  ///
  /// In en, this message translates to:
  /// **'Filed'**
  String get filed;

  /// No description provided for @noUnfiledRecords.
  ///
  /// In en, this message translates to:
  /// **'No unfiled records'**
  String get noUnfiledRecords;

  /// No description provided for @allRecordsFiled.
  ///
  /// In en, this message translates to:
  /// **'All records have been organized into albums'**
  String get allRecordsFiled;

  /// No description provided for @noFiledRecords.
  ///
  /// In en, this message translates to:
  /// **'No filed records'**
  String get noFiledRecords;

  /// No description provided for @recordsAddedToAlbumsAppearHere.
  ///
  /// In en, this message translates to:
  /// **'Records added to albums will appear here'**
  String get recordsAddedToAlbumsAppearHere;

  /// No description provided for @exportDataset.
  ///
  /// In en, this message translates to:
  /// **'Export Dataset Package'**
  String get exportDataset;

  /// No description provided for @exportScopeCurrentView.
  ///
  /// In en, this message translates to:
  /// **'Current view'**
  String get exportScopeCurrentView;

  /// No description provided for @exportScopeSelected.
  ///
  /// In en, this message translates to:
  /// **'Selected records'**
  String get exportScopeSelected;

  /// No description provided for @exportScopeAlbum.
  ///
  /// In en, this message translates to:
  /// **'Current album'**
  String get exportScopeAlbum;

  /// No description provided for @exportConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Export 1 record?} other{Export {count} records?}}'**
  String exportConfirmTitle(int count);

  /// No description provided for @exportConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This will create a Dataset Package containing only the selected records and required photos.'**
  String get exportConfirmBody;

  /// No description provided for @noRecordsToExport.
  ///
  /// In en, this message translates to:
  /// **'No records to export.'**
  String get noRecordsToExport;

  /// No description provided for @exportAction.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get exportAction;

  /// No description provided for @exportSelected.
  ///
  /// In en, this message translates to:
  /// **'Export selected'**
  String get exportSelected;

  /// No description provided for @exportPickAlbum.
  ///
  /// In en, this message translates to:
  /// **'Choose an album…'**
  String get exportPickAlbum;

  /// No description provided for @permissionDeniedTitle.
  ///
  /// In en, this message translates to:
  /// **'Permission needed'**
  String get permissionDeniedTitle;

  /// No description provided for @cameraDeniedBody.
  ///
  /// In en, this message translates to:
  /// **'Camera access is off. Enable it in Settings → LLMap → Camera to take photos.'**
  String get cameraDeniedBody;

  /// No description provided for @photoDeniedBody.
  ///
  /// In en, this message translates to:
  /// **'Photo library access is off. Enable it in Settings → LLMap → Photos to import images.'**
  String get photoDeniedBody;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openSettings;

  /// No description provided for @discardTitle.
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes'**
  String get discardTitle;

  /// No description provided for @discardEditBody.
  ///
  /// In en, this message translates to:
  /// **'Discard the changes and close?'**
  String get discardEditBody;

  /// No description provided for @discardCaptureBody.
  ///
  /// In en, this message translates to:
  /// **'Abandon this capture? Entered fields and cropped photos will not be saved.'**
  String get discardCaptureBody;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @processFailed.
  ///
  /// In en, this message translates to:
  /// **'Processing failed: {error}'**
  String processFailed(String error);

  /// No description provided for @customAddHint.
  ///
  /// In en, this message translates to:
  /// **'+ Add custom'**
  String get customAddHint;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @fieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get fieldName;

  /// No description provided for @fieldTextuality.
  ///
  /// In en, this message translates to:
  /// **'Text presence'**
  String get fieldTextuality;

  /// No description provided for @fieldDecorLang.
  ///
  /// In en, this message translates to:
  /// **'Decorative language'**
  String get fieldDecorLang;

  /// No description provided for @fieldSpatial.
  ///
  /// In en, this message translates to:
  /// **'Spatial layer'**
  String get fieldSpatial;

  /// No description provided for @fieldTemporality.
  ///
  /// In en, this message translates to:
  /// **'Temporality'**
  String get fieldTemporality;

  /// No description provided for @fieldLegibility.
  ///
  /// In en, this message translates to:
  /// **'Legibility'**
  String get fieldLegibility;

  /// No description provided for @fieldOverwrite.
  ///
  /// In en, this message translates to:
  /// **'Overwriting'**
  String get fieldOverwrite;

  /// No description provided for @fieldDiscourse.
  ///
  /// In en, this message translates to:
  /// **'Discourse type'**
  String get fieldDiscourse;

  /// No description provided for @fieldQuality.
  ///
  /// In en, this message translates to:
  /// **'Production quality'**
  String get fieldQuality;

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPending;

  /// No description provided for @statusAi.
  ///
  /// In en, this message translates to:
  /// **'AI draft'**
  String get statusAi;

  /// No description provided for @statusHumanReviewed.
  ///
  /// In en, this message translates to:
  /// **'Reviewed'**
  String get statusHumanReviewed;

  /// No description provided for @statusFinal.
  ///
  /// In en, this message translates to:
  /// **'Final'**
  String get statusFinal;

  /// No description provided for @fieldPlacement.
  ///
  /// In en, this message translates to:
  /// **'Placement'**
  String get fieldPlacement;

  /// No description provided for @navExplore.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get navExplore;

  /// No description provided for @navMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get navMap;

  /// No description provided for @navMine.
  ///
  /// In en, this message translates to:
  /// **'Mine'**
  String get navMine;

  /// No description provided for @tabFeed.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get tabFeed;

  /// No description provided for @tabThemes.
  ///
  /// In en, this message translates to:
  /// **'Themes'**
  String get tabThemes;

  /// No description provided for @toolLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get toolLanguage;

  /// No description provided for @toolColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get toolColor;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search ID or notes'**
  String get searchHint;

  /// No description provided for @photosCount.
  ///
  /// In en, this message translates to:
  /// **'{count} photos'**
  String photosCount(int count);

  /// No description provided for @exploreNoSourceTitle.
  ///
  /// In en, this message translates to:
  /// **'Explore data not connected'**
  String get exploreNoSourceTitle;

  /// No description provided for @exploreNoSourceBody.
  ///
  /// In en, this message translates to:
  /// **'Add the explore data address in Settings to browse the shared photo collection. Showing your own records for now.'**
  String get exploreNoSourceBody;

  /// No description provided for @exploreLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading explore data…'**
  String get exploreLoading;

  /// No description provided for @exploreLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load explore data: {error}'**
  String exploreLoadFailed(String error);

  /// No description provided for @goToSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get goToSettings;

  /// No description provided for @themesNeedSource.
  ///
  /// In en, this message translates to:
  /// **'Themes are built from the explore data. Add its address in Settings.'**
  String get themesNeedSource;

  /// No description provided for @mapInView.
  ///
  /// In en, this message translates to:
  /// **'{count} photos in the current map view'**
  String mapInView(int count);

  /// No description provided for @mapInViewCapped.
  ///
  /// In en, this message translates to:
  /// **'Showing the first {count}. Zoom in to see more.'**
  String mapInViewCapped(int count);

  /// No description provided for @mapInViewEmpty.
  ///
  /// In en, this message translates to:
  /// **'No photos here. Move or zoom out the map.'**
  String get mapInViewEmpty;

  /// No description provided for @backToList.
  ///
  /// In en, this message translates to:
  /// **'Back to list'**
  String get backToList;

  /// No description provided for @showOnMap.
  ///
  /// In en, this message translates to:
  /// **'Show on map'**
  String get showOnMap;

  /// No description provided for @editRecord.
  ///
  /// In en, this message translates to:
  /// **'Add details'**
  String get editRecord;

  /// No description provided for @sourceMine.
  ///
  /// In en, this message translates to:
  /// **'Mine'**
  String get sourceMine;

  /// No description provided for @sourceShared.
  ///
  /// In en, this message translates to:
  /// **'Shared'**
  String get sourceShared;

  /// No description provided for @capturedAt.
  ///
  /// In en, this message translates to:
  /// **'Captured'**
  String get capturedAt;

  /// No description provided for @locationLabel.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get locationLabel;

  /// No description provided for @noLocation.
  ///
  /// In en, this message translates to:
  /// **'No location'**
  String get noLocation;

  /// No description provided for @languagesLabel.
  ///
  /// In en, this message translates to:
  /// **'Languages'**
  String get languagesLabel;

  /// No description provided for @myRecordsTitle.
  ///
  /// In en, this message translates to:
  /// **'My records'**
  String get myRecordsTitle;

  /// No description provided for @manageArchive.
  ///
  /// In en, this message translates to:
  /// **'Albums & batch actions'**
  String get manageArchive;

  /// No description provided for @moreActions.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get moreActions;

  /// No description provided for @exploreDataUrl.
  ///
  /// In en, this message translates to:
  /// **'Explore data address'**
  String get exploreDataUrl;

  /// No description provided for @exploreDataUrlNote.
  ///
  /// In en, this message translates to:
  /// **'Address of an llmap-view folder (on a NAS or your PC). Leave empty to explore only your own records.'**
  String get exploreDataUrlNote;

  /// No description provided for @advanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advanced;

  /// No description provided for @aboutUs.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutUs;

  /// No description provided for @aboutUsBody.
  ///
  /// In en, this message translates to:
  /// **'LLMap · {version}\nA graduation project on the linguistic landscape of Shin-Ōkubo, Tokyo. It helps anyone discover and record writing on the street, while keeping a full collection workflow for researchers.\nPhotos and records stay on this device and can be exported at any time.'**
  String aboutUsBody(String version);

  /// No description provided for @quickLangPrompt.
  ///
  /// In en, this message translates to:
  /// **'Which languages appear? (optional)'**
  String get quickLangPrompt;

  /// No description provided for @quickHint.
  ///
  /// In en, this message translates to:
  /// **'A photo and a location are enough. You can add details later in Mine.'**
  String get quickHint;

  /// No description provided for @quickSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get quickSave;

  /// No description provided for @statusRawTag.
  ///
  /// In en, this message translates to:
  /// **'To complete'**
  String get statusRawTag;

  /// No description provided for @statusSubmittedTag.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get statusSubmittedTag;

  /// No description provided for @colorRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get colorRed;

  /// No description provided for @colorOrange.
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get colorOrange;

  /// No description provided for @colorYellow.
  ///
  /// In en, this message translates to:
  /// **'Yellow'**
  String get colorYellow;

  /// No description provided for @colorGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get colorGreen;

  /// No description provided for @colorBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get colorBlue;

  /// No description provided for @colorPurple.
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get colorPurple;

  /// No description provided for @colorPink.
  ///
  /// In en, this message translates to:
  /// **'Pink'**
  String get colorPink;

  /// No description provided for @colorBrown.
  ///
  /// In en, this message translates to:
  /// **'Brown'**
  String get colorBrown;

  /// No description provided for @colorWhite.
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get colorWhite;

  /// No description provided for @colorGray.
  ///
  /// In en, this message translates to:
  /// **'Gray'**
  String get colorGray;

  /// No description provided for @colorBlack.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get colorBlack;

  /// No description provided for @langJa.
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get langJa;

  /// No description provided for @langEn.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get langEn;

  /// No description provided for @langZh.
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get langZh;

  /// No description provided for @langKo.
  ///
  /// In en, this message translates to:
  /// **'Korean'**
  String get langKo;

  /// No description provided for @langVi.
  ///
  /// In en, this message translates to:
  /// **'Vietnamese'**
  String get langVi;

  /// No description provided for @langNe.
  ///
  /// In en, this message translates to:
  /// **'Nepali'**
  String get langNe;

  /// No description provided for @langOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get langOther;

  /// No description provided for @langNone.
  ///
  /// In en, this message translates to:
  /// **'No text language'**
  String get langNone;

  /// No description provided for @theme1Title.
  ///
  /// In en, this message translates to:
  /// **'The red of Chinese signs'**
  String get theme1Title;

  /// No description provided for @theme1Sub.
  ///
  /// In en, this message translates to:
  /// **'Chinese-led, with red as the main color'**
  String get theme1Sub;

  /// No description provided for @theme2Title.
  ///
  /// In en, this message translates to:
  /// **'A handwritten street'**
  String get theme2Title;

  /// No description provided for @theme2Sub.
  ///
  /// In en, this message translates to:
  /// **'Handmade notices and signs'**
  String get theme2Sub;

  /// No description provided for @theme3Title.
  ///
  /// In en, this message translates to:
  /// **'Temporary and seasonal'**
  String get theme3Title;

  /// No description provided for @theme3Sub.
  ///
  /// In en, this message translates to:
  /// **'Posters and banners that come and go'**
  String get theme3Sub;

  /// No description provided for @theme4Title.
  ///
  /// In en, this message translates to:
  /// **'Rules and prohibitions'**
  String get theme4Title;

  /// No description provided for @theme4Sub.
  ///
  /// In en, this message translates to:
  /// **'The language of \"please don\'t\" and \"no\"'**
  String get theme4Sub;

  /// No description provided for @theme5Title.
  ///
  /// In en, this message translates to:
  /// **'Word-for-word translation'**
  String get theme5Title;

  /// No description provided for @theme5Sub.
  ///
  /// In en, this message translates to:
  /// **'Multilingual signs that copy each other'**
  String get theme5Sub;

  /// No description provided for @theme6Title.
  ///
  /// In en, this message translates to:
  /// **'Vietnamese and Nepali'**
  String get theme6Title;

  /// No description provided for @theme6Sub.
  ///
  /// In en, this message translates to:
  /// **'Other voices of Shin-Ōkubo'**
  String get theme6Sub;

  /// No description provided for @theme7Title.
  ///
  /// In en, this message translates to:
  /// **'The most vivid signs'**
  String get theme7Title;

  /// No description provided for @theme7Sub.
  ///
  /// In en, this message translates to:
  /// **'The most colorful group'**
  String get theme7Sub;

  /// No description provided for @theme8Title.
  ///
  /// In en, this message translates to:
  /// **'Signs on black'**
  String get theme8Title;

  /// No description provided for @theme8Sub.
  ///
  /// In en, this message translates to:
  /// **'Text on dark backgrounds'**
  String get theme8Sub;

  /// No description provided for @theme9Title.
  ///
  /// In en, this message translates to:
  /// **'Stickers and notes'**
  String get theme9Title;

  /// No description provided for @theme9Sub.
  ///
  /// In en, this message translates to:
  /// **'Little papers stuck anywhere'**
  String get theme9Sub;

  /// No description provided for @viewFeed.
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get viewFeed;

  /// No description provided for @viewCanvas.
  ///
  /// In en, this message translates to:
  /// **'Roam'**
  String get viewCanvas;

  /// No description provided for @layoutWall.
  ///
  /// In en, this message translates to:
  /// **'Wall'**
  String get layoutWall;

  /// No description provided for @layoutGroup.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get layoutGroup;

  /// No description provided for @layoutWheel.
  ///
  /// In en, this message translates to:
  /// **'Color wheel'**
  String get layoutWheel;

  /// No description provided for @layoutHueLight.
  ///
  /// In en, this message translates to:
  /// **'Hue × lightness'**
  String get layoutHueLight;

  /// No description provided for @groupBy.
  ///
  /// In en, this message translates to:
  /// **'Group by'**
  String get groupBy;

  /// No description provided for @canvasHint.
  ///
  /// In en, this message translates to:
  /// **'Pinch to zoom · drag to roam · tap a photo to open'**
  String get canvasHint;

  /// No description provided for @exploreNext.
  ///
  /// In en, this message translates to:
  /// **'What to explore next?'**
  String get exploreNext;

  /// No description provided for @relColorName.
  ///
  /// In en, this message translates to:
  /// **'Similar colors'**
  String get relColorName;

  /// No description provided for @relSceneName.
  ///
  /// In en, this message translates to:
  /// **'Same scene'**
  String get relSceneName;

  /// No description provided for @relNearName.
  ///
  /// In en, this message translates to:
  /// **'Nearby'**
  String get relNearName;

  /// No description provided for @relLangName.
  ///
  /// In en, this message translates to:
  /// **'Same languages'**
  String get relLangName;

  /// No description provided for @relTypeName.
  ///
  /// In en, this message translates to:
  /// **'Discourse & carrier'**
  String get relTypeName;

  /// No description provided for @relContrastName.
  ///
  /// In en, this message translates to:
  /// **'Color contrast'**
  String get relContrastName;

  /// No description provided for @relColorSub.
  ///
  /// In en, this message translates to:
  /// **'The {count} with the closest palettes'**
  String relColorSub(int count);

  /// No description provided for @relSceneSub.
  ///
  /// In en, this message translates to:
  /// **'{count} more signs from the same street photo'**
  String relSceneSub(int count);

  /// No description provided for @relNearSub.
  ///
  /// In en, this message translates to:
  /// **'{count} within {meters} m'**
  String relNearSub(int meters, int count);

  /// No description provided for @relLangTitle.
  ///
  /// In en, this message translates to:
  /// **'Also {langs}'**
  String relLangTitle(String langs);

  /// No description provided for @relLangSub.
  ///
  /// In en, this message translates to:
  /// **'{count} with exactly the same language mix'**
  String relLangSub(int count);

  /// No description provided for @relTypeSub.
  ///
  /// In en, this message translates to:
  /// **'{count} with the same discourse and carrier'**
  String relTypeSub(int count);

  /// No description provided for @relContrastSub.
  ///
  /// In en, this message translates to:
  /// **'Also {lang}, but in completely different colors'**
  String relContrastSub(String lang);

  /// No description provided for @nextChooseLangs.
  ///
  /// In en, this message translates to:
  /// **'Next: languages'**
  String get nextChooseLangs;

  /// No description provided for @manageShort.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get manageShort;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
