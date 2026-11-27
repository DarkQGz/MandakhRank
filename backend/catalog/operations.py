"""Minimal public readiness and superuser-only aggregate diagnostics."""
from datetime import timedelta
from django.conf import settings
from django.contrib.admin.views.decorators import staff_member_required
from django.db import connection, DatabaseError
from django.db.models import Count, Min
from django.http import JsonResponse, HttpResponseForbidden
from django.shortcuts import render
from django.utils import timezone
from django.views.decorators.cache import never_cache
from django.views.decorators.http import require_GET
from .models import JudgeWorkerState, Submission


def record_contact(languages=None):
    # One shared state per configured engine; reports the most recent contact,
    # not a count of workers. Throttle DB writes on idle polling.
    now = timezone.now()
    row, created = JudgeWorkerState.objects.get_or_create(engine=settings.JUDGE_ENGINE,
        defaults={'last_seen': now, 'languages': languages or []})
    if not created:
        updates = {'last_seen': now}
        if languages is not None:
            updates['languages'] = languages
        if row.last_seen < now - timedelta(seconds=30) or (languages is not None and row.languages != languages):
            JudgeWorkerState.objects.filter(pk=row.pk, last_seen__lte=row.last_seen).update(**updates)


@require_GET
@never_cache
def health(request):
    try:
        with connection.cursor() as cursor:
            cursor.execute('SELECT 1')
            cursor.fetchone()
    except DatabaseError:
        return JsonResponse({'status': 'unavailable'}, status=503)
    return JsonResponse({'status': 'ok'})


def queue_snapshot():
    now = timezone.now()
    groups = list(Submission.objects.order_by().values('status').annotate(count=Count('pk')).order_by('status'))
    queued = Submission.objects.filter(status='Queued')
    oldest = queued.aggregate(oldest=Min('created_at'))['oldest']
    stale = Submission.objects.filter(status='Running', updated_at__lt=now-timedelta(seconds=max(60, settings.CMS_LEASE_SECONDS))).count()
    state = JudgeWorkerState.objects.filter(engine=settings.JUDGE_ENGINE).first()
    age = max(0, int((now-state.last_seen).total_seconds())) if state else None
    return {'engine': settings.JUDGE_ENGINE, 'groups': groups,
            'queued_by_language': list(queued.order_by().values('language').annotate(count=Count('pk')).order_by('language')),
            'oldest_queued_seconds': max(0,int((now-oldest).total_seconds())) if oldest else None,
            'stale_running': stale, 'contact_age': age,
            'contact_status': 'Recent' if age is not None and age <= 120 else 'Stale / unknown',
            'last_seen': state.last_seen if state else None, 'languages': state.languages if state else [],
            'database': connection.vendor, 'multilanguage': settings.JUDGE_MULTILANGUAGE_ENABLED}


@staff_member_required
@require_GET
@never_cache
def dashboard(request):
    if not request.user.is_superuser:
        return HttpResponseForbidden('Superuser only.')
    return render(request, 'catalog/operations.html', queue_snapshot())
