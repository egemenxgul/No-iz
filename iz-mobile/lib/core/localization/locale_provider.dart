import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum AppLanguage { tr, en }

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
    } else {
      // First launch, secure storage is empty.
      // Auto-detect and write it to secure storage for future persistence.
      final defaultLang = _getDeviceDefaultLanguage();
      await _storage.write(key: 'app_language', value: defaultLang == AppLanguage.tr ? 'tr' : 'en');
      state = LocaleState(defaultLang);
    }
  }
  
  Future<void> toggleLanguage() async {
    if (state.language == AppLanguage.tr) {
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
  }
};
