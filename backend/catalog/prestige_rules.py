"""Pure rules for server-validated profile customization."""
from .progression_rules import ACHIEVEMENTS

# Each achievement has a different visual pair and motif. IDs are stable.
DESIGNS = (
    ('60A5FA','B8E7FF','prism'), ('4385F4','38E5CF','orbit'),
    ('3B82F6','A78BFA','pulse'), ('22D3EE','818CF8','prism'),
    ('6366F1','F472B6','aurora'), ('2563EB','F5C451','royal'),
    ('0EA5E9','E9D5FF','orbit'), ('F5C451','FB7185','royal'),
    ('34D399','BAF7D0','prism'), ('10B981','67E8F9','orbit'),
    ('14B8A6','A3E635','pulse'), ('059669','E9D5FF','aurora'),
    ('4ADE80','FACC15','royal'), ('0D9488','93C5FD','prism'),
    ('3776AB','FFD343','orbit'), ('A3E635','F5C451','royal'),
    ('FB923C','FDE68A','ember'), ('F97316','FB7185','pulse'),
    ('EA580C','FACC15','ember'), ('F43F5E','FDBA74','aurora'),
    ('EF4444','F5C451','royal'), ('C084FC','93C5FD','prism'),
    ('A855F7','F472B6','orbit'), ('7C3AED','22D3EE','aurora'),
    ('C0CADB','D6A449','royal'), ('D6A449','FFF2A5','royal'),
    ('8B5CF6','34D399','pulse'), ('A855F7','FB7185','ember'),
    ('DB2777','A78BFA','prism'), ('F472B6','67E8F9','aurora'),
)
assert len(DESIGNS) == len(ACHIEVEMENTS) == 30
REWARDS = {a[0]: dict(id=a[0], title=a[2], description=a[3], colors=list(d[:2]), motif=d[2])
           for a, d in zip(ACHIEVEMENTS, DESIGNS)}
DEFAULT = dict(frame='', accent='', title='', background='plain', motion=True, featured=[])
BACKGROUNDS = ('plain', 'gradient', 'soft')


def prestige_rank(row):
    """Competition ranks (ties share a rank); only earned positive scores qualify."""
    rank = row.get('rank')
    return rank if type(rank) is int and 1 <= rank <= 5 and row.get('score', 0) > 0 else None


def unlocked_ids(progression):
    return {a['id'] for a in progression.get('achievements', [])
            if a.get('id') in REWARDS and a.get('unlocked') is True}


def validate_preferences(data, unlocked):
    """Only known unlocked achievement IDs; no arbitrary CSS, colors or role labels."""
    if not isinstance(data, dict) or set(data) != set(DEFAULT):
        raise ValueError('Тохиргооны мэдээлэл буруу байна.')
    for key in ('frame', 'accent', 'title'):
        value = data[key]
        if not isinstance(value, str) or (value and (value not in unlocked or value not in REWARDS)):
            raise ValueError('Нээгээгүй амжилтын загвар сонгох боломжгүй.')
    featured = data['featured']
    if (not isinstance(featured, list) or len(featured) > 3
            or any(not isinstance(v, str) or (v not in unlocked or v not in REWARDS) for v in featured)
            or len(set(featured)) != len(featured)):
        raise ValueError('Нээсэн 3 хүртэлх өөр амжилт сонгоно уу.')
    if not isinstance(data['background'], str) or data['background'] not in BACKGROUNDS or type(data['motion']) is not bool:
        raise ValueError('Загварын тохиргоо буруу байна.')
    return {**data, 'featured': list(featured)}


def effective_preferences(stored, unlocked):
    """Administrative resets or lost achievements never keep locked cosmetics active."""
    stored = stored if isinstance(stored, dict) else {}
    result = dict(DEFAULT, featured=[])
    for key in ('frame', 'accent', 'title'):
        v = stored.get(key)
        if isinstance(v, str) and v in unlocked and v in REWARDS:
            result[key] = v
    v = stored.get('background')
    if isinstance(v, str) and v in BACKGROUNDS:
        result['background'] = v
    if type(stored.get('motion')) is bool:
        result['motion'] = stored['motion']
    v = stored.get('featured')
    if isinstance(v, list):
        result['featured'] = list(dict.fromkeys(i for i in v if isinstance(i, str) and i in unlocked and i in REWARDS))[:3]
    return result


def appearance_data(progression, stored, rank, owner=False):
    unlocked = unlocked_ids(progression)
    prefs = effective_preferences(stored, unlocked)
    result = dict(rank=rank, background=prefs['background'], motion=prefs['motion'],
                  frame=REWARDS.get(prefs['frame']), accent=REWARDS.get(prefs['accent']),
                  title=REWARDS.get(prefs['title']), featured=[REWARDS[i] for i in prefs['featured']])
    if owner:
        progress = {a['id']: a for a in progression.get('achievements', []) if a.get('id') in REWARDS}
        result['preferences'] = prefs
        result['rewards'] = [dict(r, unlocked=k in unlocked, progress=progress.get(k, {}).get('progress', 0),
                                  target=progress.get(k, {}).get('target', 1)) for k, r in REWARDS.items()]
    return result
