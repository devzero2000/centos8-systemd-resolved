#!/bin/sh
####################################
#title           :enable-systemd-resolved.sh
#description     :this is a script to configure systemd-resolved on Centos 8.3 as in Fedora 33
#author		 :Elia Pinto
#date            :20201109
#version         :0.1    
#usage		 :bash enable-systemd-resolved.sh
#notes           :Install systemd-resolved on CentOS 8.3 to use this script.
#bash_version    :version 4.4.19(1)

####################################
# taken from systemd post scriptlet
####################################
# Create /etc/resolv.conf symlink.
# We would also create it using tmpfiles, but let's do this here
# too before NetworkManager gets a chance. (systemd-tmpfiles invocation above
# does not do this, because it's marked with ! and we don't specify --boot.)
# https://bugzilla.redhat.com/show_bug.cgi?id=1873856
if systemctl -q is-enabled systemd-resolved.service &>/dev/null; then
  ln -fsv ../run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
fi

# systemd-libs post scriptlet
function mod_nss() {
    if [ -f "$1" ] ; then
        # Add nss-systemd to passwd and group
        grep -E -q '^(passwd|group):.* systemd' "$1" ||
        sed -i.bak -r -e '
                s/^(passwd|group):(.*)/\1:\2 systemd/
                ' "$1" &>/dev/null || :

        # Add nss-resolve to hosts
        grep -E -q '^hosts:.* resolve' "$1" ||
        sed -i.bak -r -e '
                s/^(hosts):(.*) files( mdns4_minimal .NOTFOUND=return.)? dns myhostname/\1:\2 files\3 resolve [!UNAVAIL=return] myhostname dns/
                ' "$1" &>/dev/null || :
    fi
}

FILE="$(readlink /etc/nsswitch.conf || echo /etc/nsswitch.conf)"
if [ "$FILE" = "/etc/authselect/nsswitch.conf" ] && authselect check &>/dev/null; then
        mod_nss "/etc/authselect/user-nsswitch.conf"
        authselect apply-changes &> /dev/null || :
else
        mod_nss "$FILE"
        # also apply the same changes to user-nsswitch.conf to affect
        # possible future authselect configuration
        mod_nss "/etc/authselect/user-nsswitch.conf"
fi

