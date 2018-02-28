#!/bin/bash

# mysql root passwd:123456

GERRIT=gerrit-2.14.6.war
GERRIT_URL=https://gerrit-releases.storage.googleapis.com/gerrit-2.14.6.war

topdir=`cd $(dirname $0) && pwd`
echo "topdir:$topdir"

username=gerrit

function add_user_gerrit() {
	if grep -q $username /etc/passwd; then
		echo "user $username already exist."
		return
	fi

	useradd $username -m -s /bin/bash
	echo "set passwd for user $username"
	passwd $username
}

function del_user_gerrit() {
	if grep -q $username /etc/passwd; then
		echo "delete user ${username}."
		userdel -r -f $username
	fi
}

function install_dependency() {
	if grep "Ubuntu" /etc/lsb-release > /dev/null 2>&1; then
		apt-get install -y \
			apache2-utils \
			openjdk-8-jdk \
			openjdk-8-jre > /dev/null
			
	else
		yum install -y java-1.8.0-openjdk-devel \
			unzip \
			zip \
			git \
			> /dev/null
	fi
}

function install_httpd() {
	if yum list installed | grep -q httpd; then
		echo "httpd already installed"
	else
		yum install -y \
			gitweb \
			httpd \
			> /dev/null
		cp gerrit.conf /etc/httpd/conf.d/

		touch /gerrit.passwd
		htpasswd /gerrit.passwd "root" << EOF
123456
123456
EOF
	fi

	if systemctl status httpd > /dev/null; then
		echo "httpd server already started."
	else
		systemctl start httpd
	fi
}

function install_mysql() {
	if grep "Ubuntu" /etc/lsb-release > /dev/null; then
		if dpkg -l | grep mysql-serever; then
			echo "mysql-serever already installed"
			return
		fi
		apt-get install -y \
			mysql-server \
			mysql-client \
			libmysqlclient-dev > /dev/null
	else
	if yum list installed | grep -q mariadb-server; then
		echo "mariadb already installed"
	else
		yum install -y mariadb-devel \
			mariadb-libs \
			mariadb \
			mariadb-server \
			> /dev/null
	fi

	if systemctl status mariadb > /dev/null; then
		echo "mariadb service already start"
	else
		systemctl start mariadb
		echo "create database..."
		mysql << EOF
CREATE USER 'gerritdbuser'@'localhost' IDENTIFIED BY 'gerritdbpass';
CREATE DATABASE gerritdb DEFAULT CHARACTER SET 'utf8';
GRANT ALL ON gerritdb.* TO 'gerritdbuser'@'localhost';
FLUSH PRIVILEGES;
EOF
	fi
	fi
}

function configure_mysql() {
	mysql -uroot -p << EOF
create database gerritdb CHARACTER SET utf8 COLLATE utf8_general_ci;
grant all on gerritdb.* to 'gerritdbuser'@'localhost' identified by 'gerritdbpass';
flush privileges;
show databases;
exit;
EOF
	return
}

function del_database() {
	mysqladmin -u root -p drop gerritdb
}

function download_gerrit() {
	[ -f /home/gerrit/$GERRIT ] && return

	if [ ! -f $GERRIT ]; then
		echo "download $GERRIT"
		wget $GERRIT_URL -O $GERRIT
	fi

	cp $GERRIT /home/$username/
	chown $username:$username /home/$username/$GERRIT
}

function install_gerrit() {
	echo "install gerrit"
	mkdir review_site

	java -jar gerrit-2.14.6.war init -d review_site <<EOF
Y

mysql
Y




123456
123456

http




localhost


chenzhihui244@msn.com
123456
123456


Y


y



127.0.0.1
8081
http://192.168.1.201
y
y
y
y
y
y

EOF
}

function install_mvn() {
	mvn_bin=apache-maven-3.5.2.tar.gz
	mvn_dir=${mvn_bin%\.*}
	mvn_dir=${mvn_dir%\.*}
	if [ ! -d $mvn_dir ]; then
		tar xf $mvn_bin
	fi

	export PATH=$topdir/$mvn_dir/bin:$PATH
	echo "export PATH=$topdir/$mvn_dir/bin:$PATH" >> profile
}

function build_bazel() {
	bazel_url=https://github.com/bazelbuild/bazel/releases/download/0.10.0/bazel-0.10.0-dist.zip
	bazel_src=bzel-0.10.0.zip
	bazel_dir=${bazel_src%\.*}

	if [ -f $bazel_dir/output/bazel ]; then
		echo "bazel already installed"
		return
	fi

	if [ ! -d $bazel_dir ]; then
		if [ ! -f $bazel_src ]; then
			wget $bazel_url -O $bazel_src
		fi
		mkdir $bazel_dir && unzip $bazel_src -d $bazel_dir
	fi

	cd $bazel_dir
	bash ./compile.sh
	if ! grep -q "$bazel_dir" profile; then
		export PATH=$topdir/$bazel_dir/output:$PATH
		echo "export PATH=$topdir/$bazel_dir/output:$PATH" >> profile
	fi
}

function build_gerrit() {
	if [ ! -d gerrit ]; then
		echo "clone gerrit repo"
		if [ ! -f gerrit.tar.gz ]; then
			git clone --recursive https://gerrit.googlesource.com/gerrit
			tar czf gerrit.tar.gz gerrit
		else
			tar xf gerrit.tar.gz
		fi
	fi

	pushd gerrit
	#bazel build release && cp bazel-bin/release.war /home/gerrit/gerrit.war || return -1
	bazel build gerrit && cp bazel-bin/release.war /home/gerrit/gerrit.war || return -1
	popd
}

function download_gerrit() {
	if [ -f $GERRIT ]; then
		echo "$GERRIT already exist"
		return
	fi
	wget $GERRIT_URL
}

function install_proxy_server() {
	if grep "Ubuntu" /etc/lsb-release > /dev/null; then
		apt-get install -y nginx
	fi
	
}

function create_admin_account() {
	touch ./review_site/etc/passwords
	htpasswd -b ./review_site/etc/passwords gerrit gerrit
}

function create_alias() {
	echo "alias ssh-gerrit='ssh -p 29418 -i ~/.ssh/id_rsa 192.168.1.198 -l gerrit'" >> /home/gerrit/.bashrc
}

if (( `id -u` )); then
	echo "must be root"
	exit 1
fi

#del_user_gerrit
#install_dependency &&
#install_httpd &&
#install_mysql &&
configure_mysql
exit
download_gerrit &&
add_user_gerrit
install_proxy_server
#install_mvn &&
#build_bazel &&
#build_gerrit
#su - $username
#install_gerrit
#create_admin_account

