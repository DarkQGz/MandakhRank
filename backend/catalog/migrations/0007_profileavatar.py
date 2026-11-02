from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    dependencies = [
        ('catalog', '0006_cms_bridge'),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]
    operations = [
        migrations.CreateModel(
            name='ProfileAvatar',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('data', models.BinaryField()),
                ('content_type', models.CharField(default='image/jpeg', max_length=40)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('user', models.OneToOneField(on_delete=django.db.models.deletion.CASCADE, related_name='profile_avatar', to=settings.AUTH_USER_MODEL)),
            ],
            options={'verbose_name': 'Хэрэглэгчийн зураг', 'verbose_name_plural': 'Хэрэглэгчийн зургууд'},
        ),
    ]
