
from django.db import models


class Scan(models.Model):

    id = models.BigAutoField(primary_key=True)
    parent = models.ForeignKey('Scan', on_delete=models.DO_NOTHING)
    last_updated = models.DateTimeField('Last Update', auto_now=True)
    metric_filter = models.TextField('Metric Filter')
    network_filter = models.TextField('Network Filter')
    station_filter = models.TextField('Station Filter')
    location_filter = models.TextField('Location Filter')
    channel_filter = models.TextField('Channel Filter')
    start_date = models.DateField('Start Date')
    end_date = models.DateField('End Date')
    priority = models.IntegerField('Priority', default=10)
    delete_existing = models.BooleanField('Delete Exisiting', default=False)
    scheduled_run = models.DateField('Scheduled Run Date')
    finished = models.BooleanField('Scan Finished', default=False)
    taken = models.BooleanField('Scan Taken', default=False)

    class Meta:
        verbose_name = 'scan'
        verbose_name_plural = 'scans'


class ScanMessage(models.Model):

    id = models.BigAutoField(primary_key=True)
    scan = models.ForeignKey('Scan', on_delete=models.DO_NOTHING)
    network = models.CharField('Network', max_length=2)
    station = models.CharField('Station', max_length=10)
    location = models.CharField('Location', max_length=10)
    channel = models.CharField('Channel', max_length=10)
    metric = models.CharField('Metric', max_length=50)
    message = models.TextField('Message')
    timestamp = models.DateTimeField('Timestamp', auto_now=True)

    class Meta:
        verbose_name = 'scan message'
        verbose_name_plural = 'scan messages'


class ErrorLog(models.Model):

    error_time = models.DateTimeField('Error Time')
    error_message = models.TextField('Message')

    class Meta:
        verbose_name = 'error log'
        verbose_name_plural = 'error logs'


class Date(models.Model):

    date = models.DateField('Date', unique=True)

    class Meta:
        verbose_name = 'date'
        verbose_name_plural = 'dates'
        indexes = [models.Index(fields=['id', 'date'])]


class Custom(models.Model):

    user_id = models.CharField('User_id', max_length=40)
    columns = models.ManyToManyField('Metric')
