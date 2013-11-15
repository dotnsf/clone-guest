#!/bin/sh

work_dir=/tmp/clone-guest

cmd_awk=/bin/awk
cmd_cat=/bin/cat
cmd_cut=/bin/cut
cmd_grep=/bin/grep
cmd_mkdir=/bin/mkdir
cmd_sed=/bin/sed
cmd_uuidgen=/usr/bin/uuidgen
cmd_virsh=/usr/bin/virsh
cmd_virt_cat=/usr/bin/virt-cat
cmd_virt_clone=/usr/bin/virt-clone
cmd_virt_copy_in=/usr/bin/virt-copy-in

original_domain_name=$1
source_bridge=br0
clone_domain_name=$2

domain_image_dir=/var/lib/libvirt/images
clone_domain_image_path=$domain_image_dir/$clone_domain_name


# --- pre process.
if [ "$clone_domain_name" = "" ] ; then
echo "Usage: clone-guest.sh <domain_name> <clone_name>"
exit 0
fi

[ ! -e $work_dir ] && $cmd_mkdir -p $work_dir


# --- virt-clone
$cmd_virt_clone \
  --original $original_domain_name \
  --name $clone_domain_name \
  --file $clone_domain_image_path 

# --- /etc/sysconfig/network-scripts/ifcfg-eth0
$cmd_virt_cat -d $original_domain_name \
  /etc/sysconfig/network-scripts/ifcfg-eth0 \
  > $work_dir/ifcfg-eth0.org
original_mac_addr=$( \
$cmd_virsh domiflist $original_domain_name \
| $cmd_grep $source_bridge \
| $cmd_awk '{print $5}' \
)
clone_mac_addr=$( \
$cmd_virsh domiflist $clone_domain_name \
| $cmd_grep $source_bridge \
| $cmd_awk '{print $5}' \
)

original_nic_uuid=$( \
$cmd_cat $work_dir/ifcfg-eth0.org \
| $cmd_grep -i uuid \
| $cmd_cut -d'=' -f2 \
| $cmd_sed 's/"//g' \
)
clone_nic_uuid=$($cmd_uuidgen)

#$cmd_virt_cat -d $original_domain_name \
#  /etc/sysconfig/network-scripts/ifcfg-eth0 \
#  > $work_dir/ifcfg-eth0.org
$cmd_cat $work_dir/ifcfg-eth0.org \
| $cmd_sed -e "s/$original_mac_addr/$clone_mac_addr/i" \
-e "s/$original_nic_uuid/$clone_nic_uuid/i" \
> $work_dir/ifcfg-eth0
$cmd_virt_copy_in -d $clone_domain_name \
  $work_dir/ifcfg-eth0 \
  /etc/sysconfig/network-scripts/

# --- /etc/udev/rules.d/70-persistent-net.rules
$cmd_virt_cat -d $original_domain_name \
  /etc/udev/rules.d/70-persistent-net.rules \
  > $work_dir/70-persistent-net.rules.org
$cmd_cat $work_dir/70-persistent-net.rules.org \
  | $cmd_sed "s/$original_mac_addr/$clone_mac_addr/i" \
  > $work_dir/70-persistent-net.rules
$cmd_virt_copy_in -d $clone_domain_name \
  $work_dir/70-persistent-net.rules \
  /etc/udev/rules.d/



