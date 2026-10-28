# MandakhRank — автомат шалгалт, бодит эрэмбэ, 4 оронтой код

## Энэ хувилбар

- Бүртгүүлэх → имэйлээр 4 оронтой код → дөрөв дэх цифрийг оруулахад автоматаар баталгаажуулж нэвтэрнэ.
- Код 10 минут хүчинтэй; 5 буруу оролдлогын дараа шинэ код авна. Дахин илгээхэд 60 секунд хүлээнэ, бүртгүүлсэн нууц үг шаардлагатай.
- Кодыг серверийн нууц түлхүүртэй HMAC хэлбэрээр хадгална. Ашигласан код дахин ажиллахгүй. Бүртгэл, код, нэвтрэлтийн хүсэлтүүдэд DB-д хадгалдаг хязгаар бий.
- Python код илгээх → Queued → Running → Accepted / Wrong Answer / Time Limit Exceeded / Runtime Error / Judge Error.
- Accepted үед бодсон төлөв DB-д хадгалагдана. Нэг бодлогын оноог нэг хэрэглэгчид зөвхөн нэг удаа тооцно.
- Эрэмбэ бодит идэвхтэй, staff бус хэрэглэгчдээс гарна. Нийт оноо, дараа нь бодсон тоогоор эрэмбэлнэ; тэнцсэн хэрэглэгчид ижил байр эзэлнэ. Нийтлээгүй бодлого тооцогдохгүй. CMS-д оноо өөрчилбөл эрэмбийн оноо дагаж өөрчлөгдөнө.
- Flutter web нүүр хуудас болон Django API нэг Render хаяг дээр ажиллана. App 15 секунд тутам эрэмбэ/бодлогуудыг, бодлогын дэлгэц 3 секунд тутам илгээлтүүдийг шинэчилнэ.
- Нэвтрэх session апп нээлттэй байх хугацаанд санах ойд байна; хуудсаа бүтэн refresh хийвэл дахин нэвтэрнэ. Token сервер дээр 7 хоног хүчинтэй.

## Одоо байгаа Render service-ээ шинэчлэх

Эхлээд `mandakhrank` хавтсанд PowerShell нээгээд `.\scripts\build-web.ps1` ажиллуулна. Flutter PATH-д байх ёстой. Энэ нь frontend tests, release build, backend/webapp руу хуулах ажлыг дараалан хийнэ.

**Шинэ Blueprint эсвэл шинэ database үүсгэхгүй.** `mandakhrank-api` болон одоо байгаа PostgreSQL-ээ ашиглана.

1. ZIP-ийг задлаад `mandakhrank` доторх файлуудыг GitHub төслийнхөө root руу хуулж commit/push хийнэ. Өөрийн `.venv`, `.env`, DB файлыг upload хийхгүй. **Эхлээд доорх build-web.ps1 командыг ажиллуулж** `backend/webapp` үүсгэнэ. Энэ generated хавтсыг мөн commit хийнэ.
2. Render → одоо байгаа `mandakhrank-api` → Settings:
   - Root Directory: `backend`
   - Build Command: `pip install -r requirements.txt && python manage.py collectstatic --noinput`
   - Start Command:
     ```sh
     python manage.py migrate --noinput && python manage.py seed_problems --if-empty && python manage.py seed_courses --if-empty && python manage.py serve
     ```
   `serve` нь Gunicorn + judging worker-ийг хамт эхлүүлнэ. Worker-ийг гараар ажиллуулах шаардлагагүй. Байгаа сангийн бодлого, сургалтыг дарж өөрчлөхгүй.
3. Environment-д байгаа `DATABASE_URL`, `DJANGO_SECRET_KEY`, `DJANGO_DEBUG=0`-ийг хадгална. Нууц түлхүүрийг солиход хүлээгдэж байгаа verification кодууд хүчингүй болно.
4. Доорх email, Judge0 тохиргоог хийнэ. Save/redeploy.
5. Live болмогц **https://mandakhrank-api.onrender.com/** хаягийг бусдад өгнө. `/admin/` хэвээр ажиллана. Эхний удаа free service сэрэхэд удаж болно.

## Бусад хүмүүст verification email илгээх

Одоогийн `onboarding@resend.dev` sender нь зөвхөн Resend-д бүртгүүлсэн өөрийн имэйл рүү хүргэнэ. **Public signup-д verified domain шаардлагатай**; аппын код энэ provider-ийн хязгаарыг арилгахгүй.

Resend дээр өөрийн домэйныг баталгаажуулсны дараа Render environment:

```text
RESEND_API_KEY=<өөрийн түлхүүр>
DEFAULT_FROM_EMAIL=MandakhRank <noreply@your-verified-domain>
```

