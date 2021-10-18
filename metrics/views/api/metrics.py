
import json

from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt

from metrics.models import Metric, ComputeType, Custom, CustomWeight


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

    metrics = []
    for metric_object in Metric.objects.all():
        metrics.append({'id': metric_object.id, 'name': metric_object.name, 'display_name': metric_object.display_name, 'description_short': metric_object.description_short, 'description_long': metric_object.description_long, 'compute_type': metric_object.compute_type.name, 'parent': metric_object.parent.name if metric_object.parent else None})
    output = {'metrics': {'data': metrics, 'count': len(metrics)}}
    return JsonResponse(output)


def metrics_write(request):

    json_data = json.loads(request.body)
    if ComputeType.objects.all().count() < 1:
        return JsonResponse({'status': 'error', 'message': 'Metrics require compute type'})
    for value in json_data['data']:
        m_object, _ = Metric.objects.get_or_create(id=value['id'], name=value['name'], display_name=value['display_name'], description_short=value['description_short'], description_long=value['description_long'], compute_type=ComputeType.objects.get(name=value['compute_type']))
    return JsonResponse({'status': 'ok', 'message': 'Metrics loaded'})
