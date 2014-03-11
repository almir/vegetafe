#!/bin/bash

###########################################
#
# Install and configure Vegeta Frontend
#
###########################################

argmissing() {
   echo ""$0": missing arguments"
   echo "Try '"$0" --help' for more information."
   exit 1
}

isroot() {
   # Make sure only root can run this script
   if [ "$(id -u)" != "0" ]; then
      echo "This script must be run as root." 1>&2
      exit 1
   fi
}

checkprereqs() {
   echo "Checking pre-requisites..."
   if [ -f /etc/redhat-release ]; then
      # Set variables indicating OS and architecture
      RHEL=true
      ARCH=`uname -m`
      if [ "$ARCH" != "x86_64" ]; then
         echo "Unsupported architecture." 1>&2
         exit 1
      fi

      # Check for pre-requisites
      RUBY=`ruby --version 2> /dev/null`

      if [ -z "$RUBY" ]; then
         echo "Ruby: NOT INSTALLED"
      else
         echo "Ruby: INSTALLED"
      fi
   elif [ -f /etc/debian_version ]; then
      # Set variables indicating OS and architecture
      DEB=true
      ARCH=`uname -m`
      if [ "$ARCH" != "x86_64" ]; then
         echo "Unsupported architecture." 1>&2
         exit 1
      fi

      # Check for pre-requisites
      RUBY=`ruby --version 2> /dev/null`

      if [ -z "$RUBY" ]; then
         echo "Ruby: NOT INSTALLED"
      else
         echo "Ruby: INSTALLED"
      fi
   else
      echo "Distro not recognized, please install manually." 1>&2
      exit 1
   fi
}

set-credentials() {
   echo -n "Vegeta Frontend username: "
   read USERNAME
   echo -n "Vegeta Frontend password: "
   read PASSWORD

   sed -i "s/%w(.*/%w(${USERNAME} ${PASSWORD})/" /var/www/vegetafe/config.ru

   echo -e "\nUser credentials set.\n"

   # Restart Thin
   service vegetafe restart
}

configall() {
   # Install Ruby via RVM (http://tecadmin.net/how-to-install-ruby-2-0-0-on-centos-6-using-rvm)
   if [ -z "$RUBY" ]; then
      curl -L get.rvm.io | bash -s stable
      source /etc/profile.d/rvm.sh
      rvm install 2.1.1
      rvm use 2.1.1 --default

      # Update Ruby Gems and install bundler gem
      gem update --system && gem install bundler
   fi

   # Stop Thin if it's started
   service vegetafe stop

   # Install and configure Vegeta Frontend
   if [ ! -d /var/www/vegetafe ]; then
      git clone https://github.com/almir/vegetafe.git /var/www/vegetafe
      cd /var/www/vegetafe
      bundle install
   else
      cd /var/www/vegetafe
      # Revert any local changes
      git reset --hard
      # Pull sources from git repo
      git pull
      bundle install
   fi

   # Get Vegeta binary
   mkdir -p /var/www/vegetafe/bin
   cd /var/www/vegetafe/bin
   if [ ! -x /var/www/vegetafe/bin/vegeta ]; then
      wget https://github.com/almir/vegeta/releases/download/v1.3.1/vegeta-linux-amd64.tar.gz
      tar xvzf vegeta-linux-amd64.tar.gz
      rm -f vegeta-linux-amd64.tar.gz
   fi

   # Make uploads directory
   mkdir -p /var/www/vegetafe/uploads

   # Add iptables command to /etc/rc.local to forward everything from ports 443 to port 9292
   if [ -z "$(grep "/sbin/iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 443 -j REDIRECT --to-port 9292" /etc/rc.local)" ]; then
      # Add iptables rule to /etc/rc.local
      if [ -n "$(grep "exit 0" /etc/rc.local)" ]; then
         sed -i "/^exit 0/d" /etc/rc.local
         echo -e "\n# Forward everything from port 443/tcp to port 9292/tcp\n/sbin/iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 443 -j REDIRECT --to-port 9292\n\nexit 0" >> /etc/rc.local
      else
         echo -e "\n# Forward everything from port 443/tcp to port 9292/tcp\n/sbin/iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 443 -j REDIRECT --to-port 9292" >> /etc/rc.local
      fi
      # Apply iptables rule immediately
      /sbin/iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 443 -j REDIRECT --to-port 9292
   fi

   # Make ssl directory and generate self-signed certificate
   if [ ! -d /var/www/vegetafe/ssl ]; then
      mkdir -p /var/www/vegetafe/ssl
      openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /var/www/vegetafe/ssl/vegetafe.key -out /var/www/vegetafe/ssl/vegetafe.crt
      echo -e "\nReplace the self-signed certificate located in \e[0;31m/var/www/vegetafe/ssl\e[0m with your certificate, if you have it.\n\
After that modify the variables in \e[0;31m/etc/init.d/vegetafe\e[0m to reflect your changes.\n"
   fi

   set-credentials
}

