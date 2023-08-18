#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'



create_iplimit_jails() {

    cat << EOF > /var/lib/docker/volumes/3x-ui_fail2ban/_data/jail.d/3x-ipl.conf
[3x-ipl]
enabled=true
filter=3x-ipl
action=3x-ipl
logpath=/var/log/3xipl.log
maxretry=2
findtime=60
bantime=5m
EOF

    cat << EOF > /var/lib/docker/volumes/3x-ui_fail2ban/_data/filter.d/3x-ipl.conf
[Definition]
datepattern = ^%%Y/%%m/%%d %%H:%%M:%%S
failregex   = \[LIMIT_IP\]\s*Email\s*=\s*<F-USER>.+</F-USER>\s*\|\|\s*SRC\s*=\s*<ADDR>
ignoreregex =
EOF

    cat << EOF > /var/lib/docker/volumes/3x-ui_fail2ban/_data/action.d/3x-ipl.conf
[INCLUDES]
before = iptables-common.conf

[Definition]
actionstart = <iptables> -N f2b-<name>
              <iptables> -A f2b-<name> -j <returntype>
              <iptables> -I <chain> -p <protocol> -j f2b-<name>

actionstop = <iptables> -D <chain> -p <protocol> -j f2b-<name>
             <actionflush>
             <iptables> -X f2b-<name>

actioncheck = <iptables> -n -L <chain> | grep -q 'f2b-<name>[ \t]'

actionban = <iptables> -I f2b-<name> 1 -s <ip> -j <blocktype>
            echo "\$(date +"%%Y/%%m/%%d %%H:%%M:%%S")   BAN   [Email] = <F-USER> [IP] = <ip> banned for <bantime> seconds." >> /var/log/3xipl-banned.log

actionunban = <iptables> -D f2b-<name> -s <ip> -j <blocktype>
              echo "\$(date +"%%Y/%%m/%%d %%H:%%M:%%S")   UNBAN   [Email] = <F-USER> [IP] = <ip> unbanned." >> /var/log/3xipl-banned.log

[Init]
EOF

    cat << EOF > /var/lib/docker/volumes/3x-ui_fail2ban/_data/action.d/iptables-common.conf
# Fail2Ban configuration file
#
# Author: Daniel Black
#
# This is a included configuration file and includes the definitions for the iptables
# used in all iptables based actions by default.
#
# The user can override the defaults in iptables-common.local
#
# Modified: Alexander Koeppe <format_c@online.de>, Serg G. Brester <serg.brester@sebres.de>
#       made config file IPv6 capable (see new section Init?family=inet6)

[INCLUDES]

after = iptables-blocktype.local
        iptables-common.local
# iptables-blocktype.local is obsolete

[Definition]

# Option:  actionflush
# Notes.:  command executed once to flush IPS, by shutdown (resp. by stop of the jail or this action)
# Values:  CMD
#
actionflush = <iptables> -F f2b-<name>


[Init]

# Option:  chain
# Notes    specifies the iptables chain to which the Fail2Ban rules should be
#          added
# Values:  STRING  Default: INPUT
chain = INPUT

# Default name of the chain
#
name = default

# Option:  port
# Notes.:  specifies port to monitor
# Values:  [ NUM | STRING ]  Default:
#
port = ssh

# Option:  protocol
# Notes.:  internally used by config reader for interpolations.
# Values:  [ tcp | udp | icmp | all ] Default: tcp
#
protocol = tcp

# Option:  blocktype
# Note:    This is what the action does with rules. This can be any jump target
#          as per the iptables man page (section 8). Common values are DROP
#          REJECT, REJECT --reject-with icmp-port-unreachable
# Values:  STRING
blocktype = REJECT --reject-with icmp-port-unreachable

# Option:  returntype
# Note:    This is the default rule on "actionstart". This should be RETURN
#          in all (blocking) actions, except REJECT in allowing actions.
# Values:  STRING
returntype = RETURN

# Option:  lockingopt
# Notes.:  Option was introduced to iptables to prevent multiple instances from
#          running concurrently and causing irratic behavior.  -w was introduced
#          in iptables 1.4.20, so might be absent on older systems
#          See https://github.com/fail2ban/fail2ban/issues/1122
# Values:  STRING
lockingopt = -w

# Option:  iptables
# Notes.:  Actual command to be executed, including common to all calls options
# Values:  STRING
iptables = iptables <lockingopt>


[Init?family=inet6]

# Option:  blocktype (ipv6)
# Note:    This is what the action does with rules. This can be any jump target
#          as per the iptables man page (section 8). Common values are DROP
#          REJECT, REJECT --reject-with icmp6-port-unreachable
# Values:  STRING
blocktype = REJECT --reject-with icmp6-port-unreachable

# Option:  iptables (ipv6)
# Notes.:  Actual command to be executed, including common to all calls options
# Values:  STRING
iptables = ip6tables <lockingopt>

EOF

    echo -e "${green}Created Ip Limit jail files with a bantime of 5 minutes.${plain}"
}

iplimit_remove_conflicts() {
    local jail_files=(
        /var/lib/docker/volumes/3x-ui_fail2ban/_data/jail.conf
        /var/lib/docker/volumes/3x-ui_fail2ban/_data/jail.local
    )

    for file in "${jail_files[@]}"; do
        # Check for [3x-ipl] config in jail file then remove it
        if test -f "${file}" && grep -qw '3x-ipl' ${file}; then
            sed -i "/\[3x-ipl\]/,/^$/d" ${file}
            echo -e "${yellow}Removing conflicts of [3x-ipl] in jail (${file})!${plain}\n"
        fi
    done
}



iplimit_remove_conflicts

create_iplimit_jails
