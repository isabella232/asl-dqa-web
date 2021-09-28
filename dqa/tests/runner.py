import subprocess

from django.test.runner import DiscoverRunner
from django.conf import settings


class DBRunner(DiscoverRunner):

    def setup_databases(self, **kwargs):

        db = super(DBRunner, self).setup_databases(**kwargs)
        bash_cmd = f'export PGPASSWORD=\"{settings.DATABASES["metricsold"]["PASSWORD"]}\"; psql --host={settings.DATABASES["metricsold"]["HOST"]} --dbname={settings.DATABASES["metricsold"]["NAME"]} --username={settings.DATABASES["metricsold"]["USER"]} -a -f {settings.TEST_RESOURCES}/dqa_test.sql'
        process = subprocess.Popen(bash_cmd, stdout=subprocess.PIPE, shell=True)
        process.communicate()
        return db
