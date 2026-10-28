import json
from pathlib import Path
from django.http import JsonResponse, Http404
from django.views.decorators.http import require_GET
DATA = json.loads(Path(__file__).with_name('demo.json').read_text(encoding='utf-8'))
from .models import Course, Contest, Problem

def course_data(c):
    lessons=list(c.lessons.filter(published=True))
    return dict(id=c.id,title=c.title,tag=c.tag,level=c.level,description=c.description,color=c.color,
        lessons=[l.title for l in lessons],lesson_content=[dict(title=l.title,content=l.content) for l in lessons])

def contest_data(c):
    started=c.status != 'Удахгүй'
    problems=list(c.problems.all()) if started else []
    totals={}
    for p in problems:
        for r in p.results.all():
            row=totals.setdefault(r.participant,dict(participant=r.participant,score=0,penalty=0))
            row['score']+=r.score; row['penalty']+=r.penalty
    standings=sorted(totals.values(),key=lambda r:(-r['score'],r['penalty'],r['participant']))
    last=None; rank=0
    for i,r in enumerate(standings):
        key=(r['score'],r['penalty'])
        if key != last: rank=i+1
        r['rank']=rank;last=key
    return dict(id=c.id,title=c.title,description=c.description,announcement=c.announcement,
        starts_at=c.starts_at.isoformat(),ends_at=c.ends_at.isoformat(),status=c.status,
        duration_minutes=int((c.ends_at-c.starts_at).total_seconds()/60),
        problems=[dict(label=p.label,title=p.title,statement=p.statement,input=p.sample_input,output=p.sample_output,points=p.points) for p in problems],standings=standings)

def rows(kind):
    if kind == 'problems':
        from .practice import problem_data
        return [problem_data(p,set()) for p in Problem.objects.filter(published=True)]
    if kind == 'courses': return [course_data(c) for c in Course.objects.filter(published=True).prefetch_related('lessons')]
    if kind == 'contests': return [contest_data(c) for c in Contest.objects.filter(published=True).prefetch_related('problems__results')]

    if kind not in DATA: raise Http404('Not found')
    result = DATA[kind]
    if kind == 'rankings':
        result = [dict(p, rank=i+1) for i,p in enumerate(sorted(result, key=lambda p: (-p['score'], p['id'])))]
    return result
@require_GET
def collection(request, kind):
    result = rows(kind)
    q = request.GET.get('q', '').casefold()
    if q: result = [r for r in result if q in ' '.join(str(v) for v in r.values()).casefold()]
    for field in ('difficulty', 'topic', 'level'):
        value = request.GET.get(field)
        if value: result = [r for r in result if r.get(field) == value]
    return JsonResponse({'results': result, 'demo': kind in ('rankings','problems')}, json_dumps_params={'ensure_ascii': False})
@require_GET
def detail(request, kind, pk):
    item = next((r for r in rows(kind) if r['id'] == pk), None)
    if item is None: raise Http404('Not found')
    return JsonResponse(item, json_dumps_params={'ensure_ascii': False})
