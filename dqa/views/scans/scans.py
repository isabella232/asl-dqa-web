
from django.shortcuts import render

from asldqaweb.decorators.auth import dqa_login_required


@dqa_login_required(required=True)
def scans(request):
    parent_id = request.GET.get('parentid', None)
    return render(request, 'scans/list.html', {'parentid': parent_id})
