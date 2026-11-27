"""Language allowlist for queue admission and backwards-compatible claims."""
from django.conf import settings

LANGUAGES = ('python', 'c', 'cpp', 'java', 'javascript')
LABELS = ('Python 3', 'C (C17)', 'C++ (C++17)', 'Java 21', 'JavaScript (Node.js 22)')
LANGUAGE_CHOICES = tuple(zip(LANGUAGES, LABELS))


def available_languages():
    if (settings.JUDGE_ENGINE == 'docker_pull' and settings.JUDGE_WORKER_TOKEN
            and getattr(settings, 'JUDGE_MULTILANGUAGE_ENABLED', False)):
        return list(LANGUAGES)
    return ['python']


def claim_languages(data, engine):
    # Legacy clients do not send capabilities and must NEVER receive other code.
    if engine != 'docker_pull':
        return ['python']
    values = data.get('languages', ['python'])
    if (not isinstance(values, list) or not 1 <= len(values) <= len(LANGUAGES)
            or any(not isinstance(v, str) or v not in LANGUAGES for v in values)
            or len(set(values)) != len(values)):
        raise ValueError('Invalid worker languages')
    # Allow an upgraded worker to drain existing jobs after admission is disabled.
    return values
