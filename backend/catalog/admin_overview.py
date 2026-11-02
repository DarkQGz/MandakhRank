"""Staff-only overview. User PII is never exposed through public API routes."""
from django.contrib.admin.views.decorators import staff_member_required
from django.contrib.auth import get_user_model
from django.db.models import Count
from django.http import HttpResponseForbidden
from django.shortcuts import render

from .models import Course, EmailVerification, Lesson, Problem, Submission


@staff_member_required
def overview(request):
    if not request.user.is_superuser:
        return HttpResponseForbidden('Only superusers may view registered students.')
    User = get_user_model()
    students = User.objects.filter(is_staff=False)
    return render(request, 'catalog/admin_overview.html', {
        'registered': students.count(),
        'verified': EmailVerification.objects.filter(verified=True, user__is_staff=False).count(),
        'unverified': students.filter(is_active=False).count(),
        'courses': Course.objects.count(),
        'published_courses': Course.objects.filter(published=True).count(),
        'lessons': Lesson.objects.count(),
        'problems': Problem.objects.filter(published=True).count(),
        'submissions': Submission.objects.count(),
        'accepted': Submission.objects.filter(status='Accepted').count(),
        'new_students': students.order_by('-date_joined')[:12],
        'recent_courses': Course.objects.order_by('-id')[:6],
    })
