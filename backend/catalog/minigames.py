"""Database-backed, server-scored casual multiplayer programming mini-games.

Two players or two teams share one room. Nobody needs a separate judge worker.
These quick quizzes intentionally do not affect the official coding leaderboard.
"""
import json
import secrets
from datetime import timedelta

from django.db import IntegrityError, transaction
from django.http import HttpResponseNotAllowed
from django.utils import timezone
from django.views.decorators.csrf import csrf_exempt

from .game_questions import QUESTIONS, GAME_NAMES, MATCH_SECONDS, MAX_ANSWERS, TARGET_SCORE
from .models import MiniGameRoom, MiniGamePlayer, MiniGameAnswer
from .practice import current_user, response

ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'


def body_json(request):
    if len(request.body) > 4096:
        return None
    try:
        data = json.loads(request.body)
        return data if isinstance(data, dict) else None
    except (ValueError, UnicodeDecodeError):
        return None


def _finish(room, now):
    if room.status != 'running':
        return
    room.status = 'finished'
    room.winner = (1 if room.score_a > room.score_b else
                   2 if room.score_b > room.score_a else 0)
    room.save(update_fields=['status', 'winner'])


def _question(room, player):
    if room.status != 'running' or player.answered >= MAX_ANSWERS:
        return None
    question = QUESTIONS[room.mode][player.answered % len(QUESTIONS[room.mode])]
    return {
        'index': player.answered,
        'prompt': question[0],
        'code': question[1],
        'options': question[2],
        # Do not send correct option until an authenticated player answers.
    }


def _state(room, user_id):
    players = list(room.players.select_related('user').order_by('side', 'id'))
    me = next((p for p in players if p.user_id == user_id), None)
    return {
        'code': room.code,
        'mode': room.mode,
        'name': GAME_NAMES[room.mode],
        'format': room.format,
        'status': room.status,
        'host': room.host_id == user_id,
        'side': me.side if me else None,
        'scores': [room.score_a, room.score_b],
        'target': TARGET_SCORE,
        'winner': room.winner,
        'ends_at': room.ends_at.isoformat() if room.ends_at else None,
        'players': [
            {'name': p.user.username, 'side': p.side, 'correct': p.correct,
             'me': p.user_id == user_id}
            for p in players
        ],
        'question': _question(room, me) if me else None,
        'my_answers': me.answered if me else 0,
        'max_answers': MAX_ANSWERS,
    }


def _room_and_player(code, user):
    room = MiniGameRoom.objects.select_for_update().filter(code=code.upper()).first()
    if not room:
        return None, None
    player = MiniGamePlayer.objects.filter(room=room, user=user).first()
    return room, player


@csrf_exempt
def create(request):
    if request.method != 'POST':
        return HttpResponseNotAllowed(['POST'])
    user = current_user(request)
    if not user:
        return response({'error': 'Эхлээд нэвтэрнэ үү.'}, 401)
    data = body_json(request)
    if data is None:
        return response({'error': 'Өгөгдөл буруу.'}, 400)
    mode, fmt = data.get('mode'), data.get('format')
    if mode not in QUESTIONS or fmt not in ('solo', 'team'):
        return response({'error': 'Тоглоом эсвэл оролцох хэлбэр буруу.'}, 400)
    if MiniGameRoom.objects.filter(host=user, created_at__gte=timezone.now()-timedelta(hours=1)).count() >= 10:
        return response({'error': 'Нэг цагт нээх өрөөний тоо хэтэрлээ.'}, 429)
    # Opportunistic retention cleanup avoids filling free PostgreSQL tiers.
    if secrets.randbelow(20) == 0:
        MiniGameRoom.objects.filter(created_at__lt=timezone.now()-timedelta(days=7)).delete()
    for _ in range(10):
        code = ''.join(secrets.choice(ALPHABET) for _ in range(6))
        try:
            with transaction.atomic():
                room = MiniGameRoom.objects.create(code=code, mode=mode, format=fmt, host=user)
                MiniGamePlayer.objects.create(room=room, user=user, side=1)
            return response(_state(room, user.id), 201)
        except IntegrityError:
            continue
    return response({'error': 'Өрөө нээж чадсангүй. Дахин оролдоно уу.'}, 503)


