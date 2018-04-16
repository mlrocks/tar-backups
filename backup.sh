#!/usr/bin/env bash
#
# @author Martin Loehle (martin@loehle.rocks)
#

#
# start
#
START_DATE=`date +%c`
echo "starting backup: ${START_DATE}"
BASEDIR=$(dirname "$0")


#
# nicer echo output
#
function echo_green() {
        local text=$1
        echo -e "\033[40;1;32m$text\033[0m"
}

function echo_red() {
        local text=$1
        echo -e "\033[40;1;31m$text\033[0m"
}

#
# source in the config file
#
CONF_SOURCE="config.source"
if [ -e $BASEDIR/${CONF_SOURCE} ]; then
  . $BASEDIR/$CONF_SOURCE
else
  echo_red "file $BASEDIR/${CONF_SOURCE} not found!"
  echo_red "add the file $BASEDIR/${CONF_SOURCE} and set your variables."
  echo_red "exiting..."
  exit 1
fi


#
# variables
#
DATE=`date +%Y_%m_%d`

DB_DUMP_FILENAME="${DB_NAME}_${DATE}.sql"
DB_DUMP_FILE="${DESTINATION_DIR}/${DB_DUMP_FILENAME}"

TAR_FILENAME="${DATE}.tar.gz"
TAR_FILE="${DESTINATION_DIR}/${TAR_FILENAME}"


#
# dump database
#
if [ "${DB_TYPE}" == "mysql" ]; then
    echo -n "dump mysql db... "
    mysqldump --user=${DB_USER}                             \
              --password=${DB_PASSWORD}                     \
              ${DB_NAME}                                    \
              > ${DB_DUMP_FILE}                             \
              2>/dev/null
    if [ "$?" -eq 0 ]; then
        echo_green "OK"
    else
        echo_red "FAILED"
    fi

elif [ "${DB_TYPE}" == "postgres" ]; then
    echo -n "dump postgres db... "
    pg_dump --no-acl                                        \
            --no-owner                                      \
            --username=${DB_USER}                           \
            --no-password                                   \
            ${DB_NAME}                                      \
            > ${DB_DUMP_FILE}                               \
            2>/dev/null

    if [ "$?" -eq 0 ]; then
        echo_green "OK"
    else
        echo_red "FAILED"
    fi

else
    echo "no database selected!"
fi


#
# create tar file
#
echo -n "create tar file... "
if [ "${DB_TYPE}" == "mysql" ] || [ "${DB_TYPE}" == "postgres" ]; then
    SOURCE="${SOURCE_DIRS} ${DB_DUMP_FILE}"
else
    SOURCE="${SOURCE_DIRS}"
fi

tar -cpzPf ${TAR_FILE}                                      \
    --directory=/                                           \
    ${SOURCE}

if [ "$?" -eq 0 ]; then
    echo_green "OK"
else
    echo_red "FAILED"
fi


#
# upload to storage box
#
echo -n "upload to storage box... "
scp ${TAR_FILE} ${SB_USER}@${SB_USER}.your-storagebox.de:daily_${TAR_FILENAME}

if [ "$?" -eq 0 ]; then
    echo_green "OK"
else
    echo_red "FAILED"
fi


#
# remove local backup files
#
if [ "${DB_TYPE}" == "mysql" ] || [ "${DB_TYPE}" == "postgres" ]; then
    echo -n "remove db-dump file... "
    rm $DB_DUMP_FILE

    if [ "$?" -eq 0 ]; then
        echo_green "OK"
    else
        echo_red "FAILED"
    fi
fi

echo -n "remove tar file... "
rm $TAR_FILE

if [ "$?" -eq 0 ]; then
    echo_green "OK"
else
    echo_red "FAILED"
fi


#
# done
#
END_DATE=`date +%c`
echo "finished backup: ${END_DATE}"
