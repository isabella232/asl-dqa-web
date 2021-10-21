
from django.conf import settings
from django.contrib.auth import REDIRECT_FIELD_NAME
from django.contrib.auth.decorators import user_passes_test


def dqa_login_required(view_func=None, *, required=False):
    """
    This is a copy of Django login_required but adds a parameter so we can require login on certain pages
    but not on others while using Django auth system.
    :param view_func: actually passed in @ syntax
    :param required: bool, If True then we check user authentification, if False then we ignore authorization
    :return: view function that is wrapped
    """
    actual_decorator = user_passes_test(
        lambda u: u.is_authenticated if required else True,
        login_url=settings.LOGIN_URL,
        redirect_field_name=REDIRECT_FIELD_NAME
    )
    return actual_decorator
