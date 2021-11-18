
from urllib import request
import json

from django.core.management import BaseCommand
from django.db import connections
from django.conf import settings

from metrics.models import Metric


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

        print('Start')

        base_write_url = settings.API_BASE_URL
        authorization_token = settings.API_AUTHORIZATION_TOKEN

        compute_type = {}
        metrics = []
        base_metrics = set()
        with connections['metricsold'].cursor() as cursor:
            sql = "SELECT * from tblcomputetype"
            cursor.execute(sql)
            for ct in cursor.fetchall():
                # print(ct)
                compute_type[ct[0]] = ct[1]

            sql = "SELECT pkmetricid,name,fkparentmetricid,fkcomputetypeid,displayname,descriptionshort,descriptionlong from tblmetric"
            cursor.execute(sql)
            for metric in cursor.fetchall():
                print(metric)
                metrics.append(metric)
                base_metrics.add(
                    (metric[0], metric[1], metric[2], compute_type[metric[3]], metric[4], metric[5], metric[6]))

        print(f'Read {len(base_metrics)} metrics from DB')

        print('Loading new DB')
        req = request.Request(base_write_url, method="POST",
                              headers={'Authorization': f'Token {authorization_token}', 'User-Agent': 'XYZ/3.0',
                                       'Content-Type': 'application/json'})
        metrics_output = []
        for values in metrics:
            metrics_output.append(
                {'id': values[0], 'name': values[1], 'display_name': values[4], 'description_short': values[5],
                 'description_long': values[6], 'compute_type': compute_type[values[3]]})
        output = {'model': 'metric', 'count': len(metrics_output), 'data': metrics_output}
        data_json = json.dumps(output)
        r = request.urlopen(req, data=data_json.encode())
        content = json.loads(r.read().decode('utf-8'))
        if 'status' not in content or content['status'] != 'ok':
            print(f'Error in pushing data to api: {content}')

        test_metrics = set()
        for metric_object in Metric.objects.all():
            test_metrics.add((metric_object.pk, metric_object.name, metric_object.parent,
                              metric_object.compute_type.name, metric_object.display_name,
                              metric_object.description_short, metric_object.description_long))

        print(f'Read {len(test_metrics)} metrics from new DB')

        delta = test_metrics.symmetric_difference(base_metrics)
        if delta:
            print('**** Mismatch ****')
            print(delta)
        else:
            print('Verified OK')

        print('Done')
