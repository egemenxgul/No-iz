import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum AppLanguage { tr, en, de }

class LocaleState {
  final AppLanguage language;
  
  LocaleState(this.language);
}

class LocaleNotifier extends Notifier<LocaleState> {
  final _storage = const FlutterSecureStorage();
  
  AppLanguage _getDeviceDefaultLanguage() {
    try {
      final deviceLocale = ui.PlatformDispatcher.instance.locale.languageCode.toLowerCase();
      if (deviceLocale.startsWith('tr')) {
        return AppLanguage.tr;
      } else if (deviceLocale.startsWith('de')) {
        return AppLanguage.de;
      }
    } catch (_) {}
    return AppLanguage.en;
  }
  
  @override
  LocaleState build() {
    _loadLanguage();
    return LocaleState(_getDeviceDefaultLanguage());
  }
  
  Future<void> _loadLanguage() async {
    final langStr = await _storage.read(key: 'app_language');
    if (langStr == 'en') {
      state = LocaleState(AppLanguage.en);
    } else if (langStr == 'tr') {
      state = LocaleState(AppLanguage.tr);
    } else if (langStr == 'de') {
      state = LocaleState(AppLanguage.de);
    } else {
      // First launch, secure storage is empty.
      // Auto-detect and write it to secure storage for future persistence.
      final defaultLang = _getDeviceDefaultLanguage();
      await _storage.write(key: 'app_language', value: defaultLang.name);
      state = LocaleState(defaultLang);
    }
  }
  
  Future<void> toggleLanguage() async {
    if (state.language == AppLanguage.tr) {
      await _storage.write(key: 'app_language', value: 'de');
      state = LocaleState(AppLanguage.de);
    } else if (state.language == AppLanguage.de) {
      await _storage.write(key: 'app_language', value: 'en');
      state = LocaleState(AppLanguage.en);
    } else {
      await _storage.write(key: 'app_language', value: 'tr');
      state = LocaleState(AppLanguage.tr);
    }
  }
  
