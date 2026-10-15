#!/usr/bin/env bash
# Batería de verificación con curl contra la API real (uvicorn en :8099).
# Uso:  bash verificacion/run-curl.sh
set -u

BASE="${BASE:-http://localhost:8098}"
DIR="$(cd "$(dirname "$0")" && pwd)"
LOG="$DIR/salidas.txt"
DIA=$(date -d "+3 days" +%Y-%m-%d)
PASADO=$(date -d "-1 day" +%Y-%m-%d)
: > "$LOG"

LAST_BODY=""
LAST_CODE=""

req() {  # label method path [json] [token]
  local label="$1" method="$2" path="$3" data="${4:-}" token="${5:-}"
  local args=(-s -w '\n__HTTP__%{http_code}')
  [ -n "$token" ] && args+=(-H "Authorization: Bearer $token")
  [ -n "$data" ] && args+=(-H "Content-Type: application/json" -d "$data")
  local out
  out=$(curl "${args[@]}" -X "$method" "$BASE$path")
  LAST_CODE="${out##*__HTTP__}"
  LAST_BODY="${out%__HTTP__*}"
  {
    echo "--------------------------------------------------------------------"
    echo "# $label"
    echo "\$ curl -X $method $path"
    if [ -n "$token" ]; then echo "  -H 'Authorization: Bearer <token>'"; fi
    if [ -n "$data" ]; then echo "  -d '$data'"; fi
    echo "--> HTTP $LAST_CODE"
    printf '%s' "$LAST_BODY" | python3 -m json.tool 2>/dev/null || printf '%s\n' "$LAST_BODY"
  } | tee -a "$LOG"
}

json_get() { printf '%s' "$LAST_BODY" | python3 -c "import sys,json;print(json.load(sys.stdin)$1)"; }

echo "### Verificación curl - ClubSebastianMartinezAmaray API - $(date -Iseconds)" | tee -a "$LOG"
echo "### Fecha futura usada: $DIA | Fecha pasada: $PASADO" | tee -a "$LOG"

# --- Estado ----------------------------------------------------------------
req "Healthcheck" GET /health

# --- Autenticación ---------------------------------------------------------
REG='{"email":"maria@club.com","password":"Secreta123","first_name":"Maria","last_name":"Lopez","birth_date":"1996-03-08"}'
req "Registro de usuario (201)" POST /auth/register "$REG"
req "Registro con correo repetido (409)" POST /auth/register "$REG"

req "Login correcto (200)" POST /auth/login '{"email":"maria@club.com","password":"Secreta123"}'
TOKEN=$(json_get "['access_token']")
echo "### token obtenido (primeros 30): ${TOKEN:0:30}..." | tee -a "$LOG"

req "Login con contraseña incorrecta (401)" POST /auth/login '{"email":"maria@club.com","password":"mala"}'
req "Login con correo inexistente (401, mismo cuerpo)" POST /auth/login '{"email":"nadie@club.com","password":"mala"}'

# --- Perfil ----------------------------------------------------------------
req "Mi perfil (GET)" GET /users/me "" "$TOKEN"
req "Editar perfil (PATCH, nombre y fecha)" PATCH /users/me '{"first_name":"María","birth_date":"1996-03-08"}' "$TOKEN"
req "Intentar cambiar el correo (400)" PATCH /users/me '{"email":"otro@club.com"}' "$TOKEN"

# --- Sedes y espacios ------------------------------------------------------
req "Listado de sedes con horarios" GET /venues
req "Espacios de la sede 1" GET /venues/1/spaces
req "Espacios filtrados por tipo=Paddle" GET "/spaces?type=Paddle"
req "Disponibilidad de la sede 1 para $DIA" GET "/venues/1/availability?date=$DIA"
SPACE_ID=$(json_get "['spaces'][0]['space']['id']")
echo "### espacio elegido: id=$SPACE_ID" | tee -a "$LOG"

# --- Reservas --------------------------------------------------------------
RESERVA="{\"sport_space_id\":$SPACE_ID,\"date\":\"$DIA\",\"start_time\":\"10:00:00\",\"end_time\":\"11:00:00\"}"
req "Crear reserva válida (201)" POST /reservations "$RESERVA" "$TOKEN"
RESERVA_ID=$(json_get "['id']")
echo "### reserva creada: id=$RESERVA_ID" | tee -a "$LOG"

req "Reserva superpuesta al 10:00-11:00: se pide 10:00-12:00 (409)" POST /reservations \
  "{\"sport_space_id\":$SPACE_ID,\"date\":\"$DIA\",\"start_time\":\"10:00:00\",\"end_time\":\"12:00:00\"}" "$TOKEN"

req "Duración menor a una hora: 18:00-18:30 (400)" POST /reservations \
  "{\"sport_space_id\":$SPACE_ID,\"date\":\"$DIA\",\"start_time\":\"18:00:00\",\"end_time\":\"18:30:00\"}" "$TOKEN"

req "Minutos distintos de 00: 18:30-20:00 (400)" POST /reservations \
  "{\"sport_space_id\":$SPACE_ID,\"date\":\"$DIA\",\"start_time\":\"18:30:00\",\"end_time\":\"20:00:00\"}" "$TOKEN"

req "Fuera del horario de la sede: 06:00-07:00 (400)" POST /reservations \
  "{\"sport_space_id\":$SPACE_ID,\"date\":\"$DIA\",\"start_time\":\"06:00:00\",\"end_time\":\"07:00:00\"}" "$TOKEN"

req "Reserva en el pasado: $PASADO 10:00-11:00 (400)" POST /reservations \
  "{\"sport_space_id\":$SPACE_ID,\"date\":\"$PASADO\",\"start_time\":\"10:00:00\",\"end_time\":\"11:00:00\"}" "$TOKEN"

req "Listar mis reservas vigentes" GET /reservations "" "$TOKEN"

req "Cancelar la reserva (200)" POST "/reservations/$RESERVA_ID/cancel" "" "$TOKEN"
req "Volver a reservar el mismo horario tras cancelar (201)" POST /reservations "$RESERVA" "$TOKEN"
req "Historial (incluye la cancelada)" GET /reservations/history "" "$TOKEN"

# --- Recuperación de contraseña -------------------------------------------
req "Pedir token de recuperación (DEBUG=true lo devuelve)" POST /auth/forgot-password '{"email":"maria@club.com"}'
RESET_TOKEN=$(json_get ".get('reset_token') or ''")
req "Restablecer contraseña con el token (200)" POST /auth/reset-password \
  "{\"token\":\"$RESET_TOKEN\",\"new_password\":\"NuevaClave123\"}"
req "Login con la contraseña nueva (200)" POST /auth/login '{"email":"maria@club.com","password":"NuevaClave123"}'
req "Reusar el token de recuperación (400)" POST /auth/reset-password \
  "{\"token\":\"$RESET_TOKEN\",\"new_password\":\"OtraClave123\"}"

# --- Errores de transporte -------------------------------------------------
req "Ruta inexistente (404)" GET /no-existe
req "Sin token (401)" GET /users/me

echo "" | tee -a "$LOG"
echo "### Fin de la batería. Salidas guardadas en $LOG" | tee -a "$LOG"
