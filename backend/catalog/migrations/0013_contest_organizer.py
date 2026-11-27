from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion

class Migration(migrations.Migration):
    dependencies = [('catalog', '0012_classrooms'), migrations.swappable_dependency(settings.AUTH_USER_MODEL)]
    operations = [migrations.AddField(model_name='contest', name='organizer', field=models.ForeignKey(
        blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL,
        related_name='organized_contests', to=settings.AUTH_USER_MODEL))]
