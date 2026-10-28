from pathlib import Path
from tempfile import TemporaryDirectory
from django.test import TestCase, override_settings
from django.core.management import call_command
from .models import Problem, Course

class HostingTests(TestCase):
    def test_web_home_serves_built_index_without_caching(self):
        with TemporaryDirectory() as folder:
            directory=Path(folder)
            (directory/'webapp').mkdir()
            (directory/'webapp'/'index.html').write_text('<html>MandakhRank</html>')
            with override_settings(BASE_DIR=directory):
                r=self.client.get('/')
                self.assertEqual(r.status_code,200)
                self.assertEqual(b''.join(r.streaming_content),b'<html>MandakhRank</html>')
                self.assertEqual(r['Cache-Control'],'no-cache')
                r.close()
    def test_missing_build_is_clear(self):
        with TemporaryDirectory() as folder, override_settings(BASE_DIR=Path(folder)):
            self.assertEqual(self.client.get('/').status_code,503)
    def test_startup_seed_preserves_existing_cms_content(self):
        p=Problem.objects.create(title='My own problem',points=777)
        c=Course.objects.create(title='My own course')
        call_command('seed_problems',if_empty=True)
        call_command('seed_courses',if_empty=True)
        self.assertEqual(Problem.objects.count(),1)
        self.assertEqual(Course.objects.count(),1)
        p.refresh_from_db();c.refresh_from_db()
        self.assertEqual(p.points,777)
        self.assertEqual(c.title,'My own course')
