```bash
#!/bin/bash

# -------------------- CONFIGURACIÓN --------------------
usuariodb="usuario-BBDD"
passdb="password"
backupDir="/home/usuario_local/glpi_backups"
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
tar -czvf "$GLPI_BACKUP" -C /var/www/glpi .

# 3. Borrar backups antiguos de más de 15 días
find "$backupDir" -type f -mtime +15 -delete

echo "Copia local realizada correctamente" | logger -t glpi_backuplocal.sh

exit 0
```
