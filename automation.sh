#! /bin/bash
myname=rajesh
s3_bucket=upgrad-$myname

#update packages
echo "Updating packages...."
echo
sudo apt update -y

#if apache is not installed already then install it else print available message
echo "Installing apache webserver...."
echo
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
 echo "apache2 is installed"
fi

#check apache server is running
echo "Starting apache webserver...."
echo
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
 echo "apache server is running"
fi

#check apache server is enabled
echo "Enabling apache webserver...."
echo
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
 echo "apache server is enabled"
fi

# create dated tar archive of *.log files in /tmp
timestamp=$(date '+%d%m%Y-%H%M%S')
tarfile="$myname-httpd-logs-$timestamp.tar"
tar -cvf /tmp/$tarfile /var/log/apache2/*.log
if [ $? -gt 0 ]
then
 echo "Failed to create tar archive $tarfile."
 exit 4
fi

#copy to s3 bucket
aws s3 \
cp /tmp/${myname}-httpd-logs-${timestamp}.tar \
s3://${s3_bucket}/${myname}-httpd-logs-${timestamp}.tar
