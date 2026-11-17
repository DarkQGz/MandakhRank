from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    dependencies = [('catalog', '0007_profileavatar'), migrations.swappable_dependency(settings.AUTH_USER_MODEL)]
    operations = [
        migrations.CreateModel(name='MiniGameRoom', fields=[
            ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
            ('code', models.CharField(max_length=7, unique=True)),
            ('mode', models.CharField(choices=[('tug', 'Олс таталт'), ('frog', 'Мэлхийн үсрэлт'), ('rocket', 'Кодын пуужин')], max_length=12)),
            ('format', models.CharField(choices=[('solo', 'Ганцаарчилсан'), ('team', 'Багийн')], max_length=8)),
            ('status', models.CharField(default='waiting', max_length=12)),
            ('score_a', models.PositiveSmallIntegerField(default=0)),
            ('score_b', models.PositiveSmallIntegerField(default=0)),
            ('winner', models.PositiveSmallIntegerField(default=0)),
            ('created_at', models.DateTimeField(auto_now_add=True)),
            ('started_at', models.DateTimeField(blank=True, null=True)),
            ('ends_at', models.DateTimeField(blank=True, null=True)),
            ('host', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='hosted_minigames', to=settings.AUTH_USER_MODEL)),
        ], options={'ordering': ['-created_at'], 'verbose_name': 'Бяцхан тоглоомын өрөө', 'verbose_name_plural': 'Бяцхан тоглоомын өрөөнүүд'}),
        migrations.CreateModel(name='MiniGamePlayer', fields=[
            ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
            ('side', models.PositiveSmallIntegerField()),
            ('answered', models.PositiveSmallIntegerField(default=0)),
            ('correct', models.PositiveSmallIntegerField(default=0)),
            ('last_answer_at', models.DateTimeField(blank=True, null=True)),
            ('room', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='players', to='catalog.minigameroom')),
            ('user', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, to=settings.AUTH_USER_MODEL)),
        ]),
        migrations.CreateModel(name='MiniGameAnswer', fields=[
            ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
            ('question_index', models.PositiveSmallIntegerField()),
            ('selected', models.PositiveSmallIntegerField()),
            ('correct', models.BooleanField()),
            ('created_at', models.DateTimeField(auto_now_add=True)),
            ('player', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='answers', to='catalog.minigameplayer')),
        ]),
        migrations.AddConstraint(model_name='minigameplayer', constraint=models.UniqueConstraint(fields=('room', 'user'), name='unique_minigame_player')),
        migrations.AddConstraint(model_name='minigameanswer', constraint=models.UniqueConstraint(fields=('player', 'question_index'), name='unique_minigame_answer')),
    ]
