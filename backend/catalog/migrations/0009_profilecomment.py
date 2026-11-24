from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    dependencies = [('catalog', '0008_minigames'), migrations.swappable_dependency(settings.AUTH_USER_MODEL)]
    operations = [migrations.CreateModel(name='ProfileComment', fields=[
        ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
        ('body', models.CharField(max_length=500)),
        ('created_at', models.DateTimeField(auto_now_add=True)),
        ('owner', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='profile_comments', to=settings.AUTH_USER_MODEL)),
        ('author', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='written_profile_comments', to=settings.AUTH_USER_MODEL)),
    ], options={'ordering': ['-id'], 'indexes': [models.Index(fields=['owner', '-id'], name='profile_wall_owner_idx')], 'verbose_name': 'Профайлын сэтгэгдэл', 'verbose_name_plural': 'Профайлын сэтгэгдлүүд'})]
