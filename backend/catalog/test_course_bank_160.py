from io import StringIO
from django.core.management import call_command, CommandError
from django.test import TestCase
from catalog.models import Course, Lesson
from catalog.management.commands.seed_courses_160 import load_bank, PLACEHOLDER

class CourseBankTests(TestCase):
    def seed(self, **kwargs):
        call_command('seed_courses_160', stdout=StringIO(), **kwargs)

    def test_dry_run_and_repeat(self):
        self.seed(dry_run=True)
        self.assertEqual(Course.objects.count(), 0)
        self.seed()
        self.assertEqual(Course.objects.filter(published=True).count(),16)
        self.assertEqual(Lesson.objects.filter(published=True).count(),160)
        before=list(Lesson.objects.order_by('pk').values_list('pk','content','position'))
        self.seed()
        self.assertEqual(before,list(Lesson.objects.order_by('pk').values_list('pk','content','position')))

    def test_legacy_ids_preserved(self):
        call_command('seed_courses',stdout=StringIO())
        ids=list(Lesson.objects.values_list('pk',flat=True))
        courses=list(Course.objects.values_list('pk',flat=True))
        self.assertEqual(len(ids),21)
        self.seed()
        self.assertEqual(Course.objects.filter(pk__in=courses).count(),4)
        self.assertEqual(Lesson.objects.filter(pk__in=ids).count(),21)
        self.assertFalse(Lesson.objects.filter(content=PLACEHOLDER).exists())
        self.assertEqual(Lesson.objects.count(),160)

    def test_custom_content_prevents_import(self):
        call_command('seed_courses',stdout=StringIO())
        l=Lesson.objects.first(); l.content='Багшийн өөрийн агуулга'; l.save()
        with self.assertRaises(CommandError): self.seed()
        l.refresh_from_db()
        self.assertEqual(l.content,'Багшийн өөрийн агуулга')
        self.assertEqual(Course.objects.count(),4)
        self.assertEqual(Lesson.objects.count(),21)

    def test_additional_published_course_prevents_import(self):
        Course.objects.create(title='Custom',tag='Python',level='Анхан шат',description='Custom',published=True)
        with self.assertRaises(CommandError): self.seed()
        self.assertEqual(Course.objects.count(),1)

    def test_positions_and_content(self):
        self.seed()
        for row in load_bank():
            c=Course.objects.get(title=row['title'])
            self.assertEqual(list(c.lessons.values_list('position',flat=True)),list(range(1,len(row['lessons'])+1)))
            self.assertEqual(list(c.lessons.values_list('title',flat=True)),[l['title'] for l in row['lessons']])
