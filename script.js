/* ─────────────────────────────────────────────────────────────
   IEEE Xtreme Qualifier – Registration Form Logic
   Requires: @supabase/supabase-js v2 (CDN), config.js
   ───────────────────────────────────────────────────────────── */

const EMAIL_RE  = /^[A-Za-z][0-9]{6}@nu\.edu\.pk$/i;
const PHONE_RE  = /^03\d{9}$/;
const VJUDGE_RE = /^[A-Za-z0-9_]+$/;

// ── DOM refs ──────────────────────────────────────────────────
const form      = document.getElementById('registration-form');
const submitBtn = document.getElementById('submit-button');
const statusEl  = document.getElementById('form-status');

// ── Helpers ───────────────────────────────────────────────────
const val = id => document.getElementById(id)?.value.trim() || '';
const setErr = (id, msg = '') => { const el = document.getElementById(id); if (el) el.textContent = msg; };
const setFieldError = (id, msg = '') => {
  const field = document.getElementById(id);
  const error = document.getElementById(`${id}-error`);
  if (field) field.setAttribute('aria-invalid', msg ? 'true' : 'false');
  if (error) error.textContent = msg;
};
const clearErrors = () => {
  ['team-error','vjudge-error','participants-error','agreement-error'].forEach(id => setErr(id));
  ['team-name','team-vjudge', ...[1, 2, 3].flatMap(n => [`p${n}-name`, `p${n}-email`, `p${n}-phone`])]
    .forEach(id => setFieldError(id));
};

function setStatus(msg, type = '') {
  if (!statusEl) return;
  statusEl.textContent = msg;
  statusEl.className = 'form-status' + (type ? ' ' + type : '');
}
function setLoading(on) {
  if (!submitBtn) return;
  submitBtn.disabled = on || submitBtn.classList.contains('is-success');
  submitBtn.classList.toggle('is-loading', on);
}
function isConfigured() {
  const c = window.SUPABASE_CONFIG || {};
  return c.url && c.anonKey && !c.url.includes('YOUR_') && !c.anonKey.includes('YOUR_');
}

function formatPhone(value) {
  const digits = value.replace(/\D/g, '').slice(0, 11);
  return digits.length > 4 ? `${digits.slice(0, 4)} ${digits.slice(4)}` : digits;
}

function normalizePhone(value) {
  return value.replace(/\D/g, '').slice(0, 11);
}

function isValidEmail(value) {
  return EMAIL_RE.test(value) && !value.includes('..');
}

// ── Real-time inline validation ───────────────────────────────
function attachInlineValidation() {
  [1, 2, 3].forEach(n => {
    const email = document.getElementById(`p${n}-email`);
    const phone = document.getElementById(`p${n}-phone`);
    if (email) email.addEventListener('blur', () => {
      const value = email.value.trim().toLowerCase();
      setFieldError(email.id, value && !isValidEmail(value) ? 'Use the format k241234@nu.edu.pk' : '');
    });
    if (phone) {
      phone.addEventListener('input', () => {
        phone.value = formatPhone(phone.value);
        setFieldError(phone.id);
      });
      phone.addEventListener('blur', () => {
        const value = normalizePhone(phone.value.trim());
        phone.value = formatPhone(value);
        setFieldError(phone.id, value && !PHONE_RE.test(value) ? 'Enter exactly 11 digits in the format 03XX XXXXXXX' : '');
      });
    }
  });
  const vj = document.getElementById('team-vjudge');
  if (vj) vj.addEventListener('input', () => {
    const v = vj.value.trim();
    setFieldError('team-vjudge', v && !VJUDGE_RE.test(v) ? 'Only letters, numbers, and underscores allowed.' : '');
  });
}

// ── Validation ────────────────────────────────────────────────
function validate() {
  const teamName   = val('team-name');
  const vjudgeId   = val('team-vjudge');
  const honeypot   = val('website');
  const agreed     = document.getElementById('agreement')?.checked === true;

  const p = [1,2,3].map(n => ({
    name:  val('p' + n + '-name'),
    email: val('p' + n + '-email').toLowerCase(),
    phone: normalizePhone(val('p' + n + '-phone')),
  }));

  let ok = true;
  clearErrors();

  if (!teamName) { setErr('team-error', 'Please enter a team name.'); setFieldError('team-name', 'Please enter a team name.'); ok = false; }
  if (!VJUDGE_RE.test(vjudgeId)) { setErr('vjudge-error', 'Enter the exact team VJudge ID - letters, numbers, and underscores only.'); setFieldError('team-vjudge', 'Enter the exact VJudge ID using letters, numbers, and underscores only.'); ok = false; }

  let participantInvalid = false;
  p.forEach((participant, index) => {
    const n = index + 1;
    if (!participant.name) { setFieldError(`p${n}-name`, 'Enter the participant’s full name.'); ok = false; participantInvalid = true; }
    if (!isValidEmail(participant.email)) { setFieldError(`p${n}-email`, 'Use the format k241234@nu.edu.pk'); ok = false; participantInvalid = true; }
    if (!PHONE_RE.test(participant.phone)) { setFieldError(`p${n}-phone`, 'Enter exactly 11 digits in the format 03XX XXXXXXX'); ok = false; participantInvalid = true; }
  });

  const emails = p.map(x => x.email);
  if (new Set(emails.filter(Boolean)).size !== emails.filter(Boolean).length) {
    setErr('participants-error', 'Each participant must have a unique email address.');
    ok = false;
  }
  if (participantInvalid && !document.getElementById('participants-error')?.textContent) {
    setErr('participants-error', 'Review the highlighted participant fields.');
  }

  if (!agreed) { setErr('agreement-error', 'Please confirm the rules before submitting.'); ok = false; }
  if (honeypot) return { ok: false, honeypot: true };

  return { ok, teamName, vjudgeId, p };
}

