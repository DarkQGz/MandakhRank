from collections import Counter
from io import StringIO
from django.core.management import call_command, CommandError
from django.test import TestCase
from django.contrib.auth import get_user_model
from catalog.models import Problem, Submission
from catalog.management.commands.seed_problems_300 import TARGET, load_bank

class ProblemBankTests(TestCase):
    def counts(self):
        return Counter(Problem.objects.filter(published=True).values_list('difficulty', flat=True))

    def test_fresh_install_and_idempotence(self):
        call_command('seed_problems_300', dry_run=True, stdout=StringIO())
        self.assertEqual(Problem.objects.count(), 0)
        call_command('seed_problems_300', stdout=StringIO())
        self.assertEqual(self.counts(), TARGET)
        ids = list(Problem.objects.values_list('id', flat=True))
        cases = list(Problem.objects.values_list('tests__id', flat=True))
        self.assertTrue(all(10 <= p.tests.count() <= 20 for p in Problem.objects.all()))
        call_command('seed_problems_300', stdout=StringIO())
        self.assertEqual(ids, list(Problem.objects.values_list('id', flat=True)))
        self.assertEqual(cases, list(Problem.objects.values_list('tests__id', flat=True)))

    def test_legacy_upgrade_preserves_submission_and_score(self):
        call_command('seed_problems', stdout=StringIO())
        p = Problem.objects.get(title='Хоёр тооны нийлбэр')
        u = get_user_model().objects.create_user(username='bank-test')
        s = Submission.objects.create(user=u, problem=p, code='print(10)', status='Accepted', passed=4, total=4)
        ids = set(p.tests.values_list('id', flat=True))
        call_command('seed_problems_300', stdout=StringIO())
        p.refresh_from_db(); s.refresh_from_db()
        self.assertEqual(self.counts(), TARGET)
        self.assertEqual(p.points, 10)
        self.assertEqual(s.problem_id, p.pk)
        self.assertEqual((s.status, s.passed, s.total), ('Accepted',4,4))
        self.assertTrue(ids.issubset(set(p.tests.values_list('id', flat=True))))
        self.assertTrue(10 <= p.tests.count() <= 20)

    def test_custom_published_problem_counts_toward_quota(self):
        p = Problem.objects.create(title='Custom fixture', description='keep', difficulty='Хялбар', topic='Суурь', points=17, sample_input='1', sample_output='1', published=True)
        call_command('seed_problems_300', stdout=StringIO())
        p.refresh_from_db()
        self.assertEqual(self.counts(), TARGET)
        self.assertEqual((p.description,p.points), ('keep',17))

    def test_unknown_level_stops_without_writes(self):
        Problem.objects.create(title='Custom unknown', description='keep', difficulty='Unknown', topic='Суурь', sample_input='1', sample_output='1', published=True)
        with self.assertRaises(CommandError):
            call_command('seed_problems_300', stdout=StringIO())
        self.assertEqual(Problem.objects.count(), 1)
