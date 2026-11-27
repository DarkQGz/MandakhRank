"""Read-only public progression derived from published, server-verified records."""
from collections import Counter
from zoneinfo import ZoneInfo
from django.db.models import Count, Sum
from django.db.models.functions import TruncDate
from django.utils import timezone
from .models import (Problem, Course, Lesson, Submission, LessonCompletion,
                     CourseCompletion, ContestResult)
from .progression_rules import build_progression, contest_metrics

DIFFICULTIES = {'Анхан шат': 'beginner', 'Хялбар': 'easy', 'Дунд': 'medium',
                'Хүнд': 'hard', 'Мэргэжлийн': 'expert'}


def profile_progression(user):
    now = timezone.now()
    tz = ZoneInfo('Asia/Ulaanbaatar')
    today = timezone.localdate(now, timezone=tz)
    accepted = Submission.objects.filter(user=user, status='Accepted', problem__published=True, created_at__lte=now)
    solved = list(accepted.order_by().values_list('problem_id', 'problem__difficulty').distinct())
    counts = Counter(DIFFICULTIES.get(d) for _, d in solved)
    lessons = LessonCompletion.objects.filter(user=user, lesson__published=True,
                                              lesson__course__published=True, completed_at__lte=now)
    courses = CourseCompletion.objects.filter(user=user, course__published=True,
                                              completed_at__lte=now)
    # The existing contest model stores administrator-entered username strings, not user FKs.
    # Exclude contests that ended before the account existed; match the exact current username.
    results = ContestResult.objects.filter(problem__contest__published=True, problem__contest__auto_judge=False,
                                          problem__contest__ends_at__lte=now,
                                          problem__contest__ends_at__gte=user.date_joined)
    eligible = results.filter(participant=user.username, score__gt=0).order_by().values_list('problem__contest_id', flat=True)
    standings = (results.filter(problem__contest_id__in=eligible).order_by()
                 .values('problem__contest_id', 'participant')
                 .annotate(total_score=Sum('score'), total_penalty=Sum('penalty'))
                 .values_list('problem__contest_id', 'participant', 'total_score', 'total_penalty'))
    from .contest_live import progression_rows
    standings = list(standings) + progression_rows(user, now)
    metrics = dict(solved=len(solved), lessons=lessons.count(), courses=courses.count(),
                   python=int(courses.filter(course__title='Python-ийн үндэс').exists()),
                   medium=counts['medium'], hard=counts['hard'], expert=counts['expert'],
                   difficulty_count=sum(counts[d] > 0 for d in DIFFICULTIES.values()),
                   **contest_metrics(standings, user.username))
    daily = Counter()
    for qs, field, distinct_field in ((accepted, 'created_at', 'problem_id'),
                                      (lessons, 'completed_at', 'pk'), (courses, 'completed_at', 'pk')):
        grouped = (qs.order_by().annotate(day=TruncDate(field, tzinfo=tz)).values('day')
                   .annotate(n=Count(distinct_field, distinct=True)).values_list('day', 'n'))
        daily.update(dict(grouped))
    totals = dict(problems=Problem.objects.filter(published=True).count(),
                  lessons=Lesson.objects.filter(published=True, course__published=True).count(),
                  courses=Course.objects.filter(published=True).count())
    return build_progression(metrics, daily, today, totals)
