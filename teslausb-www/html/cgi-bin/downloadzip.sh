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
echo "HTTP/1.0 200 OK"
echo "Content-type: application/zip"
echo
for i in "${urlargs[@]:1}"
do
  echo "$i"
done | zip -r -0 - -@ 2> /tmp/zipout.txt
