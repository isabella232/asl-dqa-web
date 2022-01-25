
import json
import datetime

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

    @staticmethod
    def create_token():
        """ Generate an authorization token to test protected API paths """
        test_user = User.objects.create_user(username='testuser1', password='123456')
        token_object = Token.objects.create(user=test_user)
        return token_object.key

    def test_scans(self):
        url = reverse('scansapi')
        output = {'start_date': datetime.date(2022, 1, 1),
                  'end_date': datetime.date(2022, 1, 15),
                  'priority': 47,
                  'network_filter': 'IU',
                  'station_filter': 'OMNA',
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
        del resp_data['child_count']
        del resp_data['status']
        del resp_data['message']
        self.assertEqual(output, resp_data, msg="Scan read, return not same as saved")
