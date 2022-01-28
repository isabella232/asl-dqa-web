
import datetime

from django.urls import reverse

from dqa.tests.views.test_login import TestLogin


class TestLogin(TestLogin):

    databases = ['metrics', 'metricsold', 'default']

    output = {'start_date': datetime.date(2022, 1, 1),
              'end_date': datetime.date(2022, 1, 15),
              'priority': 47,
              'network_filter': 'IU',
              'station_filter': 'OMNA',
              'last_updated': '2022-01-20 01:01'
              }

    def test_scan_form_login_redirect(self):
        self.redirect_without_login(reverse('addscan'))

    def test_scan_form_valid_login(self):
        self.page_accessible_on_login(reverse('addscan'))

    def test_scan_form_post_login_redirect(self):
        self.redirect_without_login_post(reverse('addscan'), self.output)
