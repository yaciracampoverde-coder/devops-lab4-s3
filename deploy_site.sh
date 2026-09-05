#!/usr/bin/env bash
set -euo pipefail

BUCKET="${1:?Uso: $0 <bucket> <carpeta> [region]}"
SRC="${2:?Uso: $0 <bucket> <carpeta> [region]}"
REGION="${3:-${REGION:-us-east-1}}"

[[ -d "$SRC" ]] || { echo "La carpeta '$SRC' no existe"; exit 3; }
aws.exe sts get-caller-identity >/dev/null || { echo "No autenticado. Ejecuta aws.exe configure"; exit 2; }

if aws.exe s3api head-bucket --bucket "$BUCKET" >/dev/null 2>&1; then
  echo "Bucket $BUCKET ya existe, reutilizando"
else
  echo "Creando bucket $BUCKET en $REGION"
  aws.exe s3 mb "s3://$BUCKET" --region "$REGION"
fi

echo "Configurando acceso público"
aws.exe s3api put-public-access-block --bucket "$BUCKET" \
  --public-access-block-configuration \
  "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false"

aws.exe s3api put-bucket-policy --bucket "$BUCKET" --policy "$(cat <<JSON
{"Version":"2012-10-17","Statement":[{"Sid":"PublicReadGetObject","Effect":"Allow","Principal":"*","Action":"s3:GetObject","Resource":"arn:aws:s3:::$BUCKET/*"}]}
JSON
)"

echo "Sincronizando $SRC"
aws.exe s3 sync "$SRC/" "s3://$BUCKET/" --delete

aws.exe s3 website "s3://$BUCKET/" --index-document index.html --error-document error.html


SITE_URL="${SITE_URL_OVERRIDE:-http://$BUCKET.s3-website-$REGION.amazonaws.com}"

printf '\n✅ Sitio desplegado: %s\n' "$SITE_URL"
curl.exe -s -o /dev/null -w "   HTTP %{http_code}\n" "$SITE_URL"

