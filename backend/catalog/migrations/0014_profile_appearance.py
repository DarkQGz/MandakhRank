from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    dependencies = [('catalog', '0013_contest_organizer'), migrations.swappable_dependency(settings.AUTH_USER_MODEL)]
    operations = [migrations.CreateModel(name='ProfileAppearance', fields=[
        ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
        ('preferences', models.JSONField(default=dict, blank=True)),
        ('user', models.OneToOneField(on_delete=django.db.models.deletion.CASCADE,
                                     related_name='profile_appearance', to=settings.AUTH_USER_MODEL)),
    ])]