// ── Submission ────────────────────────────────────────────────
async function handleSubmit(e) {
  e.preventDefault();
  setStatus('');

  const result = validate();
  if (result.honeypot) return;
  if (!result.ok) {
    const firstErr = form.querySelector('.field-error:not(:empty)');
    if (firstErr) firstErr.scrollIntoView({ behavior: 'smooth', block: 'center' });
    return;
  }

  if (!isConfigured()) {
    setStatus('Supabase credentials are missing. Add your URL and anon key to config.js.', 'error');
    return;
  }
  if (navigator.onLine === false) {
    setStatus('You appear to be offline. Reconnect to the internet and try again.', 'error');
    return;
  }

  const { teamName, vjudgeId, p } = result;
  setLoading(true);
  setStatus('Submitting your registration...');

  try {
    if (!window.supabase?.createClient) {
      throw new Error('The registration service is unavailable. Please refresh the page and try again.');
    }
    const client = window.supabase.createClient(window.SUPABASE_CONFIG.url, window.SUPABASE_CONFIG.anonKey);

    // One flat row per team - all participant details stored as individual columns
    const payload = {
      team_name:      teamName,
      vjudge_id:      vjudgeId,
      p1_name:        p[0].name,
      p1_email:       p[0].email,
      p1_phone:       p[0].phone,
      p2_name:        p[1].name,
      p2_email:       p[1].email,
      p2_phone:       p[1].phone,
      p3_name:        p[2].name,
      p3_email:       p[2].email,
      p3_phone:       p[2].phone,
      agreed_to_rules: true,
    };

    const insertRequest = client.from('registrations').insert(payload);
    const timeout = new Promise((_, reject) => setTimeout(() => reject(new Error('The request took too long. Please check your connection and try again.')), 15000));
    const { error: supaErr } = await Promise.race([insertRequest, timeout]);

    if (supaErr) {
      const errorText = [supaErr.message, supaErr.details, supaErr.hint].filter(Boolean).join(' ');
      const isVjudgeDuplicate = /reg_vjudge_uniq|vjudge/i.test(errorText);
      const isEmailDuplicate = !isVjudgeDuplicate && (supaErr.code === '23505' || /duplicate|unique|already registered|email/i.test(errorText));
      throw new Error(
        isVjudgeDuplicate
          ? 'That VJudge team ID is already registered. Please check the ID and try again.'
          : isEmailDuplicate
          ? 'One or more participant emails are already registered in another team. Each participant may only join one team.'
          : 'We could not save your registration. Please try again in a moment.'
      );
    }

    // ── Success ──
    form.reset();
    submitBtn.classList.add('is-success');
    submitBtn.querySelector('.button-label').textContent = '✓ You\'re in';
    form.querySelectorAll('input').forEach(el => { el.disabled = true; });
    setStatus('Team registered - good luck in the qualifier!', 'success');

  } catch (err) {
    console.error('[IEEE Registration]', err);
    setStatus(err.message || 'Something went wrong. Please check your connection and try again.', 'error');
  } finally {
    setLoading(false);
  }
}

// ── Scroll-reveal animation ───────────────────────────────────
function initReveal() {
  const sections = document.querySelectorAll('.details, .rules, .registration, footer');
  if ('IntersectionObserver' in window) {
    const obs = new IntersectionObserver((entries, observer) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) { entry.target.classList.add('is-visible'); observer.unobserve(entry.target); }
      });
    }, { threshold: 0.14, rootMargin: '0px 0px -40px 0px' });
    sections.forEach(s => obs.observe(s));
  } else {
    sections.forEach(s => s.classList.add('is-visible'));
  }
}

// ── Init ──────────────────────────────────────────────────────
if (form && submitBtn) {
  form.addEventListener('submit', handleSubmit);
  attachInlineValidation();
  initReveal();
} else {
  console.error('[IEEE Registration] Registration form could not be initialized.');
}
