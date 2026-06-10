<div align="center">

# iz — Uçtan Uca Şifreli Mesajlaşma Platformu

**Gizlilik önce gelir. Sunucu mesajlarını okuyamaz.**

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
[![Go](https://img.shields.io/badge/Backend-Go%201.25-00ADD8?logo=go)](https://golang.org)
[![Flutter](https://img.shields.io/badge/Mobile-Flutter%203-02569B?logo=flutter)](https://flutter.dev)
[![Next.js](https://img.shields.io/badge/Web-Next.js%2016-000000?logo=next.js)](https://nextjs.org)

*Developed by [Egemen GÜL](https://github.com/egemenxgul)*

</div>

---

## 📖 Nedir?

**iz**, Signal Protokolü'nden ilham alan, uçtan uca şifreli (E2EE) bir mesajlaşma platformudur. Sunucu yalnızca şifreli veri (ciphertext) saklar — düz metin mesajlara hiçbir zaman erişemez.

### Temel Özellikler

| Özellik | Durum |
|---------|-------|
| 🔐 Uçtan uca şifreleme (E2EE) | ✅ |
| 💬 Bireysel & Grup mesajlaşma | ✅ |
| 📞 Sesli & Görüntülü arama (WebRTC) | ✅ |
| 👥 Topluluklar (Community) | ✅ |
| 📖 Hikayeler / Durum | ✅ |
| 📱 iOS & Android (Flutter) | ✅ |
| 🌐 Web uygulaması (Next.js) | ✅ |
| 🔔 Push bildirimler (Firebase) | ✅ |
| 🛡️ 2FA (TOTP) | ✅ |
| 📦 Şifreli yedekleme | ✅ |
| 🔗 Davet sistemi | ✅ |

---

## 🏗️ Mimari

```
┌─────────────────────────────────────────────────────────┐
│  iz-web (Next.js)    iz-admin    iz-mobile (Flutter)    │
│         ↓                ↓              ↓               │
│              iz-backend (Go + Chi)                      │
│       PostgreSQL · Redis · MinIO · Firebase FCM         │
│              Caddy (Reverse Proxy + TLS)                │
└─────────────────────────────────────────────────────────┘
```

### Bileşenler

- **`iz-backend/`** — Go ile yazılmış REST + WebSocket API sunucusu
- **`iz-web/`** — Next.js 16 web uygulaması
- **`iz-mobile/`** — Flutter mobil uygulaması (Android & iOS)
- **`iz-admin/`** — Yönetim paneli
- **`docker/`** — Docker Compose altyapısı (Postgres, Redis, MinIO, Caddy)

---

## 🚀 Kurulum

### Gereksinimler

- Go 1.25+
- Node.js 20+
- Flutter 3.x
- Docker & Docker Compose
- PostgreSQL 16, Redis 7, MinIO

### Hızlı Başlangıç

```bash
# 1. Repo'yu klonla
git clone https://github.com/egemenxgul/No-iz.git
cd No-iz

# 2. Ortam değişkenlerini ayarla
cp .env.example .env
# .env dosyasını düzenle — her secret'ı değiştir!
# Secret üretmek için: python3 -c "import secrets; print(secrets.token_urlsafe(48))"

# 3. Altyapıyı başlat
cd docker && docker compose up -d postgres redis minio

# 4. Backend'i çalıştır
cd iz-backend && make run

# 5. Web'i çalıştır
cd iz-web && npm install && npm run dev

# 6. Mobil (Android/iOS emülatör gerekli)
cd iz-mobile && flutter pub get && flutter run
```

### Docker ile Tüm Stack

```bash
cd docker && docker compose up -d
```

---

## 🔒 Güvenlik Modeli

- **E2EE:** Sunucu yalnızca şifrelenmiş mesaj saklar. Düz metne hiçbir zaman erişemez.
- **Argon2id** ile şifre hash'leme
- **JWT** (15 dk access / 30 gün refresh) token sistemi
- **TOTP tabanlı 2FA**
- **Redis tabanlı rate limiting** (brute-force koruması)
- **MinIO** ile şifreli medya depolama
- **WebRTC** P2P ses/görüntü (TURN destekli)

---

## 📁 Dizin Yapısı

```
No-iz/
├── iz-backend/         # Go API sunucusu
│   ├── cmd/            # Main entry point
│   ├── internal/       # Modüller (auth, messaging, call, ...)
│   ├── migrations/     # PostgreSQL migration dosyaları
│   └── pkg/            # Paylaşılan paketler
├── iz-web/             # Next.js web uygulaması
│   └── src/
│       ├── app/        # Sayfalar (App Router)
│       ├── components/ # UI bileşenleri
│       ├── lib/        # API client, WebSocket, crypto
│       └── store/      # State yönetimi
├── iz-mobile/          # Flutter mobil uygulama
│   └── lib/
│       ├── core/       # Tema, ağ, crypto, DB
│       └── features/   # Auth, Messages, Call, Story, ...
├── iz-admin/           # Admin paneli
├── docker/             # Docker Compose + Caddy config
├── .env.example        # Ortam değişkeni şablonu
└── LICENSE             # AGPL-3.0
```

---

## 🤝 Katkıda Bulunma

Katkılar memnuniyetle karşılanır! Lütfen önce bir **Issue** açın, ardından **Pull Request** gönderin.

1. Fork'la
2. Feature branch oluştur (`git checkout -b feat/ozellik-adi`)
3. Değişikliklerini commit et (`git commit -m 'feat: açıklama'`)
4. Branch'ini push'la (`git push origin feat/ozellik-adi`)
5. Pull Request aç

### Commit Mesajı Formatı

```
feat: yeni özellik
fix: hata düzeltmesi
docs: dokümantasyon
chore: yapılandırma değişikliği
refactor: kod yeniden yapılandırma
```

---

## 📄 Lisans

Bu proje **GNU Affero General Public License v3.0 (AGPL-3.0)** altında lisanslanmıştır.

**Önemli:** Bu yazılımı kullanıyorsanız, dağıtıyorsanız veya değiştiriyorsanız:
- Orijinal geliştiriciyi belirtmek zorundasınız: **Egemen GÜL (github.com/egemenxgul)**
- Türev çalışmalar da AGPL-3.0 altında yayınlanmalıdır
- Ağ üzerinden hizmet olarak sunuyorsanız kaynak kodu paylaşmalısınız

Detaylar için [LICENSE](LICENSE) dosyasına bakın.

---

<div align="center">

**iz** — *Originally developed by [Egemen GÜL](https://github.com/egemenxgul)*

</div>
