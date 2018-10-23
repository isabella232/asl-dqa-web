#!/bin/bash

cd bin
pwd | tr -d '\n' > ../html/cgi-bin/settings.txt
echo "/" >> ../html/cgi-bin/settings.txt
