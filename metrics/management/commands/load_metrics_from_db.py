
from django.core.management import BaseCommand
from django.db import connections

from metrics.models import Metric, ComputeType


class Command(BaseCommand):
    help = """Load metrics table from old DB"""

    def handle(self, *args, **options):
        """
        Parameters
        ----------
        args

        Returns
        -------

        """

        print('Update Metrics table from previous DB')

        compute_type = {}
        metrics = []
        base_metrics = set()
        with connections['metricsold'].cursor() as cursor:
            sql = "SELECT * from tblcomputetype"
            cursor.execute(sql)
            for ct in cursor.fetchall():
                compute_type[ct[0]] = ct[1]

            sql = "SELECT pkmetricid,name,fkparentmetricid,fkcomputetypeid,displayname,descriptionshort,descriptionlong,unittype from tblmetric"
            cursor.execute(sql)
            for metric in cursor.fetchall():
                metrics.append(metric)
                base_metrics.add(
                    (metric[0], metric[1], metric[2], compute_type[metric[3]], metric[4], metric[5], metric[6], metric[7]))

        for values in metrics:
            m_object, _ = Metric.objects.get_or_create(id=values[0],
                                                       name=values[1],
                                                       display_name=values[4],
                                                       description_short=values[5],
                                                       description_long=values[6],
                                                       compute_type=ComputeType.objects.get(name=compute_type[values[3]]),
                                                       units=values[7]
                                                       )

        test_metrics = set()
        for metric_object in Metric.objects.all():
            test_metrics.add((metric_object.pk, metric_object.name, metric_object.parent,
                              metric_object.compute_type.name, metric_object.display_name,
                              metric_object.description_short, metric_object.description_long,
                              metric_object.units))

        delta = test_metrics.symmetric_difference(base_metrics)
        if delta:
            print(f'*** Error copying metrics: {delta}')
        else:
            print(f'Copied {len(test_metrics)} metrics: verified OK')
