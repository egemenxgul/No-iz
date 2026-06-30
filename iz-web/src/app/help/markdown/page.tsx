import React from 'react';

export const metadata = {
  title: 'Markdown Kullanımı | No-iz Yardım Merkezi',
  description: 'No-iz mesajlaşmalarında Markdown kullanarak metinlerinizi nasıl biçimlendirebileceğinizi öğrenin.',
};

export default function MarkdownHelpPage() {
  return (
    <div style={{ maxWidth: '800px', lineHeight: 1.6, paddingBottom: '50px' }}>
      <h1 style={{ fontSize: '28px', fontWeight: 'bold', marginBottom: '10px' }}>Mesajlarda Markdown Kullanımı</h1>
      <p style={{ color: 'var(--text-secondary)', marginBottom: '30px' }}>
        No-iz'de sohbet ederken, mesajlarınızı daha anlaşılır ve düzenli hale getirmek için 
        <strong> Markdown</strong> (basit metin biçimlendirme dili) kullanabilirsiniz. 
        Hem web hem de mobil uygulamamız bu formatı otomatik olarak destekler.
      </p>

      <section style={{ marginBottom: '30px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 'bold', marginBottom: '15px', color: 'var(--accent)' }}>1. Metin Biçimlendirme (Kalın & İtalik)</h2>
        <table style={{ width: '100%', borderCollapse: 'collapse', marginBottom: '15px' }}>
          <thead>
            <tr style={{ borderBottom: '1px solid var(--border)', textAlign: 'left' }}>
              <th style={{ padding: '10px' }}>Yazdığınız</th>
              <th style={{ padding: '10px' }}>Görünen</th>
            </tr>
          </thead>
          <tbody>
            <tr style={{ borderBottom: '1px solid var(--border)' }}>
              <td style={{ padding: '10px' }}><code>**Kalın Metin**</code></td>
              <td style={{ padding: '10px' }}><strong>Kalın Metin</strong></td>
            </tr>
            <tr style={{ borderBottom: '1px solid var(--border)' }}>
              <td style={{ padding: '10px' }}><code>*İtalik Metin*</code> veya <code>_İtalik Metin_</code></td>
              <td style={{ padding: '10px' }}><em>İtalik Metin</em></td>
            </tr>
            <tr style={{ borderBottom: '1px solid var(--border)' }}>
              <td style={{ padding: '10px' }}><code>~~Üstü Çizili~~</code></td>
              <td style={{ padding: '10px' }}><del>Üstü Çizili</del></td>
            </tr>
          </tbody>
        </table>
      </section>

      <section style={{ marginBottom: '30px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 'bold', marginBottom: '15px', color: 'var(--accent)' }}>2. Listeler Oluşturma</h2>
        <p style={{ marginBottom: '10px' }}>Maddeli veya numaralı listeler oluşturmak için satır başlarına özel karakterler ekleyebilirsiniz:</p>
        
        <div style={{ background: 'var(--bg-surface)', padding: '15px', borderRadius: '8px', marginBottom: '15px' }}>
          <p style={{ fontWeight: 'bold', marginBottom: '5px' }}>Maddeli Liste (Yazdığınız):</p>
          <pre style={{ margin: 0, color: 'var(--text-secondary)' }}>
            - Birinci madde<br/>
            - İkinci madde<br/>
            - Üçüncü madde
          </pre>
        </div>

        <div style={{ background: 'var(--bg-surface)', padding: '15px', borderRadius: '8px', marginBottom: '15px' }}>
          <p style={{ fontWeight: 'bold', marginBottom: '5px' }}>Numaralı Liste (Yazdığınız):</p>
          <pre style={{ margin: 0, color: 'var(--text-secondary)' }}>
            1. Birinci adım<br/>
            2. İkinci adım<br/>
            3. Üçüncü adım
          </pre>
        </div>
      </section>

      <section style={{ marginBottom: '30px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 'bold', marginBottom: '15px', color: 'var(--accent)' }}>3. Kod ve Alıntılar</h2>
        <table style={{ width: '100%', borderCollapse: 'collapse', marginBottom: '15px' }}>
          <thead>
            <tr style={{ borderBottom: '1px solid var(--border)', textAlign: 'left' }}>
              <th style={{ padding: '10px' }}>Kullanım Amacı</th>
              <th style={{ padding: '10px' }}>Yazdığınız</th>
            </tr>
          </thead>
          <tbody>
            <tr style={{ borderBottom: '1px solid var(--border)' }}>
              <td style={{ padding: '10px' }}>Kısa Kod (Satıriçi)</td>
              <td style={{ padding: '10px' }}>Lütfen `npm install` komutunu çalıştırın.</td>
            </tr>
            <tr style={{ borderBottom: '1px solid var(--border)' }}>
              <td style={{ padding: '10px' }}>Alıntı (Quote)</td>
              <td style={{ padding: '10px' }}>{'>'} Hayat kısa, No-iz güvenli.</td>
            </tr>
            <tr style={{ borderBottom: '1px solid var(--border)' }}>
              <td style={{ padding: '10px' }}>Kod Bloğu</td>
              <td style={{ padding: '10px' }}>```<br/>console.log("Merhaba Dünya!");<br/>```</td>
            </tr>
          </tbody>
        </table>
      </section>

      <section style={{ marginBottom: '30px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 'bold', marginBottom: '15px', color: 'var(--accent)' }}>4. Bağlantılar (Linkler)</h2>
        <p style={{ marginBottom: '10px' }}>Bir metne tıklanabilir link eklemek istiyorsanız şu yapıyı kullanın:</p>
        <div style={{ background: 'var(--bg-surface)', padding: '15px', borderRadius: '8px' }}>
          <code>[No-iz'e Git](https://no-iz.app)</code>
        </div>
        <p style={{ marginTop: '10px', fontSize: '14px', color: 'var(--text-secondary)' }}>Not: Doğrudan yazılan `https://...` linkleri de otomatik olarak tıklanabilir hale getirilecektir.</p>
      </section>
      
      <div style={{ marginTop: '40px', padding: '15px', borderLeft: '4px solid var(--accent)', backgroundColor: 'var(--bg-elevated)', borderRadius: '0 8px 8px 0' }}>
        <strong>🔒 Gizlilik Notu:</strong> Markdown biçimlendirmeleri sadece görsel bir özelliktir. No-iz, yazdığınız mesajların içeriğini **asla** göremez. Mesajlar cihazınızda şifrelenir (E2EE) ve Markdown biçimlendirmeleri yalnızca mesajı okuyan kişi tarafından (şifre çözüldükten sonra) anlık olarak uygulanır.
      </div>
    </div>
  );
}
