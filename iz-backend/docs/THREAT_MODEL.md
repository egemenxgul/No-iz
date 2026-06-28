# No-iz Tehdit Modeli (Threat Model)

Bu doküman, uygulamanın güvenlik modelini, uçtan uca şifreleme (E2EE) yapısını ve potansiyel risk vektörlerini analiz eder.

## 1. Sisteme Genel Bakış ve Varlıklar (Assets)
- **Kullanıcı Kimlikleri (User Identities):** Public key (Identity Key), telefon no, display name.
- **Şifreli Veri (Ciphertext):** Mesaj içerikleri sunucuda yalnızca şifrelenmiş halde saklanır.
- **PreKey'ler:** X3DH (Extended Triple Diffie-Hellman) için üretilen key bundle'ları.
- **Medya Dosyaları:** MinIO üzerinde şifreli olarak tutulan dosyalar.

## 2. Güven Kaynakları ve Sınırları (Trust Boundaries)
- **Sunucu (Backend):** Mesajların, prekey'lerin ve diğer verilerin depolandığı yer. Sunucu, düz metin mesajları KESİNLİKLE OKUYAMAZ (Zero-Knowledge). Sunucuya %100 güvenilmez.
- **Kullanıcı Cihazı (Client):** Mesajların şifrelenip çözüldüğü, private key'lerin (Identity Key, PreKeys vb.) güvenle saklandığı tek yer (Secure Storage / Keychain / Keystore).
- **Ağ (Network):** TLS 1.3 / HTTPS üzerinden iletim. WebRTC sinyalleşmesi (WSS üzerinden E2EE).

## 3. Potansiyel Tehditler ve Önlemler
1. **Veritabanı Sızıntısı:**
   - *Tehdit:* Saldırgan veya kötü niyetli sunucu yöneticisi veritabanına sızar.
   - *Önlem:* Tüm mesaj içerikleri Signal Protokolü kullanılarak uçtan uca şifrelidir. Düz metin ele geçirilemez.

2. **Man-in-the-Middle (MitM) Saldırıları:**
   - *Tehdit:* İletişim sırasında verilerin ele geçirilmesi veya değiştirilmesi.
   - *Önlem:* Tüm iletişim TLS ile sağlanır (Transit Encryption) ve mesajlar ek olarak payload seviyesinde şifrelidir (E2EE).

3. **Cihaz Çalınması / Fiziksel Erişim:**
   - *Tehdit:* Cihazın ele geçirilmesi ve verilerin kopyalanması.
   - *Önlem:* Flutter tarafında SQLCipher ile yerel SQLite veritabanı şifrelidir.

4. **WebRTC Sinyalleşme Sızıntısı:**
   - *Tehdit:* Aramaların IP adresini ifşa etmesi.
   - *Önlem:* Arama sinyalleşmesi E2EE ile güvence altındadır ve trafiği gizlemek için TURN sunucuları (relay mode) desteklenmektedir.
