#!/usr/bin/env bash

# LAMP Setup with self signed certificate for HTTPS

DEVHOST="demo" #host name, .dev will be appended
YL='\033[1;33m' #Yellow
NC='\033[0m' # No Color

echo -e "${YL}--- Setup domain name in vagrant to ${DEVHOST}.dev ---${NC}"
sudo echo "127.0.0.1   ${DEVHOST}.dev" >> /etc/hosts

echo -e "${YL}--- We want the bleeding edge of PHP, right? ---${NC}"
sudo add-apt-repository -y ppa:ondrej/php

echo -e "${YL}--- Updating packages list ---${NC}"
sudo apt-get update && sudo apt-get upgrade -y

echo "Europe/Belgrade" > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata

echo -e "${YL}--- MySQL server ---${NC}"
echo "mysql-server-5.6 mysql-server/root_password password root" | sudo debconf-set-selections
echo "mysql-server-5.6 mysql-server/root_password_again password root" | sudo debconf-set-selections
apt-get -y install mysql-server-5.6

echo -e "${YL}--- Installing base packages ---${NC}"
sudo apt-get install -y vim curl python-software-properties htop git-core

# echo "--- Installing packages for kernel modules compile. Used by VirtualBox guest addon ---${NC}"
# sudo apt-get install build-essential linux-headers-`uname -r` dkms

echo -e "${YL}--- Installing Apache and PHP specific packages ---${NC}"
sudo apt-get install -y php7.0 apache2 libapache2-mod-php7.0 php7.0-curl php7.0-gd php7.0-mcrypt php7.0-mysql php7.0-json php7.0-sybase freetds-dev
sudo phpenmod mcrypt
sudo phpenmod sybase

echo -e "${YL}--- Default server name is ${DEVHOST}.dev ---${NC}"
echo "ServerName ${DEVHOST}.dev" | sudo tee /etc/apache2/conf-available/servername.conf
sudo a2enconf servername

echo -e "${YL}--- Installing and configuring Xdebug ---${NC}"
sudo apt-get install -y php7.0-xdebug

cat << EOF | sudo tee -a /etc/php/7.0/mods-available/xdebug.ini
xdebug.scream=1
xdebug.cli_color=1
xdebug.show_local_vars=1
EOF

echo -e "${YL}--- Installing ssmtp sendmail ---${NC}"
sudo apt-get install -y ssmtp

sudo sed -i 's/mailhub=mail/mailhub=10.10.10.1/' /etc/ssmtp/ssmtp.conf
sudo sed -i 's/#FromLineOverride=YES/FromLineOverride=YES/' /etc/ssmtp/ssmtp.conf

echo -e "${YL}--- Enabling mod-rewrite ---${NC}"
sudo a2enmod rewrite

echo -e "${YL}--- Setting document root and linking to /vagrant/public---${NC}"
sudo rm -rf /var/www
sudo ln -fs /vagrant/public /var/www

echo -e "${YL}--- Creating Key and SSL certificate ---${NC}"
sudo mkdir -p /etc/ssl/private
sudo mkdir -p /etc/ssl/certs

sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/apache-selfsigned.key -out /etc/ssl/certs/apache-selfsigned.crt -subj "/C=RS/ST=Serbia/L=Belgrade/O=NoOrg/CN=${DEVHOST}.dev"

cat << EOF | sudo tee /etc/apache2/conf-available/ssl-params.conf
SSLCipherSuite EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH
SSLProtocol All -SSLv2 -SSLv3
SSLHonorCipherOrder On
Header always set Strict-Transport-Security "max-age=63072000; includeSubDomains"
Header always set X-Frame-Options DENY
Header always set X-Content-Type-Options nosniff
# Requires Apache >= 2.4
SSLCompression off 
SSLUseStapling on 
SSLStaplingCache "shmcb:logs/stapling-cache(150000)"
EOF


sudo cp /etc/apache2/sites-available/default-ssl.conf /etc/apache2/sites-available/default-ssl.conf.orig


cat << EOF | sudo tee /etc/apache2/sites-available/default-ssl.conf
<IfModule mod_ssl.c>
        <VirtualHost _default_:443>
                ServerAdmin root@${DEVHOST}.dev
                ServerName ${DEVHOST}.dev

                DocumentRoot /var/www

                ErrorLog \${APACHE_LOG_DIR}/error.log
                CustomLog \${APACHE_LOG_DIR}/access.log combined

                SSLEngine on

                SSLCertificateFile      /etc/ssl/certs/apache-selfsigned.crt
                SSLCertificateKeyFile /etc/ssl/private/apache-selfsigned.key

                <FilesMatch "\.(cgi|shtml|phtml|php)$">
                                SSLOptions +StdEnvVars
                </FilesMatch>
                <Directory /usr/lib/cgi-bin>
                                SSLOptions +StdEnvVars
                </Directory>

                BrowserMatch "MSIE [2-6]" \
                               nokeepalive ssl-unclean-shutdown \
                               downgrade-1.0 force-response-1.0

        </VirtualHost>
</IfModule>
EOF

cat << EOF | sudo tee /etc/apache2/sites-available/000-default.conf
<VirtualHost *:80>
        ServerName ${DEVHOST}.dev
        Redirect permanent "/" "https://${DEVHOST}.dev"

        ErrorLog \${APACHE_LOG_DIR}/error.log
        CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF


sudo a2enmod ssl
sudo a2enmod headers
sudo a2enconf ssl-params
sudo a2ensite default-ssl

# Setting DocumentRoot
# sudo sed -i "s:DocumentRoot\s*.*:DocumentRoot /var/www:" /etc/apache2/sites-available/000-default.conf
# sudo sed -i "s:#ServerName\s*.*:ServerName ${DEVHOST}.dev:" /etc/apache2/sites-available/000-default.conf

echo -e "${YL}--- What developer codes without errors turned on ---${NC}"
sudo sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/7.0/apache2/php.ini
sudo sed -i "s/display_errors = .*/display_errors = On/" /etc/php/7.0/apache2/php.ini
sudo sed -i 's/AllowOverride None/AllowOverride All/' /etc/php/7.0/apache2/php.ini

echo -e "${YL}--- Restarting Apache ---${NC}"
sudo service apache2 restart

# Create default database
echo -e "${YL}--- Default mysql database ${DEVHOST} ---${NC}"
mysql -u root -p"root" -e "CREATE DATABASE if not exists ${DEVHOST} DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;"

# Create testing database
echo -e "${YL}--- Default mysql test database ${DEVHOST}_testing ---${NC}"
mysql -u root -p"root" -e "CREATE DATABASE if not exists ${DEVHOST}_testing DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;"

# Let root connect to mysql from everywhere (dev)
mysql -u root -p"root" -e ";GRANT ALL ON *.* TO root@'%' IDENTIFIED BY 'root';"

# Let mysql listen on all ips
sudo sed -i 's/127.0.0.1/0.0.0.0/g' /etc/mysql/my.cnf
sudo service mysql restart

echo -e "${YL}--- Composer is the future! ---${NC}"
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer

echo -e "${YL}--- Add useful aliases ---${NC}"
cat << EOF | sudo tee -a /home/vagrant/.bashrc
alias art='php artisan'
alias phpunit='vendor/bin/phpunit --color=always'
EOF

echo -e "${YL}--- All set to go! ---${NC}"
sudo apt-get -y autoclean
