"""Pure answer-validation rules. Never execute a student's input."""
TYPED_KINDS = frozenset(('fill', 'short'))
MAX_ANSWER_LENGTH = 200


def is_typed(q):
    return q.get('kind') in TYPED_KINDS


def normalize(text, casefold=False):
    text = text.strip()
    return text.casefold() if casefold else text


def valid_answer(q, value):
    if not isinstance(value, str) or not value.strip() or len(value) > MAX_ANSWER_LENGTH:
        return False
    if is_typed(q):
        # Single-line fragments only; rejecting control characters also keeps feedback readable.
        return not any(ord(c) < 32 or ord(c) == 127 for c in value)
    return value in {o['id'] for o in q['options']}


def is_correct(q, value):
    if not valid_answer(q, value):
        return False
    if is_typed(q):
        return normalize(value, q['casefold']) in {normalize(a, q['casefold']) for a in q['accepted']}
    return value == q['correct']


def answer_text(q, value):
    if is_typed(q):
        return value.strip()
    return next(o['text'] for o in q['options'] if o['id'] == value)
