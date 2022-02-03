
import datetime

from django.shortcuts import render
from django.shortcuts import reverse
from django.http import HttpResponseRedirect
from django.conf import settings

from dqa.forms.scan import ScanAddForm
from asldqaweb.decorators.auth import dqa_login_required
from dqa.views.api.scans import scan_post_update


@dqa_login_required(required=True)
def scanadd(request):
    if request.method == 'POST':
        group = request.GET.get('group', None)
        group_param = f'?group={group}' if group is not None else ''
        form = ScanAddForm(request.POST)
        if form.is_valid():
            output = {'start_date': form.data['start_date'],
                      'end_date': form.data['end_date'],
                      'priority': form.data['priority'],
                      'network_filter': f"'{form.data['network_filter']}'" if form.data['network_filter'] else "null",
                      'station_filter': f"'{form.data['station_filter']}'" if form.data['station_filter'] else "null",
                      'last_updated': datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                      }
            status = scan_post_update(output)
            if status == 201:
                return HttpResponseRedirect(reverse('scans') + group_param)
            else:
                form.add_error(field=None, error=f'Scan not saved: {status}')
    else:
        group = request.GET.get('group', None)
        group_param = f'?group={group}' if group is not None else ''
        form = ScanAddForm()

    return render(request, 'scans/addscan.html',
                  {'form': form,
                   'next_url': f"{reverse('scans')}{group_param}",
                   'version': settings.VERSION,
                   'username': request.user.username,
                   'group': group
                   })
