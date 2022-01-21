
import urllib
import json
import datetime

from django.shortcuts import render
from django.shortcuts import reverse
from django.http import HttpResponseRedirect
from rest_framework.authtoken.models import Token

from dqa.forms.scan import ScanAddForm
from asldqaweb.decorators.auth import dqa_login_required


@dqa_login_required(required=True)
def scanadd(request):
    if request.method == 'POST':
        form = ScanAddForm(request.POST)
        if form.is_valid():
            req = urllib.request.Request(request.build_absolute_uri(reverse('scansapi')))
            req.add_header('Content-Type', 'application/json')
            output = {'start_date': form.data['start_date'],
                      'end_date': form.data['end_date'],
                      'priority': form.data['priority'],
                      'network_filter': form.data['network_filter'],
                      'station_filter': form.data['station_filter'],
                      'last_updated': datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                      }
            data = json.dumps(output)
            token_object = Token.objects.get(user=request.user)
            req.add_header('AUTHORIZATION', 'Token ' + token_object.key)
            response = urllib.request.urlopen(req, data.encode('utf-8'))
            if response.code == 201:
                return HttpResponseRedirect(reverse('scans'))
            else:
                form.add_error(field=None, error='Scan not saved')
    else:
        form = ScanAddForm()

    return render(request, 'scans/addscan.html',
                  {'form': form,
                   'next_url': reverse('scans')})
