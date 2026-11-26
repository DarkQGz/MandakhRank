"""Guided lesson assessment. Only the authenticated user's server-graded passes count."""
import hashlib
import json
import re
from functools import lru_cache
from pathlib import Path
from random import SystemRandom

from django.db import transaction
from django.utils.crypto import salted_hmac
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_GET, require_http_methods

from .accounts import limited
from .models import Course, LessonCompletion, CourseCompletion
from .practice import current_user, payload, response
from .quiz_rules import is_typed, valid_answer, is_correct, answer_text

rng = SystemRandom()


@lru_cache(maxsize=1)
def bank():
    return json.loads(Path(__file__).with_name('learning_questions.json').read_text(encoding='utf-8'))


def questions_for(lesson, final=False):
    row = bank().get(lesson.course.title, {}).get(lesson.title)
    if not row or row['sha256'] != hashlib.sha256(lesson.content.encode('utf-8')).hexdigest():
        return []  # Do not award passes against unrelated or edited teaching material.
    return [row['final']] if final else row['questions']


def sections(content):
    # Split the original 4-section course material, leaving code indentation untouched.
    pattern = r'(?m)^([1-4])\. (?:ОЙЛГОЛТ|ЖИШЭЭ|ҮР ДҮН БА ТАЙЛБАР|БИЕ ДААХ ДАДЛАГА)\s*\n'
    matches = list(re.finditer(pattern, content))
    if [m.group(1) for m in matches] != ['1', '2', '3', '4']:
        return {'theory': content, 'example': '', 'result': '', 'practice': ''}
    return {key: content[m.end():matches[i+1].start() if i+1<len(matches) else len(content)].strip('\n')
            for i, (key, m) in enumerate(zip(('theory','example','result','practice'), matches))}


def completion_sets(user):
    if not user:
        return set(), set()
    return (set(LessonCompletion.objects.filter(user=user, lesson__published=True, lesson__course__published=True).values_list('lesson_id', flat=True)),
            set(CourseCompletion.objects.filter(user=user, course__published=True).values_list('course_id', flat=True)))


def catalog_progress(user):
    done, passed = completion_sets(user)
    return {c.pk: {'completed': sum(l.pk in done for l in lessons), 'total': len(lessons),
                   'passed': c.pk in passed and bool(lessons) and all(l.pk in done for l in lessons)}
            for c in Course.objects.filter(published=True).prefetch_related('lessons')
            for lessons in [[l for l in c.lessons.all() if l.published]]}


def profile_learning(user):
    lessons = LessonCompletion.objects.filter(user=user, lesson__published=True, lesson__course__published=True)
    courses = CourseCompletion.objects.filter(user=user, course__published=True)
    lesson_rows = [{'title': r.lesson.title, 'course': r.lesson.course.title, 'completed_at': r.completed_at.isoformat()}
                   for r in lessons.select_related('lesson__course').order_by('-completed_at', '-pk')]
    return {'lessons': len(lesson_rows), 'courses': courses.count(),
            'completed_courses': [{'title': r.course.title, 'score': r.score, 'completed_at': r.completed_at.isoformat()}
                                  for r in courses.select_related('course').order_by('-completed_at', '-pk')],
            'recent_lessons': lesson_rows[:6], 'completed_lessons': lesson_rows}



@require_GET
def course(request, course_id):
    c = Course.objects.filter(pk=course_id, published=True).first()
    if not c:
        return response({'error': 'Сургалт олдсонгүй.'}, 404)
    user = current_user(request)
    done, passed = completion_sets(user)
    lessons = list(c.lessons.filter(published=True).select_related('course'))
    rows = [dict(id=l.pk, title=l.title, position=l.position, completed=l.pk in done,
                 has_quiz=bool(questions_for(l)), question_count=len(questions_for(l)), **sections(l.content)) for l in lessons]
    ready = bool(rows) and all(l['has_quiz'] for l in rows)
    all_done = bool(rows) and all(l['completed'] for l in rows)
    return response({'id': c.pk, 'title': c.title, 'description': c.description, 'tag': c.tag, 'level': c.level,
                     'lessons': rows, 'completed': sum(l['completed'] for l in rows),
                     'authenticated': user is not None, 'has_final': ready,
                     'final_unlocked': ready and all_done, 'passed': c.pk in passed and all_done})


