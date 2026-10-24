// الصق هذا الكود في Apps Script المرتبط بجدول Google Sheets (انظر tools/DONORS_SETUP.md).
// الصف الأول عناوين: التاريخ | الاسم | المبلغ. لحذف اسم غير مرغوب احذف صفه من الجدول.
const MAX_ROWS = 200;

function doGet(e) {
  const p = e.parameter || {};
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheets()[0];
  if (p.action === 'add') {
    const lock = LockService.getScriptLock();
    lock.waitLock(10000);
    try {
      sheet.appendRow([new Date(), clean(p.name, 40) || 'فاعل خير', clean(p.amount, 20)]);
    } finally {
      lock.releaseLock();
    }
  }
  const last = sheet.getLastRow();
  const n = Math.min(Math.max(last - 1, 0), MAX_ROWS);
  const rows = n === 0 ? [] : sheet.getRange(last - n + 1, 1, n, 3).getValues();
  const out = rows.reverse().map(function (r) {
    return { date: new Date(r[0]).toISOString(), name: String(r[1]), amount: String(r[2]) };
  });
  return ContentService.createTextOutput(JSON.stringify(out)).setMimeType(ContentService.MimeType.JSON);
}

// يمنع تحويل النص إلى صيغة جدول (=، +، -، @) ويقصّ الطول.
function clean(s, max) {
  s = String(s || '').replace(/[\r\n\t]+/g, ' ').trim().slice(0, max);
  return /^[=+\-@]/.test(s) ? "'" + s : s;
}
