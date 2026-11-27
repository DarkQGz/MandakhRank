from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    dependencies = [('catalog', '0018_automatic_contests')]
    operations = [
        migrations.CreateModel(name='Announcement', fields=[
            ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
            ('title', models.CharField(max_length=120)),
            ('body', models.TextField(max_length=2000)),
            ('created_at', models.DateTimeField(auto_now_add=True, db_index=True)),
            ('withdrawn', models.BooleanField(default=False)),
            ('author', models.ForeignKey(null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='mr_announcements', to='auth.user')),
            ('classroom', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.CASCADE, related_name='announcements', to='catalog.classroom')),
        ], options={'ordering': ['-created_at', '-pk'], 'indexes': [models.Index(fields=['author', 'created_at'], name='mr_announce_author_idx')]}),
        migrations.CreateModel(name='NotificationRead', fields=[
            ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
            ('event_key', models.CharField(max_length=96)),
            ('event_at', models.DateTimeField()),
            ('user', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='mr_notification_reads', to='auth.user')),
        ], options={'constraints': [models.UniqueConstraint(fields=['user', 'event_key'], name='mr_notice_read_unique')], 'indexes': [models.Index(fields=['user', 'event_at'], name='mr_notice_read_age_idx')]}),
    ]
