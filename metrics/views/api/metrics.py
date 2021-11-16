
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticatedOrReadOnly
from rest_framework.parsers import JSONParser

from metrics.models import Metric, ComputeType


class metrics(APIView):

    permission_classes = (IsAuthenticatedOrReadOnly,)
    parser_classes = [JSONParser]

    def get(self, request):
        metrics = []
        for metric_object in Metric.objects.all():
            metrics.append({'id': metric_object.id, 'name': metric_object.name, 'display_name': metric_object.display_name, 'description_short': metric_object.description_short, 'description_long': metric_object.description_long, 'compute_type': metric_object.compute_type.name, 'parent': metric_object.parent.name if metric_object.parent else None})
        output = {'metrics': {'data': metrics, 'count': len(metrics)}}
        return Response(output)

    def post(self, request):
        if ComputeType.objects.all().count() < 1:
            return JsonResponse({'status': 'error', 'message': 'Metrics require compute type'})
        for value in request.data['data']:
            m_object, _ = Metric.objects.get_or_create(id=value['id'], name=value['name'], display_name=value['display_name'], description_short=value['description_short'], description_long=value['description_long'], compute_type=ComputeType.objects.get(name=value['compute_type']))
        return Response({'status': 'ok', 'message': 'Metrics loaded'})
