
import json

from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.contrib.auth.models import User
from django.conf import settings
from django.contrib.auth import login

from metrics.models import Metric, ComputeType, Custom, CustomWeight


@csrf_exempt
def usersettings(request):
    """
    Process user settings
    :param request:
    :return:
    """

    if request.method == 'GET':
        return usersettings_read(request)
    elif request.method == 'POST':
        return usersettings_write(request)


def usersettings_read(request):

    username = request.GET.get('username', None)
    if username is None:
        return JsonResponse({'user_settings': {'error': 'missing user id parameter'}})
    user = User.objects.get(username=username)
    login(request, user, backend=settings.AUTHENTICATION_BACKENDS[0])
    custom_object, _ = Custom.objects.get_or_create(user_id=username)
    columns = [m.display_name for m in custom_object.columns.all()]
    weights = {w.metric.display_name: w.weight for w in custom_object.customweight_set.all()}
    output = {'user_settings': {'columns': columns, 'weights': weights, 'date_format': custom_object.date_format}}
    return JsonResponse(output)


def usersettings_write(request):

    json_data = json.loads(request.body)
    custom_object, _ = Custom.objects.get_or_create(user_id=request.user)
    for key, values in json_data['user_settings'].items():
        if key == 'columns':
            custom_object.columns.clear()
            for metric_name in values:
                if metric_name in ['Network', 'Station', 'Location', 'Channel', 'Group', 'Aggregate']:
                    continue
                metric = Metric.objects.get(display_name=metric_name)
                custom_object.columns.add(metric)
        elif key == 'weights':
            custom_object.weights.clear()
            for key, value in values.items():
                metric_object = Metric.objects.get(display_name=key)
                CustomWeight.objects.create(custom=custom_object, metric=metric_object, weight=value)
        elif key == 'date_format':
            custom_object.date_format = values
            custom_object.save()
        else:
            return JsonResponse({'status': 'error', 'message': 'Unknown model to process'})
    return JsonResponse({'status': 'ok', 'message': 'Settings updated'})
