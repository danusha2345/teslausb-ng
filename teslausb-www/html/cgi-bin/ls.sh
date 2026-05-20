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
cd "$_CGI_BASE" || exit

# ${*:1} (not ${@:1}) joins remaining args into a single string via IFS[0];
# the rest of this script treats lspath as a single path argument to find.
lspath="${urlargs[*]:1}"
if [[ -z "$lspath" ]]
then
  lspath=.
fi

cat << EOF
HTTP/1.0 200 OK
Content-type: text/plain

EOF
{
  find "$lspath" -mindepth 1 -maxdepth 1 \( -type d -printf 'd:%p\n' \) -o -printf "f:%p:%s\n"
  find "$lspath" -mindepth 2 -maxdepth 2 \( -type d -printf 'D:%p\n' -prune \)
  eval "$(stat --file-system --format="echo s:\$((%f*%S)):\$((%b*%S))" "$lspath/.")"
} | sed 's/:\.\//:/' | LC_ALL=C sort -f
