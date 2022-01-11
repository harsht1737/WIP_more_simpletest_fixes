#!/usr/bin/env bash

# State Transfer SDDC controller - This tool helps a developer to perform command-line essential
# operations when analyzing or testing State Transfer.

# This script assumes that the output path is empty. If not, it fails with a warning.
set -eo pipefail

# For non self-explanatory commands, a comment above the command will explain how to use the command in more details
usage() {
    short_dash_line="---------------\n"
    printf "\n${short_dash_line}st-ctl usage:\n${short_dash_line}"
    printf "%s\n" " -h --help, print this message"
    printf "%s\n" " -s --set-concord-log-level <log level,string:TRACE|DEBUG|INFO|WARN|ERROR|FATAL>"
    printf "%s\n" " -c --show-concord-log-properties"
    printf "%s\n" " -m --comm-ctl <ip list,comma seperated ip list> <operation,string:down|up>"
    printf "%s\n\t%s\n" " -f --copy-from-multi <remotes source path,string> <local destination path,string> <remotes ip list,comma-seperated ip list>" \
           "<user name,string,optional,default:root> <password,string,optional,default:Bl0ckch@!n>"
    printf "%s\n\t%s\n" " -t --copy-to-multi <local source path,string> <remote destination path,string>" \
           "<remotes ip list,comma-seperated ip list> <user name,string,optional,default:root> <password,string,default:Bl0ckch@!n>"
    # install packages and create profile/bashrc files to enhance the working enviorment
    printf "%s\n" " -i --install-tools"
    printf "%s\n" " -g --gen-concord-coredump-summary <output_path,string> <container_id,12 digits string>"
    # If line number is given, version will be changed only for this line number
    printf "%s\n" " -a --agent-replace-version <current version,integer> <new version,integer> <line number,integer,optional>"
    printf "%s\n" " -v --agent-show-containers-version"
    printf "%s\n" " -r --reset-containers <agent version,integer>"
    printf "%s\n\t%s\n" " -p --compress-truncate-container-logs <container_name,string> <output_folder_path,string> <repeat_times,integer>" \
        "<wait_before_iteration,seconds,optional,default=0> <wait_after_iteration,seconds,optional,default=0>"
    printf "%s\n" " -u --truncate-container-logs <container_name,string>"
    printf "%s\n" " -k --kill-concord-process"
}

