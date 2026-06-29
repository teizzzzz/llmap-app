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
  /// **'AI auto-recognition'**
  String get aiAuto;

  /// No description provided for @aiAutoSub.
  ///
  /// In en, this message translates to:
  /// **'When on, fields are auto-recognized as you open each boxed sign.'**
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
  /// **'Source'**
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
  /// **'Source type'**
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
