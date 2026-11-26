"""Pure progression rules. No client input, no side effects, no leaderboard points."""
from datetime import timedelta

XP_PER_LEVEL = 250
XP_WEIGHTS = {'solved': 20, 'lessons': 10, 'courses': 100, 'contests': 50}
GROUPS = ('Бодлого', 'Суралцах', 'Тууштай байдал', 'Тэмцээн', 'Ур чадвар')
# code, group, title, requirement, metric, threshold, icon
ACHIEVEMENTS = (
    ('solve_1', 0, 'Анхны алхам', '1 бодлогыг зөв бодох', 'solved', 1, 'code'),
    ('solve_5', 0, 'Шинэ кодлогч', '5 өөр бодлогыг зөв бодох', 'solved', 5, 'code'),
    ('solve_10', 0, 'Кодлогч', '10 өөр бодлогыг зөв бодох', 'solved', 10, 'code'),
    ('solve_25', 0, 'Бодолтын хэмнэл', '25 өөр бодлогыг зөв бодох', 'solved', 25, 'code'),
    ('solve_50', 0, 'Алгоритмч', '50 өөр бодлогыг зөв бодох', 'solved', 50, 'brain'),
    ('solve_100', 0, 'Зуун бодлого', '100 өөр бодлогыг зөв бодох', 'solved', 100, 'trophy'),
    ('solve_200', 0, 'Шилдэг бодогч', '200 өөр бодлогыг зөв бодох', 'solved', 200, 'trophy'),
    ('solve_300', 0, 'Төгс гүйцэтгэл', '300 өөр бодлогыг зөв бодох', 'solved', 300, 'crown'),
    ('lesson_1', 1, 'Мэдлэгийн эхлэл', '1 хичээлийн шалгалтад тэнцэх', 'lessons', 1, 'book'),
    ('lesson_10', 1, 'Идэвхтэй суралцагч', '10 хичээл дуусгах', 'lessons', 10, 'book'),
    ('lesson_40', 1, 'Мэдлэг цуглуулагч', '40 хичээл дуусгах', 'lessons', 40, 'book'),
    ('lesson_80', 1, 'Эрдэмтэн', '80 хичээл дуусгах', 'lessons', 80, 'school'),
    ('lesson_160', 1, 'Мэдлэгийн оргил', '160 хичээл дуусгах', 'lessons', 160, 'school'),
    ('course_1', 1, 'Анхны сургалт', '1 сургалтын нэгдсэн шалгалтад тэнцэх', 'courses', 1, 'school'),
    ('python', 1, 'Python мастер', 'Python-ийн үндэс сургалтыг дуусгах', 'python', 1, 'code'),
    ('course_16', 1, 'Их мастер', '16 сургалт дуусгах', 'courses', 16, 'crown'),
    ('streak_3', 2, 'Хэмнэлээ олсон', '3 өдөр дараалан идэвхтэй байх', 'longest_streak', 3, 'flame'),
    ('streak_7', 2, 'Тууштай суралцагч', '7 өдөр дараалан идэвхтэй байх', 'longest_streak', 7, 'flame'),
    ('streak_14', 2, 'Хоёр долоо хоног', '14 өдөр дараалан идэвхтэй байх', 'longest_streak', 14, 'flame'),
    ('streak_30', 2, 'Сарын сорилт', '30 өдөр дараалан идэвхтэй байх', 'longest_streak', 30, 'flame'),
    ('streak_100', 2, 'Зуун өдрийн дадал', '100 өдөр дараалан идэвхтэй байх', 'longest_streak', 100, 'flame'),
    ('contest_1', 3, 'Анхны тэмцээн', 'Дууссан 1 тэмцээнд баталгаажсан эерэг оноо авах', 'contests', 1, 'flag'),
    ('contest_3', 3, 'Өрсөлдөгч', 'Дууссан 3 тэмцээнд эерэг оноо авах', 'contests', 3, 'flag'),
    ('contest_10', 3, 'Тэмцээний туршлага', 'Дууссан 10 тэмцээнд эерэг оноо авах', 'contests', 10, 'trophy'),
    ('contest_podium', 3, 'Шилдэг гурав', 'Дууссан тэмцээнд эерэг оноотой эхний 3 байрт орох', 'podiums', 1, 'medal'),
    ('contest_win', 3, 'Аварга', 'Дууссан тэмцээнд эерэг оноотой 1-р байрт орох', 'wins', 1, 'crown'),
    ('medium_10', 4, 'Алгоритмын дадал', 'Дунд түвшний 10 өөр бодлогыг зөв бодох', 'medium', 10, 'brain'),
    ('hard_10', 4, 'Хүндийг давсан', 'Хүнд түвшний 10 өөр бодлогыг зөв бодох', 'hard', 10, 'brain'),
    ('expert_5', 4, 'Мэргэшсэн кодлогч', 'Мэргэжлийн түвшний 5 өөр бодлогыг зөв бодох', 'expert', 5, 'medal'),
    ('all_difficulties', 4, 'Олон талын ур чадвар', 'Таван түвшин тус бүрээс 1-ээс доошгүй бодлого зөв бодох', 'difficulty_count', 5, 'crown'),
)

