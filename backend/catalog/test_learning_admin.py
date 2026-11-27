"""Exercise real Django admin POST flow; never run against production database."""
from io import StringIO
from django.contrib import admin
from django.contrib.admin.models import LogEntry
from django.contrib.auth import get_user_model
from django.contrib.auth.models import Permission
from django.core.management import call_command
from django.test import Client, RequestFactory, TestCase
from django.urls import reverse
from .models import Course, Lesson, CourseCompletion, LessonCompletion, ProjectAttempt


class LearningAdminTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        call_command('seed_courses_160', stdout=StringIO())
        users = get_user_model().objects
        cls.owner = users.create_superuser(username='admin-progress', email='admin@example.test', password='test-only-password')
        cls.other = users.create_user(username='other-student')
        cls.staff = users.create_user(username='ordinary-staff', is_staff=True)
        cls.staff.user_permissions.add(*Permission.objects.filter(content_type__app_label='catalog', codename__in=['view_course','change_course','view_lesson','view_lessoncompletion','view_coursecompletion']))
        cls.course = Course.objects.get(title='Python-ийн үндэс')
        cls.lesson = cls.course.lessons.filter(published=True).first()
        cls.other_course = Course.objects.get(title='Git ба GitHub')

    def setUp(self):
        self.client.force_login(self.owner)

    def url(self, model):
        return reverse('admin:catalog_'+model._meta.model_name+'_changelist')

    def post(self, model, action, ids, confirm=True, **extra):
        data = {'action': action, '_selected_action': [str(pk) for pk in ids], 'select_across': '0', **extra}
        if confirm:
            data['confirm_progress'] = 'yes'
        return self.client.post(self.url(model), data)

    def complete(self):
        response = self.post(Course, 'mr_complete_courses', [self.course.pk])
        self.assertEqual(response.status_code, 302)

    def test_confirmation_and_bulk_repeat_safe(self):
        ids = list(Course.objects.filter(published=True).values_list('pk', flat=True))
        page = self.post(Course, 'mr_complete_courses', ids, confirm=False, index='0')
        self.assertEqual(page.status_code, 200)
        self.assertTemplateUsed(page, 'admin/catalog/learning_progress_confirm.html')
        self.assertFalse(CourseCompletion.objects.exists())
        self.assertFalse(LessonCompletion.objects.exists())
        for _ in range(2):
            self.assertEqual(self.post(Course, 'mr_complete_courses', ids).status_code, 302)
        self.assertEqual(CourseCompletion.objects.filter(user=self.owner).count(), 16)
        self.assertEqual(LessonCompletion.objects.filter(user=self.owner).count(), 160)
        self.assertFalse(CourseCompletion.objects.filter(user=self.other).exists())
        self.assertEqual(LogEntry.objects.filter(user=self.owner, change_message__contains='ADMIN TEST OVERRIDE').count(), 16)

    def test_existing_scores_and_other_users_preserved(self):
        existing = CourseCompletion.objects.create(user=self.owner, course=self.course, score=85)
        original_date = existing.completed_at
        other = CourseCompletion.objects.create(user=self.other, course=self.course, score=90)
        other_lesson = LessonCompletion.objects.create(user=self.other, lesson=self.lesson)
        self.complete()
        existing.refresh_from_db()
        self.assertEqual(existing.score, 85)
        self.assertEqual(existing.completed_at, original_date)
        self.assertEqual(self.post(Course, 'mr_reset_courses', [self.course.pk], user_id=self.other.pk).status_code, 302)
        self.assertFalse(CourseCompletion.objects.filter(user=self.owner, course=self.course).exists())
        self.assertFalse(LessonCompletion.objects.filter(user=self.owner, lesson__course=self.course).exists())
        self.assertTrue(CourseCompletion.objects.filter(pk=other.pk).exists())
        self.assertTrue(LessonCompletion.objects.filter(pk=other_lesson.pk).exists())

    def test_final_reset_and_restore(self):
        self.complete()
        total = self.course.lessons.filter(published=True).count()
        self.assertEqual(self.post(Course, 'mr_reset_finals', [self.course.pk]).status_code, 302)
        self.assertEqual(LessonCompletion.objects.filter(user=self.owner).count(), total)
        self.assertFalse(CourseCompletion.objects.filter(user=self.owner).exists())
        self.assertEqual(self.post(Course, 'mr_complete_finals', [self.course.pk, self.other_course.pk]).status_code, 302)
        self.assertTrue(CourseCompletion.objects.filter(user=self.owner, course=self.course).exists())
        self.assertFalse(CourseCompletion.objects.filter(user=self.owner, course=self.other_course).exists())

    def test_lesson_reset_invalidates_final_and_preserves_project(self):
        self.complete()
        attempt = ProjectAttempt.objects.create(user=self.owner, course=self.course, project_key='test', mode='review', source='keep')
        self.assertEqual(self.post(Lesson, 'mr_reset_lessons', [self.lesson.pk]).status_code, 302)
        self.assertFalse(CourseCompletion.objects.filter(user=self.owner, course=self.course).exists())
        self.assertFalse(LessonCompletion.objects.filter(user=self.owner, lesson=self.lesson).exists())
        self.assertTrue(ProjectAttempt.objects.filter(pk=attempt.pk, source='keep').exists())
        self.assertEqual(self.post(Lesson, 'mr_complete_lessons', [self.lesson.pk]).status_code, 302)
        self.assertTrue(LessonCompletion.objects.filter(user=self.owner, lesson=self.lesson).exists())
        self.assertFalse(CourseCompletion.objects.filter(user=self.owner, course=self.course).exists())
        self.assertEqual(self.post(Course, 'mr_complete_finals', [self.course.pk]).status_code, 302)
        self.assertTrue(CourseCompletion.objects.filter(user=self.owner, course=self.course).exists())

    def test_permissions_and_readonly_records(self):
        self.complete()
        other = CourseCompletion.objects.create(user=self.other, course=self.course, score=90)
        page = self.client.get(self.url(CourseCompletion))
        self.assertEqual(page.status_code, 200)
        self.assertEqual(list(page.context['cl'].queryset.values_list('user_id', flat=True)), [self.owner.pk])
        other_url = reverse('admin:catalog_coursecompletion_change', args=[other.pk])
        self.assertIn(self.client.get(other_url).status_code, (302, 403, 404))
        self.assertEqual(self.client.get(reverse('admin:catalog_coursecompletion_add')).status_code, 403)
        self.assertEqual(self.client.get(self.url(LessonCompletion)).status_code, 200)
        self.client.force_login(self.staff)
        page = self.client.get(self.url(Course))
        self.assertEqual(page.status_code, 200)
        self.assertNotContains(page, 'mr_complete_courses')
        self.post(Course, 'mr_complete_courses', [self.other_course.pk])
        self.assertFalse(CourseCompletion.objects.filter(user=self.staff).exists())
        self.assertEqual(self.client.get(self.url(CourseCompletion)).status_code, 403)
        request = RequestFactory().post('/', {'confirm_progress':'yes'})
        request.user = self.staff
        from django.core.exceptions import PermissionDenied
        with self.assertRaises(PermissionDenied):
            admin.site._registry[Course].mr_complete_courses(request, Course.objects.all())

    def test_unpublished_and_edited_content_skipped(self):
        Lesson.objects.filter(pk=self.lesson.pk).update(content='changed')
        Course.objects.filter(pk=self.other_course.pk).update(published=False)
        self.assertEqual(self.post(Course, 'mr_complete_courses', [self.course.pk, self.other_course.pk]).status_code, 302)
        self.assertFalse(CourseCompletion.objects.filter(user=self.owner).exists())
        self.assertFalse(LessonCompletion.objects.filter(user=self.owner).exists())
        self.assertEqual(self.post(Lesson, 'mr_complete_lessons', [self.lesson.pk]).status_code, 302)
        self.assertFalse(LessonCompletion.objects.filter(user=self.owner).exists())

    def test_csrf_required(self):
        client = Client(enforce_csrf_checks=True)
        client.force_login(self.owner)
        response = client.post(self.url(Course), {'action':'mr_complete_courses', '_selected_action':str(self.course.pk), 'confirm_progress':'yes'})
        self.assertEqual(response.status_code, 403)
        self.assertFalse(CourseCompletion.objects.filter(user=self.owner).exists())
