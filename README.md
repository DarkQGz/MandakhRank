# v0.3 — Автомат шалгалттай дасгал бодлогууд

Шинэ боломжууд: 8 Монгол бодлого / 28 тест, account бүртгэл ба нэвтрэлт, Python 3 код илгээх, автомат verdict, өөрийн submission history, database-д хадгалагдсан completion. Django Admin нь бодлого болон нууц тестийн CMS. Тусдаа cms-dev judging platform суулгаагүй; Judge0 API ашиглана.

## Шинэчлээд ажиллуулах
Өмнөх db.sqlite3-аа хадгална. Доорх командыг backend хавтаснаас ажиллуулна:

```powershell
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe manage.py migrate
.\.venv\Scripts\python.exe manage.py seed_problems
```

Хэрэв шинэ төсөл бол доорх Backend эхлүүлэх хэсгийн venv, migrate, createsuperuser алхмыг мөн хийнэ. Seed command дахин ажиллахад байгаа бодлогуудыг дарж өөрчлөхгүй.

## Judge0 заавал тохируулах
Ажиллаж байгаа өөрийн Judge0 CE серверийн URL хэрэгтэй. Judge0 суулгах албан repository: https://github.com/judge0/judge0 . API баримт: https://ce.judge0.com/docs . Энэхүү ZIP нь Judge0 сервер, credentials эсвэл үнэгүй hosted эрх агуулаагүй. Judge0 серверээ Linux орчинд тусад нь байрлуулах эсвэл өөрийн ашиглах эрхтэй compatible endpoint тохируулна. Энэ орчноос серверийг deploy хийгээгүй.

Django terminal дээр, өөрийн бодит endpoint-оор солих:

```powershell
$env:JUDGE0_URL = "http://127.0.0.1:2358"
$env:JUDGE0_PYTHON_ID = "71"
# Сервер X-Auth-Token шаарддаг бол:
# $env:JUDGE0_TOKEN = "YOUR_TOKEN"
.\.venv\Scripts\python.exe manage.py runserver
```

71 нь Judge0 CE Python language ID-ийн default. Өөрийн Judge0 `/languages` endpoint-оос Python ID-г шалгаж тохируулна. Provider нь зөвхөн X-Auth-Token header ашигладаг endpoint байх ёстой; RapidAPI-ийн тусгай headers энэ adapter-д ороогүй.

Backend хавтсанд хоёр дахь terminal нээгээд ижил environment variables тавьж worker ажиллуулна:

```powershell
$env:JUDGE0_URL = "http://127.0.0.1:2358"
$env:JUDGE0_PYTHON_ID = "71"
# Шаардлагатай бол ижил JUDGE0_TOKEN тохируулна.
.\.venv\Scripts\python.exe manage.py judge_worker
```

Flutter-ийг доорх API_BASE_URL-тай командаар гурав дахь terminal-д ажиллуулна. Бодлого сонгох → Бүртгүүлэх/Нэвтрэх → Python код → Илгээж шалгуулах. Жишээ эхний бодлогын зөв код:

```python
a, b = map(int, input().split())
print(a + b)
```

Queued → Running → Accepted / Wrong Answer / Time Limit Exceeded / Runtime Error / Compilation Error / Judge Error.
Бүх тест Accepted бол тухайн хэрэглэгчийн completion хадгалагдана. Апп дээр 3 секунд тутам үр дүнг шинэчилнэ. Буцаж бодлогын жагсаалт руу ороход ✓ тэмдэг гарна. Нэвтрэлтийн token memory-д хадгалагдана: refresh/restart хийвэл дахин нэвтрэх шаардлагатай, харин completion database-д үлдэнэ. Token 7 хоногийн хүчинтэй.

Тест бүр 2 секунд CPU, 5 секунд wall time, 128MB, network disabled хүсэлтээр Judge0-д очно. Код ба нууц тестүүд зөвхөн тохируулсан Judge0 серверт илгээгдэнэ. Django host дээр хэрэглэгчийн код ажиллуулахгүй. Worker зогссон бол Queued хэвээр байна; interrupted Running submission-ийг ганц worker байх үед `judge_worker --recover` командаар Judge Error болгоод хэрэглэгч дахин илгээж болно. Judge0 холболт тасарвал Judge Error; хэзээ ч Accepted гэж хуурамчаар тэмдэглэхгүй.

## Бодлого ба тестийн CMS
Admin → Дасгал бодлогууд → Add: нөхцөл, жишээ, оноо, түвшин, сэдэв, Нийтлэх. Доорх Нууц тестүүд дээр stdin болон expected output оруулна. Тестгүй бодлого submission хүлээж авахгүй. Verdict нь Judge0-ийн output comparison ашиглана. Нууц тестүүд public API-д очихгүй. Илгээх үед тестийн snapshot хадгалдаг тул дараа нь CMS дээр засварлахад хуучин submission өөрчлөгдөхгүй. Өмнө Accepted болсон completion автоматаар дахин шүүгдэхгүй.

## Шалгасан хүрээ ба хязгаар
14 backend тест амжилттай; Judge0 response mock ашиглан Accepted, Wrong Answer, TLE, runtime error, outage, completion, auth/access, hidden test хамгаалалтыг шалгасан. Live Judge0 endpoint байхгүй тул бодит кодын execution-ийг end-to-end ажиллуулаагүй. Flutter syntax шалгасан; SDK байхгүй тул Flutter build/render баталгаажаагүй.
Энэ нь local prototype: public deploy хийхээс өмнө HTTPS, нэвтрэх хүсэлтийн rate limit, queue capacity/worker monitoring, provider quotas тохируулна. Contest submissions/scoring энэ шинэчлэлд холбогдоогүй; автомат шалгалт нь Дасгал бодлогууд хуудсанд ажиллана.

