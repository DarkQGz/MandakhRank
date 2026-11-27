"""Phase 3.1: superuser-only, self-account learning test controls.

These are administrative test passes, not evidence of actual exam performance.
No course content, student submissions, or capstone records are modified.
"""
from django.contrib import admin, messages
from django.contrib.admin.helpers import ACTION_CHECKBOX_NAME
from django.contrib.auth import get_user_model
from django.core.exceptions import PermissionDenied
from django.db import transaction
from django.db.models import Count, Exists, OuterRef, Q
from django.template.response import TemplateResponse

from .models import Course, Lesson, CourseCompletion, LessonCompletion
from .learning import questions_for


def allowed(request):
    u = request.user
    return bool(u.is_active and u.is_staff and u.is_superuser)


def ready(lesson):
    return bool(questions_for(lesson) and questions_for(lesson, final=True))


class OwnProgressMixin:
    progress_actions = ()

    def has_own_progress_permission(self, request):
        return allowed(request)

    def get_actions(self, request):
        actions = super().get_actions(request)
        # Supersede the older, unconfirmed example action if it was installed.
        actions.pop('complete_own_courses', None)
        if allowed(request) and self.actions is not None and '_popup' not in request.GET:
            for name in self.progress_actions:
                actions[name] = self.get_action(name)
        return actions

    def _confirm(self, request, queryset, action, title, explanation, operation):
        if not allowed(request) or request.method != 'POST':
            raise PermissionDenied
        if request.POST.get('confirm_progress') != 'yes':
            # Freeze the selected rows rather than using select_across on confirmation.
            rows = list(queryset.order_by('pk'))
            return TemplateResponse(request, 'admin/catalog/learning_progress_confirm.html', {
                **self.admin_site.each_context(request),
                'title': title, 'opts': self.model._meta,
                'action_name': action, 'action_checkbox_name': ACTION_CHECKBOX_NAME,
                'rows': rows, 'explanation': explanation,
            })
        with transaction.atomic():
            user = get_user_model().objects.select_for_update().get(pk=request.user.pk)
            if not (user.is_active and user.is_staff and user.is_superuser):
                raise PermissionDenied
            lessons, courses, skipped = operation(user, queryset.order_by('pk'), request)
        self.message_user(request, f'Өөрийн бүртгэл: {lessons} хичээл, {courses} сургалтын шалгалтын төлөв өөрчлөгдлөө. Алгассан: {skipped}.', messages.SUCCESS if not skipped else messages.WARNING)
        # Returning None lets Django redirect to the changelist.
        return None


