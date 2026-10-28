"""Run the HTTP server and queue worker together on a single Render instance."""
import os
import signal
import subprocess
import sys
import time
from django.core.management.base import BaseCommand, CommandError

class Command(BaseCommand):
    help = 'Start Gunicorn and the automatic Judge0 queue worker (Linux hosting).'

    def handle(self, *args, **options):
        children = []
        stopping = False
        def stop(signum, frame):
            nonlocal stopping
            stopping = True
        signal.signal(signal.SIGTERM, stop)
        signal.signal(signal.SIGINT, stop)
        try:
            children.append(subprocess.Popen([sys.executable, '-m', 'gunicorn',
                'config.wsgi:application', '--bind', '0.0.0.0:' + os.environ.get('PORT', '8000'),
                '--workers', '2', '--timeout', '60']))
            children.append(subprocess.Popen([sys.executable, 'manage.py', 'judge_worker']))
            while not stopping:
                if any(child.poll() is not None for child in children):
                    raise CommandError('A server process stopped. Restart the service.')
                time.sleep(1)
        finally:
            for child in children:
                if child.poll() is None: child.terminate()
            for child in children:
                try: child.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    child.kill()
                    child.wait()
