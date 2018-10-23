# asl-dqa-web
This is the frontend that displays data found in a DQA database.

### Setup
Python CGI must be enabled on the web server
psycopg2 module must be installed.

###### Example Apache conf using mod_wsgi
LoadModule wsgi_module modules/mod_wsgi.so
<Directory /var/www/html/dqa>
    Options Indexes FollowSymLinks MultiViews ExecCGI
    AddHandler cgi-script .py
    Require all granted
</Directory>



Only the html folder needs to be exposed via the web server.  
This is done by a soft link.  
sudo ln -s /data/www/dqa/html /var/www/html/dqa  


### License
Everything written by James Holland and Joel Edwards was created by employees of the US Government and is Public Domain.

###### Datatables  
Copyright:&nbsp;&nbsp;Allan Jardine  
License:&nbsp;&nbsp;&nbsp;&nbsp;BSD License  
###### jqplot  
Copyright:&nbsp;&nbsp;Chris Leonello  
License:&nbsp;&nbsp;&nbsp;&nbsp;MIT License  
###### jquery.ajaxmanager.js  
Copyright:&nbsp;&nbsp;Alexander Farkas  
License:&nbsp;&nbsp;&nbsp;&nbsp;MIT License
###### jQuery  
Copyright:&nbsp;&nbsp;jQuery Foundation, Inc and others  
License:&nbsp;&nbsp;&nbsp;&nbsp;MIT License  
###### jQuery UI  
Copyright:&nbsp;&nbsp;jQuery Foundation, Inc and others  
License:&nbsp;&nbsp;&nbsp;&nbsp;MIT License  
###### naturalSort.js  
Copyright:&nbsp;&nbsp;Jim Palmer  
License:&nbsp;&nbsp;&nbsp;&nbsp;MIT License  
