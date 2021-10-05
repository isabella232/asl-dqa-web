
import json

from django.http import HttpResponse, JsonResponse
from django.views.decorators.csrf import csrf_exempt

from metrics.models import Metric, ComputeType, Custom


@csrf_exempt
def metrics(request):
    """
    Pass back metrics for given parameters
    :param request:
    :return:
    """

    if request.method == 'GET':
        return metrics_read(request)
    elif request.method == 'POST':
        return metrics_write(request)


def metrics_read(request):

    model = request.GET.get('model', None)
    user_settings = request.GET.get('usersettings', None)

    metrics = []
    if model == 'metric':
        for metric_object in Metric.objects.all():
            metrics.append({'id': metric_object.id, 'name': metric_object.name, 'display_name': metric_object.display_name, 'description_short': metric_object.description_short, 'description_long': metric_object.description_long, 'compute_type': metric_object.compute_type.name, 'parent': metric_object.parent.name if metric_object.parent else None})
    else:
        return JsonResponse({'Error': f'Unknown model parameter: {model}'})
    output = {'metrics': {'data': metrics, 'count': len(metrics)}}
    if user_settings is not None:
        custom_object = Custom.objects.get(user_id='dwitte')
        output['user_settings'] = {'metric_columns': [m.id for m in custom_object.columns.all()]}
    return JsonResponse(output)


def metrics_write(request):

    json_data = json.loads(request.body)
    if json_data['model'] == 'metric':
        if ComputeType.objects.all().count() < 1:
            return JsonResponse({'status': 'error', 'message': 'Metrics require compute type'})
        for value in json_data['data']:
            m_object, _ = Metric.objects.get_or_create(id=value['id'], name=value['name'], display_name=value['display_name'], description_short=value['description_short'], description_long=value['description_long'], compute_type=ComputeType.objects.get(name=value['compute_type']))
        return JsonResponse({'status': 'ok', 'message': 'Metrics loaded'})
    elif json_data['model'] == 'custom':
        if json_data['type'] == 'columns':
            user_custom, _ = Custom.objects.get_or_create(user_id='dwitte')
            user_custom.columns.clear()
            for metric_name in json_data['data']:
                if metric_name in ['Network', 'Station', 'Group']:
                    continue
                metric = Metric.objects.get(display_name=metric_name)
                user_custom.columns.add(metric)
            return JsonResponse({'status': 'ok', 'message': 'Custom columns updated'})
    else:
        return JsonResponse({'status': 'error', 'message': 'Unknown model to process'})
