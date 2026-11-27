from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [('catalog', '0014_profile_appearance')]
    operations = [migrations.AddField(
        model_name='submission', name='language',
        field=models.CharField(max_length=12, default='python', choices=[
            ('python', 'Python 3'), ('c', 'C (C17)'), ('cpp', 'C++ (C++17)'),
            ('java', 'Java 21'), ('javascript', 'JavaScript (Node.js 22)')]),
    )]
