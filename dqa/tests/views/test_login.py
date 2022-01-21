
from django.contrib.auth.models import User
from django.test import TestCase


class TestLogin(TestCase):

    databases = ['metrics', 'metricsold', 'default']

    @classmethod
    def setUpClass(cls):
        super(TestLogin, cls).setUpClass()
        cls.test_user1 = User.objects.create_user(username='testuser1', password='12345')
        cls.test_user1.save()

    def do_login(self):
        login = self.client.login(username='testuser1', password='12345')
        return login

    def redirect_without_login(self, url):
        resp = self.client.get(url)
        self.assertRedirects(resp, '/accounts/login/?next=' + str(url))

    def page_accessible_on_login(self, url, template=None, response_code=200):
        login = self.do_login()
        resp = self.client.get(url)
        self.assertTrue(login)
        # Check our user is logged in
        self.assertEqual(int(self.client.session['_auth_user_id']), self.test_user1.pk)
        # Check that we got a positive response
        self.assertEqual(resp.status_code, response_code)
        if template is not None:
            self.assertTemplateUsed(resp, template)

    def redirect_without_login_post(self, url, arguments):
        resp = self.client.post(url, arguments)
        self.assertRedirects(resp, '/accounts/login/?next=' + str(url))