def streaks(days, today):
    """Today or yesterday preserves a live streak; best uses all historical days."""
    days = {d for d in days if d <= today}
    previous = None
    run = best = 0
    for day in sorted(days):
        run = run + 1 if previous and day - previous == timedelta(days=1) else 1
        best = max(best, run)
        previous = day
    current = run if previous and (today - previous).days <= 1 else 0
    return current, best


def contest_metrics(rows, username):
    """Rows are aggregated by contest and participant, matching standings tie rules."""
    by_contest = {}
    for contest_id, participant, score, penalty in rows:
        by_contest.setdefault(contest_id, {})[participant] = (score, penalty)
    totals = {'contests': 0, 'podiums': 0, 'wins': 0}
    for standings in by_contest.values():
        own = standings.get(username)
        if not own or own[0] <= 0:
            continue
        rank = 1 + sum((-s, p) < (-own[0], own[1]) for s, p in standings.values())
        totals['contests'] += 1
        totals['podiums'] += rank <= 3
        totals['wins'] += rank == 1
    return totals


def build_progression(metrics, daily, today, totals):
    metrics = dict(metrics)
    current, longest = streaks((d for d, count in daily.items() if count > 0), today)
    metrics['longest_streak'] = longest
    xp = sum(metrics.get(key, 0) * weight for key, weight in XP_WEIGHTS.items())
    level = 1 + xp // XP_PER_LEVEL
    rank = next(name for limit, name in ((300, 'Их мастер'), (100, 'Мастер'), (50, 'Алгоритмч'), (10, 'Кодлогч'), (0, 'Суралцагч')) if metrics.get('solved', 0) >= limit)
    awards = [dict(id=key, category=GROUPS[group], title=title, description=description,
                   progress=metrics.get(metric, 0), target=target, icon=icon,
                   unlocked=metrics.get(metric, 0) >= target)
              for key, group, title, description, metric, target, icon in ACHIEVEMENTS]
    start = today - timedelta(days=139)
    return {'xp': xp, 'level': level, 'rank': rank,
            'xp_in_level': xp % XP_PER_LEVEL, 'xp_per_level': XP_PER_LEVEL,
            'current_streak': current, 'longest_streak': longest,
            'solved': metrics.get('solved', 0), 'lessons': metrics.get('lessons', 0),
            'courses': metrics.get('courses', 0), 'contests': metrics.get('contests', 0),
            'totals': totals, 'achievements': awards,
            'unlocked_count': sum(a['unlocked'] for a in awards),
            'heatmap': [{'date': (start + timedelta(days=i)).isoformat(),
                         'count': daily.get(start + timedelta(days=i), 0)} for i in range(140)]}
