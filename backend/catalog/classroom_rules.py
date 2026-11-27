"""Pure status and CSV helpers; no Django dependency."""
import csv
import io
from datetime import datetime


def assignment_status(completed, due, created, available, now):
    if not available:
        return 'unavailable'
    if completed is not None:
        if due is not None and completed > due:
            return 'late'
        if completed < created:
            return 'prior'
        return 'done'
    return 'overdue' if due is not None and now > due else 'pending'


def parse_deadline(value):
    if value in (None, ''):
        return None
    if not isinstance(value, str) or len(value) > 50:
        raise ValueError('Invalid deadline')
    result = datetime.fromisoformat(value.replace('Z', '+00:00'))
    if result.tzinfo is None or result.utcoffset() is None:
        raise ValueError('Timezone required')
    return result


def safe_cell(value):
    text = str(value if value is not None else '')
    # Spreadsheet formula injection; includes leading whitespace and control characters.
    if text.lstrip().startswith(('=', '+', '-', '@')) or text.startswith(('\t', '\r', '\n')):
        return "'" + text
    return text


def make_csv(rows):
    output = io.StringIO(newline='')
    writer = csv.writer(output)
    for row in rows:
        writer.writerow([safe_cell(cell) for cell in row])
    return '\ufeff' + output.getvalue()