parser() {
    cmd_set_concord_log_level=false
    cmd_show_concord_log_properties=false
    cmd_comm_ctl=false
    cmd_copy_from_multi=false
    cmd_copy_to_multi=false
    cmd_install_tools=false
    cmd_gen_concord_coredump_summary=false
    cmd_agent_replace_version=false
    cmd_agent_show_containers_version=false
    cmd_reset_containers=false
    cmd_compress_truncate_container_logs=false
    cmd_truncate_container_logs=false
    cmd_kill_concord=false

    while [ "$1" ]; do
        case $1 in
        -h | --help)
        usage
        exit
        ;;

        -s | --set-concord-log-level)
        cmd_set_concord_log_level=true
        if [[ $# -lt 2 ]]; then echo "error: bad input for option -s | --set_concord_log_level!" >&2; usage; exit; fi
        concord_log_level=$2
        if [[ ! $concord_log_level = "TRACE" ]] && [[ ! $concord_log_level = "DEBUG" ]] && [[ ! $concord_log_level = "WARN" ]] && \
            [[ ! $concord_log_level = "ERROR" ]] && [[ ! $concord_log_level = "FATAL" ]] && [[ ! $concord_log_level = "INFO" ]]; then
            echo "error: bad log level $concord_log_level for option -s | --set_concord_log_level!" >&2
            usage
            exit
        fi
        break
        ;;

        -c | --show-concord-log-properties)
        cmd_show_concord_log_properties=true
        break
        ;;

        -m | --comm-ctl)
        cmd_comm_ctl=true
        if [[ $# -lt 3 ]] ; then echo "error: bad input for option -m | --comm_ctl!" >&2; usage; exit; fi
        ip_list=$2      # won't check for validity, too complicated
        operation=$3
        if [[ ! $operation = "down" ]] && [[ ! $operation = "up" ]]; then
            echo "error: bad log level $operation for option -m | --comm_ctl!" >&2
            usage
            exit
        fi
        break
        ;;

        -f | --copy-from-multi)
        cmd_copy_from_multi=true
        if [[ $# -lt 4 ]]; then echo "error: bad input for option -f | --copy_from_multi!" >&2; usage; exit; fi
        from_path=$2
        to_path=$3
        remotes_ip_list=$4
        if [[ $# -eq 4 ]] || [[ $5 == -* ]] || [ "$5" == "--*" ]; then
            user_name="root"
            password="Bl0ckch@!n"
        else
            user_name=$5
            password=$6
        fi
        break
        ;;

        -t | --copy-to-multi)
        cmd_copy_to_multi=true
        if [[ $# -lt 4 ]]; then echo "error: bad input for option -t | --copy_to_multi!" >&2; usage; exit; fi
        from_path=$2
        to_path=$3
        remotes_ip_list=$4
        if [[ $# -eq 4 ]] || [[ $5 == -* ]] || [ "$5" == "--*" ]; then
            user_name="root"
            password="Bl0ckch@!n"
        else
            user_name=$5
            password=$6
        fi
        break
        ;;

        -i | --install-tools)
        cmd_install_tools=true
        break
        ;;

        -g | --gen-concord-coredump-summary)
        cmd_gen_concord_coredump_summary=true
        if [[ $# -lt 3 ]]; then echo "error: bad input for option -g | --gen_concord_coredump_summary!" >&2; usage; exit; fi
        output_path=$2
        container_id=$3
        break
        ;;

        -a | --agent-replace-version)
        cmd_agent_replace_version=true
        if [[ $# -lt 3 ]]; then echo "error: bad input for option -a | --agent_replace_version!" >&2; usage; exit; fi
        cur_ver=$2
        new_ver=$3
        line=
        if [[ $# -eq 3 ]] || [[ $4 != -* ]] || [ "$4" != "--*" ]; then
            line=$4
        fi
        break
        ;;

        -v | --agent-show-containers-version)
        cmd_agent_show_containers_version=true
        break
        ;;

        -r | --reset-containers)
        cmd_reset_containers=true
        if [[ $# -lt 2 ]]; then echo "error: bad input for option -r | --reset_containers!" >&2; usage; exit; fi
        agent_version=$2
        break
        ;;

        -p | --compress-truncate-container-logs)
        cmd_compress_truncate_container_logs=true
        if [[ $# -lt 4 ]]; then echo "error: bad input for option -p | --compress_truncate_container_logs!" >&2; usage; exit; fi
        container_name=$2
        output_folder_path=$(realpath "$3")
        repeat_times=$4
        wait_before_iteration=0
        wait_after_iteration=0
        if [[ $# -eq 6 ]] || [[ $5 == -* ]] || [ "$5" == "--*" ]; then
            wait_before_iteration=$5
            wait_after_iteration=$6
        fi
        if [[ $# -eq 5 ]] || [[ $5 == -* ]] || [ "$5" == "--*" ]; then
            wait_before_iteration=$5
        fi
        if [ -d "${output_folder_path}" ]; then echo "${output_folder_path} already exist!"; exit 1; fi
        break
        ;;

        -u | --truncate-container-logs)
        cmd_truncate_container_logs=true
        if [[ $# -lt 2 ]]; then echo "error: bad input for option -u | --truncate-container-logs!" >&2; usage; exit; fi
        container_name=$2
        break
        ;;

        -k | --kill-concord-process)
        cmd_kill_concord=true
        break
        ;;

        *)
        echo "error: unknown input $1!" >&2
        usage
        exit
        ;;
        esac
    done
}

if [[ $# -eq 0 ]]; then
    usage
    exit 1
fi
parser "$@"

# Constants
concord_container_name="concord"
vm_agent_config_path="/config/agent/config.json"
concord_log_properties_path="/concord/resources/log4cplus.properties"
####

##########################################
# handle cmd_set_concord_log_level
##########################################
if $cmd_set_concord_log_level; then
    declare -a arr=( \
        "concord.bft.st.dst" \
        "concord.bft.st.src" \
        "concord.util.handoff" \
        "concord.bft.st.dbdatastore" \
        "concord.bft.st.inmem" \
        "concord.bft.st.rvbm" \
        # Uncomment as needed
        #"serializable" \
        #'rocksdb'
    )
    for logger in "${arr[@]}"
    do
        rc=$(docker exec -t ${concord_container_name} bash -c "grep -q \"$logger\" \"${concord_log_properties_path}\"; echo $?")
	    rc=`echo $rc | tr -d '\r'`
        if [[ "$rc" -eq 0 ]]; then
            docker exec ${concord_container_name} bash -c \
                "echo 'log4cplus.logger.$logger=${concord_log_level}' >> '${concord_log_properties_path}'"
        else
            docker exec ${concord_container_name} bash -c \
                "sed -i 's/.*${logger}.*/log4cplus.logger.$logger=${concord_log_level}/g' '${concord_log_properties_path}'"
        fi
    done
    docker exec ${concord_container_name} bash -c "cat '${concord_log_properties_path}'"
    echo "===Done!==="
fi

##########################################
# handle cmd_show_concord_log_properties
##########################################
if $cmd_show_concord_log_properties; then
    docker exec ${concord_container_name} bash -c "cat '${concord_log_properties_path}'"
fi

##########################################
# handle cmd_comm_ctl
##########################################
if $cmd_comm_ctl; then
    IFS=', ' read -r -a IPS <<< "$ip_list"
    for IP in "${IPS[@]}"; do
        if [[ "$operation" == "down" ]]; then
            CMD="-I"
            echo "blocking outgoing/incoming traffic, IP=$IP"
        else # up
            echo "Unblocking outgoing/incoming traffic, IP=$IP"
            CMD="-D"
        fi
        iptables $CMD DOCKER-USER -d "$IP" -j DROP
        iptables $CMD DOCKER-USER -s "$IP" -j DROP
    done
fi

##########################################
# handle cmd_copy_from_multi
##########################################
if $cmd_copy_from_multi; then
    IFS=', ' read -r -a remote_ips <<< "$remotes_ip_list"
    i=0
    for remote_ip in "${remote_ips[@]}"; do
        echo "copying from $remote_ip.."
        sshpass -p "${password}" \
            scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -r \
            "${user_name}@${remote_ip}:${from_path}" "${to_path}" &
        pids[${i}]=$!
        ((i = i + 1))
    done

    # wait for all pids
    for pid in ${pids[*]}; do
        wait $pid
    done
    echo "===Done!==="
fi

##########################################
# handle cmd_copy_to_multi
##########################################
if $cmd_copy_to_multi; then
    IFS=', ' read -r -a remote_ips <<< "$remotes_ip_list"
    i=0
    for remote_ip in "${remote_ips[@]}"; do
        sshpass -p ${password} rsync  -avuq -e 'ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null' \
            "${from_path}" "${user_name}@${remote_ip}:${to_path}" &
        pids[${i}]=$!
        ((i = i + 1))
    done

    # wait for all pids
    for pid in ${pids[*]}; do
        wait $pid
    done
    echo "===Done!==="
fi

##########################################
# handle cmd_install_tools
##########################################
if $cmd_install_tools; then
rm -rf ~/.tmux.conf ~/.profile

cat <<EOF > ~/.tmux.conf
# Scroll History
set-option -g history-limit 10000000
# Set ability to capture on start and restore on exit window data when running an application
setw -g alternate-screen on

# Lower escape timing from 500ms to 50ms for quicker response to scroll-buffer access.
set -s escape-time 50

set-option -g mouse on
setw -g alternate-screen on
EOF

sed -i "s/^TMOUT=.*$/TMOUT=9000000/g" /etc/bash.bashrc
sed -i "s/^readonly TMOUT$/#readonly TMOUT/g" /etc/bash.bashrc
sed -i "s/^export TMOUT$/#export TMOUT/g" /etc/bash.bashrc

sed -i "s/^TMOUT=.*$/TMOUT=9000000/g" /etc/profile.d/tmout.sh
sed -i "s/^readonly TMOUT$/#readonly TMOUT/g" /etc/profile.d/tmout.sh
sed -i "s/^export TMOUT$/#export TMOUT/g" /etc/profile.d/tmout.sh

rpm -i https://packages.vmware.com/photon/3.0/photon_release_3.0_x86_64/x86_64/nano-3.0-1.ph3.x86_64.rpm || true
rpm -i https://packages.vmware.com/photon/3.0/photon_release_3.0_x86_64/x86_64/tmux-2.7-1.ph3.x86_64.rpm || true

cd /root/
rm -rf ./lnav-0.9.0 ./lnav-0.9.0-musl-64bit.zip
wget https://github.com/tstack/lnav/releases/download/v0.9.0/lnav-0.9.0-musl-64bit.zip
unzip lnav-0.9.0-musl-64bit.zip
mv lnav-0.9.0/lnav /usr/bin/
rm -rf ./lnav-0.9.0 ./lnav-0.9.0-musl-64bit.zip

cat <<EOF >> ~/.profile
alias myip="echo $(ifconfig | grep "10\.202" | cut -d ":" -f 2 | cut -d " " -f 1)"
alias ll="ls -la"
alias cd_grep_log_full="docker logs concord | grep -ia"
alias cd_grep_log_tail="docker logs concord --tail 10 -f | grep -ia"

alias cd_login="docker exec -it concord /bin/bash"
alias cd_logs_zip="docker logs concord | zip -9 log.zip -"
alias myid="ls /config/concord/config-generated/ 2> /dev/null | cut -d "." -f 2"
alias cd_truncate='truncate -s 0 $(docker inspect --format='{{.LogPath}}' concord)'

export PATH="$PATH:/root"
fagent_change_config_ver() {
    if [[ $# -ne 2 ]]; then echo "usage: agent_change_config_ver <old_ver> <new_ver>"; return; fi
    sed -i 's/$1/$2/g' /config/agent/config.json
}

fdocker_truncate_logs() {
    if [[ $# -ne 1 ]]; then echo "usage: cd_docker_truncate_logs <container_name>"; return; fi
    truncate -s 0 $(docker inspect --format='{{.LogPath}}' $1)
}
# If set, Bash checks the window size after each command and, if necessary, updates the values of LINES and COLUMNS
shopt -u checkwinsize
export PS1="\e[0;31m[\w][id_\$(myid || "")][ip_\$(myip)]\e[m > "
EOF

# inside concord container
docker exec -it ${concord_container_name} bash -c "apt update && apt install nano -y"  >/dev/null 2>&1 || true
echo "Done Installing tools, please log in and out"
fi

##########################################
# handle cmd_gen_concord_coredump_summary
##########################################
if $cmd_gen_concord_coredump_summary; then
    myip=$(ifconfig | grep "10\." | cut -d ":" -f 2 | cut -d " " -f 1)
    output_file="${output_path}/cores_summary_${myip}.log"
    rm -f "${output_file}" || true 2> /dev/null
    mkdir -p ${output_path}
    echo "Generating output file (this may take some time) ..."
    docker exec -it "${container_id}" bash -c \
        'for filename in /concord/cores/core.concord*; do echo "***bt for ${filename}:***"; echo "set pagination off" > ~/.gdbinit; gdb concord ${filename} -ex bt -ex quit; done' >> "${output_file}"
    echo "Done generating summary under ${output_file}"
fi

##########################################
# handle cmd_agent_replace_version
##########################################
if $cmd_agent_replace_version; then
    echo "Before changing version:"
    grep -r "${cur_ver}" ${vm_agent_config_path}

    echo "Changing version:"
    set -x
    sed -i "${line}s/0.0.0.0.${cur_ver}/0.0.0.0.${new_ver}/" ${vm_agent_config_path}
    set +x

    echo "After changing version:"
    grep -r "${new_ver}" $vm_agent_config_path

    echo "Done changing version"
fi

##########################################
# handle cmd_agent_show_containers_version
##########################################
if $cmd_agent_show_containers_version; then
    echo "Agent configured versions:"
    grep -rn "vmwblockchain" ${vm_agent_config_path}
fi

##########################################
# handle cmd_reset_containers
##########################################
if $cmd_reset_containers; then
    agent_full_version=0.0.0.0.${agent_version}
    docker stop $(docker ps -a -q) || true
    docker rm -f $(docker ps -a -q) || true
    rm -rf /config/daml-index-db/*
    rm -rf /config/concord/config-generated/*
    rm -rf /mnt/data/db/*
    rm -rf /mnt/data/rocksdbdata/*
    docker volume prune -f || true
    docker run -d --name=agent --restart=always \
                        --network=blockchain-fabric \
                        -p 127.0.0.1:8546:8546 \
                        -v /config:/config -v /var/run/docker.sock:/var/run/docker.sock \
                        blockchain-docker-internal.artifactory.eng.vmware.com/vmwblockchain/agent:${agent_full_version}
    echo "===Done!==="
fi

##########################################
# handle cmd_compress_truncate_container_logs
##########################################
if $cmd_compress_truncate_container_logs; then
    mkdir -p "${output_folder_path}"
    for (( c=1; c <= repeat_times; c++ )); do
        if [[ ${wait_before_iteration} -gt 0 ]]; then echo "sleeping ${wait_after_iteration} seconds (before).."; sleep "${wait_before_iteration}"; fi
        raw_log_path="${output_folder_path}/${container_name}_${c}.log"
        docker logs "${container_name}" > "${raw_log_path}"
        truncate -s 0 $(docker inspect --format='{{.LogPath}}' ${container_name})
        cd "${output_folder_path}"
        echo "${container_name} log truncated!" && date
        output_zip_file_name="${output_folder_path}/log_n${c}_$(date +"%Y_%m_%d_%R:%S").zip"
        zip -9 "${output_zip_file_name}" "${raw_log_path}"
        rm -rf "${raw_log_path}"
        if [[ ${wait_after_iteration} -gt 0 ]]; then echo "sleeping ${wait_after_iteration} seconds (after).."; sleep "${wait_after_iteration}"; fi
    done
    echo "===Done!==="
fi

##########################################
# handle cmd_truncate_container_logs
##########################################
if $cmd_truncate_container_logs; then
    truncate -s 0 "$(docker inspect --format='{{.LogPath}}' ${container_name})"
    echo "===Done!==="
fi

##########################################
# handle cmd_kill_concord
##########################################
if $cmd_kill_concord; then
    killall concord
    echo "===Done!==="
fi
