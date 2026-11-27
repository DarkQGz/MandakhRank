from django.contrib import admin
from .learning_admin import CourseProgressMixin, LessonProgressMixin
from .models import Course, Lesson, Contest, ContestProblem, ContestResult
admin.site.site_header='Mandakhrank • Удирдлага'
admin.site.site_title='Mandakhrank CMS'
admin.site.index_title='Сургалт ба тэмцээний удирдлага'
class LessonInline(admin.StackedInline):
    model=Lesson
    extra=0
@admin.register(Course)
class CourseAdmin(CourseProgressMixin, admin.ModelAdmin):
    list_display=['title','tag','level','published']
    list_filter=['published','level']
    search_fields=['title','description']
    inlines=[LessonInline]
class ProblemInline(admin.StackedInline):
    model=ContestProblem
    extra=0
@admin.register(Contest)
class ContestAdmin(admin.ModelAdmin):
    list_display=['title','starts_at','ends_at','published']
    list_filter=['published']
    search_fields=['title']
    inlines=[ProblemInline]
@admin.register(ContestResult)
class ResultAdmin(admin.ModelAdmin):
    list_display=['participant','problem','score','penalty']
    list_filter=['problem__contest']
    search_fields=['participant']

from .models import Problem,TestCase,Submission
class TestInline(admin.StackedInline):
    model=TestCase
    extra=0
@admin.register(Problem)
class PracticeAdmin(admin.ModelAdmin):
    list_display=['title','difficulty','points','published','cms_task_name']
    list_filter=['published','difficulty']
    search_fields=['title']
    inlines=[TestInline]
@admin.register(Submission)
class SubmissionAdmin(admin.ModelAdmin):
    list_display=['id','user','problem','status','passed','total','created_at']
    list_filter=['status','problem']
    readonly_fields=['user','problem','code','status','passed','total','created_at','updated_at','test_snapshot']
    def has_add_permission(self,request):return False
    def has_change_permission(self,request,obj=None):return False

# Make the existing Django Users page useful for MandakhRank administrators.
from django.contrib.auth import get_user_model
from django.contrib.auth.admin import UserAdmin
from django.db.models import Exists, OuterRef
from .models import EmailVerification, ProfileAvatar

User = get_user_model()
admin.site.unregister(User)

@admin.register(User)
class StudentAdmin(UserAdmin):
    list_display = ('username', 'email', 'is_active', 'email_confirmed', 'has_avatar', 'is_staff', 'date_joined')
    list_filter = ('is_active', 'is_staff', 'date_joined')
    search_fields = ('username', 'email', 'first_name', 'last_name')
    ordering = ('-date_joined',)
    list_per_page = 40

    def get_queryset(self, request):
        qs = super().get_queryset(request)
        return qs.annotate(
            _email_confirmed=Exists(EmailVerification.objects.filter(user_id=OuterRef('pk'), verified=True)),
            _has_avatar=Exists(ProfileAvatar.objects.filter(user_id=OuterRef('pk'))),
        )

    @admin.display(boolean=True, description='Имэйл баталгаажсан')
    def email_confirmed(self, obj):
        return obj._email_confirmed

    @admin.display(boolean=True, description='Профайл зураг')
    def has_avatar(self, obj):
        return obj._has_avatar

@admin.register(Lesson)
class LessonAdmin(LessonProgressMixin, admin.ModelAdmin):
    list_display = ('title', 'course', 'position', 'published')
    list_filter = ('published', 'course')
    search_fields = ('title', 'content', 'course__title')
    ordering = ('course_id', 'position')


from .models import MiniGameRoom, MiniGamePlayer, MiniGameAnswer

class MiniGamePlayerInline(admin.TabularInline):
    model = MiniGamePlayer
    extra = 0
    readonly_fields = ('user', 'side', 'answered', 'correct')
    can_delete = False

@admin.register(MiniGameRoom)
class MiniGameRoomAdmin(admin.ModelAdmin):
    list_display = ('code', 'mode', 'format', 'host', 'status', 'score_a', 'score_b', 'created_at')
    list_filter = ('mode', 'format', 'status')
    search_fields = ('code', 'host__username')
    readonly_fields = ('code', 'mode', 'format', 'host', 'status', 'score_a', 'score_b', 'winner', 'created_at', 'started_at', 'ends_at')
    inlines = [MiniGamePlayerInline]
    def has_add_permission(self, request): return False

@admin.register(MiniGameAnswer)
class MiniGameAnswerAdmin(admin.ModelAdmin):
    list_display = ('player', 'question_index', 'selected', 'correct', 'created_at')
    readonly_fields = ('player', 'question_index', 'selected', 'correct', 'created_at')
    def has_add_permission(self, request): return False
    def has_change_permission(self, request, obj=None): return False


from .models import ProfileComment

@admin.register(ProfileComment)
class ProfileCommentAdmin(admin.ModelAdmin):
    list_display = ('id', 'owner', 'author', 'body', 'created_at')
    search_fields = ('owner__username', 'author__username', 'body')
    list_filter = ('created_at',)
    list_select_related = ('owner', 'author')
    readonly_fields = ('owner', 'author', 'body', 'created_at')
    def has_add_permission(self, request): return False
    def has_change_permission(self, request, obj=None): return False

# Register staff-only capstone review.
from . import project_admin

# Phase 5 classroom administration.
from . import classroom_admin
