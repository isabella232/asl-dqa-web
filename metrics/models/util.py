
from django.db import models


class Scan(models.Model):
    """
    Scan table
    This table stores the scan parameters for seedscan to use in performing scans
    crons inject the nightly and monthly scans
    """

    id = models.BigAutoField(primary_key=True)
    parent = models.ForeignKey('Scan', on_delete=models.DO_NOTHING, help_text="None indicates root level, otherwise points to parent scan")
    last_updated = models.DateTimeField('Last Update', auto_now=True, help_text="Last time this scan was modified")
    metric_filter = models.TextField('Metric Filter', help_text="Limit scan to this metric")
    network_filter = models.TextField('Network Filter', help_text="Limit scan to this network")
    station_filter = models.TextField('Station Filter', help_text="Limit scan to this station")
    location_filter = models.TextField('Location Filter', help_text="Limit scan to this location")
    channel_filter = models.TextField('Channel Filter', help_text="Limit scan to this channel")
    start_date = models.DateField('Start Date', help_text="Scan starting at this date")
    end_date = models.DateField('End Date', help_text="Scan ends on this date")
    priority = models.IntegerField('Priority', default=10, help_text="Scan priority, 100 highest. 0 forget it")
    delete_existing = models.BooleanField('Delete Exisiting', default=False, help_text="Flag to delete existing scan data as you scan")
    scheduled_run = models.DateField('Scheduled Run Date', help_text="Run scan in the future after this date")
    finished = models.BooleanField('Scan Finished', default=False, help_text="Scan of this entry is finished")
    taken = models.BooleanField('Scan Taken', default=False, help_text="Scan of this entry is in progress, scan engine uses multi-threading")

    class Meta:
        verbose_name = 'scan'
        verbose_name_plural = 'scans'


class ScanMessage(models.Model):
    """
    Messages attached to a scan, usually an error
    """
    id = models.BigAutoField(primary_key=True)
    scan = models.ForeignKey('Scan', on_delete=models.DO_NOTHING, help_text="scan message applies to")
    network = models.CharField('Network', max_length=2, help_text="network")
    station = models.CharField('Station', max_length=10, help_text="station")
    location = models.CharField('Location', max_length=10, help_text="location")
    channel = models.CharField('Channel', max_length=10, help_text="channel")
    metric = models.CharField('Metric', max_length=50, help_text="metric")
    message = models.TextField('Message', help_text="Actual message")
    timestamp = models.DateTimeField('Timestamp', auto_now=True, help_text="Timestamp for message creation")

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
    columns = models.ManyToManyField('Metric', related_name='custom_columns')
    weights = models.ManyToManyField('Metric', related_name='custom_weight', through='CustomWeight')
    date_format = models.CharField('DateFormat', max_length=10, default='yy-mm-dd')


class CustomWeight(models.Model):

    custom = models.ForeignKey('Custom', on_delete=models.CASCADE)
    metric = models.ForeignKey('Metric', on_delete=models.CASCADE)
    weight = models.IntegerField('Weight')
