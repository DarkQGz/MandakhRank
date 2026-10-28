import json
from pathlib import Path
from django.core.management.base import BaseCommand
from catalog.models import Course,Lesson
class Command(BaseCommand):
    help='Жишээ сургалтуудыг нэг удаа нэмэх (байгааг өөрчлөхгүй)'
    def add_arguments(self,parser):
        parser.add_argument('--if-empty',action='store_true')
    def handle(self,*args,**kwargs):
        if kwargs.get('if_empty') and Course.objects.exists(): return
        data=json.loads((Path(__file__).resolve().parents[2]/'demo.json').read_text(encoding='utf-8'))
        for row in data['courses']:
            c,created=Course.objects.get_or_create(title=row['title'],defaults={k:row[k] for k in ['tag','level','description','color']}|{'published':True})
            if created:
                for i,title in enumerate(row['lessons']): Lesson.objects.create(course=c,title=title,position=i+1,content='Энэ бол жишээ хичээл. Admin хэсгээс агуулгыг оруулна уу.',published=True)
        self.stdout.write(self.style.SUCCESS('Сургалтууд бэлэн.'))
