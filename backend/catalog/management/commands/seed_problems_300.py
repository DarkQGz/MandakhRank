"""Non-destructive, repeat-safe published practice library expansion."""
from collections import Counter
import json
from pathlib import Path
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction
from catalog.models import Problem, TestCase

TARGET = {'Анхан шат': 50, 'Хялбар': 100, 'Дунд': 100, 'Хүнд': 40, 'Мэргэжлийн': 10}
BANK = Path(__file__).resolve().parents[2] / 'problem_bank_300.json'
FIELDS = ('title', 'description', 'difficulty', 'topic', 'points', 'sample_input', 'sample_output')

def normalized(value):
    return value.strip().split()


def load_bank():
    try:
        rows = json.loads(BANK.read_text(encoding='utf-8'))
        if len(rows) != 300 or len({r['title'] for r in rows}) != 300:
            raise ValueError('Expected 300 unique titles')
        if Counter(r['difficulty'] for r in rows) != TARGET:
            raise ValueError('Unexpected difficulty distribution')
        for r in rows:
            for f in FIELDS:
                if f not in r:
                    raise ValueError(f'Missing field {f}')
            if not (10 <= len(r['tests']) <= 20):
                raise ValueError('Invalid test count')
            keys = [tuple(normalized(t['stdin'])) for t in r['tests']]
            if len(set(keys)) != len(keys) or tuple(normalized(r['sample_input'])) in keys:
                raise ValueError('Duplicate test input or sample repeated')
    except (OSError, ValueError, KeyError, TypeError) as e:
        raise CommandError(f'Invalid problem bank: {e}') from e
    return rows


class Command(BaseCommand):
    help = 'Нийтэлсэн бодлогын тоог 300 болгоно; байгаа бодлого, илгээлтийг устгахгүй.'

    def add_arguments(self, parser):
        parser.add_argument('--dry-run', action='store_true', help='Show plan without writing to database.')

    @transaction.atomic
    def handle(self, *args, **options):
        bank = load_bank()
        existing = list(Problem.objects.select_for_update().all())
        by_title = {p.title: p for p in existing}
        counts = Counter(p.difficulty for p in existing if p.published)
        if any(k not in TARGET or v > TARGET[k] for k, v in counts.items()):
            raise CommandError(f'Existing published difficulty counts exceed the target or use unknown labels: {dict(counts)}. No data changed.')
        planned = []
        for row in bank:
            level = row['difficulty']
            if row['title'] not in by_title and counts[level] < TARGET[level]:
                planned.append(row)
                counts[level] += 1
        if counts != TARGET:
            raise CommandError(f'Cannot reach exact quotas without changing existing records: {dict(counts)}. Unpublished or renamed items may occupy bank titles. No data changed.')
        # Only upgrade exact legacy seed records, with compatible existing fixtures.
        # Custom problems, unpublished records, and modified seed records are never overwritten.
        upgrades = []
        for row in bank:
            p = by_title.get(row['title'])
            if not p or not p.published or 'legacy_description' not in row:
                continue
            if p.description not in (row['legacy_description'], row['description']) or any(
                getattr(p, f) != row[f] for f in ('difficulty', 'topic', 'points', 'sample_input', 'sample_output')
            ):
                self.stdout.write(f'Preserving modified legacy problem: {p.title}')
                continue
            known = {tuple(normalized(t['stdin'])): normalized(t['expected']) for t in row['tests']}
            known[tuple(normalized(row['sample_input']))] = normalized(row['sample_output'])
            current = list(p.tests.all())
            if any(tuple(normalized(t.stdin)) not in known or known[tuple(normalized(t.stdin))] != normalized(t.expected) for t in current):
                self.stdout.write(f'Preserving custom test cases: {p.title}')
                continue
            present = {tuple(normalized(t.stdin)) for t in current}
            missing = [t for t in row['tests'] if tuple(normalized(t['stdin'])) not in present]
            if len(current) + len(missing) > 20:
                self.stdout.write(f'Preserving existing tests (would exceed 20): {p.title}')
                continue
            if missing or p.description != row['description']:
                upgrades.append((p, row, missing))
        self.stdout.write(f'Published before: {sum(p.published for p in existing)}; new: {len(planned)}; legacy upgrades: {len(upgrades)}')
        self.stdout.write(f'Target published: {sum(counts.values())} — {dict(counts)}')
        if options['dry_run']:
            self.stdout.write('Dry run: no database writes.')
            return
        for row in planned:
            p = Problem.objects.create(**{f: row[f] for f in FIELDS}, published=True)
            TestCase.objects.bulk_create([TestCase(problem=p, **t) for t in row['tests']])
        for p, row, missing in upgrades:
            if p.description != row['description']:
                p.description = row['description']
                p.save(update_fields=['description'])
            TestCase.objects.bulk_create([TestCase(problem=p, **t) for t in missing])
        final = Counter(Problem.objects.filter(published=True).values_list('difficulty', flat=True))
        if final != TARGET:
            raise CommandError('Final count differs from target; import rolled back.')
        self.stdout.write(self.style.SUCCESS('MandakhRank: 300 published problems ready.'))
