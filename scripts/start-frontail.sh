#!/bin/bash

frontail -d -t dark -l 5000 --log-path /tmp/frontail.log /var/log/logfile_$(date +"%Y-%m-%d")*
