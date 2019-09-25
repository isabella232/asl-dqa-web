"""dqa URL Configuration"""

from django.conf.urls import url

from dqa.views.api import metrics, dqaget
from dqa.views.index import index

urlpatterns = [
    url(r'^cgi-bin/metrics.py$', metrics.metrics, name="metrics"),
    url(r'^cgi-bin/dqaget.py$', dqaget.dqaget, name="dqaget"),
    url(r'index.html', index.index, name="index"),
    url(r'dataq.html', index.index, name="dataq"),
    url(r'^$', index.index, name="home"),
]
