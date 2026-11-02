from django.db import migrations, models

class Migration(migrations.Migration):
    dependencies = [('catalog', '0005_firebaseidentity')]
    operations = [
        migrations.AddField(model_name='problem', name='cms_task_name', field=models.CharField(blank=True,default='',max_length=100,verbose_name='CMS task name')),
        migrations.AddField(model_name='submission', name='cms_claim_key', field=models.CharField(blank=True,default='',max_length=64)),
        migrations.AddField(model_name='submission', name='cms_submission_id', field=models.CharField(blank=True,default='',max_length=128)),
        migrations.AddField(model_name='submission', name='cms_attempts', field=models.PositiveSmallIntegerField(default=0)),
    ]
