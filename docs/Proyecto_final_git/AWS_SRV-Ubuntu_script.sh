#!/bin/bash

#Ejecutaremos el script AWS_SRV-Ubuntu_script.sh

# Instalamos la pila LAMP (apache2-mariadb-php) sin GLPI

#Instalación de dialog
sudo apt update
sudo apt install dialog -y

#Función para capturar el código de retorno del diálogo
function acabar() {
  exit_status=$?
  # Verificar si se seleccionó "Cancelar"
  if [ $exit_status -ne 0 ]; then
    clear
    echo "Operación cancelada"
    exit 1
  fi
}

#Actualizamos el sistema
dialog --title "Actualización del sistema update-upgrade" \
  --yesno "¿Actualizamos?" 0 0
ans=$?
if [ $ans -eq 0 ]; then
  clear
  sudo apt dist-upgrade -y && sudo apt autoremove -y
fi

##### APARTADO APACHE ##########

#Instalamos Apache2
clear
sudo apt install apache2 -y

#Realizamos un backup de nuestro 000-defaults.conf
sudo mv /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/000-default.conf.bkp

#Creamos un archivo de configuración para el sitio de GLPI en Apache
echo "<VirtualHost *:80>
        ServerName edu.com
        DocumentRoot /var/www/glpi/public

        <Directory /var/www/glpi/public>
            Options Indexes FollowSymLinks
            AllowOverride All
            Require all granted
            RewriteEngine On
            # Redirect all requests to GLPI router, unless file exists.
            RewriteCond %{REQUEST_FILENAME} !-f
            RewriteRule ^(.*)$ index.php [QSA,L]
        </Directory>

        ErrorLog ${APACHE_LOG_DIR}/error.log
        CustomLog ${APACHE_LOG_DIR}/access.log combined

</VirtualHost>" | sudo tee /etc/apache2/sites-available/glpi.conf

#Habilitamos el archivo .conf que hemos creado y habilitamos el modulo rewrite
#Recargamos, activamos y reiniciamos apache2.service
sudo a2ensite glpi.conf
sudo a2enmod rewrite
sudo systemctl reload apache2.service
sudo systemctl enable apache2.service
sudo systemctl restart apache2.service

##### APARTADO PHP #############

#Instalamos los repositorios de php y actualizaremos
sudo apt install software-properties-common apt-transport-https -y
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update -y && sudo apt dist-upgrade -y && sudo apt autoremove -y

#Poner la última versión de php compatible con la version de GLPI
version_php=$(dialog --title "Poner los 2 dígitos de la última version de php compatible" \
  --backtitle "Revise la documentación oficial de GLPI" \
  --stdout \
  --inputbox "(ejemplo:8.1)" 0 0)
#Llamo a la funcion:
acabar

#Instalamos la versión de php, reiniciamos
clear
sudo apt install php"$version_php" php"$version_php"-cli php"$version_php"-common libapache2-mod-php"$version_php" libapache2-mod-fcgid php"$version_php"-fpm -y
sudo systemctl restart apache2.service

#Habilitamos funciones instaladas de php, activamos "session.cookie_httponly", habilitamos la función fpm y recargamos-reiniciamos
sudo a2enmod proxy_fcgi setenvif
sudo sed -i '1432s/.*/session.cookie_httponly = on/' /etc/php/"$version_php"/fpm/php.ini
sudo systemctl restart php"$version_php"-fpm
sudo a2enconf php"$version_php"-fpm
sudo systemctl reload apache2.service
sudo systemctl restart apache2.service

#Instalamos la extensiones (dependencias) que vamos a necesitar para glpi
sudo apt install -y php"$version_php"-{curl,gd,imagick,intl,apcu,memcache,imap,mysqli,ldap,tidy,xmlrpc,pspell,gettext,mbstring,fpm,iconv,xml,xsl,bz2,Phar,zip,exif}

##### APARTADO MARIADB ###############

#Instalamos MariaDB y securizamos (nos permitirá poner contraseña a la cuenta root de mariaDB)
sudo apt install mariadb-server -y

#Aviso
dialog --title "mysql_secure_installation" \
       --msgbox "Enter-n-y-Enter_pass-Re_enter_pass-y-y-y-y" 0 0
clear       
sudo mysql_secure_installation

#Creamos una BBDD para GLPI y el usuario con contraseña en mariadb-server también para la GLPI que exportamos
nomuser=$(dialog --title "Creamos el usuario para la BBDD" \
  --backtitle "Debe ser el mismo que en la BBDD que exportaremos" \
  --stdout \
  --inputbox "Nombre" 0 0)
#Llamo a la funcion:
acabar

passuser=$(dialog --title "Contraseña para el nuevo usuario de GLPI" \
  --stdout \
  --inputbox "Password" 0 50)
#Llamo a la función:
acabar
clear

#Ahora creamos la BBDD (glpi), un nuevo usuario para GLPI, damos privilegios y activamos la zona horaria en mysql
sqlcomandosphp="create database glpi; 
create user '$nomuser'@'%' identified by '$passuser';
GRANT ALL PRIVILEGES ON glpi.* TO '$nomuser'@'%';
GRANT SELECT ON mysql.time_zone_name TO '$nomuser'@'%';
flush privileges;"

#Ejecutamos los comandos SQL en mysql
dialog --title "Creamos la BBDD con nombre \"glpi\" para GLPI y el usuario \"$nomuser\"" \
  --msgbox "Introducimos la contraseña de root " 0 0
clear
sudo mysql -u root -p -e "$sqlcomandosphp"

#Cargamos las ZONAS HORARIAS DEL SISTEMA
dialog --title "Cargamos las zonas horarias del sistema" \
  --msgbox "Introducimos la contraseña de root " 0 0
clear
sudo mysql_tzinfo_to_sql /usr/share/zoneinfo | sudo mysql -u root -p mysql
exit 0