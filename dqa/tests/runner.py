import subprocess

from django.test.runner import DiscoverRunner


class DBRunner(DiscoverRunner):

    def setup_databases(self, **kwargs):

        db = super(DBRunner, self).setup_databases(**kwargs)
        bash_cmd = f'export PGPASSWORD="test1234"; psql --host=vmdbx01.cr.usgs.gov --dbname=test_dqa_prod_clone --username=dwitte -a -f /home/dwitte/dev/asl-dqa-web/dqa/tests/resources/dqa_test.sql'
        process = subprocess.Popen(bash_cmd, stdout=subprocess.PIPE, shell=True)
        process.communicate()
        return db
