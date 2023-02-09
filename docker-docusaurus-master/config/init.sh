#!/usr/bin/env bash

msg() {
    echo -E "/* $1 */"
}

find_autoupdate_cron_jobs() {
    local auto_update_jobs=0

    while read -r line; do
        [[ $line == *"auto_update_job"* ]] && (( auto_update_jobs++ ))
    done

    echo $auto_update_jobs
}

DOCU_PATH="/docusaurus"
WEB_SRC_PATH="$DOCU_PATH"/website
AUTO_UPD_CRONTAB_PATH="/auto_update_crontab.txt"

echo -e "Variables:
\\t- UID=${TARGET_UID}
\\t- GID=${TARGET_GID}
\\t- AUTO_UPDATE=${AUTO_UPDATE}
\\t- WEBSITE_NAME=${WEBSITE_NAME}
\\t- TEMPLATE=${TEMPLATE}
\\t- RUN_MODE=${RUN_MODE}"

[[ -z "$WEBSITE_NAME" ]] && \
    msg "You have to enter your website name. Program will be closed." && exit

if [[ "$AUTO_UPDATE" == true ]]; then
    msg "Register a new cron job for auto updating..."
    cat "$AUTO_UPD_CRONTAB_PATH" >> /etc/crontabs/root
    if [[ $(find_autoupdate_cron_jobs < <(crontab -l)) -gt 0 ]]; then
        msg "Successfully registered."
    else
        msg "Register failed with unknown problem. Please issue this on my Github repository."
    fi
fi

if [[ ! -d "$DOCU_PATH"/"$WEBSITE_NAME" ]]; then
    msg "Install docusaurus..."
    npx @docusaurus/init@latest init "$WEBSITE_NAME" "$TEMPLATE" &
    [[ "$!" -gt 0 ]] && wait $!
    ln -s "$DOCU_PATH"/"$WEBSITE_NAME" "$WEB_SRC_PATH"
    chown -R "$TARGET_UID":"$TARGET_GID" "$DOCU_PATH"
else
    msg "Docusaurus configuration already exists in the target directory $DOCU_PATH"
fi

if [[ ! -d "$DOCU_PATH"/"$WEBSITE_NAME"/node_modules ]]; then
    msg "Installing node modules..."
    cd "$DOCU_PATH"/"$WEBSITE_NAME"
    yarn install &
    [[ "$!" -gt 0 ]] && wait $!
    cd ..
    ln -sf "$DOCU_PATH"/"$WEBSITE_NAME" "$WEB_SRC_PATH"
    chown -R "$TARGET_UID":"$TARGET_GID" "$DOCU_PATH"
else
    msg "Node modules already exist in $DOCU_PATH/$WEBSITE_NAME/node_modules"
fi

if [[ "$RUN_MODE" != "development" ]]; then
    msg "Other mode is not supported yet. It will run as a development mode."
fi

msg "Start supervisord to start Docusaurus..."
supervisord -c /etc/supervisor/conf.d/supervisord.conf

