from django.db import migrations, models

class Migration(migrations.Migration):
    dependencies = [('catalog', '0016_submission_showcase')]
    operations = [
        migrations.CreateModel(name='JudgeWorkerState', fields=[
            ('engine', models.CharField(max_length=20, primary_key=True, serialize=False)),
            ('last_seen', models.DateTimeField()),
            ('languages', models.JSONField(default=list, blank=True)),
        ]),
        migrations.AddIndex(model_name='submission', index=models.Index(fields=['status','language','id'], name='mr_sub_queue_idx')),
        migrations.AddIndex(model_name='submission', index=models.Index(fields=['status','updated_at'], name='mr_sub_lease_idx')),
        migrations.AddIndex(model_name='submission', index=models.Index(fields=['user','status','problem'], name='mr_sub_user_solved_idx')),
        migrations.AddIndex(model_name='submission', index=models.Index(fields=['user','created_at'], name='mr_sub_user_time_idx')),
        migrations.AddIndex(model_name='accesstoken', index=models.Index(fields=['created_at'], name='mr_token_expiry_idx')),
        migrations.AddIndex(model_name='auththrottle', index=models.Index(fields=['started_at'], name='mr_throttle_expiry_idx')),
    ]