class CourseProgressMixin(OwnProgressMixin):
    progress_actions = ('mr_complete_courses', 'mr_complete_finals', 'mr_reset_finals', 'mr_reset_courses')

    def get_queryset(self, request):
        qs = super().get_queryset(request)
        if not allowed(request):
            return qs
        return qs.annotate(
            mr_total=Count('lessons', filter=Q(lessons__published=True), distinct=True),
            mr_done=Count('lessons', filter=Q(lessons__published=True, lessons__pk__in=LessonCompletion.objects.filter(user_id=request.user.pk).values('lesson_id')), distinct=True),
            mr_final=Exists(CourseCompletion.objects.filter(user_id=request.user.pk, course_id=OuterRef('pk'))),
        )

    def get_list_display(self, request):
        cols = tuple(super().get_list_display(request))
        return cols + ('mr_own_lessons', 'mr_own_final') if allowed(request) else cols

    @admin.display(description='Миний хичээлүүд')
    def mr_own_lessons(self, obj):
        return f'{obj.mr_done}/{obj.mr_total}'

    @admin.display(description='Миний нэгдсэн шалгалт', boolean=True)
    def mr_own_final(self, obj):
        return obj.mr_final

    def _complete(self, user, queryset, request, include_lessons):
        nl = nc = skipped = 0
        for course in queryset:
            lessons = list(course.lessons.filter(published=True).select_related('course'))
            if not course.published or not lessons or not all(ready(l) for l in lessons):
                skipped += 1
                continue
            if not include_lessons and LessonCompletion.objects.filter(user=user, lesson_id__in=[l.pk for l in lessons]).count() != len(lessons):
                skipped += 1
                continue
            added = 0
            if include_lessons:
                for lesson in lessons:
                    _, created = LessonCompletion.objects.get_or_create(user=user, lesson=lesson)
                    added += int(created)
            _, created = CourseCompletion.objects.get_or_create(user=user, course=course, defaults={'score': 100})
            nl += added
            nc += int(created)
            if added or created:
                self.log_change(request, course, f'Phase 3.1 ADMIN TEST OVERRIDE own user={user.pk}: lessons added={added}, final added={int(created)}; synthetic final score=100 if new.')
        return nl, nc, skipped

    def _reset(self, user, queryset, request, include_lessons):
        nl = nc = 0
        for course in queryset:
            # Remove the final first. Resetting a final alone keeps all lesson passes.
            final = CourseCompletion.objects.filter(user=user, course=course).delete()[0]
            lessons = LessonCompletion.objects.filter(user=user, lesson__course=course).delete()[0] if include_lessons else 0
            nc += final
            nl += lessons
            if final or lessons:
                self.log_change(request, course, f'Phase 3.1 ADMIN TEST RESET own user={user.pk}: lessons removed={lessons}, final removed={final}; project records preserved.')
        return nl, nc, 0

    @admin.action(description='[Туршилт] Миний сургалтыг бүрэн дуусгах', permissions=['own_progress'])
    def mr_complete_courses(self, request, queryset):
        return self._confirm(request, queryset, 'mr_complete_courses', 'Сургалтыг бүрэн дуусгах', 'Сонгосон сургалтын нийтлэгдсэн хичээл болон нэгдсэн шалгалтыг зөвхөн таны бүртгэлд тэнцсэн гэж тэмдэглэнэ. Шинэ нэгдсэн шалгалтын дүн 100% байна. Энэ нь бодитоор өгсөн шалгалт биш.', lambda u,q,r: self._complete(u,q,r,True))

    @admin.action(description='[Туршилт] Миний нэгдсэн шалгалтыг дуусгах', permissions=['own_progress'])
    def mr_complete_finals(self, request, queryset):
        return self._confirm(request, queryset, 'mr_complete_finals', 'Нэгдсэн шалгалтыг дуусгах', 'Бүх нийтлэгдсэн хичээл нь дууссан сургалтад л шинэ нэгдсэн шалгалтын 100% дүн бүртгэнэ. Өмнөх дүнг өөрчлөхгүй.', lambda u,q,r: self._complete(u,q,r,False))

    @admin.action(description='[Туршилт] Миний нэгдсэн шалгалтыг цуцлах', permissions=['own_progress'])
    def mr_reset_finals(self, request, queryset):
        return self._confirm(request, queryset, 'mr_reset_finals', 'Нэгдсэн шалгалтыг цуцлах', 'Зөвхөн таны сонгосон сургалтын нэгдсэн шалгалтын дүнг устгана. Хичээлийн ахиц, төсөл болон бусад хэрэглэгчийн мэдээлэл хэвээр үлдэнэ.', lambda u,q,r: self._reset(u,q,r,False))

    @admin.action(description='[Туршилт] Миний сургалтын бүх ахицыг цуцлах', permissions=['own_progress'])
    def mr_reset_courses(self, request, queryset):
        return self._confirm(request, queryset, 'mr_reset_courses', 'Сургалтын бүх ахицыг цуцлах', 'Таны сонгосон сургалтын бүх хичээлийн тэнцсэн бүртгэл болон нэгдсэн шалгалтын дүн устна. Жинхэнэ шалгалтаар авсан дүн ч устаж болно. Сургалтын агуулга, төсөл, бусад хэрэглэгчийн мэдээлэл устахгүй.', lambda u,q,r: self._reset(u,q,r,True))


