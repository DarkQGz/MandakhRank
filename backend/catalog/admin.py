from django.contrib import admin
from .models import Course, Lesson, Contest, ContestProblem, ContestResult
admin.site.site_header='Mandakhrank • Удирдлага'
admin.site.site_title='Mandakhrank CMS'
admin.site.index_title='Сургалт ба тэмцээний удирдлага'
class LessonInline(admin.StackedInline):
    model=Lesson
    extra=0
@admin.register(Course)
class CourseAdmin(admin.ModelAdmin):
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
    list_display=['title','difficulty','points','published']
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
