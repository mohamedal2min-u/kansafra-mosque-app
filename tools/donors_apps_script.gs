// الصق هذا الكود في Apps Script المرتبط بجدول Google Sheets (انظر tools/DONORS_SETUP.md).
// الورقة الأولى: التاريخ | الاسم | المبلغ | المالك   (لحذف اسم غير مرغوب احذف صفه)
// ورقة «الدعم»: التاريخ | الاسم | الهاتف | النوع | الرسالة | المالك | الرد | تاريخ الرد
// للرد على رسالة: اكتب الرد في عمود «الرد» أمام الرسالة، فيراه صاحبها في التطبيق.
const MAX_ROWS = 200;
// اتركه فارغًا إن لم تفعّل دخول Google. وإلا ضع Web client ID من Google Cloud Console.
const WEB_CLIENT_ID = '843002779261-9mp73ui95d4f2h3hha9399m05bg3d611.apps.googleusercontent.com';

const DONOR_HEADERS = ['التاريخ', 'الاسم', 'المبلغ', 'المالك', 'المرجع'];
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

  // إضافة متبرع: للمسؤول فقط (أو لخدمة الدفع لاحقًا) بمفتاح سرّي مخزَّن في Script Properties باسم ADMIN_KEY.
  if (p.action === 'add') {
    const adminKey = PropertiesService.getScriptProperties().getProperty('ADMIN_KEY');
    if (!adminKey || p.key !== adminKey) return json({ error: 'forbidden' });
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

// شغّل هذه الدالة مرة واحدة من المحرّر (زر Run) ووافق على الأذونات، ثم: نشر ← إدارة عمليات النشر ← تعديل ← إصدار جديد.
// بدونها يفشل التحقق من حساب Google (UrlFetchApp) ويظهر في التطبيق «تعذّر تحميل السجل» بعد تسجيل الدخول.
function authorizeOnce() {
  const r = UrlFetchApp.fetch('https://oauth2.googleapis.com/tokeninfo?id_token=x', { muteHttpExceptions: true });
  Logger.log('UrlFetch OK: ' + r.getResponseCode());
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


// ====================== ربط شام كاش عبر shamcash-api.com ======================
// خدمة طرف ثالث (غير رسمية من شام كاش). تقرأ التحويلات الواردة لمحفظة المسجد فقط (قراءة).
// الإعداد: Project Settings ثم Script properties، أضف:
//   SHAMCASH_TOKEN       = رمز API من لوحة shamcash-api.com (سرّي، لا يُرسل لأحد)
//   SHAMCASH_ACCOUNT_ID  = معرّف الحساب (يظهر في نتيجة shamcashProbe)
// ثم شغّل shamcashProbe مرة، وبعد تأكيد الحقول شغّل installSyncTrigger.

const SHAMCASH_BASE = 'https://api.shamcash-api.com/v1';

// أسماء حقول التحويل في ردّ /transactions. تُضبط بعد تشغيل shamcashProbe، ثم يُغيَّر CONFIRMED إلى true.
const SHAM_FIELDS = {
  CONFIRMED: false,
  id: 'id',                    // معرّف التحويل (لمنع التكرار)
  time: 'occurred_at',         // وقت التحويل (موثّق في الوثائق)
  amount: 'amount',            // المبلغ
  name: 'counterparty_name',   // اسم المحوِّل
  isIncoming: function (t) { return true; }, // اجعلها تفحص نوع التحويل: وارد أم صادر
};
// كيف يظهر اسم المتبرع: 'full' الاسم كاملًا، 'first' الاسم الأول فقط، 'anonymous' فاعل خير دائمًا.
const DISPLAY_NAME_MODE = 'first';

function shamGet_(path, params) {
  const token = PropertiesService.getScriptProperties().getProperty('SHAMCASH_TOKEN');
  if (!token) throw new Error('SHAMCASH_TOKEN غير مضبوط');
  const qs = Object.keys(params || {}).map(function (k) { return k + '=' + encodeURIComponent(params[k]); }).join('&');
  const r = UrlFetchApp.fetch(SHAMCASH_BASE + path + (qs ? '?' + qs : ''), {
    headers: { Authorization: 'Bearer ' + token, Accept: 'application/json' },
    muteHttpExceptions: true,
  });
  const payload = JSON.parse(r.getContentText());
  if (payload.status !== 'success') throw new Error(payload.code + ': ' + payload.message);
  return payload.data;
}

// يعرض بنية الحسابات وآخر 5 تحويلات في السجل (Execution log). احذف الأسماء والأرقام قبل مشاركة الناتج.
function shamcashProbe() {
  const accounts = shamGet_('/accounts');
  Logger.log('ACCOUNTS: ' + JSON.stringify(accounts));
  const props = PropertiesService.getScriptProperties();
  const id = props.getProperty('SHAMCASH_ACCOUNT_ID') || (accounts[0] && accounts[0].id);
  const tx = shamGet_('/transactions', { account_id: id, limit: 5 });
  Logger.log('TRANSACTIONS: ' + JSON.stringify(tx));
}

function displayName_(raw) {
  const name = String(raw || '').trim();
  if (!name || DISPLAY_NAME_MODE === 'anonymous') return 'فاعل خير';
  if (DISPLAY_NAME_MODE === 'first') return name.split(/\s+/)[0];
  return name;
}

// يضيف التحويلات الواردة الجديدة إلى قائمة المتبرعين (تُشغَّل كل 5 دقائق بمشغّل زمني).
function syncShamCash() {
  if (!SHAM_FIELDS.CONFIRMED) throw new Error('ثبّت أسماء الحقول في SHAM_FIELDS ثم اجعل CONFIRMED = true');
  const props = PropertiesService.getScriptProperties();
  const accountId = props.getProperty('SHAMCASH_ACCOUNT_ID');
  const since = props.getProperty('SHAMCASH_LAST_SYNC') || iso(new Date(Date.now() - 24 * 3600 * 1000));
  const tx = shamGet_('/transactions', { account_id: accountId, start_at: since, limit: 100 });
  const list = (Array.isArray(tx) ? tx : (tx.transactions || [])).slice().sort(function (a, b) {
    return new Date(a[SHAM_FIELDS.time]) - new Date(b[SHAM_FIELDS.time]);
  });
  withLock(function () {
    const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheets()[0];
    ensureHeaders(sheet, DONOR_HEADERS);
    const seen = {};
    rowsOf(sheet, 5).forEach(function (r) { if (r[4]) seen[String(r[4])] = true; });
    let latest = since;
    list.forEach(function (t) {
      if (!SHAM_FIELDS.isIncoming(t)) return;
      const ref = 'sham:' + t[SHAM_FIELDS.id];
      if (seen[ref]) return;
      sheet.appendRow([new Date(t[SHAM_FIELDS.time]), displayName_(t[SHAM_FIELDS.name]), String(t[SHAM_FIELDS.amount]), '', ref]);
      seen[ref] = true;
      if (new Date(t[SHAM_FIELDS.time]) > new Date(latest)) latest = iso(t[SHAM_FIELDS.time]);
    });
    props.setProperty('SHAMCASH_LAST_SYNC', latest);
  });
}

function installSyncTrigger() {
  ScriptApp.getProjectTriggers().forEach(function (t) {
    if (t.getHandlerFunction() === 'syncShamCash') ScriptApp.deleteTrigger(t);
  });
  ScriptApp.newTrigger('syncShamCash').timeBased().everyMinutes(5).create();
}
