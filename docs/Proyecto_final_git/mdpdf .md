```bash
#!/bin/bash

#Script que convierte un archivo Markdown a PDF con formato específico
# Verificar que se pasó al menos un argumento
if [ $# -ne 1 ]; then
  echo "Uso: $0 nombre_base (por ejemplo: proyecto)"
  exit 1
fi

# Asignar nombre base
BASENAME="$1"
INPUT="${BASENAME}.md"
OUTPUT="${BASENAME}.pdf"

# Ejecutar Pandoc con las opciones deseadas
pandoc "$INPUT" -o "$OUTPUT" \
  --from markdown \
  --template eisvogel.latex \
  --pdf-engine=lualatex \
  --listings \
  --toc --toc-depth=5

# Mensaje de éxito
echo "PDF generado: $OUTPUT"

exit 0
```
