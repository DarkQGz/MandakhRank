"""Staff review; user-supplied code is displayed as escaped text, never run here."""
from django import forms
from django.contrib import admin, messages
from django.utils import timezone
from .models import ProjectAttempt
from .projects import bank, status


class ReviewForm(forms.ModelForm):
    class Meta:
        model = ProjectAttempt
        fields = ('review_status', 'feedback')

    def clean(self):
        data = super().clean()
        if data.get('review_status') in ('approved', 'rejected') and not (data.get('feedback') or '').strip():
            self.add_error('feedback', 'Шалгасан үндэслэл, санал хүсэлт бичнэ үү.')
        return data


@admin.register(ProjectAttempt)
class ProjectAttemptAdmin(admin.ModelAdmin):
    form = ReviewForm
    list_display = ('id', 'user', 'course', 'mode', 'verdict', 'created_at')
    list_filter = ('mode', 'review_status', 'course')
    search_fields = ('user__username', 'course__title')
    list_select_related = ('user', 'course', 'submission')
    fields = ('user', 'course', 'project_key', 'mode', 'created_at', 'verdict', 'rubric', 'source', 'review_status', 'feedback', 'reviewed_by', 'reviewed_at')
    readonly_fields = ('user', 'course', 'project_key', 'mode', 'created_at', 'verdict', 'rubric', 'source', 'reviewed_by', 'reviewed_at')

    @admin.display(description='Дүн')
    def verdict(self, obj):
        return status(obj)

    @admin.display(description='Шалгах шаардлага')
    def rubric(self, obj):
        row = bank().get(obj.course.title, {})
        return '\n'.join(row.get('requirements', []))

    def get_readonly_fields(self, request, obj=None):
        if obj and (obj.mode != 'review' or obj.review_status != 'pending'):
            return (*self.readonly_fields, 'review_status', 'feedback')
        return self.readonly_fields

    def has_add_permission(self, request):
        return False

    def has_delete_permission(self, request, obj=None):
        return False

    def save_model(self, request, obj, form, change):
        # An already finalized attempt cannot be overwritten by a stale admin form.
        if obj.mode != 'review':
            return
        fields = {'review_status': obj.review_status, 'feedback': obj.feedback}
        if obj.review_status in ('approved', 'rejected'):
            fields.update(reviewed_at=timezone.now(), reviewed_by=request.user)
        if not ProjectAttempt.objects.filter(pk=obj.pk, mode='review', review_status='pending').update(**fields):
            self.message_user(request, 'Энэ илгээлтийг өмнө нь шалгасан байна. Өөрчлөлт хадгалаагүй.', messages.WARNING)
