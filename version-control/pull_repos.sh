#!/bin/bash

#
# This is script is written to fetch and keep updated GIT repositories.
# Bear in mind, that before repo pull, hard reset will be done for two reasons:
#   1) to reset local changes and avoid mess with main stream
#   2) makes a habit to submit changes immedeately, mostly applies to password databases)
#


#
# 2021 09 00  + init /A
# 2022 03 19  * this script is written to hard reset repositories and pull
# 2022 08 05  * changed message /A
# 2023-01-17  * adapted for new structure /A
# 2023-05-23  + show repo's path /A
#             - disabled hard reset /A
# 2024-05-06  * moved public, as seen helpful for daily works /A
#

#
# Logic:
#
#  path1
#    \____host1
#           \____repo1
#           \____repo2
#           \____repo3
#  path2
#    \____host1
#    |      \____repo1
#    |      \____repo2
#    |      \____repo3
#    \____host2
#           \____repo1
#           \____repo2
#           \____repo3
#           \____repo4
#           \____repo5
#

# TODO:
# 2022-09-06  + check existance of repo, before git reset and pull


# location for github repositories hosts

paths=(
    '/Users/anton/dox-w/path-to-repos/'
)

for path in "${paths[@]}" ; do
    printf "\n\nPath: [${path}]"
    if [[ -d "${path}" ]]
    then
        printf "\n\nPath: [${path}] exists."
        cd ${path}
        for host in */ ; do
            printf "\n\n\nHost: [${host}]:"
            cd ${host}
            for repo in */ ; do
                printf "\nRepo: [${repo}]:"
                cd ${repo}
                printf "\nPath: [$(pwd)]:"
                # disabled reset for a while
                # git reset --hard
                git pull --ff-only
                cd ..
            done
            cd ..
        done
    fi
done