class LessonProgressMixin(OwnProgressMixin):
    progress_actions = ('mr_complete_lessons', 'mr_reset_lessons')

    def get_queryset(self, request):
        qs = super().get_queryset(request)
        if not allowed(request):
            return qs
        return qs.annotate(mr_lesson_done=Exists(LessonCompletion.objects.filter(user_id=request.user.pk, lesson_id=OuterRef('pk'))))

    def get_list_display(self, request):
        cols = tuple(super().get_list_display(request))
        return cols + ('mr_own_pass',) if allowed(request) else cols

    @admin.display(description='Миний шалгалт', boolean=True)
    def mr_own_pass(self, obj):
        return obj.mr_lesson_done

    def _complete_lessons(self, user, queryset, request):
        nl = skipped = 0
        for lesson in queryset.select_related('course'):
            if not lesson.published or not lesson.course.published or not ready(lesson):
                skipped += 1
                continue
            _, created = LessonCompletion.objects.get_or_create(user=user, lesson=lesson)
            nl += int(created)
            if created:
                self.log_change(request, lesson, f'Phase 3.1 ADMIN TEST OVERRIDE own user={user.pk}: lesson pass added.')
        return nl, 0, skipped

    def _reset_lessons(self, user, queryset, request):
        nl = nc = 0
        for lesson in queryset:
            removed = LessonCompletion.objects.filter(user=user, lesson=lesson).delete()[0]
            if removed:
                final = CourseCompletion.objects.filter(user=user, course_id=lesson.course_id).delete()[0]
                nl += removed
                nc += final
                self.log_change(request, lesson, f'Phase 3.1 ADMIN TEST RESET own user={user.pk}: lesson removed; course={lesson.course_id}, final removed={final}; projects preserved.')
        return nl, nc, 0

    @admin.action(description='[Туршилт] Миний хичээлийн шалгалтыг дуусгах', permissions=['own_progress'])
    def mr_complete_lessons(self, request, queryset):
        return self._confirm(request, queryset, 'mr_complete_lessons', 'Хичээлийн шалгалтыг дуусгах', 'Сонгосон нийтлэгдсэн, шалгалттай хичээлүүдийг зөвхөн таны бүртгэлд тэнцсэн гэж тэмдэглэнэ. Нэгдсэн шалгалтыг автоматаар дуусгахгүй.', self._complete_lessons)

    @admin.action(description='[Туршилт] Миний хичээлийн шалгалтыг цуцлах', permissions=['own_progress'])
    def mr_reset_lessons(self, request, queryset):
        return self._confirm(request, queryset, 'mr_reset_lessons', 'Хичээлийн шалгалтыг цуцлах', 'Таны сонгосон хичээлийн тэнцсэн бүртгэл болон холбогдох сургалтын нэгдсэн шалгалтын дүнг устгана. Жинхэнэ шалгалтын дүн ч устаж болно. Төслийн илгээлт хэвээр үлдэнэ.', self._reset_lessons)


class OwnCompletionReadOnly(admin.ModelAdmin):
    actions = None

    def get_queryset(self, request):
        qs = super().get_queryset(request)
        return qs.filter(user_id=request.user.pk) if allowed(request) else qs.none()

    def has_module_permission(self, request):
        return allowed(request)

    def has_view_permission(self, request, obj=None):
        return allowed(request) and (obj is None or obj.user_id == request.user.pk)

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False


@admin.register(LessonCompletion)
class OwnLessonCompletionAdmin(OwnCompletionReadOnly):
    list_display = ('lesson', 'course_name', 'completed_at')
    list_filter = ('lesson__course',)
    search_fields = ('lesson__title', 'lesson__course__title')
    list_select_related = ('lesson__course',)
    fields = readonly_fields = ('user', 'lesson', 'completed_at')

    @admin.display(description='Сургалт', ordering='lesson__course__title')
    def course_name(self, obj):
        return obj.lesson.course.title


@admin.register(CourseCompletion)
class OwnCourseCompletionAdmin(OwnCompletionReadOnly):
    list_display = ('course', 'score', 'completed_at')
    search_fields = ('course__title',)
    list_select_related = ('course',)
    fields = readonly_fields = ('user', 'course', 'score', 'completed_at')
