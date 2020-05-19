
from django.test import TestCase
from django.urls import reverse


class Testmetrics(TestCase):

    @classmethod
    def setUpClass(cls):
        super(Testmetrics, cls).setUpClass()

    def test_no_command(self):
        url = reverse('metrics')
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, 200)
        response_reference = b'Error: No command string'
        self.assertEqual(response_reference, resp.content, msg='no command did not match')

    def test_no_parameters(self):
        url = reverse('metrics') + '?cmd=metrics&param='
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, 200)
        response_reference = b'No parameters provided\nM,29,Event Compare Synthetic\nM,28,Event Compare Strong Motion\nM,27,Difference: 200-500\nM,26,Difference: 90-110\nM,25,Difference: 18-22\nM,24,Difference: 4-8\nM,23,Coherence: 200-500\nM,22,Station Deviation: 200-500\nM,21,Station Deviation: 90-110\nM,20,Station Deviation: 18-22\nM,19,Dead Channel: 4-8\nM,18,Station Deviation: 4-8\nM,17,Coherence: 90-110\nM,16,NLNM Deviation: 200-500\nM,15,NLNM Deviation: 90-110\nM,14,Coherence: 18-22\nM,13,NLNM Deviation: 18-22\nM,12,NLNM Deviation: 4-8\nM,11,Coherence: 4-8\nM,10,NLNM Deviation: 0.125-0.25\nM,9,NLNM Deviation: 0.5-1\nM,8,Vacuum Monitor\nM,7,ALNM Deviation: 18-22\nM,6,ALNM Deviation: 4-8\nM,5,Mass Position\nM,4,Timing Quality\nM,2,Availability\nM,3,Gap Count\nM,32,Pressure Metric\nM,30,Event Compare PWave Orientation\nM,31,Infrasound Metric'
        self.assertEqual(response_reference, resp.content, msg='no parameter did not match')

    def test_metrics(self):
        url = reverse('metrics') + '?cmd=metrics'
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, 200)
        response_reference = b'M,29,Event Compare Synthetic\nM,28,Event Compare Strong Motion\nM,27,Difference: 200-500\nM,26,Difference: 90-110\nM,25,Difference: 18-22\nM,24,Difference: 4-8\nM,23,Coherence: 200-500\nM,22,Station Deviation: 200-500\nM,21,Station Deviation: 90-110\nM,20,Station Deviation: 18-22\nM,19,Dead Channel: 4-8\nM,18,Station Deviation: 4-8\nM,17,Coherence: 90-110\nM,16,NLNM Deviation: 200-500\nM,15,NLNM Deviation: 90-110\nM,14,Coherence: 18-22\nM,13,NLNM Deviation: 18-22\nM,12,NLNM Deviation: 4-8\nM,11,Coherence: 4-8\nM,10,NLNM Deviation: 0.125-0.25\nM,9,NLNM Deviation: 0.5-1\nM,8,Vacuum Monitor\nM,7,ALNM Deviation: 18-22\nM,6,ALNM Deviation: 4-8\nM,5,Mass Position\nM,4,Timing Quality\nM,2,Availability\nM,3,Gap Count\nM,32,Pressure Metric\nM,30,Event Compare PWave Orientation\nM,31,Infrasound Metric'
        self.assertEqual(response_reference, resp.content, msg='metrics command did not match')

    def test_dates(self):
        url = reverse('metrics') + '?cmd=dates'
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, 200)
        response_reference = b'DE,2020-01-06\nDS,2020-01-05'
        self.assertEqual(response_reference, resp.content, msg='date command did not match')

    def test_groups(self):
        url = reverse('metrics') + '?cmd=groups'
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, 200)
        response_reference = b'G,649,IU,1\nG,650,US,1\n\nT,1,Network Code,649,650\n'
        self.assertEqual(response_reference, resp.content, msg='group command did not match')

    def test_groups_stations(self):
        url = reverse('metrics') + '?cmd=groups_stations'
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, 200)
        response_reference = b'G,649,IU,1\nG,650,US,1\n\nT,1,Network Code,649,650\n\nS,146,650,WVOR,650\nS,147,650,WMOK,650\nS,161,649,ANMO,649\nS,165,649,FURI,649\n'
        self.assertEqual(response_reference, resp.content, msg='station command did not match')

    def test_all(self):
        url = reverse('metrics') + '?cmd=dates_metrics_groups_stations'
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, 200)
        response_reference = b'DE,2020-01-06\nDS,2020-01-05\nM,29,Event Compare Synthetic\nM,28,Event Compare Strong Motion\nM,27,Difference: 200-500\nM,26,Difference: 90-110\nM,25,Difference: 18-22\nM,24,Difference: 4-8\nM,23,Coherence: 200-500\nM,22,Station Deviation: 200-500\nM,21,Station Deviation: 90-110\nM,20,Station Deviation: 18-22\nM,19,Dead Channel: 4-8\nM,18,Station Deviation: 4-8\nM,17,Coherence: 90-110\nM,16,NLNM Deviation: 200-500\nM,15,NLNM Deviation: 90-110\nM,14,Coherence: 18-22\nM,13,NLNM Deviation: 18-22\nM,12,NLNM Deviation: 4-8\nM,11,Coherence: 4-8\nM,10,NLNM Deviation: 0.125-0.25\nM,9,NLNM Deviation: 0.5-1\nM,8,Vacuum Monitor\nM,7,ALNM Deviation: 18-22\nM,6,ALNM Deviation: 4-8\nM,5,Mass Position\nM,4,Timing Quality\nM,2,Availability\nM,3,Gap Count\nM,32,Pressure Metric\nM,30,Event Compare PWave Orientation\nM,31,Infrasound Metric\nG,649,IU,1\nG,650,US,1\n\nT,1,Network Code,649,650\n\nS,146,650,WVOR,650\nS,147,650,WMOK,650\nS,161,649,ANMO,649\nS,165,649,FURI,649\n'
        self.assertEqual(response_reference, resp.content, msg='station command did not match')

    def test_stationgrid_parameter(self):
        url = reverse('metrics') + '?cmd=stationgrid&param=station.146_metric.3_dates.2020-01-06.2020-01-07'
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, 200)
        response_reference = b'146,1,84.92046370967742'
        self.assertEqual(response_reference, resp.content, msg='stationgrid parameter did not match')

    def test_stationplot_parameter(self):
        url = reverse('metrics') + '?cmd=stationplot&param=station.146_metric.3_dates.2020-01-06.2020-01-07'
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, 200)
        response_reference = b'2020-01-06,1.0000'
        self.assertEqual(response_reference, resp.content, msg='stationplot parameter did not match')

    def test_channelgrid_parameter(self):
        url = reverse('metrics') + '?cmd=channelgrid&param=channel.3357_station.146_metric.3_dates.2020-01-06.2020-01-07'
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, 200)
        response_reference = b'3357,1,84.92046370967742'
        self.assertEqual(response_reference, resp.content, msg='channelgrid parameter did not match')

    def test_channelplot_parameter(self):
        url = reverse('metrics') + '?cmd=channelplot&param=channel.3357_station.146_metric.4_dates.2020-01-06.2020-01-07'
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, 200)
        response_reference = b'2020-01-06,99.9362'
        self.assertEqual(response_reference, resp.content, msg='channelgrid parameter did not match')

    def test_channel_parameter(self):
        url = reverse('metrics') + '?cmd=channels&param=station.146'
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, 200)
        response_reference = b'C,3353,LNZ,20,146\nC,3354,VMW,00,146\nC,3355,BH2,00,146\nC,3356,VMV,00,146\nC,3357,BH1,00,146\nC,3358,VMU,00,146\nC,3359,LH2,00,146\nC,3360,LH1,00,146\nC,3361,BHZ,00,146\nC,3362,VH2,00,146\nC,3363,VH1,00,146\nC,3364,LHZ,00,146\nC,3365,VHZ,00,146\nC,3366,LN2,20,146\nC,3367,LN1,20,146'
        self.assertEqual(response_reference, resp.content, msg='channels parameter did not match')
