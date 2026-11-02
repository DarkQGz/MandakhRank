"""Student dashboard and persistent, size-limited avatars.

Avatar bytes are stored as small normalized JPEGs in PostgreSQL; Render's
free service filesystem is ephemeral and must not be used for uploaded files.
"""
from io import BytesIO

from django.db.models import Sum
from django.http import HttpResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_GET, require_http_methods
from PIL import Image, ImageOps, UnidentifiedImageError

from .models import Course, Problem, ProfileAvatar, Submission
from .practice import current_user, response

MAX_UPLOAD_BYTES = 2 * 1024 * 1024
MAX_IMAGE_PIXELS = 12_000_000


def avatar_url(user_id, version=None):
    if version is None:
        return None
    return f'/api/profile/avatar/{user_id}/?v={int(version.timestamp() * 1000000)}'


@require_GET
def me(request):
    user = current_user(request)
    if not user:
        return response({'error': 'Эхлээд нэвтэрнэ үү.'}, 401)

    avatar = ProfileAvatar.objects.filter(user=user).first()
    solved_ids = Submission.objects.filter(
        user=user, status='Accepted', problem__published=True
    ).values_list('problem_id', flat=True).distinct()
    solved_problems = Problem.objects.filter(id__in=solved_ids, published=True)
    solved = solved_problems.count()
    points = solved_problems.aggregate(total=Sum('points'))['total'] or 0
    submissions = list(Submission.objects.filter(user=user).select_related('problem')[:6])
    return response({
        'id': user.pk,
        'username': user.username,
        'display_name': user.get_full_name().strip() or user.username,
        'email': user.email,
        'joined_at': user.date_joined.isoformat(),
        'avatar_url': avatar_url(user.id, avatar.updated_at) if avatar else None,
        'statistics': {
            'solved': solved,
            'points': points,
            'submissions': Submission.objects.filter(user=user).count(),
            'courses': Course.objects.filter(published=True).count(),
        },
        'recent': [
            {'id': s.pk, 'title': s.problem.title, 'status': s.status,
             'passed': s.passed, 'total': s.total,
             'created_at': s.created_at.isoformat()}
            for s in submissions
        ],
    })


@csrf_exempt
@require_http_methods(['POST', 'DELETE'])
def avatar(request):
    user = current_user(request)
    if not user:
        return response({'error': 'Эхлээд нэвтэрнэ үү.'}, 401)
    if request.method == 'DELETE':
        ProfileAvatar.objects.filter(user=user).delete()
        return response({'ok': True, 'avatar_url': None})

    uploaded = request.FILES.get('avatar')
    if not uploaded:
        return response({'error': 'Зураг сонгоно уу.'}, 400)
    if uploaded.size > MAX_UPLOAD_BYTES:
        return response({'error': 'Зураг 2 MB-аас их байж болохгүй.'}, 413)
    try:
        contents = uploaded.read(MAX_UPLOAD_BYTES + 1)
        if len(contents) > MAX_UPLOAD_BYTES:
            return response({'error': 'Зураг 2 MB-аас их байж болохгүй.'}, 413)
        with Image.open(BytesIO(contents)) as check:
            if check.format not in ('JPEG', 'PNG', 'WEBP'):
                raise ValueError('unsupported format')
            if check.width * check.height > MAX_IMAGE_PIXELS:
                raise ValueError('image too large')
            check.verify()
        with Image.open(BytesIO(contents)) as original:
            picture = ImageOps.exif_transpose(original)
            picture = picture.convert('RGBA')
            background = Image.new('RGBA', picture.size, (255, 255, 255, 255))
            background.alpha_composite(picture)
            square = ImageOps.fit(background.convert('RGB'), (256, 256), method=Image.Resampling.LANCZOS)
            out = BytesIO()
            square.save(out, format='JPEG', quality=80, optimize=True)
            normalized = out.getvalue()
    except (UnidentifiedImageError, OSError, ValueError, Image.DecompressionBombError):
        return response({'error': 'JPG, PNG эсвэл WebP форматтай зөв зураг оруулна уу.'}, 400)

    record, _ = ProfileAvatar.objects.update_or_create(
        user=user, defaults={'data': normalized, 'content_type': 'image/jpeg'}
    )
    # Force a fresh cache version even for two uploads within the same second.
    return response({'ok': True, 'avatar_url': avatar_url(user.id, record.updated_at)})


@require_GET
def public_avatar(request, user_id):
    record = ProfileAvatar.objects.filter(user_id=user_id, user__is_active=True).first()
    if not record:
        return HttpResponse(status=404)
    result = HttpResponse(bytes(record.data), content_type='image/jpeg')
    result['Cache-Control'] = 'public, max-age=300'
    result['X-Content-Type-Options'] = 'nosniff'
    return result