API key-г Flutter эсвэл GitHub-д хийж болохгүй. Domain хараахан байхгүй бол өөрийн Resend account email-аар тест хийнэ. Өмнө бүртгүүлсэн боловч баталгаажаагүй хэрэглэгч `Код оруулах / шинэ код авах` хэсэгт имэйл болон бүртгүүлсэн нууц үгээ оруулж шинэ 4 оронтой код авна. Хуучин урт кодуудыг энэ хувилбар хүлээн авахгүй.

## Automatic judging / Judge0

Submitted code нь Django сервер дээр ажиллахгүй. Judge0 тусгаарласан орчинд ажиллуулна. Өөрийн Judge0 эсвэл Judge0 CE RapidAPI account шаардлагатай. Provider-ийн request quota/төлбөрийг шалгана: нэг илгээлт олон тест ба polling хүсэлт хэрэглэнэ.

Render → Environment:

```text
JUDGE0_URL=https://judge0-ce.p.rapidapi.com
JUDGE0_RAPIDAPI_KEY=<өөрийн RapidAPI түлхүүр>
JUDGE0_RAPIDAPI_HOST=judge0-ce.p.rapidapi.com
JUDGE0_PYTHON_ID=71
```

Өөрийн Judge0 instance ашиглавал `JUDGE0_URL`-ийг өөрийн хаягаар, шаардлагатай бол `JUDGE0_TOKEN`-ийг тохируулна; RapidAPI key хэрэггүй. Provider-ийн `/languages` жагсаалтаас Python language ID-г нягтална.

Worker API ашиглан тест бүрийг шалгана (2s CPU, 5s wall, 128 MB, network disabled). Нууц тестүүд browser-д очихгүй. Нэг хэрэглэгч 3 хүлээгдэж буй илгээлт, цагт 30 илгээлтийн хязгаартай. Сервер тасарсан Running илгээлт 5 минутын дараа Judge Error болж дахин илгээх боломжтой. Provider тасарвал Judge Error гарна, хуурамч Accepted өгөхгүй.

Free Render web instance унтсан үед worker мөн зогсоно. Хэрэглэгч аппыг ашиглаж polling хийх үед ажиллана; тасралтгүй background processing шаардлагатай бол always-on web эсвэл тусдаа worker хэрэгтэй. Энэ хувилбар нэг service дотор worker ажиллуулдаг тул paid worker заавал үүсгэхгүй.

## Flutter-ийг өөрчилсний дараа дахин build хийх

Энэ ZIP нь source code агуулна; compiled web build ороогүй. Анх удаа болон Flutter source өөрчилсний дараа төслийн root-оос PowerShell дээр:

```powershell
.\scripts\build-web.ps1
```

Дараа нь source болон `backend/webapp`-аа commit/push хийнэ. Flutter SDK-г Render build дээр суулгах шаардлагагүй.

Local web: `flutter run -d chrome --web-port 5173`. API default нь hosted `/api` хаяг. Local Django ашиглах бол `--dart-define=API_BASE_URL=http://127.0.0.1:8000/api` нэмнэ. Өөр frontend domain ашиглавал Render `CORS_ALLOWED_ORIGINS`-д яг тухайн HTTPS origin-ийг нэмнэ. Same-origin web-д нэмэх шаардлагагүй.

Local Django worker-ийг Windows дээр тусад нь ажиллуулна:

```powershell
.\.venv\Scripts\python.exe manage.py runserver
# Өөр terminal дээр (ижил Judge0 env vars тохируулсан):
.\.venv\Scripts\python.exe manage.py judge_worker
```

## Шалгах дараалал

1. Шинэ regular user бүртгүүл. Зөв кодын дөрөв дэх цифрийн дараа login автоматаар хийгдэх ёстой.
2. Хоёр тооны нийлбэр бодлогод `a,b=map(int,input().split()); print(a+b)` илгээ.
3. Queued/Running → Accepted; бодсон тэмдэг ба нийт оноо шинэчлэгдэнэ.
4. Ижил бодлогоо дахин Accepted болгоход оноо дахин нэмэгдэхгүй.
5. `print(0)` илгээвэл Wrong Answer; өмнөх solved төлөв хадгалагдана.
6. Өөр browser/device дээр өөр user бүртгүүлж leaderboard-т харагдаж буйг шалга.

CMS тэмцээний дүн өмнөх шиг admin-аар удирдагдана. Шинэ автомат judging болон leaderboard нь practice бодлогуудынх; contest-specific автомат оноолт энэ өөрчлөлтөд ороогүй.

## Validation

Backend: `python manage.py test catalog`. Email/Judge0 integration tests use mocks — real delivery/execution requires your configured provider credentials. Flutter validation results are included in `VALIDATION.md`.
