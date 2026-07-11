const APP_NAME = 'Falora';
const SUPPORT_EMAIL = 'prserdar.cakir@gmail.com';

function escapeHtml(value) {
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function baseLayout({ title, preheader, bodyHtml }) {
  return `<!DOCTYPE html>
<html lang="tr">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>${escapeHtml(title)}</title>
</head>
<body style="margin:0;padding:0;background:#f4ebe0;font-family:Georgia,'Times New Roman',serif;color:#2a2118;">
  <div style="display:none;max-height:0;overflow:hidden;opacity:0;">${escapeHtml(preheader)}</div>
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f4ebe0;padding:32px 16px;">
    <tr>
      <td align="center">
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:560px;background:#fffaf2;border:1px solid #e2d3bc;border-radius:18px;overflow:hidden;">
          <tr>
            <td style="padding:28px 28px 12px;background:#8b4513;color:#fffaf2;">
              <div style="font-size:13px;letter-spacing:0.08em;text-transform:uppercase;opacity:0.85;">${APP_NAME}</div>
              <h1 style="margin:8px 0 0;font-size:26px;line-height:1.25;">${escapeHtml(title)}</h1>
            </td>
          </tr>
          <tr>
            <td style="padding:28px;font-size:16px;line-height:1.65;">
              ${bodyHtml}
            </td>
          </tr>
          <tr>
            <td style="padding:0 28px 28px;font-size:13px;line-height:1.5;color:#6b5a45;">
              Bu e-posta ${APP_NAME} hesabınız için gönderildi.<br />
              Destek: <a href="mailto:${SUPPORT_EMAIL}" style="color:#8b4513;">${SUPPORT_EMAIL}</a>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

function ctaButton(url, label) {
  return `<p style="margin:28px 0 18px;text-align:center;">
  <a href="${escapeHtml(url)}"
     style="display:inline-block;background:#8b4513;color:#fffaf2;text-decoration:none;padding:14px 22px;border-radius:12px;font-weight:700;">
    ${escapeHtml(label)}
  </a>
</p>
<p style="margin:0;font-size:13px;color:#6b5a45;word-break:break-all;">
  Buton çalışmazsa bu bağlantıyı tarayıcınıza yapıştırın:<br />
  <a href="${escapeHtml(url)}" style="color:#8b4513;">${escapeHtml(url)}</a>
</p>`;
}

function buildVerificationEmail({ link, email }) {
  const title = 'E-posta adresini doğrula';
  const html = baseLayout({
    title,
    preheader: `${APP_NAME} hesabını doğrulamak için bağlantıya tıkla.`,
    bodyHtml: `
      <p style="margin:0 0 12px;">Merhaba,</p>
      <p style="margin:0 0 12px;">
        <strong>${escapeHtml(email)}</strong> adresiyle ${APP_NAME} hesabı oluşturuldu.
        Devam etmek için e-posta adresini doğrula.
      </p>
      ${ctaButton(link, 'E-postamı Doğrula')}
      <p style="margin:22px 0 0;color:#6b5a45;font-size:14px;">
        Bu isteği sen yapmadıysan bu e-postayı yok sayabilirsin.
      </p>
    `,
  });

  const text = [
    `${APP_NAME} — E-posta doğrulama`,
    '',
    `${email} adresiyle hesabın oluşturuldu.`,
    'Doğrulamak için bağlantıyı aç:',
    link,
    '',
    'Bu isteği sen yapmadıysan yok sayabilirsin.',
  ].join('\n');

  return { subject: `${APP_NAME} — E-posta doğrulama`, html, text };
}

function buildPasswordResetEmail({ link, email }) {
  const title = 'Şifreni sıfırla';
  const html = baseLayout({
    title,
    preheader: `${APP_NAME} şifre sıfırlama bağlantın hazır.`,
    bodyHtml: `
      <p style="margin:0 0 12px;">Merhaba,</p>
      <p style="margin:0 0 12px;">
        <strong>${escapeHtml(email)}</strong> için ${APP_NAME} şifre sıfırlama talebi aldık.
      </p>
      ${ctaButton(link, 'Şifremi Sıfırla')}
      <p style="margin:22px 0 0;color:#6b5a45;font-size:14px;">
        Bu talebi sen oluşturmadıysan endişelenme; şifren değişmez. E-postayı yok sayman yeterli.
      </p>
    `,
  });

  const text = [
    `${APP_NAME} — Şifre sıfırlama`,
    '',
    `${email} için şifre sıfırlama talebi aldık.`,
    'Şifreni sıfırlamak için bağlantıyı aç:',
    link,
    '',
    'Bu talebi sen oluşturmadıysan yok sayabilirsin.',
  ].join('\n');

  return { subject: `${APP_NAME} — Şifre sıfırlama`, html, text };
}

module.exports = {
  APP_NAME,
  buildVerificationEmail,
  buildPasswordResetEmail,
};