def assessment(c, lesson_id):
    lessons = list(c.lessons.filter(published=True).select_related('course'))
    if lesson_id:
        lessons = [l for l in lessons if l.pk == lesson_id]
    if not lessons or any(not questions_for(l) for l in lessons):
        return [], lessons
    entries = []
    for l in lessons:
        for i, q in enumerate(questions_for(l, final=not lesson_id)):
            qid = f'{l.pk}-final' if not lesson_id else f'{l.pk}-{i+1}'
            kind = q.get('kind', 'choice')
            entry = {'id': qid, 'prompt': q['prompt'], 'kind': kind, 'lesson': l.title,
                     'explanation': q.get('explanation') or sections(l.content)['theory']}
            if is_typed(entry):
                entry.update(options=[], accepted=q['accepted'], casefold=q.get('casefold', False),
                             correct=q['accepted'][0])
            else:
                choices = [{'id': salted_hmac('learning-choice', f'{qid}:{text}', algorithm='sha256').hexdigest()[:32], 'text': text}
                           for text in q['choices']]
                entry.update(options=choices, correct=choices[q['correct']]['id'])
            entries.append(entry)
    return entries, lessons


@csrf_exempt
@require_http_methods(['GET', 'POST'])
def quiz(request, course_id, lesson_id):
    user = current_user(request)
    if not user:
        return response({'error': 'Шалгалт өгөхийн тулд нэвтэрнэ үү.'}, 401)
    c = Course.objects.filter(pk=course_id, published=True).first()
    if not c:
        return response({'error': 'Сургалт олдсонгүй.'}, 404)
    entries, lessons = assessment(c, lesson_id)
    if not entries:
        return response({'error': 'Энэ агуулгын шалгалт хараахан бэлэн болоогүй байна.'}, 404)
    if not lesson_id and LessonCompletion.objects.filter(user=user, lesson_id__in=[l.pk for l in lessons]).count() != len(lessons):
        return response({'error': 'Эхлээд бүх хичээлийн шалгалтад тэнцэнэ үү.'}, 403)
    threshold = 100 if lesson_id else 80
    if request.method == 'GET':
        if any(is_typed(q) for q in entries) and request.GET.get('format') != '2':
            return response({'error': 'Шалгалтын шинэ хувилбар гарсан. Веб хуудсаа шинэчлээд дахин оролдоно уу.'}, 409)
        rows = []
        for q in entries:
            options = q['options'][:]
            rng.shuffle(options)
            rows.append({'id': q['id'], 'prompt': q['prompt'], 'kind': q['kind'], 'options': options})
        rng.shuffle(rows)
        return response({'questions': rows, 'threshold': threshold, 'title': lessons[0].title if lesson_id else c.title + ' — Нэгдсэн шалгалт'})
    data = payload(request)
    answers = data.get('answers') if data else None
    if not isinstance(answers, dict) or set(answers) != {q['id'] for q in entries} or any(
        not valid_answer(q, answers[q['id']]) for q in entries):
        return response({'error': 'Асуулт бүрд нэг хүчинтэй хариулт сонгох эсвэл бичих шаардлагатай.'}, 400)
    if limited('learning-quiz', str(user.pk), 30, 60):
        return response({'error': 'Хэт олон оролдлого. Нэг минутын дараа дахин оролдоно уу.'}, 429)
    correct = sum(is_correct(q, answers[q['id']]) for q in entries)
    score = correct * 100 // len(entries)
    passed = correct * 100 >= threshold * len(entries)
    with transaction.atomic():
        if passed:
            if lesson_id:
                LessonCompletion.objects.get_or_create(user=user, lesson=lessons[0])
            else:
                completion, _ = CourseCompletion.objects.get_or_create(user=user, course=c, defaults={'score': score})
                CourseCompletion.objects.filter(pk=completion.pk, score__lt=score).update(score=score)
    # Feedback is revealed only after submission; retries are intentionally allowed for learning.
    return response({'passed': passed, 'score': score, 'correct': correct, 'total': len(entries), 'threshold': threshold,
                     'review': [{'prompt': q['prompt'], 'lesson': q['lesson'], 'kind': q['kind'],
                                 'correct': is_correct(q, answers[q['id']]),
                                 'selected': answer_text(q, answers[q['id']]),
                                 'answer': answer_text(q, q['correct']),
                                 'explanation': q['explanation']} for q in entries]})
