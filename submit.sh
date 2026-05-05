#!/bin/bash
source ~/.pbsrc

sed -e "s/PBS_EMAIL/${PBS_EMAIL}/" \
    -e "s/PROJECT_NAME/${PROJECT_NAME}/" \
    -e "s|GRAPEVINE_PATH_PBS|${GRAPEVINE_PATH}|g" \
    "${1}" | qsub
