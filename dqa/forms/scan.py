
from django import forms


class ScanAddForm(forms.Form):

    start_date = forms.DateField(help_text="Scan starts on this date", widget=forms.TextInput(attrs={'placeholder': 'Click to enter date', 'autocomplete': "off"}))
    end_date = forms.DateField(help_text="Scan ends on this date", widget=forms.TextInput(attrs={'placeholder': 'Click to enter date', 'autocomplete': "off"}))
    network_filter = forms.CharField(max_length=4, required=False, help_text="Limit scan to this network")
    station_filter = forms.CharField(max_length=8, required=False, help_text="Limit scan to this station")
    location_filter = forms.CharField(max_length=4, required=False, help_text="Limit scan to this location")
    # channel_filter = forms.CharField(max_length=8, required=False, help_text="Limit scan to this channel")
    # metric_filter = forms.CharField(max_length=20, required=False, help_text="Limit scan to this metric")
    priority = forms.IntegerField(initial=49, min_value=0, max_value=100, help_text="Scan priority, 0-100, 100 = highest")
    # scheduled_run = forms.DateField(required=False, help_text="Run scan in the future on this date", widget=forms.TextInput(attrs={'placeholder': 'Click to enter date', 'autocomplete': "off"}))
    # delete_existing = forms.BooleanField(initial=False, required=False, help_text="Flag to delete existing scan data as you scan")
