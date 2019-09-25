# asl-dqa-web
This is the frontend that displays data found in a DQA database.

### Project Installation

#####Django Project
1. log into server as asluser ```sudo su - asluser```  
2. CD to /data/www the main directory for projects  ```cd /data/www```
3. Clone asl-dqa-web repo to server ```git clone git@code.usgs.gov:asl/asl-dqa-web.git```
4. CD to newly created dqa directory ```cd /data/www/asl-dqa-web```
5. Make sure you are on master branch ```git checkout master```
6. Execute installServer.bash
7. Edit local_setting.py file under /data/www/asl-dqa-web/dqa:
   * Update SECRET_KEY to production secret key as in other projects.
   * Update ALLOWED_HOSTS list to include production server dns names, etc.
   * Check 'USER' under DATABASES section "default" is set to 'dqa_read', this is the default dqa DB user.
   * Update 'PASSWORD' under DATABASES section "default" with proper password for 'dqa_read' user.
   * Update 'HOST' under DATABASES section "default" with the server name running the production data base.
   * Update 'NAME' under DATABASES section "default" with the name of the production data base schema in POSTGRES. 

#####Apache

1. Log into server as root ```sudo su -```
2. Run script apacheConf.bash under /data/www/asl-dqa-web to install Apache conf and restart service.  
3. DQA should now be accessible under ```hostname/dqa```  

### Project Update

1. log into server as asluser ```sudo su - asluser```
2. Execute updateServer.bash located in /data/www/asl-dqa-web directory.
3. Restart the Apache server `sudo apachectl restart`.

