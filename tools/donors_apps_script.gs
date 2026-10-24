// الصق هذا الكود في Apps Script المرتبط بجدول Google Sheets (انظر tools/DONORS_SETUP.md).
// الورقة الأولى: التاريخ | الاسم | المبلغ | المالك   (لحذف اسم غير مرغوب احذف صفه)
// ورقة «الدعم»: التاريخ | الاسم | الهاتف | النوع | الرسالة | المالك | الرد | تاريخ الرد
// للرد على رسالة: اكتب الرد في عمود «الرد» أمام الرسالة، فيراه صاحبها في التطبيق.
const MAX_ROWS = 200;
// اتركه فارغًا إن لم تفعّل دخول Google. وإلا ضع Web client ID من Google Cloud Console.
const WEB_CLIENT_ID = '843002779261-9mp73ui95d4f2h3hha9399m05bg3d611.apps.googleusercontent.com';

const DONOR_HEADERS = ['التاريخ', 'الاسم', 'المبلغ', 'المالك'];
const SUPPORT_HEADERS = ['التاريخ', 'الاسم', 'الهاتف', 'النوع', 'الرسالة', 'المالك', 'الرد', 'تاريخ الرد'];

function doGet(e) {
  const p = e.parameter || {};
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = ss.getSheets()[0];
  const owner = ownerOf(p);
  if (owner === null) return json({ error: 'auth' });

  if (p.action === 'support') {
    return withLock(function () {
      const sup = supportSheet(ss);
      sup.appendRow([new Date(), clean(p.name, 40), clean(p.phone, 20), clean(p.type, 20), clean(p.message, 500), owner, '', '']);
      return json({ ok: true });
    });
  }

  // نقل سجل الجهاز إلى أول حساب Google يدخل منه. الحساب الثاني على الجهاز نفسه لا يأخذ شيئًا.
  if (p.action === 'claim') {
    if (owner.indexOf('g:') !== 0 || !/^[a-f0-9]{32}$/.test(p.device || '')) return json({ error: 'auth' });
    return withLock(function () {
      const props = PropertiesService.getScriptProperties();
      const key = 'dev:' + p.device;
      const linked = props.getProperty(key);
      if (linked && linked !== owner) return json({ linked: false, moved: 0 });
      props.setProperty(key, owner);
      const from = 'd:' + p.device;
      const moved = relabel(sheet, 4, from, owner) + relabel(supportSheet(ss), 6, from, owner);
      return json({ linked: true, moved: moved });
    });
  }

  if (p.action === 'mine') {
    if (!owner) return json({ donations: [], messages: [] });
    const sup = supportSheet(ss);
    return json({
      donations: rowsOf(sheet, 4).filter(function (r) { return r[3] === owner; }).map(function (r) {
        return { date: iso(r[0]), name: String(r[1]), amount: String(r[2]) };
      }).reverse(),
      messages: rowsOf(sup, 8).filter(function (r) { return r[5] === owner; }).map(function (r) {
        return { date: iso(r[0]), type: String(r[3]), message: String(r[4]), reply: String(r[6] || ''), replyDate: r[7] ? iso(r[7]) : '' };
      }).reverse(),
    });
  }

  if (p.action === 'add') {
    withLock(function () {
      ensureHeaders(sheet, DONOR_HEADERS);
      sheet.appendRow([new Date(), clean(p.name, 40) || 'فاعل خير', clean(p.amount, 20), owner]);
    });
  }

  const last = sheet.getLastRow();
  const n = Math.min(Math.max(last - 1, 0), MAX_ROWS);
  const rows = n === 0 ? [] : sheet.getRange(last - n + 1, 1, n, 3).getValues();
  return json(rows.reverse().map(function (r) {
    return { date: iso(r[0]), name: String(r[1]), amount: String(r[2]) };
  }));
}

// المالك: حساب Google موثّق (g:) أو معرّف الجهاز (d:) أو فارغ. null = رمز دخول غير صالح.
function ownerOf(p) {
  if (p.idToken) {
    const sub = verifyToken(p.idToken);
    return sub ? 'g:' + sub : null;
  }
  if (p.device && /^[a-f0-9]{32}$/.test(p.device)) return 'd:' + p.device;
  return '';
}

function verifyToken(t) {
  if (!WEB_CLIENT_ID) return null;
  const r = UrlFetchApp.fetch('https://oauth2.googleapis.com/tokeninfo?id_token=' + encodeURIComponent(t), { muteHttpExceptions: true });
  if (r.getResponseCode() !== 200) return null;
  const j = JSON.parse(r.getContentText());
  return j.aud === WEB_CLIENT_ID ? j.sub : null;
}

// يغيّر مالك الصفوف من [from] إلى [to] في العمود [col] ويرجع عددها.
function relabel(sheet, col, from, to) {
  const last = sheet.getLastRow();
  if (last < 2) return 0;
  const range = sheet.getRange(2, col, last - 1, 1);
  const vals = range.getValues();
  let n = 0;
  for (let i = 0; i < vals.length; i++) {
    if (vals[i][0] === from) { vals[i][0] = to; n++; }
  }
  if (n) range.setValues(vals);
  return n;
}

function supportSheet(ss) {
  let sup = ss.getSheetByName('الدعم');
  if (!sup) sup = ss.insertSheet('الدعم');
  ensureHeaders(sup, SUPPORT_HEADERS);
  return sup;
}

function ensureHeaders(sheet, headers) {
  sheet.getRange(1, 1, 1, headers.length).setValues([headers]);
}

function rowsOf(sheet, cols) {
  const last = sheet.getLastRow();
  if (last < 2) return [];
  const n = Math.min(last - 1, 2000);
  return sheet.getRange(last - n + 1, 1, n, cols).getValues();
}

function withLock(fn) {
  const lock = LockService.getScriptLock();
  lock.waitLock(10000);
  try { return fn(); } finally { lock.releaseLock(); }
}

function iso(d) { return new Date(d).toISOString(); }

function json(o) {
  return ContentService.createTextOutput(JSON.stringify(o)).setMimeType(ContentService.MimeType.JSON);
}

// يمنع تحويل النص إلى صيغة جدول (=، +، -، @) ويقصّ الطول.
function clean(s, max) {
  s = String(s || '').replace(/[\r\n\t]+/g, ' ').trim().slice(0, max);
  return /^[=+\-@]/.test(s) ? "'" + s : s;
}
