"""Pure bounded inbox ordering/selection; no database or network dependency."""
from datetime import timedelta

WINDOW = timedelta(days=30)
LIMIT = 100


def recent(events, now):
    by_key = {e['id']: e for e in events if now - WINDOW <= e['at'] <= now}
    return sorted(by_key.values(), key=lambda e: (e['at'], e['id']), reverse=True)[:LIMIT]


def valid_keys(value):
    return (isinstance(value, list) and 1 <= len(value) <= LIMIT
            and all(isinstance(k, str) and 1 <= len(k) <= 96 and k.isascii() for k in value)
            and len(set(value)) == len(value))


def serialize(events, read_keys):
    items = [dict(e, at=e['at'].isoformat(), read=e['id'] in read_keys) for e in events]
    return {'results': items, 'unread': sum(not e['read'] for e in items), 'limit': LIMIT, 'days': WINDOW.days}
