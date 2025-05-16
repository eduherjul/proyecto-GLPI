#!/bin/bash

#Script para la restauración de glpi desde un backup local

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

#Función cancelar (acabar)
function cancelar() {
  clear
  echo "Operación cancelada"
  exit 1
}

# Función para vaciar la base de datos
vaciar_bbdd() {
    echo "Vaciando BBDD existente..."
    tablas=$(mysql -u "$usuariodb" -p"$passdb" -D glpi -e "SHOW TABLES;" | grep -v Tables_in)
    for tabla in $tablas; do
        mysql -u "$usuariodb" -p"$passdb" -D glpi -e "DROP TABLE $tabla;"
    done
    echo "BBDD vaciada."
}

# Función restaurar la BBDD
restaurar_bbdd() {
    vaciar_bbdd
    echo "Restaurando BBDD"
    gunzip -kf "$DB_BACKUP"
    SQL_FILE="${DB_BACKUP%.gz}"
    mysql -u "$usuariodb" -p"$passdb" glpi < "$SQL_FILE"
    #Aviso
    dialog --title "Base de Datos" \
           --msgbox "Restauración realizada correctamente" 0 0

}

# Función restaurar archivos GLPI
restaurar_ficheros() {
    #Deteniendo Apache
    systemctl stop apache2

    #Restaurando archivos en $glpiDir
    tar -xzvf "$FILES_BACKUP" -C "$glpiDir"

    systemctl start apache2
    #Aviso
    dialog --title "Archivos GLPI" \
           --msgbox "Restauración realizada correctamente" 0 0

}

#Actualizamos el sistema
dialog --title "Actualización del sistema update-upgrade" \
  --yesno "¿Actualizamos?" 0 0
ans=$?
if [ $ans -eq 0 ]; then
  clear
  sudo apt dist-upgrade -y && sudo apt autoremove -y
fi

# -------------------- CONFIGURACIÓN --------------------
usuariodb=$(dialog --title "Usuario de la BBDD" \
  --stdout \
  --inputbox "Nombre" 0 0)
#Llamo a la funcion:
acabar

passdb=$(dialog --title "Contraseña del usuario de la BBDD de GLPI" \
  --stdout \
  --inputbox "Password" 0 50)
#Llamo a la función:
acabar
clear

backupDir="/home/yo/glpi_backups"
glpiDir="/var/www/glpi"
# ------------------------------------------------------
fecha=$(dialog --title "Introduce la fecha del backup a restaurar (formato: YYYY-MM-DD_HH-MM-SS):" \
  --backtitle "Seleccionar la fecha del backup a elegir, sin extensión (ejemplo:2025-03-26_16-06-01)" \
  --stdout \
  --fselect /home/yo/glpi_backups/ 20 120) #Cambiar el nombre del usuario que este en vigor
#Llamo a la funcion:
acabar
clear

# Rutas de los backups
solofecha=$(basename "$fecha")
DB_BACKUP="$backupDir/glpi_db_${solofecha}.sql.gz"
FILES_BACKUP="$backupDir/glpi_files_${solofecha}.tar.gz"

#Preguntamos la opción que queremos ejecutar
while true; do
  respuesta=$(
    dialog --title "MENU:" \
      --stdout \
      --menu "Opciones:\n" 22 75 14 \
      1 "SOLO LA BBDD" \
      2 "SOLO LOS ARCHIVOS DE GLPI" \
      3 "AMBOS (BBDD Y ARCHIVOS)" \
      4 "Finalizar"
  )

  case $respuesta in

    1) #Opción restaurar DDBB
        clear
        restaurar_bbdd
        ;;

    2) #Opción restaurar ficheros
        clear
        restaurar_ficheros
        ;;
    3) #Opción restaurar ambos
        clear
        restaurar_bbdd
        restaurar_ficheros
        ;;

    4) #Finalizando el menu
    clear
    exit 0
    ;;

    *) #Cancelar la operación
        #Llamo a la función cancelar
        cancelar
        ;;
esac
done
