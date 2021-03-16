#! /bin/bash
myname=rajesh
s3_bucket=upgrad-$myname

#update packages
echo "Updating packages...."
sudo apt update -y
echo -e "Packages updated!\n"

#if apache is not installed already then install it else print available message
echo "Installing apache webserver...."
installed=$(dpkg -s apache2 | gawk '$0 ~ /Status.*installed/{print "Installed"}')
if [ "$installed"  != 'Installed' ]
then
 (sudo apt-get install apache2 -y)
 installed=$?
 if [ $installed -gt 0 ]
 then
  echo "Failed to install apache2 package"
  exit 1
 fi
else
 echo -e "apache2 is installed!\n"
fi


#check apache server is running
echo "Starting apache webserver...."
running=$(sudo systemctl status apache2 | gawk '$0 ~ /Active: active/{print "running"}')
if [ "$running"  != 'running' ]
then
 (sudo systemctl start apache2)
 running=$?
 if [ $running -gt 0 ]
 then
  echo "Failed to start apache server"
  exit 3
 fi
else
 echo -e "apache server is running!\n"
fi

#check apache server is enabled
echo "Enabling apache webserver...."
enabled=$(sudo systemctl status apache2 | gawk '$0 ~ /Loaded:.*enabled/{print "enabled"}')
if [ "$enabled"  != 'enabled' ]
then
 (sudo systemctl enable apache2)
 enabled=$?
 if [ $enabled -gt 0 ]
 then
  echo "Failed to enable apache server"
  exit 2
 fi
else
 echo -e "apache server is enabled!\n"
fi

# create dated tar archive of *.log files in /tmp
echo "Log Collection begins..."
timestamp=$(date '+%d%m%Y-%H%M%S')
tarfile=/tmp/${myname}-httpd-logs-${timestamp}.tar
tar -cvf $tarfile /var/log/apache2/*.log
if [ $? -gt 0 ]
then
 echo "Failed to create tar archive $tarfile."
 exit 4
else
 echo -e "tar archive $tarfile created!"
fi

#copy to s3 bucket
aws s3 \
cp $tarfile \
s3://${s3_bucket}/${myname}-httpd-logs-${timestamp}.tar

#Bookkeeping
echo "Bookkeeping begins....."
logtype='httpd-logs'
ftype=${tarfile##*.}
size=$(ls -s $tarfile | gawk '{print $1}')
inventory='/var/www/html/inventory.html'

if [ ! -f  $inventory ]
then
 echo "$inventory will be created with $timestamp entry"
 (gawk 'BEGIN{OFS="\t" ; print "Log Type","Time Created","Type","Size" ; print "<br/>"}' > $inventory)
 created=$?
 if [ ${created} -gt 0 ]
 then
  echo "Failed to create $inventory"
  exit 5
 else
  echo "$inventory created!"
 fi
else
 echo "$inventory exists and will be appended with entry for $timestamp"
fi
(gawk -v logtype=${logtype} -v timestamp=${timestamp} -v ftype=${ftype} -v size=${size} 'BEGIN{OFS="\t" ; print logtype,timestamp,ftype,size ; print "<br/>"}' >> $inventory)
echo -e "Bookkeeping complete!\n" 

#Scheduling through cron
echo "Scheduling Daily Execution..."
cronfile='/etc/cron.d/automation'

if [ ! -f  $cronfile ]
then
 echo "$cronfile will be created for daily script execution"
 (sudo echo '0 0 * * 0-6 root /root/Automation_Project/automation.sh >> /root/Automation_Project/cronlogs/cron.log 2>/root/Automation_Project/cronlogs/cron.err' > $cronfile)
 created=$?
 if [ ${created} -gt 0 ]
 then
  echo "Failed to create cron file $cronfile"
  exit 6
 else
  echo "cron entry created in $cronfile !"
 fi
else
 echo "$cronfile exists!"
fi
echo -e "Daily Execution scheduled!\n"
