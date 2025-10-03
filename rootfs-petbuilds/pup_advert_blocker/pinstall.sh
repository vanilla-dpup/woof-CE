sed -i 's/ dns$/ adlist dns/g' etc/nsswitch.conf

rm -f etc/resolv.conf
cp -f /etc/resolv.conf etc/resolv.conf
chroot . pup-advert-blocker update
rm -f etc/resolv.conf