@csrf_exempt
def room_action(request, code, action='state'):
    if action == 'state' and request.method != 'GET':
        return HttpResponseNotAllowed(['GET'])
    if action != 'state' and request.method != 'POST':
        return HttpResponseNotAllowed(['POST'])
    if action not in ('state', 'join', 'start', 'answer'):
        return response({'error': 'Үйлдэл олдсонгүй.'}, 404)
    user = current_user(request)
    if not user:
        return response({'error': 'Эхлээд нэвтэрнэ үү.'}, 401)
    data = {} if request.method == 'GET' else body_json(request)
    if data is None:
        return response({'error': 'Өгөгдөл буруу.'}, 400)
    if len(code) != 6 or not all(c in ALPHABET for c in code.upper()):
        return response({'error': 'Өрөөний код буруу.'}, 404)
    with transaction.atomic():
        room, me = _room_and_player(code, user)
        if not room:
            return response({'error': 'Өрөө олдсонгүй.'}, 404)
        now = timezone.now()
        if room.status == 'running' and room.ends_at <= now:
            _finish(room, now)
        if action == 'join':
            if me:
                return response(_state(room, user.id))
            if room.status != 'waiting':
                return response({'error': 'Тоглоом эхэлсэн тул нэгдэх боломжгүй.'}, 409)
            counts = {
                side: MiniGamePlayer.objects.filter(room=room, side=side).count()
                for side in (1, 2)
            }
            capacity = 1 if room.format == 'solo' else 3
            preferred = data.get('side')
            if preferred is not None and (type(preferred) is not int or preferred not in (1, 2)):
                return response({'error': 'Багийн сонголт буруу.'}, 400)
            side = preferred or (2 if counts[2] <= counts[1] else 1)
            if counts[side] >= capacity:
                return response({'error': 'Энэ тал дүүрсэн байна.'}, 409)
            MiniGamePlayer.objects.create(room=room, user=user, side=side)
            return response(_state(room, user.id))
        if not me:
            return response({'error': 'Энэ өрөөнд нэгдээгүй байна.'}, 403)
        if action == 'start':
            if room.host_id != user.id:
                return response({'error': 'Зөвхөн өрөө нээсэн хүн эхлүүлнэ.'}, 403)
            if room.status != 'waiting':
                return response({'error': 'Тоглоом аль хэдийн эхэлсэн.'}, 409)
            if not room.players.filter(side=1).exists() or not room.players.filter(side=2).exists():
                return response({'error': 'Хоёр талд дор хаяж нэг тоглогч хэрэгтэй.'}, 409)
            room.status = 'running'
            room.started_at = now
            room.ends_at = now + timedelta(seconds=MATCH_SECONDS)
            room.save(update_fields=['status', 'started_at', 'ends_at'])
            return response(_state(room, user.id))
        if action == 'answer':
            if room.status != 'running':
                return response({'error': 'Тоглоом идэвхгүй байна.'}, 409)
            index, choice = data.get('index'), data.get('choice')
            if (type(index) is not int or type(choice) is not int or
                index != me.answered or not 0 <= choice < 4 or me.answered >= MAX_ANSWERS):
                return response({'error': 'Асуултын дугаар эсвэл хариулт буруу.'}, 409)
            if me.last_answer_at and (now - me.last_answer_at).total_seconds() < .3:
                return response({'error': 'Хэт хурдан дараалсан үйлдэл.'}, 429)
            correct = QUESTIONS[room.mode][me.answered % len(QUESTIONS[room.mode])][3] == choice
            MiniGameAnswer.objects.create(player=me, question_index=me.answered, selected=choice, correct=correct)
            me.answered += 1
            me.last_answer_at = now
            if correct:
                me.correct += 1
                if me.side == 1:
                    room.score_a += 1
                else:
                    room.score_b += 1
            me.save(update_fields=['answered', 'correct', 'last_answer_at'])
            room.save(update_fields=['score_a', 'score_b'])
            if (room.score_a >= TARGET_SCORE or room.score_b >= TARGET_SCORE or
                    not room.players.filter(answered__lt=MAX_ANSWERS).exists()):
                _finish(room, now)
            return response({'correct': correct, 'room': _state(room, user.id)})
        return response(_state(room, user.id))
