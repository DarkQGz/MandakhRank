# Gmail-ээс 4 оронтой код автоматаар илгээх

Энэ хувилбар Firebase болон Resend ашиглахгүй. Django код үүсгэж шалгана; Google Apps Script таны тусгай Gmail account-аас илгээнэ. Flutter-д Gmail password эсвэл sender secret хадгалахгүй.

## 1. Gmail sender (нэг удаа)

1. App-д зориулсан тусдаа Gmail account үүсгэх эсвэл өөрийн сонгосон account-даа нэвтэрнэ. Шинэ Gmail account үүсгэх/Google sign-in-ийг та өөрөө хийнэ.
2. Тэр account-аар https://script.google.com/ нээгээд **New project** сонгоно.
3. `Code.gs` дотор ZIP-ийн `google-mailer/Code.gs` файлын агуулгыг хуулж Save хийнэ.
4. Компьютерийн PowerShell дээр sender secret үүсгэнэ:

```powershell
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$mailerBytes = New-Object byte[] 32
$rng.GetBytes($mailerBytes)
$rng.Dispose()
([BitConverter]::ToString($mailerBytes)).Replace('-', '').ToLowerInvariant()
```

Гарсан 64 тэмдэгт утгыг хадгална. Үүнийг чат, GitHub, Flutter source руу оруулахгүй.

5. Apps Script → **Project Settings → Script Properties → Add script property**:
   - Property: `MAILER_SECRET`
   - Value: үүсгэсэн 64 тэмдэгт secret
6. **Deploy → New deployment → Web app**:
   - Execute as: **Me** (dedicated Gmail account)
   - Who has access: **Anyone**
   - Deploy хийж, өөрийн үүсгэсэн script-д email илгээх Google зөвшөөрлийг батална.
   - Хэрэв Workspace байгууллагын account нь Anyone сонголтыг хориглосон бол энэ тохиргоо ажиллахгүй; тухайн admin-ийн бодлогыг мөрдөнө.
7. `/exec`-ээр төгссөн **Web app URL**-ийг хуулна. `/dev` test URL ашиглахгүй.

Anyone гэдэг нь Render server endpoint-д хүрч чадна гэсэн утгатай. Secret таарахгүй хүсэлтийг script илгээхээс өмнө хориглоно. Script зөвхөн тогтсон verification template, нэг recipient, 4 оронтой код илгээнэ; arbitrary mail relay биш. Secret өөрчлөх бол Apps Script болон Render дээр хоёуланг нь солино.

## 2. Render тохиргоо

Одоо байгаа `mandakhrank-api` → Environment дээр:

| Key | Value |
| --- | --- |
| `GMAIL_SCRIPT_URL` | Дээр хуулсан `https://script.google.com/macros/s/.../exec` URL |
| `GMAIL_SCRIPT_SECRET` | `MAILER_SECRET`-тэй яг ижил secret |
| `EMAIL_BACKEND` | `catalog.email_backend.GmailScriptBackend` |

`RESEND_API_KEY`, `DEFAULT_FROM_EMAIL`, `FIREBASE_PROJECT_ID` энэ хувилбарт хэрэггүй. `DATABASE_URL`, `DJANGO_SECRET_KEY`, Judge0 variables-аа хадгална. Gmail password/App Password шаардлагагүй.

Start Command хэвээр:

```text
python manage.py migrate --noinput && python manage.py seed_problems --if-empty && python manage.py seed_courses --if-empty && python manage.py serve
```

## 3. App шинэчлэх

ZIP доторх `mandakhrank`-ийн агуулгыг repo root руу хуулж файлуудыг replace хийнэ. Өөрийн `.venv`, `.env`, database болон platform тохиргоогоо устгахгүй. Firebase release-ээс сольж байгаа бол `frontend/lib/firebase_session.dart` болон `backend/catalog/firebase_auth.py` нь хэрэггүй, устгаж болно. Хуучин migration файлуудыг устгахгүй; migration 0005 энэ ZIP-д нийцтэй байдлаар хадгалагдсан.

PowerShell — repo root:

```powershell
$env:Path = "C:\Users\dquat\develop\flutter\bin;$env:Path"
Unblock-File .\scripts\build-web.ps1
.\scripts\build-web.ps1
```

Энэ script Firebase key асуухгүй. Хэрэв асууж байвал хуучин script-ээ replace хийгээгүй байна.

Source болон generated `backend/webapp`-ийг commit/push хийнэ. Render → **Manual Deploy → Deploy latest commit**. Шинэ service/database үүсгэхгүй.

## 4. Хэрэглэгчийн урсгал

Бүртгүүлэх → dedicated Gmail-аас 4 оронтой код ирнэ → дөрөв дэх цифрийг оруулахад Django автоматаар шалгаж login хийнэ.

Код 10 минут хүчинтэй; 5 удаа буруу оруулбал шинэ код авна. Resend 60 секунд cooldown-той, бүртгүүлсэн нууц үг шаарддаг. Хэрэглэгч Gmail бус өөр эзэмшдэг email хаяг ашиглаж болно. Spam хавтсыг мөн шалгана.

Анхны Django хэрэглэгчид/admin, problems/courses/submissions хадгалагдана. Хэрэв Firebase release-ээр шинэ хэрэглэгч үнэхээр үүсгэсэн бол тэд local password-гүй байдаг; админ тухайн хэрэглэгчийн password-ийг тусад нь тохируулах шаардлагатай. Firebase account password-ийг app мэдэхгүй, автоматаар хуулдаггүй.

## Хязгаар ба оношлогоо

- Render Free нь SMTP 25/465/587 портыг блоклодог учир HTTPS Google Script ашиглаж байна.
- Google-ийн personal Gmail Apps Script quota одоогоор өдөрт 100 recipient. Resend код ч quota хэрэглэнэ. Google энэ хязгаарыг өөрчилж/бууруулж болно. Script нэг минутанд 10 илгээлтийн нэмэлт хязгаартай.
- Энэ нь жижиг project/demo-д зориулсан шийдэл; их хэрэглэгчтэй бол илүү өндөр багтаамжтай transactional sender шаардлагатай.
- Script code-оо засвал Deploy → Manage deployments → Edit → New version → Deploy. URL хэвээр үлдэнэ.
- URL-ийг browser-д нээхэд `{"ok":false,"message":"POST only"}` гарвал хэвийн, энэ нь email илгээхгүй.
- `EMAIL_BACKEND`-ийг console/SMTP/Resend гэж үлдээж болохгүй. URL/secret mismatch, authorization, quota асуудлыг Apps Script → Executions хэсгээс шалгана. Secret/code-оо log хийхгүй.
- Автоматаар илгээх sender нь dedicated Google account эзэмшигч. Gmail password эсвэл secret нь хэрэглэгчийн app bundle-д орохгүй.

Албан ёсны лавлагаа:
- https://render.com/docs/free
- https://developers.google.com/apps-script/guides/web
- https://developers.google.com/apps-script/reference/mail/mail-app
- https://developers.google.com/apps-script/guides/services/quotas

Энэ багц source code; live Google deployment болон бодит имэйл илгээлт account эзэмшигчийн нэг удаагийн authorization/setup-ийн дараа ажиллана. App link, verification болон Judge0-г эцэслэн бодитоор туршина.
