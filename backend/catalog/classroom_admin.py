from django.contrib import admin
from .models import ClassroomTeacher, Classroom, ClassroomMember, ClassroomAssignment


class SuperuserOnly(admin.ModelAdmin):
    def allowed(self, request):
        return request.user.is_active and request.user.is_superuser

    def has_module_permission(self, request):
        return self.allowed(request)

    def has_view_permission(self, request, obj=None):
        return self.allowed(request)

    def has_add_permission(self, request):
        return self.allowed(request)

    def has_change_permission(self, request, obj=None):
        return self.allowed(request)

    def has_delete_permission(self, request, obj=None):
        return self.allowed(request)


@admin.register(ClassroomTeacher)
class ClassroomTeacherAdmin(SuperuserOnly):
    list_display = ('user', 'granted_at')
    search_fields = ('user__username',)
    raw_id_fields = ('user',)
    readonly_fields = ('granted_at',)

    # Grant and revoke; don't transfer an existing role to a different user.
    def has_change_permission(self, request, obj=None):
        return False


class ClassroomReadOnly(SuperuserOnly):
    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False


@admin.register(Classroom)
class ClassroomAdmin(ClassroomReadOnly):
    list_display = ('name', 'owner', 'archived', 'created_at')
    list_filter = ('archived',)
    search_fields = ('name', 'owner__username')
    exclude = ('join_code',)


@admin.register(ClassroomMember)
class ClassroomMemberAdmin(ClassroomReadOnly):
    list_display = ('classroom', 'user', 'joined_at')
    search_fields = ('classroom__name', 'user__username')


@admin.register(ClassroomAssignment)
class ClassroomAssignmentAdmin(ClassroomReadOnly):
    list_display = ('title', 'classroom', 'kind', 'due_at', 'archived')
    list_filter = ('kind', 'archived')
    search_fields = ('title', 'classroom__name')
