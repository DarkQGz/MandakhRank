"""Install the MandakhRank curriculum without deleting existing course or lesson IDs."""
import json
from pathlib import Path
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction
from catalog.models import Course, Lesson

BANK = Path(__file__).resolve().parents[2] / 'course_bank_160.json'
PLACEHOLDER = 'Энэ бол жишээ хичээл. Admin хэсгээс агуулгыг оруулна уу.'
FIELDS = ('title', 'tag', 'level', 'description', 'color')
COUNTS = [12,10,10,12,10,10,10,10,12,10,8,8,8,10,10,10]

def load_bank():
    try:
        rows = json.loads(BANK.read_text(encoding='utf-8'))
        if len(rows) != 16 or len({r['title'] for r in rows}) != 16 or [len(r['lessons']) for r in rows] != COUNTS:
            raise ValueError('Expected 16 courses and 160 lessons in the planned distribution.')
        for row in rows:
            for field in FIELDS:
                if not isinstance(row[field], str) or not row[field].strip():
                    raise ValueError(f'Invalid course field: {field}')
            titles = {l['title'] for l in row['lessons']}
            if len(titles) != len(row['lessons']):
                raise ValueError('Duplicate lesson title')
            if row.get('legacy') and not set(row['legacy']['lessons']) <= titles:
                raise ValueError('Missing legacy lesson')
            for l in row['lessons']:
                if not l['title'].strip() or len(l['title']) > 200 or not all(s in l['content'] for s in ('1. ОЙЛГОЛТ','2. ЖИШЭЭ','3. ҮР ДҮН БА ТАЙЛБАР','4. БИЕ ДААХ ДАДЛАГА')):
                    raise ValueError('Invalid lesson content')
        return rows
    except (OSError, ValueError, KeyError, TypeError) as e:
        raise CommandError(f'Invalid course bank: {e}') from e

class Command(BaseCommand):
    help = '16 сургалт, 160 хичээл нэмнэ. Өмнөх хичээлийн ID-г хадгална.'

    def add_arguments(self, parser):
        parser.add_argument('--dry-run', action='store_true', help='Preview without database writes.')

    @transaction.atomic
    def handle(self, *args, **options):
        bank = load_bank()
        existing = list(Course.objects.select_for_update().all())
        known = set()
        plans = []
        new_c = new_l = upgraded = 0
        # Preflight all records before writing. Never overwrite manually edited content.
        for row in bank:
            legacy = row.get('legacy', {})
            aliases = {row['title'], legacy.get('title')}
            matches = [c for c in existing if c.title in aliases]
            if len(matches) > 1:
                raise CommandError(f'Duplicate course aliases: {row["title"]}. No data changed.')
            c = matches[0] if matches else None
            lessons = []
            if c:
                known.add(c.pk)
                if not c.published:
                    raise CommandError(f'Course is unpublished: {c.title}. No data changed.')
                if not (all(getattr(c,f) == row[f] for f in FIELDS) or (legacy and all(getattr(c,f) == legacy[f] for f in FIELDS))):
                    raise CommandError(f'Custom course metadata: {c.title}. No data changed.')
                lessons = list(Lesson.objects.select_for_update().filter(course=c))
            else:
                new_c += 1
            by_title = {l.title:l for l in lessons}
            desired = {l['title']:l for l in row['lessons']}
            if len(by_title) != len(lessons) or set(by_title) - set(desired):
                raise CommandError(f'Custom or duplicate lessons in {row["title"]}. No data changed.')
            for l in lessons:
                if not l.published:
                    raise CommandError(f'Unpublished lesson: {l.title}. No data changed.')
                if l.content == desired[l.title]['content']:
                    continue
                if l.title not in legacy.get('lessons', []) or l.content not in ('', PLACEHOLDER):
                    raise CommandError(f'Custom lesson content: {l.title}. No data changed.')
                upgraded += 1
            new_l += len(desired) - len(lessons)
            plans.append((row,c,by_title))
        if any(c.published and c.pk not in known for c in existing):
            raise CommandError('Additional published courses exist. Cannot reach exactly 16 without removing them. No data changed.')
        self.stdout.write(f'New courses: {new_c}; new lessons: {new_l}; placeholder lessons upgraded: {upgraded}.')
        if options['dry_run']:
            self.stdout.write('Dry run: target 16 published courses, 160 published lessons; no writes.')
            return
        for row,c,by_title in plans:
            values = {f:row[f] for f in FIELDS}
            if c is None:
                c = Course.objects.create(**values, published=True)
            else:
                changed = [f for f,v in values.items() if getattr(c,f)!=v]
                if changed:
                    for f in changed: setattr(c,f,values[f])
                    c.save(update_fields=changed)
            for position, item in enumerate(row['lessons'], 1):
                l = by_title.get(item['title'])
                if l is None:
                    Lesson.objects.create(course=c,position=position,published=True,**item)
                else:
                    changed=[]
                    if l.content != item['content']:
                        l.content=item['content']; changed.append('content')
                    if l.position != position:
                        l.position=position; changed.append('position')
                    if changed: l.save(update_fields=changed)
        if Course.objects.filter(published=True).count()!=16 or Lesson.objects.filter(published=True,course__published=True).count()!=160:
            raise CommandError('Final counts differ; import rolled back.')
        self.stdout.write(self.style.SUCCESS('MandakhRank: 16 published courses, 160 published lessons ready.'))
