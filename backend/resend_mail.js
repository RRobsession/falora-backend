const { Resend } = require('resend');

function resolveFromAddress() {
  const raw = (process.env.RESEND_FROM_EMAIL || '').trim();
  if (!raw) {
    return null;
  }
  if (raw.includes('<') && raw.includes('>')) {
    return raw.replace(/^[^<]*/, 'Falora ');
  }
  return `Falora <${raw}>`;
}

/**
 * @param {{ to: string, subject: string, html: string, text: string }} params
 */
async function sendAuthEmail({ to, subject, html, text }) {
  const apiKey = (process.env.RESEND_API_KEY || '').trim();
  const from = resolveFromAddress();

  if (!apiKey) {
    const error = new Error('RESEND_API_KEY tanımlı değil.');
    error.code = 'resend_not_configured';
    throw error;
  }
  if (!from) {
    const error = new Error('RESEND_FROM_EMAIL tanımlı değil.');
    error.code = 'resend_not_configured';
    throw error;
  }

  const resend = new Resend(apiKey);
  const { data, error } = await resend.emails.send({
    from,
    to: [to],
    subject,
    html,
    text,
  });

  if (error) {
    const message =
      typeof error === 'string'
        ? error
        : error.message || JSON.stringify(error);
    const wrapped = new Error(`Resend gönderimi başarısız: ${message}`);
    wrapped.code = 'resend_send_failed';
    throw wrapped;
  }

  return data;
}

module.exports = {
  sendAuthEmail,
  resolveFromAddress,
};
