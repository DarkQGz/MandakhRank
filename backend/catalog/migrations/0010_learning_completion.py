from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    dependencies = [('catalog', '0009_profilecomment'), migrations.swappable_dependency(settings.AUTH_USER_MODEL)]
    operations = [
        migrations.CreateModel(name='LessonCompletion', fields=[
            ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
            ('completed_at', models.DateTimeField(auto_now_add=True)),
            ('user', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, to=settings.AUTH_USER_MODEL)),
            ('lesson', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, to='catalog.lesson')),
        ], options={'constraints': [models.UniqueConstraint(fields=('user', 'lesson'), name='unique_learning_lesson')]}),
        migrations.CreateModel(name='CourseCompletion', fields=[
            ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
            ('score', models.PositiveSmallIntegerField()),
            ('completed_at', models.DateTimeField(auto_now_add=True)),
            ('user', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, to=settings.AUTH_USER_MODEL)),
            ('course', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, to='catalog.course')),
        ], options={'constraints': [models.UniqueConstraint(fields=('user', 'course'), name='unique_learning_course')]}),
    ]