---

# Mandakhrank v0.3 — Сургалт ба тэмцээний CMS

Django Admin нь CMS болно. Энэ нь тусдаа cms-dev Contest Management System программын integration биш.

## Backend эхлүүлэх (PowerShell)
Төслийн үндсэн mandakhrank хавтаснаас:

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe manage.py migrate
.\.venv\Scripts\python.exe manage.py seed_courses
.\.venv\Scripts\python.exe manage.py createsuperuser
.\.venv\Scripts\python.exe manage.py runserver
```

http://127.0.0.1:8000/admin/ хаягаар өөрийн үүсгэсэн admin эрхээр нэвтэрнэ.

## Flutter ажиллуулах
Шинэ terminal дээр төслийн үндсэн хавтаснаас:

```powershell
cd frontend
$env:Path = "C:\Users\dquat\develop\flutter\bin;$env:Path"
flutter create --project-name mandakhrank --platforms=web,android .
flutter pub get
flutter run -d chrome --web-port 5173 --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```

CMS-ийн шинэ өгөгдлийг харахын тулд API_BASE_URL тохиргоотой ажиллуулах шаардлагатай. Тохиргоогүй үед хуучин JSON demo ажиллана, тэмцээний жагсаалт хоосон байна. Admin дээр хадгалсны дараа аппын баруун дээд Шинэчлэх товчийг дарна. Нээлттэй detail цонхыг хаагаад шинэчилнэ.

## Сургалт нэмэх
1. Admin → Сургалтууд → Add.
2. Нэр, чиглэл, түвшин, тайлбар, өнгө сонгоно.
3. Хичээлүүд хэсэгт гарчиг, дараалал, агуулгыг оруулна. Агуулга нь plain text, кодыг текстээр оруулж болно.
4. Сургалт болон харуулах хичээл бүрийн Нийтлэх сонголтыг идэвхжүүлээд хадгална.
5. Flutter → Сургалтууд → Шинэчлэх → Хөтөлбөр үзэх. Хичээлийг дэлгэж агуулгыг уншина.

## Тэмцээн удирдах
1. Admin → Тэмцээнүүд → Add.
2. Нэр, тайлбар, зарлал, эхлэх/дуусах цаг оруулна. Admin цагийн бүс Asia/Ulaanbaatar.
3. Бодлогуудыг A, B, C гэсэн давтагдахгүй дугаартай нэмнэ. Нөхцөл, жишээ оролт/гаралт, дээд оноо тохируулна.
4. Нийтлэх сонголтыг идэвхжүүлж хадгална.
5. Flutter → Тэмцээнүүд дээр статусын шүүлтүүр, хайлт, хугацаа, дэлгэрэнгүй харагдана. Төхөөрөмжийн цагийн бүсээр огноог харуулна.
6. Бодлогын нөхцөл эхлэх цаг хүртэл API дээр нууцлагдана. Draft тэмцээн бүхэлдээ харагдахгүй.
7. Admin → Баталгаажуулсан дүнгүүд дээр бодлого, оролцогчийн username, оноо, торгуулийн минутыг оруулна. Нэг бодлого/username-д нэг дүн байна; засахдаа хуучин дүнг өөрчилнө.
8. Standings нь оноог нийлүүлж буурахаар, тэнцвэл торгуулийн минут өсөхөөр эрэмбэлнэ. Оноо/торгууль хоёулаа тэнцвэл ижил байр эзэлнэ. Энэ нь Codeforces-ийн dynamic scoring/rating алгоритм биш.

## Одоогийн хүрээ
Бэлэн: database-backed сургалт/хичээл, draft/publish, admin permissions, тэмцээний хуваарь/зарлал/бодлого, manually verified standings, Flutter course content болон contest UI.

Ороогүй: contest registration, автомат contest scoring, Codeforces rating, видео, сургалтын явц хадгалах. Rank хуудас жишээ JSON ашиглана. Дасгалын бодлогууд database ашиглаж автомат шалгалт, бодсон төлөвтэй болсон. Тэмцээний оноо нь одоогоор admin гараар баталгаажуулсан дүн.

## Шалгалт
Backend: `python manage.py test catalog` — 14 тест амжилттай (Judge0 хариуг mock хийсэн). Migration болон Django system check амжилттай. Dart syntax parser шалгалт амжилттай. Flutter SDK байхгүй учир build, flutter analyze, widget tests болон rendering шалгалтыг ажиллуулаагүй.

## Файлууд
- backend/catalog/models.py — database models
- backend/catalog/admin.py — CMS forms / inline lessons and problems
- backend/catalog/views.py — published API, embargo, standings
- backend/catalog/migrations/ — schema migration
- frontend/lib/main.dart — course content, contest list/details
- frontend/lib/data.dart — API loading

API: /api/courses/, /api/courses/<id>/, /api/contests/, /api/contests/<id>/.
Эдгээр нь public read-only endpoints; засварыг admin эрхээр CMS дээр хийнэ.

Local development тохиргоотой. Production-д SECRET_KEY, DEBUG=False, allowed hosts, HTTPS тохируулна. Database болон admin password ZIP-д ороогүй. Шинэ ZIP-ийг тусдаа хавтсанд задлаад ашиглах эсвэл өөрийн git changes-ийг хадгалсны дараа source файлуудыг нийлүүлнэ. Өөрийн .venv, db.sqlite3, .git файлуудыг устгахгүй.
