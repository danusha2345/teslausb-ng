#!/bin/bash

declare -a urlargs
IFS='&' read -r -a urlargs <<<"$QUERY_STRING" 

declare -i len=${#urlargs[@]}
for ((i=0; i<${len}; i++ ))
do
  val="${urlargs[i]//+/ }"
  urlargs[i]="$(echo -e "${val//%/\\x}")"
done

. "$(dirname "$0")/_validate_path.sh"
validate_cgi_base
validate_cgi_operands
cd "$_CGI_BASE" || exit 1

cat << EOF
HTTP/1.0 200 OK
Content-type: text/plain

EOF
if cp "${urlargs[@]:1}"  &> /dev/null
then
  echo OK
else
  echo FAILED
fi
