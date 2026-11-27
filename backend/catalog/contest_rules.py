"""Deterministic automatic contest scoring, independent of worker completion order."""
from collections import defaultdict

PENDING = frozenset(('Queued', 'Running'))
PENALIZED = frozenset(('Wrong Answer', 'Runtime Error', 'Time Limit Exceeded',
                       'Memory Limit Exceeded', 'Output Limit Exceeded'))
WRONG_PENALTY = 20


def scoreboard(attempts, points, starts_at, ends_at):
    """Only in-window admissions; first accepted by admission time; no partial points.

    attempts: (id, user_id, username, task_id, status, passed, total, created_at).
    """
    by_user = {}
    grouped = defaultdict(list)
    pending = 0
    for aid, uid, name, tid, status, passed, total, at in attempts:
        if tid not in points or not starts_at <= at < ends_at:
            continue
        by_user.setdefault(uid, dict(user_id=uid, participant=name, score=0, penalty=0, solved=0, tasks={}))
        grouped[uid, tid].append((at, aid, status, passed, total))
        pending += status in PENDING
    for (uid, tid), items in grouped.items():
        row = by_user[uid]
        wrong = 0
        accepted = False
        for at, aid, status, passed, total in sorted(items):
            if status == 'Accepted' and total > 0 and passed == total:
                penalty = int((at - starts_at).total_seconds() // 60) + wrong * WRONG_PENALTY
                row['score'] += points[tid]
                row['penalty'] += penalty
                row['solved'] += 1
                accepted = True
                break
            if status in PENALIZED:
                wrong += 1
        row['tasks'][str(tid)] = dict(solved=accepted, attempts=len(items), wrong=wrong,
                                     pending=sum(s in PENDING for _, _, s, _, _ in items))
    rows = sorted(by_user.values(), key=lambda r: (-r['score'], r['penalty'], r['participant'].casefold(), r['user_id']))
    previous = None
    rank = 0
    for i, row in enumerate(rows, 1):
        key = row['score'], row['penalty']
        if key != previous:
            rank = i
        row['rank'] = rank
        previous = key
    return rows, pending
