# Release Notes

###### Version 2.2.0
1. Upgrades:
   * Added tooltips to data column headers with short descriptions.
   * Added user login.
   * Added ability for user to save visible columns, column weights and date format.
   * Added Y label to plots.
   * Added scan list page to display scan status.
   * Added form to input new scans.
2. Backend Changes:
   * Updated test runners.
   * Change project structure and split DB in preparation for migration to Django.
   * Added authorization to API and implemented Django rest framework for API.
3. Additional Upgrade Notes:
   * Since project structure changes we must also update Apache conf file to reflect those changes.  The repo conf file has been updated so ApacheConf.bash must be run to update Apache service.  The proper conf to grab needs to be set in Apacheconf.bash, either dqa_dev or dqa_prod version.   
   * The addition of the Django rest framework added a Token table to the auth DB so that needs to get migrated.  To create a Token you can use the admin web pages or run `manage.py drf_create_token <username>`
   * There was a change to updateLocal.bash so make sure update is run, either updateLocal.bash for local developer machines or updateServer.bash for dev or prod server.
