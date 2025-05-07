#!/bin/bash

# -------------------- CONFIGURACIÓN --------------------
usuariodb="edu"
passdb="123"
backupDir="/home/yo/glpi_backups"
fecha=$(date +'%Y-%m-%d_%H-%M-%S')

# Configuración del servidor remoto, disco externo,...
remoteUser="yo"
remoteHost="192.168.10.137"
remoteDir="/home/yo/backups_glpi"

# ------------------------------------------------------

# Crear carpeta local si no existe
mkdir -p "$backupDir"

# 1. Backup de la BBDD
DB_BACKUP="$backupDir/glpi_db_$fecha.sql"
mysqldump --user="$usuariodb" --password="$passdb" glpi > "$DB_BACKUP"
gzip "$DB_BACKUP"
DB_BACKUP="$DB_BACKUP.gz"  # Actualizamos nombre tras comprimir

# 2. Backup de los archivos GLPI
GLPI_BACKUP="$backupDir/glpi_files_$fecha.tar.gz"
tar -czvf "$GLPI_BACKUP" -C /var/www/glpi .

# 3. Identificar últimos backups (usando mapfile + ls como solicitaste)
mapfile -t db_files < <(ls -t "$backupDir"/*.sql.gz 2>/dev/null)
mapfile -t glpi_files < <(ls -t "$backupDir"/glpi_files_*.tar.gz 2>/dev/null)

# Verificar que se encontraron archivos
if [ ${#db_files[@]} -eq 0 ]; then
    exit 1
fi

if [ ${#glpi_files[@]} -eq 0 ]; then
    exit 1
fi

lastDB="${db_files[0]}"
lastGLPI="${glpi_files[0]}"

# 4. Copiar al servidor remoto vía SCP
scp "$lastDB" "$remoteUser@$remoteHost:$remoteDir"

scp "$lastGLPI" "$remoteUser@$remoteHost:$remoteDir"

# 5. Borrar backups antiguos locales de más de 15 días
find "$backupDir" -type f -mtime +15 -delete

# 5. Registrar en el log del sistema
echo "Copia local y remota realizada correctamente" | logger -t glpi_backupdual.sh

exit 0

#Crear clave publica rsa para el copiado
#sudo ssh-keygen -t rsa

#Copiar llave a servidor remoto:
#sudo ssh-copy-id remote_username@remote_IP_Address