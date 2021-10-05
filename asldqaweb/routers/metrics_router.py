
class MetricsRouter(object):
    """
    A router to control access to dqa databse.
    """

    def db_for_read(self, model, **hints):
        """
        Attempts to read dqa models go to dqa database.
        """
        if model._meta.app_label == 'metrics':
            return 'metrics'
        return None

    def db_for_write(self, model, **hints):
        """
        Attempts to write dqa models go to dqa database.
        """
        if model._meta.app_label == 'metrics':
            return 'metrics'
        return None

    def allow_relation(self, obj1, obj2, **hints):
        """
        Allow relations if a model in the dqa app is involved.
        """
        if obj1._meta.app_label == 'metrics' or obj2._meta.app_label == 'metrics':
            return True
        return None

    def allow_migrate(self, db, app_label, model_name=None, **hints):
        if app_label == 'metrics' and db == 'metrics':
            return True
        if app_label != 'metrics' and db == 'metrics':
            return False
        if app_label == 'metrics' and db != 'metrics':
            return False
        return None
