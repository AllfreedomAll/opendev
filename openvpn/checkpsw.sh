#!/bin/sh
PASSFILE="/etc/openvpn/password_file"
pwdExist=`grep -c "${password}" ${PASSFILE}`
if [ "${pwdExist}" = "1" ]; then
  exit 0
fi
exit 1

