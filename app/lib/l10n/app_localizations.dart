import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';

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
    Locale('bn', 'BD'),
    Locale('en'),
    Locale('bn'),
  ];

  /// No description provided for @adminDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get adminDashboard;

  /// No description provided for @adminPatients.
  ///
  /// In en, this message translates to:
  /// **'Patients'**
  String get adminPatients;

  /// No description provided for @adminContent.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get adminContent;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @myPlan.
  ///
  /// In en, this message translates to:
  /// **'My Plan'**
  String get myPlan;

  /// No description provided for @resources.
  ///
  /// In en, this message translates to:
  /// **'Resources'**
  String get resources;

  /// No description provided for @progress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get progress;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @patientResources.
  ///
  /// In en, this message translates to:
  /// **'Islamic Resources'**
  String get patientResources;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @attentionRequired.
  ///
  /// In en, this message translates to:
  /// **'Something needs attention'**
  String get attentionRequired;

  /// No description provided for @genericFailure.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t complete that request. Please try again.'**
  String get genericFailure;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @goBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get goBack;

  /// No description provided for @signInEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Private care access'**
  String get signInEyebrow;

  /// No description provided for @signInWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get signInWelcome;

  /// No description provided for @signInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to see your care plan or admin workspace.'**
  String get signInSubtitle;

  /// No description provided for @signInDetails.
  ///
  /// In en, this message translates to:
  /// **'Sign in details'**
  String get signInDetails;

  /// No description provided for @signInIdentifierHelp.
  ///
  /// In en, this message translates to:
  /// **'Use your Patient ID, phone number, or administrator email.'**
  String get signInIdentifierHelp;

  /// No description provided for @signInIdentifier.
  ///
  /// In en, this message translates to:
  /// **'Patient ID, phone, or email'**
  String get signInIdentifier;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @signingIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in…'**
  String get signingIn;

  /// No description provided for @continueSecurely.
  ///
  /// In en, this message translates to:
  /// **'Continue securely'**
  String get continueSecurely;

  /// No description provided for @signInNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Sign-in is currently unavailable.'**
  String get signInNotConfigured;

  /// No description provided for @signInFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t sign in. Check your details and try again.'**
  String get signInFailed;

  /// No description provided for @patientDataPrivate.
  ///
  /// In en, this message translates to:
  /// **'Your patient information stays protected.'**
  String get patientDataPrivate;

  /// No description provided for @adminQuickActions.
  ///
  /// In en, this message translates to:
  /// **'Start a task'**
  String get adminQuickActions;

  /// No description provided for @adminQuickActionsHelp.
  ///
  /// In en, this message translates to:
  /// **'Go straight to the work you need to do.'**
  String get adminQuickActionsHelp;

  /// No description provided for @addPatient.
  ///
  /// In en, this message translates to:
  /// **'Add a patient'**
  String get addPatient;

  /// No description provided for @findPatient.
  ///
  /// In en, this message translates to:
  /// **'Find a patient'**
  String get findPatient;

  /// No description provided for @manageResources.
  ///
  /// In en, this message translates to:
  /// **'Manage resources'**
  String get manageResources;

  /// No description provided for @adminWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to your workspace'**
  String get adminWelcome;

  /// No description provided for @adminWelcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage patient care and resources from one place.'**
  String get adminWelcomeSubtitle;

  /// No description provided for @signInIdentifierError.
  ///
  /// In en, this message translates to:
  /// **'Enter your Patient ID, phone number, or admin email.'**
  String get signInIdentifierError;

  /// No description provided for @passwordError.
  ///
  /// In en, this message translates to:
  /// **'Use between 8 and 72 characters.'**
  String get passwordError;

  /// No description provided for @passwordTitle.
  ///
  /// In en, this message translates to:
  /// **'Secure your account'**
  String get passwordTitle;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @firstSignIn.
  ///
  /// In en, this message translates to:
  /// **'First sign in'**
  String get firstSignIn;

  /// No description provided for @createPrivatePassword.
  ///
  /// In en, this message translates to:
  /// **'Create your private password'**
  String get createPrivatePassword;

  /// No description provided for @passwordResetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Replace your temporary password before opening patient information.'**
  String get passwordResetSubtitle;

  /// No description provided for @temporaryPassword.
  ///
  /// In en, this message translates to:
  /// **'Temporary password'**
  String get temporaryPassword;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// No description provided for @confirmNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get confirmNewPassword;

  /// No description provided for @updatingPassword.
  ///
  /// In en, this message translates to:
  /// **'Updating…'**
  String get updatingPassword;

  /// No description provided for @secureMyAccount.
  ///
  /// In en, this message translates to:
  /// **'Save new password'**
  String get secureMyAccount;

  /// No description provided for @passwordChanged.
  ///
  /// In en, this message translates to:
  /// **'Your password has been updated.'**
  String get passwordChanged;

  /// No description provided for @passwordChangeFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t change your password. Check your details and try again.'**
  String get passwordChangeFailed;

  /// No description provided for @passwordNotMatch.
  ///
  /// In en, this message translates to:
  /// **'The two passwords do not match.'**
  String get passwordNotMatch;

  /// No description provided for @passwordSafetyHint.
  ///
  /// In en, this message translates to:
  /// **'Use at least 8 characters and avoid reusing your temporary password.'**
  String get passwordSafetyHint;
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
      <String>['bn', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'bn':
      {
        switch (locale.countryCode) {
          case 'BD':
            return AppLocalizationsBnBd();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
