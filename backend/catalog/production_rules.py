"""Pure, non-secret production configuration validation."""

def configuration_issues(*, debug, secret, engine, hosts, judge_engine, worker_token,
                         secure_cookies, secure_proxy, lease, gmail_url='', gmail_secret='',
                         email_backend='', ssl_redirect=False, judge0_url=''):
    errors, warnings = [], []
    if debug:
        errors.append('DJANGO_DEBUG must be 0 in production.')
    if not isinstance(secret, str) or len(secret) < 32 or len(set(secret)) < 8 or secret == 'local-template-only-not-for-production':
        errors.append('DJANGO_SECRET_KEY must be a strong, persistent secret (at least 32 characters).')
    if engine != 'django.db.backends.postgresql':
        errors.append('Production requires PostgreSQL; check DATABASE_URL. Never fall back to SQLite.')
    if not hosts or '*' in hosts or not any(h and h not in ('localhost','127.0.0.1','10.0.2.2','testserver','[::1]') for h in hosts):
        errors.append('Configure explicit production ALLOWED_HOSTS; wildcard hosts are not allowed.')
    if not secure_cookies or not secure_proxy:
        errors.append('Secure cookies and the trusted HTTPS proxy configuration are required.')
    if not ssl_redirect:
        warnings.append('HTTPS redirection is disabled. Confirm TLS is enforced by the hosting proxy.')
    if judge_engine not in ('docker_pull','cms_pull','judge0'):
        errors.append('Unrecognized JUDGE_ENGINE.')
    if judge_engine in ('docker_pull','cms_pull'):
        if not worker_token:
            errors.append('JUDGE_WORKER_TOKEN is missing.')
        elif len(worker_token) < 32 or len(set(worker_token)) < 8:
            warnings.append('Rotate JUDGE_WORKER_TOKEN to a strong random value on both Render and the worker before public use.')
        if not 120 <= lease <= 3600:
            errors.append('CMS_LEASE_SECONDS should be between 120 and 3600 for this worker.')
    elif judge_engine == 'judge0':
        if not judge0_url.startswith('https://'):
            errors.append('Judge0 is selected but JUDGE0_URL is missing or not HTTPS.')
        else:
            warnings.append('Judge0 is selected; verify this is intentional.')
    if email_backend == 'catalog.email_backend.GmailScriptBackend' and (not gmail_url.startswith('https://') or not gmail_secret):
        warnings.append('Gmail script configuration is incomplete; registration email may fail.')
    return errors, warnings
