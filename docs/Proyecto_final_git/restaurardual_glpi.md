```bash
#!/bin/bash

# -------------------- INSTALACIÓN DEPENDENCIAS --------------------
sudo apt update
sudo apt install dialog -y

# -------------------- FUNCIONES GENERALES --------------------
function acabar() {
  exit_status=$?
  if [ $exit_status -ne 0 ]; then
    clear
    echo "Operación cancelada"
    exit 1
  fi
}

function cancelar() {
  clear
  echo "Operación cancelada"
  exit 1
}

# -------------------- CONFIGURACIÓN --------------------
backupDir="/home/yo/glpi_backups"
glpiDir="/var/www/glpi"

usuariodb=$(dialog --title "Usuario de la BBDD" --stdout --inputbox "Nombre" 0 0)
acabar

passdb=$(dialog --title "Contraseña del usuario de la BBDD de GLPI" --stdout --inputbox "Password" 0 50)
acabar

# -------------------- ORIGEN DEL BACKUP --------------------
origen=$(dialog --title "Origen del backup" \
  --stdout \
  --menu "¿Desde dónde deseas restaurar los backups?" 15 60 2 \
  1 "Local" \
  2 "Remoto")

acabar

fecha=$(dialog --title "Introduce la fecha del backup (formato: YYYY-MM-DD_HH-MM-SS):" \
  --stdout \
  --inputbox "(ejemplo:2025-03-26_16-06-01)" 0 0)
acabar

# -------------------- RUTAS --------------------
DB_BACKUP="$backupDir/glpi_db_${fecha}.sql.gz"
FILES_BACKUP="$backupDir/glpi_files_${fecha}.tar.gz"

# -------------------- SI ES REMOTO, DESCARGAR --------------------
if [ "$origen" == "2" ]; then
  remoteUser=$(dialog --title "Usuario SSH remoto" \
  --stdout \
  --inputbox "Usuario SSH" 0 0)
  acabar

  remoteHost=$(dialog --title "Host remoto" \
  --stdout \
  --inputbox "IP del servidor remoto" 0 0)
  acabar

  remoteDir=$(dialog --title "Ruta remota de backups" \
  --stdout \
  --inputbox "Ruta remota (ejem: /home/yo/backups_glpi)" 0 0)
  acabar

  # Crear carpeta local si no existe
  mkdir -p "$backupDir"

  # Verificación y confirmación antes de sobrescribir BBDD
  if [ -f "$DB_BACKUP" ]; then
    dialog --title "Archivo ya existe" \
      --yesno "El archivo $DB_BACKUP ya existe en local. ¿Deseas sobrescribir?" 0 0
    ans=$?
    if [ $ans -eq 0 ]; then
    clear
    # Descargar el archivo desde el servidor remoto
    scp "$remoteUser@$remoteHost:$remoteDir/glpi_db_${fecha}.sql.gz" "$DB_BACKUP"
    fi
  fi

  # Verificación y confirmación antes de sobrescribir archivos GLPI
  if [ -f "$FILES_BACKUP" ]; then
    dialog --title "Archivo ya existe" \
      --yesno "El archivo $FILES_BACKUP ya existe en local. ¿Deseas sobrescribir?" 0 0
    ans=$?
    if [ $ans -eq 0 ]; then
    clear
    # Descargar el archivo desde el servidor remoto
    scp "$remoteUser@$remoteHost:$remoteDir/glpi_files_${fecha}.tar.gz" "$FILES_BACKUP"  
    fi
  fi
fi
 
# -------------------- FUNCIONES DE RESTAURACIÓN --------------------
vaciar_bbdd() {
    echo "Vaciando BBDD existente..."
    tablas=$(mysql -u "$usuariodb" -p"$passdb" -D glpi -e "SHOW TABLES;" | grep -v Tables_in)
    for tabla in $tablas; do
        mysql -u "$usuariodb" -p"$passdb" -D glpi -e "DROP TABLE $tabla;"
    done
    echo "BBDD vaciada."
}

restaurar_bbdd() {
    vaciar_bbdd
    echo "Restaurando la BBDD"
    gunzip -f "$DB_BACKUP"
    SQL_FILE="${DB_BACKUP%.gz}"
    mysql -u "$usuariodb" -p"$passdb" glpi < "$SQL_FILE"

    dialog --title "Base de Datos" \
           --msgbox "Restauración realizada correctamente" 0 0
}

restaurar_ficheros() {
    systemctl stop apache2
    tar -xzvf "$FILES_BACKUP" -C "$glpiDir"
    systemctl start apache2

    dialog --title "Archivos GLPI" \
           --msgbox "Restauración realizada correctamente" 0 0
}

# -------------------- MENÚ PRINCIPAL --------------------
while true; do
  respuesta=$(
    dialog --title "MENU: Ficheros a restaurar" \
      --stdout \
      --menu "Opciones:\n" 22 75 14 \
      1 "SOLO LA BBDD" \
      2 "SOLO LOS ARCHIVOS DE GLPI" \
      3 "AMBOS (BBDD Y ARCHIVOS)" \
      4 "Finalizar"
  )

  case $respuesta in
    1) clear; restaurar_bbdd ;;
    2) clear; restaurar_ficheros ;;
    3) clear; restaurar_bbdd; restaurar_ficheros ;;
    4) clear; exit 0 ;;
    *) cancelar ;;
  esac
done
```