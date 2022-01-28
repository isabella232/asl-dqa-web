
from django.shortcuts import render
from django.conf import settings

from asldqaweb.decorators.auth import dqa_login_required


@dqa_login_required(required=True)
def scans(request):
    parent_id = request.GET.get('parentid')
    group = request.GET.get('group', '')
    return render(request, 'scans/scanlist.html', {'parentid': parent_id,
                                                   'version': settings.VERSION,
                                                   'username': request.user.username,
                                                   'group': group
                                                   })
