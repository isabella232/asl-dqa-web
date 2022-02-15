

import datetime

from django.db import connections
from django.test import TestCase
from django.urls import reverse
from rest_framework.authtoken.models import Token
from django.contrib.auth.models import User
from rest_framework.test import APIClient

from dqa.views.api.scans import scan_post_update, scan_status, scan_order


class Testmetrics(TestCase):

    databases = ['metrics', 'metricsold', 'default']

    @classmethod
    def setUpClass(cls):
        super(Testmetrics, cls).setUpClass()

    @staticmethod
    def create_token():
        """ Generate an authorization token to test protected API paths """
        test_user = User.objects.create_user(username='testuser1', password='123456')
        token_object = Token.objects.create(user=test_user)
        return token_object.key

    @staticmethod
    def clean_scan_tables():
        with connections['metricsold'].cursor() as cursor:
            sql = f"TRUNCATE TABLE public.tblscanmessage CASCADE;"
            cursor.execute(sql)
            sql = f"TRUNCATE TABLE public.tblscan CASCADE;"
            cursor.execute(sql)

    def test_scan_update(self):
        self.clean_scan_tables()
        output = {}
        status = scan_post_update(data=output)
        self.assertTrue(status.startswith('KeyError:'))
        output = {'start_date': datetime.date(2021, 1, 1),
                  'end_date': datetime.date(2021, 1, 15),
                  'priority': 55,
                  'network_filter': 'IU',
                  'station_filter': 'AAAA',
                  'location_filter': '00',
                  'last_updated': '2021-01-20 01:01',
                  'ordering': '4:55:2021-01-15'
                  }
        status = scan_post_update(data=output)
        self.assertEqual(status, 201)
        url = reverse('scansapi')
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, 200)
        resp_data = resp.data['data'][0]
        del resp_data['id']
        del resp_data['status']
        del resp_data['message']
        self.assertEqual(output, resp_data, msg="Scan update, return not same as saved")

    def test_scans(self):
        self.clean_scan_tables()
        url = reverse('scansapi')
        output = {'start_date': datetime.date(2022, 1, 1),
                  'end_date': datetime.date(2022, 1, 15),
                  'priority': 47,
                  'network_filter': 'IU',
                  'station_filter': 'OMNA',
                  'location_filter': '00,10',
                  'last_updated': '2022-01-20 01:01',
                  'ordering': '4:47:2022-01-15'
                  }
        # requires auth
        apiclient = APIClient()
        post_resp = apiclient.post(url, data=output, format='json')
        self.assertEqual(post_resp.status_code, 401)
        # POST with auth
        apiclient.credentials(HTTP_AUTHORIZATION='Token ' + self.create_token())
        post_resp = apiclient.post(url, data=output, format='json')
        self.assertEqual(post_resp.status_code, 201)
        # GET does not require auth
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, 200)
        resp_data = resp.data['data'][0]
        del resp_data['id']
        del resp_data['status']
        del resp_data['message']
        self.assertEqual(output, resp_data, msg="Scan read, return not same as saved")

    def test_scan_status(self):
        status = scan_status(False, False, "", None, None)
        self.assertEqual('Pending', status, msg="Error in Pending")
        status = scan_status(True, False, "", None, None)
        self.assertEqual('Complete', status, msg="Error in Complete")
        status = scan_status(False, True, "", None, None)
        self.assertEqual('Running', status, msg="Error in Running")
        status = scan_status(False, True, "Got lost", None, None)
        self.assertEqual('Error', status, msg="Error in Error")
        status = scan_status(False, True, "Got lost", 100, 50)
        self.assertEqual('Error: 50.0%', status, msg="Error in Error")

    def test_scan_order(self):
        # order = scan_order(finished, taken, message, priority, end_date)
        order = scan_order(False, False, "", 99, "2022-01-01")
        self.assertEqual('4:99:2022-01-01', order, msg="Error scan order Pending")
        order = scan_order(True, False, "", 98, "2022-01-02")
        self.assertEqual('0:98:2022-01-02', order, msg="Error scan order Complete")
        order = scan_order(False, True, "", 97, "2022-01-03")
        self.assertEqual('7:97:2022-01-03', order, msg="Error scan order Running")
        order = scan_order(False, True, "Got really lost", 96, "2022-01-04")
        self.assertEqual('9:96:2022-01-04', order, msg="Error scan order Error")
        order = scan_order(True, True, "", 0, "")
        self.assertEqual('0:0:', order, msg="Error scan order scrambled")
