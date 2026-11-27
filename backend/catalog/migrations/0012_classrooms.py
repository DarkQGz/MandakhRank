from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    dependencies = [('catalog', '0011_project_attempt'), migrations.swappable_dependency(settings.AUTH_USER_MODEL)]
    operations = [
        migrations.CreateModel(name='ClassroomTeacher', fields=[
            ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
            ('granted_at', models.DateTimeField(auto_now_add=True)),
            ('user', models.OneToOneField(on_delete=django.db.models.deletion.CASCADE, related_name='classroom_teacher_role', to=settings.AUTH_USER_MODEL)),
        ], options={'verbose_name': 'Багшийн эрх', 'verbose_name_plural': 'Багшийн эрхүүд'}),
        migrations.CreateModel(name='Classroom', fields=[
            ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
            ('name', models.CharField(max_length=100)),
            ('description', models.CharField(blank=True, max_length=500)),
            ('join_code', models.CharField(max_length=24, unique=True)),
            ('archived', models.BooleanField(default=False)),
            ('created_at', models.DateTimeField(auto_now_add=True)),
            ('owner', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='owned_classrooms', to=settings.AUTH_USER_MODEL)),
        ], options={'ordering': ['-id'], 'verbose_name': 'Суралцах анги', 'verbose_name_plural': 'Суралцах ангиуд'}),
        migrations.CreateModel(name='ClassroomMember', fields=[
            ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
            ('joined_at', models.DateTimeField(auto_now_add=True)),
            ('classroom', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='members', to='catalog.classroom')),
            ('user', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='classroom_memberships', to=settings.AUTH_USER_MODEL)),
        ], options={'constraints': [models.UniqueConstraint(fields=('classroom', 'user'), name='mr_unique_class_member')]}),
        migrations.CreateModel(name='ClassroomAssignment', fields=[
            ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
            ('title', models.CharField(max_length=120)),
            ('instructions', models.TextField(blank=True, max_length=2000)),
            ('kind', models.CharField(choices=[('lesson', 'Хичээл'), ('course', 'Сургалт'), ('problem', 'Бодлого'), ('project', 'Төсөл')], max_length=12)),
            ('target_id', models.PositiveBigIntegerField()),
            ('target_title', models.CharField(max_length=300)),
            ('due_at', models.DateTimeField(blank=True, null=True)),
            ('archived', models.BooleanField(default=False)),
            ('created_at', models.DateTimeField(auto_now_add=True)),
            ('classroom', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='assignments', to='catalog.classroom')),
        ], options={'ordering': ['-id'], 'verbose_name': 'Ангийн даалгавар', 'verbose_name_plural': 'Ангийн даалгаврууд'}),
    ]
