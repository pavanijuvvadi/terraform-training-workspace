#!/bin/bash

set -e

readonly FILEDIR="$(dirname "$0")"

runtest() {
    rm -rf .tox dist ecs_service_deployment_checker.egg-info
    tox
}

build() {
    # Build python2
    pex --python-shebang='/usr/bin/env python' \
        -r requirements.txt \
        --python=python2.7 \
        --platform macosx_10.12-x86_64 \
        --platform macosx_10.13-x86_64 \
        --platform macosx_10.14-x86_64 \
        --platform linux-x86_64 \
        -o dist/check-ecs-service-deployment-py27 \
        -e check_ecs_service_deployment.main \
        --disable-cache \
        .

    # Build python3
    pex --python-shebang='/usr/bin/env python' \
        -r requirements.txt \
        --python=python3.5 \
        --python=python3.6 \
        --python=python3.7 \
        --platform macosx_10.12-x86_64 \
        --platform macosx_10.13-x86_64 \
        --platform macosx_10.14-x86_64 \
        --platform linux-x86_64 \
        -o dist/check-ecs-service-deployment-py3 \
        -e check_ecs_service_deployment.main \
        --disable-cache \
        .

    cp ./dist/check-ecs-service-deployment* ../bin/
}

(cd "${FILEDIR}/check-ecs-service-deployment" && runtest)

if [[ "$1" = "--testonly" ]]; then
    exit 0
fi

(cd "${FILEDIR}/check-ecs-service-deployment" && build)