install() {
   # Check for pre-requisites for installation of Vegeta Frontend
   checkprereqs
   echo -e "Installing Vegeta Frontend with pre-requisites...\n"
   if [ "$RHEL" = true ]; then
      # Configure EPEL package repositories if not already

      # Check whether EPEL repos have been set up
      EPEL=`rpm -q epel-release`

      if [ "$EPEL" == "package epel-release is not installed" ]; then
         wget http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
         yum -y install epel-release-6*.rpm
         rm -f epel-release-6*.rpm
      fi

      # Install some dependencies first
      yum -y install gcc-c++ patch readline readline-devel zlib zlib-devel \
                     libyaml-devel libffi-devel openssl-devel make bzip2 autoconf \
                     automake libtool bison libevent-devel

      # Configure Thin to start on boot
      if [ ! -x /etc/init.d/vegetafe ]; then
         cp /var/www/vegetafe/install/vegetafe-rhel-svc.sh /etc/init.d/vegetafe
         chmod +x /etc/init.d/vegetafe
         chkconfig --add vegetafe
      fi

      configall
   elif [ "$DEB" = true ]; then
      # Install some dependencies first
      apt-get -y install build-essential git-core curl

      # Configure Thin to start on boot
      if [ ! -x /etc/init.d/vegetafe ]; then
         cp /var/www/vegetafe/install/vegetafe-deb-svc.sh /etc/init.d/vegetafe
         chmod +x /etc/init.d/vegetafe
         update-rc.d vegetafe start 99 2 3 5 . stop 05 0 6 .
      fi

      configall
   fi
}

cleanup() {
   # Empty the uploads directory
   if [ -d /var/www/vegetafe/uploads ]; then
      UPLOADEDFILES=`ls /var/www/vegetafe/uploads/`
      if [ -n "$UPLOADEDFILES" ]; then
         rm -f /var/www/vegetafe/uploads/*
      fi
   fi

   # Delete old testing results
   if [ -d /var/www/vegetafe/bin ]; then
      OLDRESULTS=`ls /var/www/vegetafe/bin/*.bin 2> /dev/null`
      if [ -n "$OLDRESULTS" ]; then
         rm -f /var/www/vegetafe/bin/*.bin /var/www/vegetafe/bin/*.csv
      fi
   fi
}

case "$1" in
  --install)
        # Check whether the user has root privileges
        isroot
        # Install and configure Vegeta Frontend
        install
        ;;
  --set-credentials)
        # Check whether the user has root privileges
        isroot
        # Set user credentials
        set-credentials
        ;;
  --check-prereqs)
        # Check whether the user has root privileges
        isroot
        # Check for pre-requisites for installation of Vegeta Frontend
        checkprereqs
        ;;
  --cleanup)
        # Check whether the user has root privileges
        isroot
        # Do cleanup
        cleanup
        ;;
  --help)
        echo "Usage: "$0" OPTION"
        echo "eg.:   "$0" --check-prereqs"
        echo
        echo "Available options:"
        echo "     --install          Install Vegeta Frontend."
        echo "     --set-credentials  Set user credentials (username and password)."
        echo "     --check-prereqs    Check whether the prerequsites for installation have been met."
        echo "     --cleanup          Empties the uploads directory and deletes old testing results."
        echo "     --help             Display this help."
        ;;
  *)
        argmissing
        ;;
esac

exit 0
