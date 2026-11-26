from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    dependencies = [('catalog', '0010_learning_completion'), migrations.swappable_dependency(settings.AUTH_USER_MODEL)]
    operations = [migrations.CreateModel(name='ProjectAttempt', fields=[
        ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
        ('project_key', models.CharField(max_length=32)),
        ('mode', models.CharField(choices=[('python', 'Python judge'), ('review', 'Staff review')], max_length=10)),
        ('source', models.TextField(blank=True)),
        ('review_status', models.CharField(choices=[('pending', 'Хүлээгдэж буй'), ('approved', 'Тэнцсэн'), ('rejected', 'Засвар шаардлагатай')], default='pending', max_length=10)),
        ('feedback', models.TextField(blank=True)),
        ('reviewed_at', models.DateTimeField(blank=True, null=True)),
        ('created_at', models.DateTimeField(auto_now_add=True)),
        ('course', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, to='catalog.course')),
        ('submission', models.OneToOneField(blank=True, null=True, on_delete=django.db.models.deletion.CASCADE, related_name='project_attempt', to='catalog.submission')),
        ('user', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, to=settings.AUTH_USER_MODEL)),
        ('reviewed_by', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='reviewed_projects', to=settings.AUTH_USER_MODEL)),
    ], options={'ordering': ['-id'], 'verbose_name': 'Төслийн илгээлт', 'verbose_name_plural': 'Төслийн илгээлтүүд', 'indexes': [models.Index(fields=['user', 'course', 'project_key'], name='mr_project_user_course_idx')]})]
