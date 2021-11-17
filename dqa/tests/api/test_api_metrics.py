
import json

from django.test import TestCase
from django.urls import reverse
from rest_framework.authtoken.models import Token
from django.contrib.auth.models import User
from rest_framework.test import APIClient


class Testmetrics(TestCase):

    databases = ['metrics', 'metricsold', 'default']

    @classmethod
    def setUpClass(cls):
        super(Testmetrics, cls).setUpClass()

    def test_no_command(self):
        url = reverse('oldmetrics')
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, 200)
        response_reference = b'Error: No command string'
        self.assertEqual(response_reference, resp.content, msg='no command did not match')

    def test_no_parameters(self):
        url = reverse('oldmetrics') + '?cmd=metrics&param='
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, 200)
        response_reference = b'No parameters provided\n'
        self.assertEqual(response_reference, resp.content, msg='no parameter did not match')

    @staticmethod
    def create_token():
        """ Generate an authorization token to test protected API paths """
        test_user = User.objects.create_user(username='testuser1', password='123456')
        token_object = Token.objects.create(user=test_user)
        return token_object.key

    def test_metrics(self):
        output = {"model": "metric", "count": 3, "data": [{"id": 2, "name": "AvailabilityMetric", "display_name": "Availability", "description_short": "Returns a percentage of expected samples in the trace", "description_long": "For a sensors sample rate and the length of a full day, this metric compares the number of points gotten from the data archive with the expected number of samples it should have. This is returned as a percentage; if we have 1 point when we expected 2, this would be a 50% availability result.", "compute_type": "AVG_CH"}, {"id": 3, "name": "GapCountMetric", "display_name": "Gap Count", "description_short": "Returns the number of gaps found between data records for a sensors full-day trace.", "description_long": "This metric compares the start and end times of consecutive data records from a seed file for a sensors full-day data. If these records are more than a sample apart in time, then that is counted as a gap. The total number of gaps found is reported. Some metrics require a gapless trace, so if this value is positive, other metrics will have an empty result.", "compute_type": "VALUE_CO"}, {"id": 4, "name": "TimingQualityMetric", "display_name": "Timing Quality", "description_short": "Returns the average of the blockette 1001 timing records for the day", "description_long": "This metric takes the timing records for each blockette 1001 from a days SEED data and returns the average of these values.", "compute_type": "AVG_CH"}]}
        url = reverse('metrics')
        # POST requires auth
        apiclient = APIClient()
        post_resp = apiclient.post(url, data=output, format='json')
        self.assertEqual(post_resp.status_code, 401)
        apiclient.credentials(HTTP_AUTHORIZATION='Token ' + self.create_token())
        post_resp = apiclient.post(url, data=output, format='json')
        self.assertEqual(post_resp.status_code, 200)
        self.assertEqual({'status': 'ok', 'message': 'Metrics loaded'}, json.loads(post_resp.content.decode()), msg="metrics did not load")
        # GET does not require auth
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, 200)
        response_reference = b'{"metrics":{"data":[{"id":2,"name":"AvailabilityMetric","display_name":"Availability","description_short":"Returns a percentage of expected samples in the trace","description_long":"For a sensors sample rate and the length of a full day, this metric compares the number of points gotten from the data archive with the expected number of samples it should have. This is returned as a percentage; if we have 1 point when we expected 2, this would be a 50% availability result.","compute_type":"AVG_CH","parent":null},{"id":3,"name":"GapCountMetric","display_name":"Gap Count","description_short":"Returns the number of gaps found between data records for a sensors full-day trace.","description_long":"This metric compares the start and end times of consecutive data records from a seed file for a sensors full-day data. If these records are more than a sample apart in time, then that is counted as a gap. The total number of gaps found is reported. Some metrics require a gapless trace, so if this value is positive, other metrics will have an empty result.","compute_type":"VALUE_CO","parent":null},{"id":4,"name":"TimingQualityMetric","display_name":"Timing Quality","description_short":"Returns the average of the blockette 1001 timing records for the day","description_long":"This metric takes the timing records for each blockette 1001 from a days SEED data and returns the average of these values.","compute_type":"AVG_CH","parent":null}],"count":3}}'
        self.assertEqual(response_reference, resp.content, msg='metrics did not read')

    def test_dates(self):
        url = reverse('oldmetrics') + '?cmd=dates'
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, 200)
        response_reference = b'DE,2020-01-06\nDS,2020-01-05'
        self.assertEqual(response_reference, resp.content, msg='date command did not match')

    def test_groups(self):
        url = reverse('oldmetrics') + '?cmd=groups'
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, 200)
        response_reference = b'G,649,IU,1\nG,650,US,1\n\nT,1,Network Code,649,650\n'
        self.assertEqual(response_reference, resp.content, msg='group command did not match')

    def test_groups_stations(self):
        url = reverse('oldmetrics') + '?cmd=groups_stations'
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, 200)
        response_reference = b'G,649,IU,1\nG,650,US,1\n\nT,1,Network Code,649,650\n\nS,146,650,WVOR,650\nS,147,650,WMOK,650\nS,161,649,ANMO,649\nS,165,649,FURI,649\n'
        self.assertEqual(response_reference, resp.content, msg='station command did not match')

    def test_all(self):
        url = reverse('oldmetrics') + '?cmd=dates_metrics_groups_stations'
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, 200)
        response_reference = b'DE,2020-01-06\nDS,2020-01-05\n\nG,649,IU,1\nG,650,US,1\n\nT,1,Network Code,649,650\n\nS,146,650,WVOR,650\nS,147,650,WMOK,650\nS,161,649,ANMO,649\nS,165,649,FURI,649\n'
        self.assertEqual(response_reference, resp.content, msg='station command did not match')

    def test_stationgrid_parameter(self):
        url = reverse('oldmetrics') + '?cmd=stationgrid&param=station.146_metric.3_dates.2020-01-06.2020-01-07'
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, 200)
        response_reference = b'146,1,84.92046370967742'
        self.assertEqual(response_reference, resp.content, msg='stationgrid parameter did not match')

    def test_stationplot_parameter(self):
        url = reverse('oldmetrics') + '?cmd=stationplot&param=station.146_metric.3_dates.2020-01-06.2020-01-07'
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, 200)
        response_reference = b'2020-01-06,1.0000'
        self.assertEqual(response_reference, resp.content, msg='stationplot parameter did not match')

    def test_channelgrid_parameter(self):
        url = reverse(
            'oldmetrics') + '?cmd=channelgrid&param=channel.3357_station.146_metric.3_dates.2020-01-06.2020-01-07'
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, 200)
        response_reference = b'3357,1,84.92046370967742'
        self.assertEqual(response_reference, resp.content, msg='channelgrid parameter did not match')

    def test_channelplot_parameter(self):
        url = reverse(
            'oldmetrics') + '?cmd=channelplot&param=channel.3357_station.146_metric.4_dates.2020-01-06.2020-01-07'
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, 200)
        response_reference = b'2020-01-06,99.9362'
        self.assertEqual(response_reference, resp.content, msg='channelgrid parameter did not match')

    def test_channel_parameter(self):
        url = reverse('oldmetrics') + '?cmd=channels&param=station.146'
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, 200)
        response_reference = b'C,3353,LNZ,20,146\nC,3354,VMW,00,146\nC,3355,BH2,00,146\nC,3356,VMV,00,146\nC,3357,BH1,00,146\nC,3358,VMU,00,146\nC,3359,LH2,00,146\nC,3360,LH1,00,146\nC,3361,BHZ,00,146\nC,3362,VH2,00,146\nC,3363,VH1,00,146\nC,3364,LHZ,00,146\nC,3365,VHZ,00,146\nC,3366,LN2,20,146\nC,3367,LN1,20,146'
        self.assertEqual(response_reference, resp.content, msg='channels parameter did not match')

