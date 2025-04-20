#!/bin/bash

#Script para la instalación de una pila LAMP (apache2-mariadb-php) y GLPI

#Instalación de dialog
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
  sudo apt update -y && sudo apt dist-upgrade -y && sudo apt autoremove -y
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

        ErrorLog \${APACHE_LOG_DIR}/error.log
        CustomLog \${APACHE_LOG_DIR}/access.log combined

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

#Instalamos la última versión de php, reiniciamos
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
       --infobox "Enter-n-y-Enter_pass-Re_enter_pass-y-y-y-y" 0 0
clear       
sudo mysql_secure_installation

#Creamos una BBDD para GLPI y un nuevo usuario con contraseña en mariadb-server también para GLPI
nomuser=$(dialog --title "Creamos el usuario para la BBDD" \
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

##### APARTADO GLPI ###############

#Poner la última versión de glpi
version_glpi=$(dialog --title "Poner los 3 dígitos de la última version de GLPI" \
  --backtitle "Revise la documentación oficial de  GLPI" \
  --stdout \
  --inputbox "(ejemplo:10.0.1)" 0 0)
#Llamo a la funcion:
acabar

#Descarga de glpi
clear
wget https://github.com/glpi-project/glpi/releases/download/"$version_glpi"/glpi-"$version_glpi".tgz

#Descomprimimos, cambiamos el fichero .tgz a /var/wwww/html, eliminamos el index.html y el .tgz
sudo tar -zxvf glpi-"$version_glpi".tgz -C /var/www/
sudo rm -rf glpi-"$version_glpi".tgz 
sudo rm -rf /var/www/html/index.html

#Damos permisos
sudo chown -R www-data:www-data /var/www/glpi
sudo chmod -R 755 /var/www/glpi

#Cargamos las ZONAS HORARIAS DEL SISTEMA
dialog --title "Cargamos las zonas horarias del sistema" \
  --msgbox "Introducimos la contraseña de root " 0 0
clear
sudo mysql_tzinfo_to_sql /usr/share/zoneinfo | sudo mysql -u root -p mysql

#Aviso
dialog --title "Cuando se inicialize la BBDD, por razones de seguridad, por favor elimine el archivo: \"install/install.php\"" \
       --msgbox "sudo rm -rf /var/www/glpi/install/install.php" 0 0

########Preguntamos si queremos cambiar los LOGOTIPOS DE GLPI###########
dialog --title "Cambiar los logotipos de GLPI" \
       --backtitle "Debe tener el logo-master en el $HOME del servidor" \
  --yesno "¿Quieres?" 0 0
ans=$?
if [ $ans -eq 0 ]; then
  clear
  #Llamo a la función:
  acabar

  sudo apt install imagemagick -y

  #Función listar el nombre del logo-master
  ellogo=$(dialog --title "Listado de los elementos del $HOME" \
    --backtitle "Utilizar las flechas de dirección para seleccionar y la barra espaciadora para confirmar la selección" \
    --stdout \
    --fselect "$HOME"/ 20 120)
  #Llamo a la funcion:
  acabar

  #Hacemos un backup de los logos originales de la aplicación
  sudo mv /var/www/glpi/pics/favicon.ico /var/www/glpi/pics/favicon.ico.bkp
  sudo mv /var/www/glpi/pics/logos/logo-GLPI-100-white.png /var/www/glpi/pics/logos/logo-GLPI-100-white.png.bkp
  sudo mv /var/www/glpi/pics/logos/logo-GLPI-250-black.png /var/www/glpi/pics/logos/logo-GLPI-250-black.png.bkp
  
  #Creamos los logos con los tamaños requeridos (pixeles) que vamos a necesitar
  unlogo=$(basename "$ellogo")
  sudo convert "$unlogo" -resize 32x32\! favicon.ico
  sudo convert "$unlogo" -resize 100x55\! logo-GLPI-100-white.png
  sudo convert "$unlogo" -resize 220x130\! logo-GLPI-250-black.png

  #Cambiamos los permisos a 755
  sudo chmod 755 favicon.ico
  sudo chmod 755 logo-GLPI-100-white.png
  sudo chmod 755 logo-GLPI-250-black.png

  #Copiamos los ficheros de imagen creados de los logos a sus respectivas rutas
  sudo cp favicon.ico /var/www/glpi/pics/
  sudo cp logo-GLPI-100-white.png /var/www/glpi/pics/logos/
  sudo cp logo-GLPI-250-black.png /var/www/glpi/pics/logos/
  
  #Cambiamos el propietario y el grupo a www-data
  sudo chown www-data:www-data /var/www/glpi/pics/favicon.ico
  sudo chown www-data:www-data /var/www/glpi/pics/favicon.ico.bkp
  sudo chown www-data:www-data /var/www/glpi/pics/logos/logo-GLPI-100-white.png
  sudo chown www-data:www-data /var/www/glpi/pics/logos/logo-GLPI-100-white.png.bkp
  sudo chown www-data:www-data /var/www/glpi/pics/logos/logo-GLPI-250-black.png
  sudo chown www-data:www-data /var/www/glpi/pics/logos/logo-GLPI-250-black.png.bkp
fi
clear
exit 0