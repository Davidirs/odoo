#!/bin/bash

set -e

# 1. ===== CONFIGURACIÓN DE VARIABLES DE POSTGRES =====
# - Usa PGHOST, PGPORT, etc. de Render (NO más 'db' como fallback)
: ${HOST:=${PGHOST}}  # Obligatorio en Render (sin valor por defecto 'db')
: ${PORT:=${PGPORT:-5432}}
: ${USER:=${PGUSER:-odoo}}
: ${PASSWORD:=${PGPASSWORD:-odoo}}

# 2. ===== GENERA odoo.conf DINÁMICAMENTE (opcional pero recomendado) =====
# - Esto asegura que las variables se usen incluso si odoo.conf no las tiene
cat > /etc/odoo/odoo.conf <<EOF
[options]
db_host = $HOST
db_port = $PORT
db_user = $USER
db_password = $PASSWORD
$(grep -v -E '^(db_host|db_port|db_user|db_password)' /etc/odoo/odoo.conf 2>/dev/null || echo "")
EOF

# 3. ===== PREPARA ARGUMENTOS PARA ODOO =====
DB_ARGS=()
function check_config() {
    param="$1"
    value="$2"
    if grep -q -E "^\s*\b${param}\b\s*=" "$ODOO_RC" ; then       
        value=$(grep -E "^\s*\b${param}\b\s*=" "$ODOO_RC" |cut -d " " -f3|sed 's/["\n\r]//g')
    fi;
    DB_ARGS+=("--${param}")
    DB_ARGS+=("${value}")
}
check_config "db_host" "$HOST"
check_config "db_port" "$PORT"
check_config "db_user" "$USER"
check_config "db_password" "$PASSWORD"
echo "Conectando a PostgreSQL: host=$HOST, user=$USER, db_name=${PGDATABASE:-odoo}"
# 4. ===== EJECUCIÓN DE ODOO =====
case "$1" in
    -- | odoo)
        shift
        if [[ "$1" == "scaffold" ]] ; then
            exec odoo "$@"
        else
            # Verifica conexión a PostgreSQL (opcional, puede comentarse si falla)
            wait-for-psql.py ${DB_ARGS[@]} --timeout=30
            exec odoo "$@" "${DB_ARGS[@]}"
        fi
        ;;
    -*)
        wait-for-psql.py ${DB_ARGS[@]} --timeout=30
        exec odoo "$@" "${DB_ARGS[@]}"
        ;;
    *)
        exec "$@"
esac

exit 1
