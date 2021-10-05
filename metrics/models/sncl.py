
from django.db import models


class Channel(models.Model):

    sensor = models.ForeignKey('Sensor', on_delete=models.DO_NOTHING)
    name = models.CharField('Name', max_length=16)
    derived = models.IntegerField('Derived', default=0)
    is_ignored = models.BooleanField('Is Ignored', default=False)

    def __str__(self):
        return f'{self.name}'

    class Meta:
        verbose_name = 'channel'
        verbose_name_plural = 'channels'
        indexes = [models.Index(fields=['id', 'sensor', 'is_ignored'])]


class Sensor(models.Model):

    station = models.ForeignKey('Station', on_delete=models.DO_NOTHING)
    location = models.CharField('Location', max_length=16)

    def __str__(self):
        return f'{self.station}:{self.location}'

    class Meta:
        verbose_name = 'sensor'
        verbose_name_plural = 'sensors'
        unique_together = ('station', 'location',)
        indexes = [models.Index(fields=['id', 'station'])]


class Station(models.Model):

    name = models.CharField('Name', max_length=16)
    network = models.ForeignKey('Group', related_name='station_network', on_delete=models.DO_NOTHING)
    groups = models.ManyToManyField('Group')

    def __str__(self):
        return f'{self.name}'

    class Meta:
        verbose_name = 'station'
        verbose_name_plural = 'stations'
        unique_together = ['name', 'network']


class GroupType(models.Model):

    name = models.CharField('Name', max_length=16, unique=True)

    def __str__(self):
        return self.name

    class Meta:
        verbose_name = 'group type'
        verbose_name_plural = 'group types'


class Group(models.Model):

    name = models.CharField('Name', max_length=36, unique=True)
    is_ignored = models.BooleanField('Is Ignored', default=False)
    group_type = models.ForeignKey('GroupType', null=True, on_delete=models.DO_NOTHING)

    def __str__(self):
        return self.name

    class Meta:
        verbose_name = 'group'
        verbose_name_plural = 'groups'
        unique_together = ('group_type', 'name')
