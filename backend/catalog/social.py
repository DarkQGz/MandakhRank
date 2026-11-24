"""Public student profiles and authenticated profile-wall comments."""
from django.contrib.auth import get_user_model
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
from .accounts import limited
from .models import ProfileAvatar, ProfileComment
from .practice import current_user, payload, response
from .profile import avatar_url, profile_data

PAGE_SIZE = 20


def can_delete(viewer, comment):
    return bool(viewer and (viewer.pk in (comment.author_id, comment.owner_id) or viewer.is_superuser))


def comment_data(comment, viewer, avatars):
    return {'id': comment.pk, 'author_id': comment.author_id,
            'author': comment.author.username,
            'avatar_url': avatar_url(comment.author_id, avatars.get(comment.author_id)),
            'body': comment.body, 'created_at': comment.created_at.isoformat(),
            'can_delete': can_delete(viewer, comment)}


@csrf_exempt
@require_http_methods(['GET', 'POST'])
def public_profile(request, user_id):
    viewer = current_user(request)
    owner = get_user_model().objects.filter(pk=user_id, is_active=True).first()
    if owner is None:
        return response({'error': 'Хэрэглэгч олдсонгүй.'}, 404)
    if request.method == 'POST':
        if viewer is None:
            return response({'error': 'Эхлээд нэвтэрнэ үү.'}, 401)
        data = payload(request)
        body = data.get('body') if data else None
        if not isinstance(body, str) or not 1 <= len(body.strip()) <= 500 or '\x00' in body or any(0xD800 <= ord(c) <= 0xDFFF for c in body):
            return response({'error': 'Сэтгэгдэл 1–500 тэмдэгттэй байна.'}, 400)
        if limited('profile-comment', str(viewer.pk), 10, 60):
            return response({'error': 'Хэт олон сэтгэгдэл илгээлээ. Түр хүлээнэ үү.'}, 429)
        comment = ProfileComment.objects.create(owner=owner, author=viewer, body=body.strip())
        return response({'id': comment.pk}, 201)
    before = request.GET.get('before')
    comments = ProfileComment.objects.filter(owner=owner, author__is_active=True).select_related('author')
    if before is not None:
        try:
            cursor = int(before)
            if not 0 < cursor <= 9223372036854775807:
                raise ValueError()
        except ValueError:
            return response({'error': 'Хуудасны дугаар буруу.'}, 400)
        comments = comments.filter(pk__lt=cursor)
    page = list(comments.order_by('-pk')[:PAGE_SIZE + 1])
    more = len(page) > PAGE_SIZE
    page = page[:PAGE_SIZE]
    avatars = dict(ProfileAvatar.objects.filter(user_id__in={owner.pk, *(c.author_id for c in page)}).values_list('user_id', 'updated_at'))
    data = profile_data(owner, is_owner=bool(viewer and viewer.pk == owner.pk), avatar_version=avatars.get(owner.pk))
    data.update({
        'can_comment': viewer is not None,
        'comments': [comment_data(c, viewer, avatars) for c in page],
        'next_before': page[-1].pk if more else None,
    })
    return response(data)


@csrf_exempt
@require_http_methods(['POST'])
def delete_comment(request, user_id, comment_id):
    viewer = current_user(request)
    if not viewer:
        return response({'error': 'Эхлээд нэвтэрнэ үү.'}, 401)
    comment = ProfileComment.objects.filter(pk=comment_id, owner_id=user_id).first()
    if not comment:
        return response({'error': 'Сэтгэгдэл олдсонгүй.'}, 404)
    if not can_delete(viewer, comment):
        return response({'error': 'Устгах эрхгүй байна.'}, 403)
    comment.delete()
    return response({'ok': True})
