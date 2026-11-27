"""Account-scoped cosmetics; no progression or ranking writes."""
from django.db import transaction
from django.contrib.auth import get_user_model
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
from .models import ProfileAppearance
from .practice import current_user, payload, response
from .progression import profile_progression
from .prestige_rules import appearance_data, unlocked_ids, validate_preferences


def rank_for(user):
    if not user.is_active or user.is_staff:
        return None
    # Use the existing leaderboard's exact ordering and tie policy.
    from .views import rows
    return next((row['prestige_rank'] for row in rows('rankings') if row['id'] == user.pk), None)


def profile_appearance(user, progression, *, owner=False):
    stored = ProfileAppearance.objects.filter(user=user).values_list('preferences', flat=True).first()
    return appearance_data(progression, stored, rank_for(user), owner=owner)


@csrf_exempt
@require_http_methods(['GET', 'POST'])
def customize(request):
    user = current_user(request)
    if not user:
        return response({'error': 'Эхлээд нэвтэрнэ үү.'}, 401)
    if request.method == 'GET':
        return response({'appearance': profile_appearance(user, profile_progression(user), owner=True)})
    if len(request.body) > 4096:
        return response({'error': 'Тохиргооны хэмжээ хэтэрсэн.'}, 400)
    data = payload(request)
    try:
        with transaction.atomic():
            user = get_user_model().objects.select_for_update().get(pk=user.pk)
            if not user.is_active or current_user(request) is None:
                return response({'error': 'Эхлээд нэвтэрнэ үү.'}, 401)
            progression = profile_progression(user)
            preferences = validate_preferences(data, unlocked_ids(progression))
            ProfileAppearance.objects.update_or_create(user=user, defaults={'preferences': preferences})
    except ValueError as exc:
        return response({'error': str(exc)}, 400)
    # Re-read current achievements after the transaction. If admin reset one,
    # the read-time policy strips any invalid choice before it becomes public.
    return response({'appearance': profile_appearance(user, profile_progression(user), owner=True)})
