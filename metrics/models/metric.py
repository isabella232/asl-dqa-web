
from django.db import models


class MetricData(models.Model):
    id = models.BigAutoField(primary_key=True)
    channel = models.ForeignKey('Channel', on_delete=models.DO_NOTHING)
    date = models.DateField('Date')
    metric = models.ForeignKey('Metric', on_delete=models.DO_NOTHING)
    value = models.FloatField('Value')
    hash = models.ForeignKey('Hash', on_delete=models.DO_NOTHING)

    def __str__(self):
        return f'{self.channel}:{self.metric}'

    class Meta:
        verbose_name = 'metric data'
        verbose_name_plural = 'metric data'
        indexes = [models.Index(fields=['date', 'channel']),
                   models.Index(fields=['metric', 'date', 'channel', 'value'])]


class Metric(models.Model):

    name = models.CharField('Name', max_length=64, unique=True)
    parent = models.ForeignKey('Metric', null=True, on_delete=models.DO_NOTHING)
    compute_type = models.ForeignKey('ComputeType', on_delete=models.DO_NOTHING)
    display_name = models.CharField('Display Name', max_length=64, blank=True)
    description_short = models.CharField("Short Description", max_length=128, blank=True)
    description_long = models.TextField("Long Description", blank=True)

    def __str__(self):
        return f'{self.name}'

    class Meta:
        verbose_name = 'metric'
        verbose_name_plural = 'metrics'


class ComputeType(models.Model):

    name = models.CharField('Name', max_length=8, unique=True)
    description = models.TextField('Description', blank=True)
    is_calibration = models.BooleanField('Is Calibration', default=False)

    def __str__(self):
        return f'{self.name}'

    class Meta:
        verbose_name = 'compute type'
        verbose_name_plural = 'compute types'


class Hash(models.Model):

    hash = models.BinaryField('Hash', unique=True)

    class Meta:
        verbose_name = 'hash'
        verbose_name_plural = 'hashes'
        indexes = [models.Index(fields=['id', 'hash'])]
