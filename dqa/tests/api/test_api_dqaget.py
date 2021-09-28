
from django.test import TestCase
from django.urls import reverse


class Testdqaget(TestCase):

    databases = ['metricsold', 'default']

    @classmethod
    def setUpClass(cls):
        super(Testdqaget, cls).setUpClass()

    def test_no_command(self):
        url = reverse('dqaget')
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, 200)
        response_reference = b'Error: No command string'
        self.assertEqual(response_reference, resp.content, msg='no command did not match')

    def test_networks_list(self):
        url = reverse('dqaget') + '?cmd=networks'
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, 200)
        response_reference = b'IU\nUS'
        self.assertEqual(response_reference, resp.content, msg='networks list did not match')

    def test_metrics_list(self):
        url = reverse('dqaget') + '?cmd=metrics'
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, 200)
        response_reference = b'ALNMDeviationMetric:18-22\nALNMDeviationMetric:4-8\nAvailabilityMetric\nCoherencePBM:18-22\nCoherencePBM:200-500\nCoherencePBM:4-8\nCoherencePBM:90-110\nDeadChannelMetric:4-8\nDifferencePBM:18-22\nDifferencePBM:200-500\nDifferencePBM:4-8\nDifferencePBM:90-110\nEventComparePWaveOrientation\nEventCompareStrongMotion\nEventCompareSynthetic\nGapCountMetric\nInfrasoundMetric\nMassPositionMetric\nNLNMDeviationMetric:0.125-0.25\nNLNMDeviationMetric:0.5-1\nNLNMDeviationMetric:18-22\nNLNMDeviationMetric:200-500\nNLNMDeviationMetric:4-8\nNLNMDeviationMetric:90-110\nPressureMetric\nStationDeviationMetric:18-22\nStationDeviationMetric:200-500\nStationDeviationMetric:4-8\nStationDeviationMetric:90-110\nTimingQualityMetric\nVacuumMonitorMetric'
        self.assertEqual(response_reference, resp.content, msg='metrics list did not match')

    def test_stations_list(self):
        url = reverse('dqaget') + '?cmd=stations'
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, 200)
        response_reference = b'ANMO\nFURI\nWMOK\nWVOR'
        self.assertEqual(response_reference, resp.content, msg='stations list did not match')

    def test_metric_values_default(self):
        url = reverse('dqaget') + '?cmd=data&network=IU&station=ANMO&location=00&channel=BHZ&metric=%25&sdate=2020-01-06&edate=2020-01-07'
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, 200)
        response_reference = b'2020-01-06  IU   ANMO  00  BHZ       GapCountMetric 0.000000\n2020-01-06  IU   ANMO  00  BHZ NLNMDeviationMetric:0.125-0.25 8.396555\n2020-01-06  IU   ANMO  00  BHZ NLNMDeviationMetric:0.5-1 10.922241\n2020-01-06  IU   ANMO  00  BHZ  TimingQualityMetric 99.891102\n2020-01-06  IU   ANMO  00  BHZ   AvailabilityMetric 99.999971\n'
        self.assertEqual(response_reference, resp.content, msg='metric values did not match')

    def test_metric_values_single_metric(self):
        url = reverse('dqaget') + '?cmd=data&network=IU&station=ANMO&location=00&channel=BHZ&metric=TimingQualityMetric&sdate=2020-01-06&edate=2020-01-07'
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, 200)
        metric_values = b'2020-01-06  IU   ANMO  00  BHZ  TimingQualityMetric 99.891102\n'
        self.assertEqual(metric_values, resp.content, msg='single metric values did not match')

    def test_metric_values_bad_network(self):
        url = reverse('dqaget') + '?cmd=data&network=II&station=ANMO&location=00&channel=BHZ&metric=%25&sdate=2020-01-06&edate=2020-01-07'
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, 200)
        metric_values = b"Error: Database Query did not return data for these parameters: {'cmd': 'data', 'network': 'II', 'station': 'ANMO', 'location': '00', 'channel': 'BHZ', 'metric': '%', 'sdate': '2020-01-06', 'edate': '2020-01-07'}"
        self.assertEqual(metric_values, resp.content, msg='bad network metric values did not match')

    def test_metric_values_bad_dates(self):
        url = reverse('dqaget') + '?cmd=data&network=IU&station=ANMO&location=00&channel=BHZ&metric=%25&sdate=2019-01-06&edate=2019-01-07'
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, 200)
        metric_values = b"Error: Database Query did not return data for these parameters: {'cmd': 'data', 'network': 'IU', 'station': 'ANMO', 'location': '00', 'channel': 'BHZ', 'metric': '%', 'sdate': '2019-01-06', 'edate': '2019-01-07'}"
        self.assertEqual(metric_values, resp.content, msg='bad dates metric values did not match')

    def test_metric_values_json(self):
        url = reverse('dqaget') + '?cmd=data&network=US&station=WVOR&location=00&channel=BHZ&metric=%25&sdate=2020-01-06&edate=2020-01-07&format=json'
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, 200)
        json_metric_values = b'{"records": [{"date": "2020-01-06", "network": "US", "station": "WVOR", "location": "00", "channel": "BHZ", "metric": "GapCountMetric", "value": 0.0}, {"date": "2020-01-06", "network": "US", "station": "WVOR", "location": "00", "channel": "BHZ", "metric": "NLNMDeviationMetric:0.5-1", "value": 15.604805547392974}, {"date": "2020-01-06", "network": "US", "station": "WVOR", "location": "00", "channel": "BHZ", "metric": "NLNMDeviationMetric:0.125-0.25", "value": 18.4937139932448}, {"date": "2020-01-06", "network": "US", "station": "WVOR", "location": "00", "channel": "BHZ", "metric": "TimingQualityMetric", "value": 99.93748944078392}, {"date": "2020-01-06", "network": "US", "station": "WVOR", "location": "00", "channel": "BHZ", "metric": "AvailabilityMetric", "value": 99.99997106482319}], "count": 5}'
        self.assertEqual(json_metric_values, resp.content, msg='json metric values did not match')

    def test_metric_values_csv(self):
        url = reverse('dqaget') + '?cmd=data&network=US&station=WVOR&location=00&channel=BHZ&metric=%25&sdate=2020-01-06&edate=2020-01-07&format=csv'
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, 200)
        response_reference = b'2020-01-06, US, WVOR, 00, BHZ, GapCountMetric, 0.0\n2020-01-06, US, WVOR, 00, BHZ, NLNMDeviationMetric:0.5-1, 15.604805547392974\n2020-01-06, US, WVOR, 00, BHZ, NLNMDeviationMetric:0.125-0.25, 18.4937139932448\n2020-01-06, US, WVOR, 00, BHZ, TimingQualityMetric, 99.93748944078392\n2020-01-06, US, WVOR, 00, BHZ, AvailabilityMetric, 99.99997106482319'
        self.assertEqual(response_reference, resp.content, msg='csv metric values did not match')

    def test_metric_values_hash_json(self):
        url = reverse('dqaget') + '?cmd=hash&network=US&station=WVOR&location=00&channel=BHZ&metric=%25&sdate=2020-01-06&edate=2020-01-07&format=json'
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, 200)
        response_reference = b'{"records": [{"date": "2020-01-06", "network": "US", "station": "WVOR", "location": "00", "channel": "BHZ", "metric": "GapCountMetric", "value": 0.0, "hash": "2ce7836d887be0772cb96f9287f5306b"}, {"date": "2020-01-06", "network": "US", "station": "WVOR", "location": "00", "channel": "BHZ", "metric": "NLNMDeviationMetric:0.5-1", "value": 15.604805547392974, "hash": "2ce7836d887be0772cb96f9287f5306b"}, {"date": "2020-01-06", "network": "US", "station": "WVOR", "location": "00", "channel": "BHZ", "metric": "NLNMDeviationMetric:0.125-0.25", "value": 18.4937139932448, "hash": "2ce7836d887be0772cb96f9287f5306b"}, {"date": "2020-01-06", "network": "US", "station": "WVOR", "location": "00", "channel": "BHZ", "metric": "TimingQualityMetric", "value": 99.93748944078392, "hash": "2ce7836d887be0772cb96f9287f5306b"}, {"date": "2020-01-06", "network": "US", "station": "WVOR", "location": "00", "channel": "BHZ", "metric": "AvailabilityMetric", "value": 99.99997106482319, "hash": "2ce7836d887be0772cb96f9287f5306b"}], "count": 5}'
        self.assertEqual(response_reference, resp.content, msg='hash metric values did not match')

    def test_metric_values_md5(self):
        url = reverse('dqaget') + '?cmd=md5&network=US&station=WVOR&location=00&channel=BHZ&metric=%25&sdate=2020-01-06&edate=2020-01-07'
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, 200)
        response_reference = b'2020-01-06 57c9dab3b71edb1470fde1b9718d6da8\n'
        self.assertEqual(response_reference, resp.content, msg='md5 metric values did not match')

    def test_metric_values_julian_date(self):
        url = reverse('dqaget') + '?cmd=data&network=US&station=WVOR&location=00&channel=BHZ&metric=NLNMDeviationMetric:0.5-1&sdate=2020-01-06&edate=2020-01-07&format=json&julian=true'
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, 200)
        response_reference = b'{"records": [{"date": "2020-006", "network": "US", "station": "WVOR", "location": "00", "channel": "BHZ", "metric": "NLNMDeviationMetric:0.5-1", "value": 15.604805547392974}], "count": 1}'
        self.assertEqual(response_reference, resp.content, msg='julian date metric values did not match')

    def test_metric_values_multiple_channels(self):
        url = reverse('dqaget') + '?cmd=data&network=US&station=WVOR&metric=NLNMDeviationMetric:0.5-1&sdate=2020-01-06&edate=2020-01-07&format=json&julian=true'
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, 200)
        response_reference = b'{"records": [{"date": "2020-006", "network": "US", "station": "WVOR", "location": "00", "channel": "BH1", "metric": "NLNMDeviationMetric:0.5-1", "value": 15.665083611347193}, {"date": "2020-006", "network": "US", "station": "WVOR", "location": "00", "channel": "BH2", "metric": "NLNMDeviationMetric:0.5-1", "value": 14.276040377107257}, {"date": "2020-006", "network": "US", "station": "WVOR", "location": "00", "channel": "BHZ", "metric": "NLNMDeviationMetric:0.5-1", "value": 15.604805547392974}], "count": 3}'
        self.assertEqual(response_reference, resp.content, msg='multiple channels metric values did not match')

    def test_metric_values_multiple_stations(self):
        url = reverse('dqaget') + '?cmd=data&network=US&metric=GapCountMetric&sdate=2020-01-06&edate=2020-01-07&format=json&julian=true'
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, 200)
        response_reference = b'{"records": [{"date": "2020-006", "network": "US", "station": "WMOK", "location": "00", "channel": "BH1", "metric": "GapCountMetric", "value": 0.0}, {"date": "2020-006", "network": "US", "station": "WMOK", "location": "00", "channel": "BH2", "metric": "GapCountMetric", "value": 0.0}, {"date": "2020-006", "network": "US", "station": "WMOK", "location": "00", "channel": "BHZ", "metric": "GapCountMetric", "value": 0.0}, {"date": "2020-006", "network": "US", "station": "WMOK", "location": "00", "channel": "LH1", "metric": "GapCountMetric", "value": 1.0}, {"date": "2020-006", "network": "US", "station": "WMOK", "location": "00", "channel": "LH2", "metric": "GapCountMetric", "value": 1.0}, {"date": "2020-006", "network": "US", "station": "WMOK", "location": "00", "channel": "LHZ", "metric": "GapCountMetric", "value": 1.0}, {"date": "2020-006", "network": "US", "station": "WMOK", "location": "00", "channel": "VH1", "metric": "GapCountMetric", "value": 0.0}, {"date": "2020-006", "network": "US", "station": "WMOK", "location": "00", "channel": "VH2", "metric": "GapCountMetric", "value": 1.0}, {"date": "2020-006", "network": "US", "station": "WMOK", "location": "00", "channel": "VHZ", "metric": "GapCountMetric", "value": 0.0}, {"date": "2020-006", "network": "US", "station": "WMOK", "location": "00", "channel": "VMU", "metric": "GapCountMetric", "value": 0.0}, {"date": "2020-006", "network": "US", "station": "WMOK", "location": "00", "channel": "VMV", "metric": "GapCountMetric", "value": 0.0}, {"date": "2020-006", "network": "US", "station": "WMOK", "location": "00", "channel": "VMW", "metric": "GapCountMetric", "value": 0.0}, {"date": "2020-006", "network": "US", "station": "WMOK", "location": "10", "channel": "BH1", "metric": "GapCountMetric", "value": 0.0}, {"date": "2020-006", "network": "US", "station": "WMOK", "location": "10", "channel": "BH2", "metric": "GapCountMetric", "value": 0.0}, {"date": "2020-006", "network": "US", "station": "WMOK", "location": "10", "channel": "BHZ", "metric": "GapCountMetric", "value": 1.0}, {"date": "2020-006", "network": "US", "station": "WMOK", "location": "10", "channel": "LH1", "metric": "GapCountMetric", "value": 0.0}, {"date": "2020-006", "network": "US", "station": "WMOK", "location": "10", "channel": "LH2", "metric": "GapCountMetric", "value": 0.0}, {"date": "2020-006", "network": "US", "station": "WMOK", "location": "10", "channel": "LHZ", "metric": "GapCountMetric", "value": 0.0}, {"date": "2020-006", "network": "US", "station": "WMOK", "location": "10", "channel": "VH1", "metric": "GapCountMetric", "value": 0.0}, {"date": "2020-006", "network": "US", "station": "WMOK", "location": "10", "channel": "VH2", "metric": "GapCountMetric", "value": 1.0}, {"date": "2020-006", "network": "US", "station": "WMOK", "location": "10", "channel": "VHZ", "metric": "GapCountMetric", "value": 0.0}, {"date": "2020-006", "network": "US", "station": "WMOK", "location": "10", "channel": "VMU", "metric": "GapCountMetric", "value": 0.0}, {"date": "2020-006", "network": "US", "station": "WMOK", "location": "10", "channel": "VMV", "metric": "GapCountMetric", "value": 0.0}, {"date": "2020-006", "network": "US", "station": "WMOK", "location": "10", "channel": "VMW", "metric": "GapCountMetric", "value": 0.0}, {"date": "2020-006", "network": "US", "station": "WMOK", "location": "20", "channel": "LN1", "metric": "GapCountMetric", "value": 0.0}, {"date": "2020-006", "network": "US", "station": "WMOK", "location": "20", "channel": "LN2", "metric": "GapCountMetric", "value": 0.0}, {"date": "2020-006", "network": "US", "station": "WMOK", "location": "20", "channel": "LNZ", "metric": "GapCountMetric", "value": 0.0}, {"date": "2020-006", "network": "US", "station": "WMOK", "location": "30", "channel": "LDO", "metric": "GapCountMetric", "value": 0.0}, {"date": "2020-006", "network": "US", "station": "WVOR", "location": "00", "channel": "BH1", "metric": "GapCountMetric", "value": 1.0}, {"date": "2020-006", "network": "US", "station": "WVOR", "location": "00", "channel": "BH2", "metric": "GapCountMetric", "value": 0.0}, {"date": "2020-006", "network": "US", "station": "WVOR", "location": "00", "channel": "BHZ", "metric": "GapCountMetric", "value": 0.0}, {"date": "2020-006", "network": "US", "station": "WVOR", "location": "00", "channel": "LH1", "metric": "GapCountMetric", "value": 0.0}, {"date": "2020-006", "network": "US", "station": "WVOR", "location": "00", "channel": "LH2", "metric": "GapCountMetric", "value": 0.0}, {"date": "2020-006", "network": "US", "station": "WVOR", "location": "00", "channel": "LHZ", "metric": "GapCountMetric", "value": 0.0}, {"date": "2020-006", "network": "US", "station": "WVOR", "location": "00", "channel": "VH1", "metric": "GapCountMetric", "value": 0.0}, {"date": "2020-006", "network": "US", "station": "WVOR", "location": "00", "channel": "VH2", "metric": "GapCountMetric", "value": 0.0}, {"date": "2020-006", "network": "US", "station": "WVOR", "location": "00", "channel": "VHZ", "metric": "GapCountMetric", "value": 0.0}, {"date": "2020-006", "network": "US", "station": "WVOR", "location": "00", "channel": "VMU", "metric": "GapCountMetric", "value": 0.0}, {"date": "2020-006", "network": "US", "station": "WVOR", "location": "00", "channel": "VMV", "metric": "GapCountMetric", "value": 0.0}, {"date": "2020-006", "network": "US", "station": "WVOR", "location": "00", "channel": "VMW", "metric": "GapCountMetric", "value": 0.0}, {"date": "2020-006", "network": "US", "station": "WVOR", "location": "20", "channel": "LN1", "metric": "GapCountMetric", "value": 0.0}, {"date": "2020-006", "network": "US", "station": "WVOR", "location": "20", "channel": "LN2", "metric": "GapCountMetric", "value": 0.0}, {"date": "2020-006", "network": "US", "station": "WVOR", "location": "20", "channel": "LNZ", "metric": "GapCountMetric", "value": 0.0}], "count": 43}'
        self.assertEqual(response_reference, resp.content, msg='multiple stations metric values did not match')
