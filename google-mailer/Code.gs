/* Deploy under your dedicated Gmail account: Execute as Me, access Anyone.
 * Set MAILER_SECRET (64 lowercase hex characters) in Script Properties first.
 * Never put this secret in Flutter or in the deployment URL.
 */
function reply(value) {
  return ContentService.createTextOutput(JSON.stringify(value))
    .setMimeType(ContentService.MimeType.JSON);
}
function sameSecret(a, b) {
  if (typeof a !== 'string' || typeof b !== 'string' ||
      !/^[a-f0-9]{64}$/.test(a) || !/^[a-f0-9]{64}$/.test(b)) return false;
  var difference = 0;
  for (var i = 0; i < 64; i++) difference |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return difference === 0;
}
function doPost(e) {
  var lock = null;
  try {
    if (!e || !e.postData || e.postData.contents.length > 4096) return reply({ok:false});
    var data = JSON.parse(e.postData.contents);
    var properties = PropertiesService.getScriptProperties();
    if (!sameSecret(data.secret, properties.getProperty('MAILER_SECRET'))) return reply({ok:false});
    if (typeof data.code !== 'string' || !/^[0-9]{4}$/.test(data.code) ||
        typeof data.to !== 'string' || data.to.length > 254 ||
        !/^[^\s@,;<>]+@[^\s@,;<>]+\.[^\s@,;<>]+$/.test(data.to)) return reply({ok:false});
    lock = LockService.getScriptLock();
    if (!lock.tryLock(5000)) return reply({ok:false});
    // Hard global throughput limit backed by properties, not evictable cache.
    var now = Date.now();
    var windowStart = Number(properties.getProperty('WINDOW_START') || 0);
    var count = Number(properties.getProperty('WINDOW_COUNT') || 0);
    if (now - windowStart >= 60000) { windowStart = now; count = 0; }
    if (count >= 10 || MailApp.getRemainingDailyQuota() < 1) return reply({ok:false});
    properties.setProperties({WINDOW_START:String(windowStart), WINDOW_COUNT:String(count+1)});
    // Fixed template only: this endpoint cannot send arbitrary HTML/subjects.
    MailApp.sendEmail({
      to:data.to,
      subject:'MandakhRank — Баталгаажуулах код',
      body:'Таны баталгаажуулах код: ' + data.code + '\n\n' +
        'Апп дээр энэ 4 оронтой кодыг оруулна уу. 10 минут хүчинтэй.\n' +
        'Та бүртгүүлээгүй бол энэ имэйлийг үл хэрэгсэнэ үү. Кодыг бусдад бүү дамжуулаарай.',
      name:'MandakhRank'
    });
    return reply({ok:true});
  } catch (error) {
    return reply({ok:false});
  } finally {
    if (lock && lock.hasLock()) lock.releaseLock();
  }
}
function doGet() { return reply({ok:false, message:'POST only'}); }
