from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [('catalog', '0015_submission_language')]
    operations = [
        migrations.AddField(model_name='submission', name='share_on_profile',
                            field=models.BooleanField(default=False, editable=False)),
        migrations.AddConstraint(model_name='submission', constraint=models.UniqueConstraint(
            fields=('user', 'problem'), condition=models.Q(share_on_profile=True),
            name='unique_showcase_solution_per_problem')),
    ]
