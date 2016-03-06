#!/bin/bash

show_aws_post_setup_commands() {
    InstanceId=$(wget -qO- http://169.254.169.254/latest/meta-data/instance-id)
    RegionName=$(wget -qO- http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/\(us-\(west\|east\)-[0-9]\)[a-z]/\1/g')

cat <<MOO

**** SHUTDOWN THE MACHINE TO RUN THE FOLLOWING COMMANDS ****

On a machine with AWS-CLI Installed you need to run the following commands to finish up.

aws ec2 modify-instance-attribute --region="${RegionName}" --instance-id ${InstanceId} --sriov-net-support simple
aws ec2 start-instances --instance-id ${InstanceId} --region="${RegionName}"
MOO
}

if [ $EUID -ne 0 ]; then
    echo "You should run this as root."
    exit 1
fi

CurrentDriverVersion=$(modinfo ixgbevf | grep '^version' | tr -d ' ' | cut -f2 -d:)
if [ "${CurrentDriverVersion}" == '2.16.4' ]; then
    echo -e "\033[33m+ \033[32mDriver is already built.  Skipping the build process.\033[0m"

    LoadedEthZeroDriverVersion=$(ethtool -i eth0 | grep '^version' | tr -d ' ' | cut -f2 -d:)
    if [ "${LoadedEthZeroDriverVersion}" == "2.16.4" ]; then
        echo "\033[33m+ \033[32mYou've already rebooted to get the new driver.  HOORAY!\033[0m"
    else
        echo -e "\033[31m! \033[35mYOU STILL NEED TO SHUTDOWN/REBOOT\033[0m"
        show_aws_post_setup_commands
    fi

    exit 0
fi

apt-get update && apt-get upgrade -y && apt-get install -y dkms

wget "sourceforge.net/projects/e1000/files/ixgbevf stable/2.16.4/ixgbevf-2.16.4.tar.gz"
tar xvf ixgbevf-2.16.4.tar.gz
mv ixgbevf-2.16.4 /usr/src
touch /usr/src/ixgbevf-2.16.4/dkms.conf

cat <<LLAMA > /usr/src/ixgbevf-2.16.4/dkms.conf
PACKAGE_NAME="ixgbevf"
PACKAGE_VERSION="2.16.4"
CLEAN="cd src/; make clean"
MAKE="cd src/; make BUILD_KERNEL=\${kernelver}"
BUILT_MODULE_LOCATION[0]="src/"
BUILT_MODULE_NAME[0]="ixgbevf"
DEST_MODULE_LOCATION[0]="/updates"
DEST_MODULE_NAME[0]="ixgbevf"
AUTOINSTALL="yes"
LLAMA

echo ""
echo -e "\033[36mDriver Information (Pre-Build)\033[0m"
echo -e "\033[36m===============================\033[0m"
modinfo ixgbevf

echo ""
dkms add -m ixgbevf -v 2.16.4
dkms build -m ixgbevf -v 2.16.4
dkms install -m ixgbevf -v 2.16.4
update-initramfs -c -k all

echo ""
echo -e "\033[36mDriver Information (Post-Build)\033[0m"
echo -e "\033[36m===============================\033[0m"
modinfo ixgbevf

echo ""
echo -e "\033[32m==========\033[0m"
echo -e "\033[32mOKAY DONE!\033[0m"
echo -e "\033[32m==========\033[0m"
echo ""

show_aws_post_setup_commands
