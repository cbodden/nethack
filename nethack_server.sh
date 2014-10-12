#!/usr/bin/env bash

OS=$(grep ^NAME /etc/os-release | cut -d= -f2 | sed 's/"//g')
DOMAIN="SET THIS TO YOUR NETHACK SERVER ADDRESS"
# DOMAIN="nethack.alt.org"
LPATH="~/nhsh"
TMP_FILE=$(mktemp --tmpdir nhsh.$$.XXXXXXXXXX)
trap 'printf "${NAME}: Quitting.\n\n" 1>&2 ; \
   rm -rf ${TMP_FILE} ; exit 1' 0 1 2 3 9 15

case "${OS}" in
  'CentOS') ;;
  'Gentoo')
    sudo emerge -v sys-devel/autoconf sys-devel/bison sys-devel/flex \
      dev-vcs/git sys-apps/groff sys-libs/ncurses net-misc/netkit-telnetd \
      dev-db/sqlite sys-apps/xinetd ;;
  'Ubuntu')
    sudo apt-get update
    sudo apt-get install -y autoconf bison build-essential bsdmainutils \
      flex gcc git groff libncursesw5-dev libsqlite3-dev make ncurses-dev \
      sqlite3 tar telnetd-ssl xinetd
    sudo apt-get clean ;;
  *) exit 1 ;;
esac

mkdir -p ${LPATH} ; cd ${LPATH}

## dgamelaunch install section
git clone git://github.com/paxed/dgamelaunch.git
cd dgamelaunch
sed -i -e "s/-lrt/-lrt -pthread/" configure.ac
sed -i \
  -e "/^maxnicklen/s/=.*/= 20/" \
  -e "/game_\(path\|args\)/s/nethack/nethack.343-nao/" \
  -e "/^commands\[\(register\|login\)\]/s/=\(.*\)/= mkdir \"%ruserdata\/%N\",\n\1/" \
  -e "s:/%n:/%N/%n:" \
  -e "s/nethack.alt.org/${DOMAIN}/g" examples/dgamelaunch.conf
sed -i -e "s/nethack.alt.org/${DOMAIN}/g" dgl-create-chroot

./autogen.sh \
  --enable-sqlite \
  --enable-shmem \
  --with-config-file=/opt/nethack/${DOMAIN}/etc/dgamelaunch.conf

make
sudo ./dgl-create-chroot
cd ..
rm -rf dgamelaunch

## nh343-nao install section
git clone http://alt.org/nethack/nh343-nao.git
cd nh343-nao
sed -i -e "/^CFLAGS/s/-O/-O2 -fomit-frame-pointer/" sys/unix/Makefile.src
sed -i \
  -e "/rmdir \.\/-p/d" \
  -e "/^PREFIX/s/nethack.alt.org/${DOMAIN}/" sys/unix/Makefile.top
sed -i -e "/^CFLAGS/s/-O/-O2 -fomit-frame-pointer/" sys/unix/Makefile.utl
make all
sudo make install
cd ..
rm -rf nh343-nao

sudo touch /opt/nethack/${DOMAIN}/nh343/perm
sudo mkdir /opt/nethack/${DOMAIN}/nh343/save
sudo chmod 777 /opt/nethack/${DOMAIN}/nh343/save

case "${OS}" in
  'CentOS') ;;
  'Gentoo')
    tar cf - /usr/lib64/libncurses* |\
      sudo tar xf - -C /opt/nethack/${DOMAIN}/ ;;
  'Ubuntu')
    tar cf - /lib/x86_64-linux-gnu/libncurses* |\
      sudo tar xf - -C /opt/nethack/${DOMAIN}/ ;;
esac

if [[ ! -e /etc/xinet.d/nethack ]]; then
  echo "service telnet
{
  socket_type = stream
  protocol    = tcp
  user        = root
  wait        = no
  server      = /usr/sbin/in.telnetd
  server_args = -h -L /opt/nethack/${DOMAIN}/dgamelaunch
  rlimit_cpu  = 120
}" >> ${TMP_FILE} 
  sudo cp ${TMP_FILE} /etc/xinetd.d/nethack
  sudo service xinetd restart
fi

rm -rf ${LPATH}
