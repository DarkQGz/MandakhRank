import json
from pathlib import Path
from django.core.management.base import BaseCommand
from django.db import transaction
from catalog.models import Problem,TestCase
TESTS=[ [('3 7','10'),('-8 3','-5'),('0 0','0'),('1000000 999999','1999999')], [('8','EVEN'),('7','ODD'),('0','EVEN'),('-3','ODD')], [('5\n2 8 3 9 1','9'),('3\n-8 -2 -5','-2'),('1\n42','42')], [('level','YES'),('python','NO'),('a','YES'),('abba','YES')], [('5 7\n1 3 5 7 9','3'),('3 8\n1 2 3','-1'),('1 4\n4','0')], [('4 3\n1 2\n2 3\n3 4','3'),('4 2\n1 2\n3 4','-1'),('3 3\n1 2\n2 3\n1 3','1')], [('6\n2 2 3 1 3 4','2 3 1 4'),('3\n5 5 5','5'),('4\n-1 0 -1 2','-1 0 2')], [('7','13'),('0','0'),('1','1'),('40','102334155')]]
class Command(BaseCommand):
    help='8 бодлого, 28 нууц тест нэмнэ. Байгаа бодлогыг өөрчлөхгүй.'
    def add_arguments(self,parser):
        parser.add_argument('--if-empty',action='store_true')
    @transaction.atomic
    def handle(self,*args,**kwargs):
        if kwargs.get('if_empty') and Problem.objects.exists(): return
        data=json.loads((Path(__file__).resolve().parents[2]/'demo.json').read_text(encoding='utf-8'))
        for row,tests in zip(data['problems'],TESTS):
            p,created=Problem.objects.get_or_create(title=row['title'],defaults=dict(description=row['description'],difficulty=row['difficulty'],topic=row['topic'],points=row['points'],sample_input=row['input'],sample_output=row['output'],published=True))
            if created:
                TestCase.objects.bulk_create([TestCase(problem=p,stdin=i+'\n',expected=o+'\n') for i,o in tests])
        self.stdout.write('8 бодлогын сан бэлэн.')
