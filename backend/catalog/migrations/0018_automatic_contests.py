from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    dependencies = [('catalog', '0017_production_operations')]
    operations = [
        migrations.AddField(model_name='contest', name='auto_judge', field=models.BooleanField(default=False, editable=False)),
        migrations.AddField(model_name='problem', name='is_contest_transport', field=models.BooleanField(default=False, editable=False)),
        migrations.AddConstraint(model_name='problem', constraint=models.CheckConstraint(
            condition=models.Q(is_contest_transport=False) | models.Q(published=False, points=0), name='mr_contest_transport_private')),
        migrations.AddField(model_name='contestproblem', name='judge_problem', field=models.OneToOneField(
            to='catalog.problem', null=True, blank=True, editable=False, on_delete=django.db.models.deletion.PROTECT, related_name='contest_task')),
        migrations.AddField(model_name='contestproblem', name='judge_tests', field=models.JSONField(default=list, blank=True, editable=False)),
    ]
