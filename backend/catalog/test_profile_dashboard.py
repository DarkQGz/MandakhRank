from io import BytesIO

from django.contrib.auth import get_user_model
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase
from PIL import Image

from .models import Course, Lesson, Problem, ProfileAvatar, Submission, AccessToken


class DashboardAndAvatarTests(TestCase):
    def setUp(self):
        self.student = get_user_model().objects.create_user(
            username='learner', email='learner@example.com', password='strong-pass-1482'
        )
        self.other = get_user_model().objects.create_user(
            username='other', email='other@example.com', password='strong-pass-1482'
        )
        self.token = 'a' * 64
        AccessToken.objects.create(user=self.student, key=self.token)
        self.headers = {'HTTP_AUTHORIZATION': 'Bearer ' + self.token}

    def image(self):
        out = BytesIO()
        Image.new('RGB', (512, 400), (30, 130, 200)).save(out, format='PNG')
        return SimpleUploadedFile('avatar.png', out.getvalue(), content_type='image/png')

    def test_me_private_and_points_count_solved_once(self):
        self.assertEqual(self.client.get('/api/profile/me/').status_code, 401)
        p = Problem.objects.create(title='Two Numbers', description='sum',
            sample_input='1 2', sample_output='3', published=True, points=15)
        for _ in range(2):
            Submission.objects.create(user=self.student, problem=p, code='print(3)', status='Accepted')
        r = self.client.get('/api/profile/me/', **self.headers)
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.json()['statistics']['solved'], 1)
        self.assertEqual(r.json()['statistics']['points'], 15)
        self.assertEqual(r.json()['statistics']['submissions'], 2)
        self.assertEqual(r.json()['email'], 'learner@example.com')
        self.assertNotIn('token', r.json())

    def test_avatar_normalized_to_small_jpeg_and_persistent(self):
        r = self.client.post('/api/profile/avatar/', {'avatar': self.image()}, **self.headers)
        self.assertEqual(r.status_code, 200)
        self.assertIn('?v=', r.json()['avatar_url'])
        saved = ProfileAvatar.objects.get(user=self.student)
        self.assertLess(len(saved.data), 100000)
        with Image.open(BytesIO(saved.data)) as im:
            self.assertEqual(im.format, 'JPEG')
            self.assertEqual(im.size, (256, 256))
        public = self.client.get(f'/api/profile/avatar/{self.student.pk}/')
        self.assertEqual(public.status_code, 200)
        self.assertEqual(public['Content-Type'], 'image/jpeg')
        ranking = self.client.get('/api/rankings/').json()['results']
        me = next(u for u in ranking if u['id'] == self.student.pk)
        self.assertIn('/api/profile/avatar/', me['avatar_url'])

    def test_avatar_rejects_bad_and_large_files(self):
        r = self.client.post('/api/profile/avatar/', {
            'avatar': SimpleUploadedFile('bad.jpg', b'<svg>not a real picture</svg>')
        }, **self.headers)
        self.assertEqual(r.status_code, 400)
        r = self.client.post('/api/profile/avatar/', {
            'avatar': SimpleUploadedFile('big.png', b'x' * (2 * 1024 * 1024 + 1))
        }, **self.headers)
        self.assertEqual(r.status_code, 413)
        self.assertFalse(ProfileAvatar.objects.filter(user=self.student).exists())

    def test_only_owner_can_edit_and_delete_avatar(self):
        self.assertEqual(self.client.post('/api/profile/avatar/', {'avatar': self.image()}).status_code, 401)
        self.assertEqual(self.client.post('/api/profile/avatar/', {'avatar': self.image()}, **self.headers).status_code, 200)
        self.assertEqual(self.client.delete('/api/profile/avatar/').status_code, 401)
        self.assertEqual(self.client.delete('/api/profile/avatar/', **self.headers).status_code, 200)
        self.assertEqual(self.client.get(f'/api/profile/avatar/{self.student.pk}/').status_code, 404)

    def test_course_and_lesson_publishing(self):
        course = Course.objects.create(title='Python Basics', tag='Python', level='Анхан шат', description='Intro', published=True)
        Lesson.objects.create(course=course, title='Variables', content='Learn variables', published=True)
        Lesson.objects.create(course=course, title='Draft', content='Not public', published=False)
        data = self.client.get('/api/courses/').json()['results']
        selected = next(c for c in data if c['id'] == course.id)
        self.assertEqual(selected['lessons'], ['Variables'])
        self.assertEqual(selected['lesson_content'][0]['content'], 'Learn variables')

    def test_admin_overview_only_superuser(self):
        self.client.force_login(self.student)
        self.assertNotEqual(self.client.get('/admin/overview/').status_code, 200)
        self.student.is_staff = True
        self.student.save(update_fields=['is_staff'])
        self.assertEqual(self.client.get('/admin/overview/').status_code, 403)
        self.student.is_superuser = True
        self.student.save(update_fields=['is_superuser'])
        r = self.client.get('/admin/overview/')
        self.assertEqual(r.status_code, 200)
        self.assertContains(r, 'Удирдлагын самбар')