  String translate(String key) {
    final dict = _translations[state.language];
    return dict?[key] ?? _translations[AppLanguage.tr]?[key] ?? key;
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, LocaleState>(LocaleNotifier.new);

extension LocaleExtension on BuildContext {
  String tr(WidgetRef ref, String key) {
    return ref.watch(localeProvider.notifier).translate(key);
  }
}

const _translations = {
  AppLanguage.tr: {
    'settings': 'Ayarlar',
    'accounts': 'Hesaplar',
    'add_account': 'Hesap Ekle',
    'profile': 'Profil',
    'profile_info': 'Profil Bilgileri',
    'profile_info_sub': 'Ad soyad, kullanıcı adı',
    'backup_cloud': 'Yedekleme (Bulut)',
    'auto_backup': 'Otomatik Yedekleme',
    'auto_backup_sub': 'Günlük olarak buluta yedekle',
    'include_media': 'Medyaları Dahil Et',
    'include_media_sub': 'Fotoğraf ve videoları da yedekle',
    'backup_now': 'Şimdi Yedekle',
    'last_backup': 'Son yedekleme: Bugün',
    'privacy_security': 'Gizlilik ve Güvenlik',
    'privacy_sub': 'Uçtan uca şifreleme anahtarları',
    'logout': 'Çıkış Yap',
    'active': 'Aktif',
    'switch_account_tap': 'Geçmek için tıkla',
    'profile_details': 'Profil Detayları',
    'display_name': 'Görünen Ad',
    'username': 'Kullanıcı Adı',
    'about': 'Hakkında',
    'active_account': 'Aktif Hesap',
    'switch_to_account': 'Bu Hesaba Geçiş Yap',
    'logout_this_account': 'Hesaptan Çıkış Yap',
    'save_changes': 'Değişiklikleri Kaydet',
    'username_readonly': 'Kullanıcı adınız değiştirilemez.',
    'saved_successfully': 'Profil başarıyla güncellendi!',
    'error': 'Hata',
    'success': 'Başarılı',
    'choose_avatar': 'Profil Resmi Seç',
    'avatar_url': 'Profil Resmi URL',
    'avatar_presets': 'Görsel Seçenekleri',
    'loading': 'Yükleniyor...',
    'language_setting': 'Dil / Language',
    'language_current': 'Türkçe (TR)',
    'err_display_name_length': 'Görünen ad boş olamaz!',
    'welcome_back': 'Tekrar Hoş Geldiniz',
    'tagline': 'Uçtan uca şifreli ve tamamen izsiz sohbet.',
    'please_fill_field': 'Lütfen bu alanı doldurun',
    'please_enter_password': 'Lütfen şifrenizi girin',
    'login': 'Giriş Yap',
    'no_account': 'Henüz bir hesabınız yok mu?',
    'register': 'Kayıt Ol',
    'secure_keys_fail': 'Güvenli anahtar çifti üretilemedi',
    'registration_success': 'Kayıt Başarılı! Şimdi giriş yapabilirsiniz.',
    'create_new_account': 'Yeni Hesap Oluştur',
    'security_keys_notice': 'Güvenliğiniz için cihazınızda şifreleme anahtarları üretilecektir.',
    'please_enter_username': 'Lütfen bir kullanıcı adı girin',
    'username_min_length': 'Kullanıcı adı en az 3 karakter olmalıdır',
    'email': 'E-posta',
    'please_enter_email': 'Lütfen e-posta adresinizi girin',
    'valid_email_error': 'Lütfen geçerli bir e-posta adresi girin',
    'please_enter_display_name': 'Lütfen görünen adınızı girin',
    'password': 'Şifre',
    'password_min_length': 'Şifre en az 8 karakter olmalıdır',
    'invite_code': 'Davet Kodu',
    'please_enter_invite_code': 'Lütfen davet kodunuzu girin',
    'phone_number': 'Telefon Numarası',
    'phone_number_optional': 'Telefon Numarası (İsteğe Bağlı)',
    'phone_number_invalid': 'Lütfen geçerli bir telefon numarası girin',
    'select_contact': 'Kişi Seç',
    'contacts': 'Kişiler',
    'no_contacts_found': 'Kayıtlı kişi bulunamadı',
    'invite_friend': 'Davet Et',
    'phonebook_contacts': 'Rehberimdeki Kişiler',
    'invite': 'Davet Et',
    'invited': 'Davet Edildi',
    'global_search': 'Tüm Kullanıcıları Ara',
    'friends': 'Arkadaşlar',
    'requests': 'İstekler',
    'blocked': 'Engellenenler',
    'no_friends_yet': 'Henüz arkadaşınız yok',
    'no_requests_yet': 'Bekleyen istek yok',
    'no_blocked_yet': 'Engellenen kullanıcı yok',
    'unblock': 'Engeli Kaldır',
    'accept': 'Kabul Et',
    'reject': 'Reddet',
    'block': 'Engelle',
    'social_hub': 'Sosyal',
    'friendship_accepted': 'Arkadaşlık isteği kabul edildi',
    'friendship_rejected': 'Arkadaşlık isteği reddedildi',
    'user_unblocked': 'Kullanıcının engeli kaldırıldı',
    'user_blocked': 'Kullanıcı engellendi',
    'group': 'Grup',
    'new_group': 'Yeni Grup',
    'stories': 'Hikayeler',
    'messages': 'Mesajlar',
    'calls': 'Aramalar',
    'communities': 'Topluluklar',
    'search': 'Ara...',
    'cancel': 'İptal',
    'save': 'Kaydet',
    'dialing': 'Aranıyor...',
    'group_video_call': 'Grup Görüntülü Arama',
    'video_call_started': 'Görüntülü Arama Başlatıldı',
    'group_voice_call': 'Grup Sesli Arama',
    'voice_call_started': 'Sesli Arama Başlatıldı',
    'waiting_participants': 'Katılımcılar bekleniyor...',
    'add_participant_to_call': 'Aramaya Katılımcı Ekle',
    'search_contact': 'Kişi ara...',
    'contact_not_found': 'Kişi bulunamadı',
    'invited_to_call': 'Aramaya davet edildi',
    'incoming_video_call': 'Gelen Görüntülü Arama',
    'incoming_voice_call': 'Gelen Sesli Arama',
    'calling_via_iz': 'iz üzerinden aranıyor...',
    'answer': 'Cevapla',
  },
  AppLanguage.en: {
    'settings': 'Settings',
    'accounts': 'Accounts',
    'add_account': 'Add Account',
    'profile': 'Profile',
    'profile_info': 'Profile Information',
    'profile_info_sub': 'Display name, username',
    'backup_cloud': 'Backup (Cloud)',
    'auto_backup': 'Automatic Backup',
    'auto_backup_sub': 'Daily backup to cloud',
    'include_media': 'Include Media',
    'include_media_sub': 'Backup photos and videos too',
    'backup_now': 'Backup Now',
    'last_backup': 'Last backup: Today',
    'privacy_security': 'Privacy & Security',
    'privacy_sub': 'End-to-end encryption keys',
    'logout': 'Log Out',
    'active': 'Active',
    'switch_account_tap': 'Tap to switch',
    'profile_details': 'Profile Details',
    'display_name': 'Display Name',
    'username': 'Username',
    'about': 'About',
    'active_account': 'Active Account',
    'switch_to_account': 'Switch to This Account',
    'logout_this_account': 'Log Out of This Account',
    'save_changes': 'Save Changes',
    'username_readonly': 'Your username cannot be changed.',
    'saved_successfully': 'Profile updated successfully!',
    'error': 'Error',
    'success': 'Success',
    'choose_avatar': 'Select Profile Picture',
    'avatar_url': 'Profile Picture URL',
    'avatar_presets': 'Preset Avatars',
    'loading': 'Loading...',
    'language_setting': 'Language / Dil',
    'language_current': 'English (EN)',
    'err_display_name_length': 'Display name cannot be empty!',
    'welcome_back': 'Welcome Back',
    'tagline': 'End-to-end encrypted and completely traceless chat.',
    'please_fill_field': 'Please fill this field',
    'please_enter_password': 'Please enter your password',
    'login': 'Log In',
    'no_account': "Don't have an account yet?",
    'register': 'Register',
    'secure_keys_fail': 'Failed to generate secure key pair',
    'registration_success': 'Registration successful! You can now log in.',
    'create_new_account': 'Create New Account',
    'security_keys_notice': 'For your security, encryption keys will be generated on your device.',
    'please_enter_username': 'Please enter a username',
    'username_min_length': 'Username must be at least 3 characters',
    'email': 'Email',
    'please_enter_email': 'Please enter your email address',
    'valid_email_error': 'Please enter a valid email address',
    'please_enter_display_name': 'Please enter your display name',
    'password': 'Password',
    'password_min_length': 'Password must be at least 8 characters',
    'invite_code': 'Invite Code',
    'please_enter_invite_code': 'Please enter your invite code',
    'phone_number': 'Phone Number',
    'phone_number_optional': 'Phone Number (Optional)',
    'phone_number_invalid': 'Please enter a valid phone number',
    'select_contact': 'Select Contact',
    'contacts': 'Contacts',
    'no_contacts_found': 'No contacts found',
    'invite_friend': 'Invite',
    'phonebook_contacts': 'My Contacts',
    'invite': 'Invite',
    'invited': 'Invited',
    'global_search': 'Search All Users',
    'friends': 'Friends',
    'requests': 'Requests',
    'blocked': 'Blocked',
    'no_friends_yet': 'No friends yet',
    'no_requests_yet': 'No pending requests',
    'no_blocked_yet': 'No blocked users',
    'unblock': 'Unblock',
    'accept': 'Accept',
    'reject': 'Reject',
    'block': 'Block',
    'social_hub': 'Social',
    'friendship_accepted': 'Friend request accepted',
    'friendship_rejected': 'Friend request rejected',
    'user_unblocked': 'User unblocked successfully',
    'user_blocked': 'User blocked successfully',
    'group': 'Group',
    'new_group': 'New Group',
    'stories': 'Stories',
    'messages': 'Messages',
    'calls': 'Calls',
    'communities': 'Communities',
    'search': 'Search...',
    'cancel': 'Cancel',
    'save': 'Save',
    'dialing': 'Dialing...',
    'group_video_call': 'Group Video Call',
    'video_call_started': 'Video Call Started',
    'group_voice_call': 'Group Voice Call',
    'voice_call_started': 'Voice Call Started',
    'waiting_participants': 'Waiting for participants...',
    'add_participant_to_call': 'Add Participant to Call',
    'search_contact': 'Search contact...',
    'contact_not_found': 'Contact not found',
    'invited_to_call': 'Invited to call',
    'incoming_video_call': 'Incoming Video Call',
    'incoming_voice_call': 'Incoming Voice Call',
    'calling_via_iz': 'Calling via iz...',
    'answer': 'Answer',
  },
  AppLanguage.de: {
    'settings': 'Einstellungen',
    'accounts': 'Konten',
    'add_account': 'Konto hinzufügen',
    'profile': 'Profil',
    'profile_info': 'Profilinformationen',
    'profile_info_sub': 'Anzeigename, Benutzername',
    'backup_cloud': 'Backup (Cloud)',
    'auto_backup': 'Automatisches Backup',
    'auto_backup_sub': 'Tägliches Backup in die Cloud',
    'include_media': 'Medien einschließen',
    'include_media_sub': 'Auch Fotos und Videos sichern',
    'backup_now': 'Jetzt sichern',
    'last_backup': 'Letztes Backup: Heute',
    'privacy_security': 'Datenschutz & Sicherheit',
    'privacy_sub': 'Ende-zu-Ende-Verschlüsselung',
    'logout': 'Abmelden',
    'active': 'Aktiv',
    'switch_account_tap': 'Zum Wechseln tippen',
    'profile_details': 'Profildetails',
    'display_name': 'Anzeigename',
    'username': 'Benutzername',
    'about': 'Über',
    'active_account': 'Aktives Konto',
    'switch_to_account': 'Zu diesem Konto wechseln',
    'logout_this_account': 'Von diesem Konto abmelden',
    'save_changes': 'Änderungen speichern',
    'username_readonly': 'Ihr Benutzername kann nicht geändert werden.',
    'saved_successfully': 'Profil erfolgreich aktualisiert!',
    'error': 'Fehler',
    'success': 'Erfolg',
    'choose_avatar': 'Profilbild auswählen',
    'avatar_url': 'Profilbild-URL',
    'avatar_presets': 'Vorlagen',
    'loading': 'Wird geladen...',
    'language_setting': 'Sprache / Language',
    'language_current': 'Deutsch (DE)',
    'err_display_name_length': 'Anzeigename darf nicht leer sein!',
    'welcome_back': 'Willkommen zurück',
    'tagline': 'Ende-zu-Ende verschlüsselt und komplett unsichtbar.',
    'please_fill_field': 'Bitte füllen Sie dieses Feld aus',
    'please_enter_password': 'Bitte geben Sie Ihr Passwort ein',
    'login': 'Anmelden',
    'no_account': 'Sie haben noch kein Konto?',
    'register': 'Registrieren',
    'secure_keys_fail': 'Sicheres Schlüsselpaar konnte nicht generiert werden',
    'registration_success': 'Registrierung erfolgreich! Sie können sich jetzt anmelden.',
    'create_new_account': 'Neues Konto erstellen',
    'security_keys_notice': 'Zu Ihrer Sicherheit werden Verschlüsselungsschlüssel auf Ihrem Gerät generiert.',
    'please_enter_username': 'Bitte geben Sie einen Benutzernamen ein',
    'username_min_length': 'Der Benutzername muss mindestens 3 Zeichen lang sein',
    'email': 'E-Mail',
    'please_enter_email': 'Bitte geben Sie Ihre E-Mail-Adresse ein',
    'valid_email_error': 'Bitte geben Sie eine gültige E-Mail-Adresse ein',
    'please_enter_display_name': 'Bitte geben Sie Ihren Anzeigenamen ein',
    'password': 'Passwort',
    'password_min_length': 'Das Passwort muss mindestens 8 Zeichen lang sein',
    'invite_code': 'Einladungscode',
    'please_enter_invite_code': 'Bitte geben Sie Ihren Einladungscode ein',
    'phone_number': 'Telefonnummer',
    'phone_number_optional': 'Telefonnummer (Optional)',
    'phone_number_invalid': 'Bitte geben Sie eine gültige Telefonnummer ein',
    'select_contact': 'Kontakt auswählen',
    'contacts': 'Kontakte',
    'no_contacts_found': 'Keine Kontakte gefunden',
    'invite_friend': 'Einladen',
    'phonebook_contacts': 'Meine Kontakte',
    'invite': 'Einladen',
    'invited': 'Eingeladen',
    'global_search': 'Alle Benutzer suchen',
    'friends': 'Freunde',
    'requests': 'Anfragen',
    'blocked': 'Blockiert',
    'no_friends_yet': 'Noch keine Freunde',
    'no_requests_yet': 'Keine ausstehenden Anfragen',
    'no_blocked_yet': 'Keine blockierten Benutzer',
    'unblock': 'Blockierung aufheben',
    'accept': 'Akzeptieren',
    'reject': 'Ablehnen',
    'block': 'Blockieren',
    'social_hub': 'Soziales',
    'friendship_accepted': 'Freundschaftsanfrage akzeptiert',
    'friendship_rejected': 'Freundschaftsanfrage abgelehnt',
    'user_unblocked': 'Benutzer erfolgreich entsperrt',
    'user_blocked': 'Benutzer erfolgreich blockiert',
    'group': 'Gruppe',
    'new_group': 'Neue Gruppe',
    'stories': 'Storys',
    'messages': 'Nachrichten',
    'calls': 'Anrufe',
    'communities': 'Communities',
    'search': 'Suchen...',
    'cancel': 'Abbrechen',
    'save': 'Speichern',
    'dialing': 'Wird angerufen...',
    'group_video_call': 'Gruppen-Videoanruf',
    'video_call_started': 'Videoanruf gestartet',
    'group_voice_call': 'Gruppen-Sprachanruf',
    'voice_call_started': 'Sprachanruf gestartet',
    'waiting_participants': 'Warten auf Teilnehmer...',
    'add_participant_to_call': 'Teilnehmer zum Anruf hinzufügen',
    'search_contact': 'Kontakt suchen...',
    'contact_not_found': 'Kontakt nicht gefunden',
    'invited_to_call': 'Zum Anruf eingeladen',
    'incoming_video_call': 'Eingehender Videoanruf',
    'incoming_voice_call': 'Eingehender Sprachanruf',
    'calling_via_iz': 'Wird über iz angerufen...',
    'answer': 'Antworten',
  }
};
