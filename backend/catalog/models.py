from django.db import models
from django.core.exceptions import ValidationError
from django.utils import timezone

class Course(models.Model):
    title = models.CharField('Нэр', max_length=200)
    tag = models.CharField('Чиглэл', max_length=80)
    level = models.CharField('Түвшин', max_length=40, choices=[('Анхан шат','Анхан шат'),('Дунд шат','Дунд шат'),('Ахисан шат','Ахисан шат')])
    description = models.TextField('Тайлбар')
    color = models.CharField(max_length=20, default='blue', choices=[(c,c) for c in ['blue','purple','cyan','green']])
    published = models.BooleanField('Нийтлэх', default=False)
    class Meta:
        verbose_name='Сургалт'; verbose_name_plural='Сургалтууд'; ordering=['id']
    def __str__(self): return self.title

class Lesson(models.Model):
    course = models.ForeignKey(Course, on_delete=models.CASCADE, related_name='lessons')
    title = models.CharField('Гарчиг', max_length=200)
    position = models.PositiveIntegerField('Дараалал', default=1)
    content = models.TextField('Хичээлийн агуулга', blank=True)
    published = models.BooleanField('Нийтлэх', default=False)
    class Meta:
        ordering=['position','id']; verbose_name='Хичээл'; verbose_name_plural='Хичээлүүд'
    def __str__(self): return self.title

class Contest(models.Model):
    title = models.CharField('Нэр', max_length=200)
    description = models.TextField('Тайлбар', blank=True)
    announcement = models.TextField('Зарлал', blank=True)
    starts_at = models.DateTimeField('Эхлэх цаг')
    ends_at = models.DateTimeField('Дуусах цаг')
    published = models.BooleanField('Нийтлэх', default=False)
    class Meta:
        ordering=['-starts_at']; verbose_name='Тэмцээн'; verbose_name_plural='Тэмцээнүүд'
    def clean(self):
        if self.starts_at and self.ends_at and self.ends_at <= self.starts_at:
            raise ValidationError('Дуусах цаг эхлэх цагаас хойш байна.')
    @property
    def status(self):
        now=timezone.now()
        return 'Удахгүй' if now < self.starts_at else 'Явагдаж байна' if now < self.ends_at else 'Дууссан'
    def __str__(self): return self.title

class ContestProblem(models.Model):
    contest = models.ForeignKey(Contest, on_delete=models.CASCADE, related_name='problems')
    label = models.CharField('Дугаар (A, B...)', max_length=8)
    title = models.CharField('Нэр', max_length=200)
    statement = models.TextField('Нөхцөл')
    sample_input = models.TextField('Жишээ оролт', blank=True)
    sample_output = models.TextField('Жишээ гаралт', blank=True)
    points = models.PositiveIntegerField('Оноо', default=100)
    class Meta:
        ordering=['label']; verbose_name='Тэмцээний бодлого'; verbose_name_plural='Тэмцээний бодлогууд'
        constraints=[models.UniqueConstraint(fields=['contest','label'],name='unique_contest_label')]
    def __str__(self): return f'{self.contest}: {self.label}'

class ContestResult(models.Model):
    problem = models.ForeignKey(ContestProblem,on_delete=models.CASCADE,related_name='results')
    participant = models.CharField('Оролцогчийн username',max_length=80)
    score = models.PositiveIntegerField('Баталгаажуулсан оноо',default=0)
    penalty = models.PositiveIntegerField('Торгуулийн минут',default=0)
    class Meta:
        verbose_name='Баталгаажуулсан дүн'; verbose_name_plural='Баталгаажуулсан дүнгүүд'
        constraints=[models.UniqueConstraint(fields=['problem','participant'],name='unique_problem_participant')]
    def clean(self):
        if self.problem_id and self.score > self.problem.points:
            raise ValidationError('Оноо бодлогын дээд онооноос их байж болохгүй.')
    def __str__(self): return f'{self.participant}: {self.score}'

class Problem(models.Model):
    title=models.CharField('Нэр',max_length=200,unique=True)
    description=models.TextField('Нөхцөл')
    difficulty=models.CharField('Түвшин',max_length=30,default='Хялбар')
    topic=models.CharField('Сэдэв',max_length=60,default='Суурь')
    points=models.PositiveIntegerField('Оноо',default=10)
    sample_input=models.TextField('Жишээ оролт')
    sample_output=models.TextField('Жишээ гаралт')
    published=models.BooleanField('Нийтлэх',default=False)
    class Meta:
        ordering=['id'];verbose_name='Дасгал бодлого';verbose_name_plural='Дасгал бодлогууд'
    def __str__(self):return self.title

class TestCase(models.Model):
    problem=models.ForeignKey(Problem,on_delete=models.CASCADE,related_name='tests')
    stdin=models.TextField('Оролт',blank=True)
    expected=models.TextField('Хүлээгдэх гаралт',blank=True)
    class Meta:
        ordering=['id'];verbose_name='Нууц тест';verbose_name_plural='Нууц тестүүд'

class Submission(models.Model):
    user=models.ForeignKey('auth.User',on_delete=models.CASCADE)
    problem=models.ForeignKey(Problem,on_delete=models.PROTECT)
    code=models.TextField()
    status=models.CharField(max_length=40,default='Queued')
    passed=models.PositiveIntegerField(default=0)
    total=models.PositiveIntegerField(default=0)
    created_at=models.DateTimeField(auto_now_add=True)
    updated_at=models.DateTimeField(auto_now=True)
    # Snapshot ensures later CMS edits cannot change an already queued submission.
    test_snapshot=models.JSONField(default=list)
    class Meta: ordering=['-id']

class AccessToken(models.Model):
    key=models.CharField(max_length=64,primary_key=True)
    user=models.ForeignKey('auth.User',on_delete=models.CASCADE)
    created_at=models.DateTimeField(auto_now_add=True)

class EmailVerification(models.Model):
    user=models.OneToOneField('auth.User',on_delete=models.CASCADE)
    email=models.EmailField(unique=True)
    token_hash=models.CharField(max_length=64)
    created_at=models.DateTimeField(auto_now_add=True)
    verified=models.BooleanField(default=False)
