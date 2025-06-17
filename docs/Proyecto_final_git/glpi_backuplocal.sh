#!/bin/bash

#*********Script para hacer un backup en local******************

# -------------------- CONFIGURACIÓN CAMBIAR LOS DATOS DEL USUARIO PERTINENTE--------------------
usuariodb="edu"
passdb="123"
backupDir="/home/yo/glpi_backups"
fecha=$(date +'%Y-%m-%d_%H-%M-%S')
# ------------------------------------------------------

# Crear carpeta si no existe
mkdir -p "$backupDir"

# 1. Backup de la base de datos
DB_BACKUP="$backupDir/glpi_db_$fecha.sql"
mysqldump --user="$usuariodb" --password="$passdb" glpi > "$DB_BACKUP"
gzip "$DB_BACKUP"

# 2. Backup de los archivos GLPI
GLPI_BACKUP="$backupDir/glpi_files_$fecha.tar.gz"
sudo tar -czvf "$GLPI_BACKUP" /var/www/glpi

# 3. # Con esta línea cuenta en periodos de 24 horas, o sea 2 días naturales, a partir de las 00:00 de cada día
find "$backupDir" -daystart -type f -mtime +2 -delete

echo "Copia local realizada correctamente" | logger -t glpi_backuplocal.sh

exit 0
