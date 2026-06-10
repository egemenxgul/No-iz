package i18n

import (
	"net/http"
	"strings"
)

type Language string

const (
	EN Language = "en"
	TR Language = "tr"
)

var defaultLang = EN

var translations = map[Language]map[string]string{
	EN: {
		"err_user_id_required": "user id is required",
		"err_user_not_found": "user not found",
		"err_search_failed": "search failed",
		"err_invalid_request_body": "invalid request body",
		"err_username_taken": "this username is already taken",
		"err_email_taken": "this email address is already registered",
		"err_invalid_invite_code": "invalid or expired invite code",
		"err_invite_code_full": "this invite code has reached its usage limit",
		"err_registration_failed": "registration failed",
		"err_invalid_credentials": "invalid username or password",
		"err_login_failed": "login failed",
		"err_unauthorized": "unauthorized",
		"err_password_required": "old_password and new_password are required",
		"err_incorrect_current_password": "current password is incorrect",
		"err_username_length": "username must be 3-32 characters",
		"err_invalid_email": "invalid email address",
		"err_password_length": "password must be at least 8 characters",
		"err_display_name_length": "display name must be 1-64 characters",
		"err_invite_code_required": "invite code is required",
		"err_signal_keys_required": "signal protocol keys are required",
		"err_refresh_token_required": "refresh_token is required",
		"err_internal": "internal server error",
	},
	TR: {
		"err_user_id_required": "kullanıcı id gerekli",
		"err_user_not_found": "kullanıcı bulunamadı",
		"err_search_failed": "arama başarısız",
		"err_invalid_request_body": "geçersiz istek gövdesi",
		"err_username_taken": "bu kullanıcı adı zaten alınmış",
		"err_email_taken": "bu e-posta adresi zaten kayıtlı",
		"err_invalid_invite_code": "geçersiz veya süresi dolmuş davet kodu",
		"err_invite_code_full": "bu davet kodu kullanım limitine ulaştı",
		"err_registration_failed": "kayıt işlemi başarısız",
		"err_invalid_credentials": "geçersiz kullanıcı adı veya şifre",
		"err_login_failed": "giriş işlemi başarısız",
		"err_unauthorized": "yetkisiz işlem",
		"err_password_required": "eski ve yeni şifre gereklidir",
		"err_incorrect_current_password": "mevcut şifre yanlış",
		"err_username_length": "kullanıcı adı 3-32 karakter arasında olmalıdır",
		"err_invalid_email": "geçersiz e-posta adresi",
		"err_password_length": "şifre en az 8 karakter olmalıdır",
		"err_display_name_length": "görünen ad 1-64 karakter arasında olmalıdır",
		"err_invite_code_required": "davet kodu gereklidir",
		"err_signal_keys_required": "signal protokol anahtarları gereklidir",
		"err_refresh_token_required": "refresh_token gereklidir",
		"err_internal": "sunucu hatası",
	},
}

// GetLanguage extracts the preferred language from the Accept-Language header.
func GetLanguage(r *http.Request) Language {
	accept := r.Header.Get("Accept-Language")
	if accept == "" {
		return defaultLang
	}

	langs := strings.Split(accept, ",")
	for _, lang := range langs {
		lang = strings.TrimSpace(lang)
		if len(lang) >= 2 {
			code := strings.ToLower(lang[:2])
			if code == "tr" {
				return TR
			} else if code == "en" {
				return EN
			}
		}
	}

	return defaultLang
}

// Translate returns the localized string for a given key and request.
func Translate(r *http.Request, key string) string {
	lang := GetLanguage(r)
	dict, ok := translations[lang]
	if !ok {
		dict = translations[defaultLang]
	}

	val, ok := dict[key]
	if !ok {
		// Fallback to EN if key doesn't exist in the current language
		val, ok = translations[defaultLang][key]
		if !ok {
			return key // Return key if translation is missing everywhere
		}
	}

	return val
}

// TranslateLang returns the localized string for a specific language directly.
func TranslateLang(lang Language, key string) string {
	dict, ok := translations[lang]
	if !ok {
		dict = translations[defaultLang]
	}

	val, ok := dict[key]
	if !ok {
		val, ok = translations[defaultLang][key]
		if !ok {
			return key
		}
	}

	return val
}
