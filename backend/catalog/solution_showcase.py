"""Opt-in sharing of exact accepted practice submissions. Never serialize tests."""
from django.contrib.auth import get_user_model
from django.db import transaction
from django.db.models import OuterRef, Subquery
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_GET, require_http_methods
from .models import Submission
from .practice import current_user, payload, response


def eligible(user_id):
    return Submission.objects.filter(user_id=user_id, user__is_active=True,
        status='Accepted', problem__published=True, project_attempt__isnull=True)


def metadata(qs):
    return [dict(id=row['id'], problem_id=row['problem_id'], title=row['problem__title'],
        difficulty=row['problem__difficulty'], language=row['language'],
        shared=row['share_on_profile'], created_at=row['created_at'].isoformat())
        for row in qs.order_by('-id').values('id', 'problem_id', 'problem__title',
            'problem__difficulty', 'language', 'share_on_profile', 'created_at')]


def public_solutions(user_id):
    return metadata(eligible(user_id).filter(share_on_profile=True))


def owner_choices(user_id):
    # One row per problem. Preserve an explicitly shared version; otherwise
    # propose the newest accepted solution. No future submissions inherit consent.
    qs = eligible(user_id)
    chosen = qs.filter(problem_id=OuterRef('problem_id')).order_by('-share_on_profile', '-id').values('id')[:1]
    return metadata(qs.filter(id=Subquery(chosen)))


def valid_ids(value):
    return (isinstance(value, list) and len(value) <= 1000
            and all(type(v) is int and 0 < v <= 9223372036854775807 for v in value)
            and len(set(value)) == len(value))


@csrf_exempt
@require_http_methods(['GET', 'POST'])
def manage(request):
    user = current_user(request)
    if user is None:
        return response({'error': 'Эхлээд нэвтэрнэ үү.'}, 401)
    if request.method == 'GET':
        with transaction.atomic():
            get_user_model().objects.select_for_update().get(pk=user.pk)
            results = owner_choices(user.pk)
            shared_ids = list(Submission.objects.filter(user=user, share_on_profile=True).values_list('pk', flat=True))
        return response({'results': results, 'shared_ids': shared_ids})
    if len(request.body) > 48000:
        return response({'error': 'Хүсэлт хэт урт байна.'}, 400)
    data = payload(request)
    if (not isinstance(data, dict) or set(data) != {'ids', 'previous_ids'}
            or not valid_ids(data['ids']) or not valid_ids(data['previous_ids'])):
        return response({'error': 'Сонголтын мэдээлэл буруу байна.'}, 400)
    with transaction.atomic():
        locked = get_user_model().objects.select_for_update().filter(pk=user.pk, is_active=True).first()
        if locked is None or current_user(request) is None:
            return response({'error': 'Эхлээд нэвтэрнэ үү.'}, 401)
        current = set(Submission.objects.filter(user=user, share_on_profile=True).values_list('pk', flat=True))
        if current != set(data['previous_ids']):
            return response({'error': 'Сонголт өөрчлөгдсөн байна. Дахин ачаална уу.'}, 409)
        rows = list(eligible(user.pk).filter(pk__in=data['ids']).values_list('pk', 'problem_id'))
        if len(rows) != len(data['ids']) or len({p for _, p in rows}) != len(rows):
            return response({'error': 'Зөвхөн өөрийн зөв бодсон нийтлэгдсэн бодлогыг сонгоно уу.'}, 400)
        # Clear even ineligible old shares so hidden items cannot later be revived by this save.
        Submission.objects.filter(user=user, share_on_profile=True).update(share_on_profile=False)
        Submission.objects.filter(user=user, pk__in=data['ids']).update(share_on_profile=True)
        results = public_solutions(user.pk)
    return response({'results': results})


@require_GET
def detail(request, user_id, submission_id):
    viewer = current_user(request)
    owner = bool(viewer and viewer.pk == user_id)
    qs = eligible(user_id).filter(pk=submission_id)
    if not owner:
        qs = qs.filter(share_on_profile=True)
    item = qs.select_related('problem').first()
    if item is None:
        return response({'error': 'Бодолт олдсонгүй эсвэл нууц байна.'}, 404)
    result = response({'id': item.pk, 'problem_id': item.problem_id, 'title': item.problem.title,
        'difficulty': item.problem.difficulty, 'language': item.language, 'code': item.code,
        'shared': item.share_on_profile, 'created_at': item.created_at.isoformat()})
    result['X-Content-Type-Options'] = 'nosniff'
    return result
