from pathlib import Path
import os
BASE_DIR = Path(__file__).resolve().parent.parent
SECRET_KEY = os.environ.get('DJANGO_SECRET_KEY', 'local-template-only-not-for-production')
DEBUG = os.environ.get('DJANGO_DEBUG', '1') == '1'
ALLOWED_HOSTS = os.environ.get('DJANGO_ALLOWED_HOSTS', 'localhost,127.0.0.1,10.0.2.2,testserver').split(',')
INSTALLED_APPS = ['django.contrib.admin','django.contrib.auth','django.contrib.contenttypes','django.contrib.sessions','django.contrib.messages','django.contrib.staticfiles','corsheaders', 'catalog']
MIDDLEWARE = ['django.contrib.sessions.middleware.SessionMiddleware','django.middleware.csrf.CsrfViewMiddleware','django.contrib.auth.middleware.AuthenticationMiddleware','django.contrib.messages.middleware.MessageMiddleware','django.middleware.security.SecurityMiddleware', 'corsheaders.middleware.CorsMiddleware', 'django.middleware.common.CommonMiddleware']
CORS_ALLOWED_ORIGINS = ['http://localhost:5173', 'http://127.0.0.1:5173']
ROOT_URLCONF = 'config.urls'
WSGI_APPLICATION = 'config.wsgi.application'
DATABASES = {'default': {'ENGINE': 'django.db.backends.sqlite3', 'NAME': BASE_DIR / 'db.sqlite3'}}
LANGUAGE_CODE = 'mn'
TIME_ZONE = 'Asia/Ulaanbaatar'
USE_TZ = True
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

STATIC_URL = '/static/'
TEMPLATES = [{'BACKEND':'django.template.backends.django.DjangoTemplates','DIRS':[],'APP_DIRS':True,'OPTIONS':{'context_processors':['django.template.context_processors.request','django.contrib.auth.context_processors.auth','django.contrib.messages.context_processors.messages']}}]
JUDGE0_URL = os.environ.get('JUDGE0_URL','')
JUDGE0_TOKEN = os.environ.get('JUDGE0_TOKEN','')
JUDGE0_PYTHON_ID = int(os.environ.get('JUDGE0_PYTHON_ID','71'))
AUTH_PASSWORD_VALIDATORS = [
 {'NAME':'django.contrib.auth.password_validation.MinimumLengthValidator'},
 {'NAME':'django.contrib.auth.password_validation.CommonPasswordValidator'},
 {'NAME':'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
 {'NAME':'django.contrib.auth.password_validation.NumericPasswordValidator'},
]
DATA_UPLOAD_MAX_MEMORY_SIZE = 65536

# Deployment and transactional email
if os.environ.get('DATABASE_URL'):
    import dj_database_url
    DATABASES = {'default':dj_database_url.parse(os.environ['DATABASE_URL'],conn_max_age=60,ssl_require=True)}
if os.environ.get('RENDER_EXTERNAL_HOSTNAME'):
    ALLOWED_HOSTS.append(os.environ['RENDER_EXTERNAL_HOSTNAME'])
    CSRF_TRUSTED_ORIGINS = ['https://'+os.environ['RENDER_EXTERNAL_HOSTNAME']]
    SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO','https')
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True
STATIC_ROOT = BASE_DIR/'staticfiles'
MIDDLEWARE.insert(MIDDLEWARE.index('django.middleware.security.SecurityMiddleware')+1,'whitenoise.middleware.WhiteNoiseMiddleware')
CORS_ALLOWED_ORIGINS = os.environ.get('CORS_ALLOWED_ORIGINS','http://localhost:5173,http://127.0.0.1:5173').split(',')
EMAIL_BACKEND = os.environ.get('EMAIL_BACKEND', 'catalog.email_backend.GmailScriptBackend')
DEFAULT_FROM_EMAIL = 'MandakhRank'
GMAIL_SCRIPT_URL = os.environ.get('GMAIL_SCRIPT_URL', '')
GMAIL_SCRIPT_SECRET = os.environ.get('GMAIL_SCRIPT_SECRET', '')

JUDGE0_RAPIDAPI_KEY = os.environ.get('JUDGE0_RAPIDAPI_KEY', '')
JUDGE0_RAPIDAPI_HOST = os.environ.get('JUDGE0_RAPIDAPI_HOST', 'judge0-ce.p.rapidapi.com')

# Prebuilt Flutter web files are served from this same origin.
WHITENOISE_ROOT = BASE_DIR / 'webapp'
