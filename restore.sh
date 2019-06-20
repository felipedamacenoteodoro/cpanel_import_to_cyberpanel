#!/bin/bash
# Author: Maks Usmanov - Skamasle modify by Felipe 
# SKamasle.com
# cpanelimporter@skamasle.com | @skamasle in tw | modify by contato@datacenterweb.com.br
# Version 0.5.3 beta | FiX USER PASS | GET MX
# Run at your own risk
# This script take cpanel full backup and import it in vestacp account modify for restoure in cyberpanel
# This script can import databases and database users and password, 
# Import domains, subdomains and website files
# This script import also mail accounts and mails into accounts if previous cpanel run dovecot
# Mail password not are restored this was reset by new one.
###########
# If you need restore main database user read line 160 or above
###########
if [ ! -e /usr/bin/rsync ] || [ ! -e /usr/bin/file ] ; then
	echo "#######################################"
	echo "rsync not installed, try install it"
	echo "This script need: rsync, file"
	echo "#######################################"
	if  [ -e /etc/redhat-release ]; then
		echo "Run: yum install rync file"
	else
		echo "Run: apt-get install rsync file"
	fi
	exit 3
fi
# Put this to 0 if you want use bash -x to debug it
sk_debug=1
datacenterweb_cyberpanel_package=default
#
# Only for gen_password but I dont like it, a lot of lt
# maybe will use it for orther functions :)
#source /usr/local/vesta/func/main.sh 
sk_file=$1
usuario_painel=$2
mysql_root_pass=$3
sk_tmp=sk_tmp
# I see than this is stupid, not know why is here.
sk_file_name=$(ls $sk_file)
tput setaf 2
echo "Checking provided file..."
tput sgr0 
if file $sk_file |grep -q -c "gzip compressed data," ; then
	tput setaf 2
	echo "OK - Gziped File"
	tput sgr0 	
	if [ ! -d /root/${sk_tmp} ]; then
		echo "Creating tmp.."
		mkdir /root/${sk_tmp}
	fi
	echo "Extracting backup..."
	if [ "$sk_debug" != 0 ]; then
		tar xzvf $sk_file -C /root/${sk_tmp} 2>&1 |
     		   while read sk_extracted_file; do
       				ex=$((ex+1))
       				echo -en "wait... $ex files extracted\r"
       		   done
		else
			tar xzf $sk_file -C /root/${sk_tmp}
	fi
		if [ $? -eq 0 ];then
			tput setaf 2
			echo "Backup extracted without errors..."
			tput sgr0 
		else
			echo "Error on backup extraction, check your file, try extract it manually"
			echo "Remove tmp"
			rm -rf "/root/${sk_tmp}"
			exit 1
		fi
	else
	echo "Error 3 not-gzip - no stantard cpanel backup provided of file not installed ( Try yum install file, or apt-get install file )"
	rm -rf "/root/${sk_tmp}"
	exit 3
fi
cd /root/${sk_tmp}/*
sk_importer_in=$(pwd)
echo "Access tmp directory $sk_importer_in"
echo "Get prefix..."
sk_dead_prefix=$(cat meta/dbprefix)
if [ $sk_dead_prefix = 1 ]; then
	echo "Error 666 - I dont like your prefix, I dont want do this job"
	exit 666
else
	echo "I like your prefix, start working"
fi
main_domain1=$(grep main_domain userdata/main |cut -d " " -f2)
if [ "$(ls -A mysql)" ]; then
	sk_cp_user=$(ls mysql |grep sql | grep -v roundcube.sql |head -n1 |cut -d "_" -f1)
	if [ -z "$sk_cp_user" ]; then
		 	sk_cp_user=$(grep "user:" userdata/${main_domain1} | cut -d " " -f2)
	fi
	echo "$sk_cp_user" > sk_db_prefix
	tput setaf 2
	echo "Get user: $sk_cp_user"
	tput sgr0
	sk_restore_dbs=0
else
	sk_restore_dbs=1
# get real cPanel user if no databases exist
	sk_cp_user=$(grep "user:" userdata/${main_domain1} | cut -d " " -f2)
fi

# # So get real user, may be we need it after -- oh yes, not remember where but this save my day march 19 2017 on 0.5
# sk_real_cp_user=$(grep "user:" userdata/${main_domain1} | cut -d " " -f2)
# if /usr/local/vesta/bin/v-list-users | grep -q -w $sk_cp_user ;then
# 	echo "User alredy exist on your server, maybe on vestacp or in your /etc/passwd"
# 	echo "**"
# 	echo "Grep your /etc/passwd"
# 	grep -q -w $sk_cp_user /etc/passwd
# 	echo "**"
# 	echo "Stop Working, clening..."
# 	rm -rf /root/${sk_tmp}
# 	exit 21
# else
# 	echo "Generate random password for $sk_cp_user and create Vestacp Account ..."
# 	sk_password=$(generate_password)
# 	/usr/local/vesta/bin/v-add-user $sk_cp_user $sk_password administrator@${main_domain1} $datacenterweb_cyberpanel_package $sk_cp_user $sk_cp_user
# 	if [ $? != 0 ]; then
# 		tput setaf 2
# 		echo "Stop Working... Cant create user...if is fresh install of vestacp try reboot or reopen session check bug https://bugs.vestacp.com/issues/138"
# 		tput sgr0
# 		rm -rf "/root/${sk_tmp}"
# 		exit 4
# 		fi
# fi

# Leave vesta restore passwords and create users
tput setaf 2
echo "Rebuild databases files for $sk_cp_user"
tput sgr0 
#/usr/local/vesta/bin/v-rebuild-databases $sk_cp_user

# ## end mysql

skaddons=$(cat addons |cut -d "=" -f1)
sed -i 's/_/./g; s/=/ /g' addons
echo "Converting addons domains, subdomains and some orther fun"
cp sds sk_sds
cp sds2 sk_sds2
sed -i 's/_/./g' sk_sds
sed -i 's/public_html/public@html/g; s/_/./g; s/public@html/public_html/g; s/=/ /g; s/$sk_default_sub/@/g' sk_sds2
cat addons | while read sk_addon_domain sk_addon_sub
do
	echo "Converting default subdomain: $sk_addon_sub in domain: $sk_addon_domain"
	sed -i -e "s/$sk_addon_sub/$sk_addon_domain/g" sk_sds
	sed -i -e "s/$sk_addon_sub/$sk_addon_domain/g" sk_sds2
	mv userdata/$sk_addon_sub userdata/${sk_addon_domain}
done

tput setaf 2
echo "Iniciando restauracao de dominios"
tput sgr0


function get_domain_path() {
		while read sk_domain path
	do
		if [ -e userdata/${sk_domain} ];then
            cyberpanel createWebsite --package Default --owner $usuario_painel --domainName $main_domain1 --email $sk_cp_user@$main_domain1 --php 5.6 --dkim 1 --openBasedir 1
 #$sk_cp_user $sk_domain
			echo "Restaurando sub-dominio $sk_domain..."
            rm -f /home/${sk_domain}/public_html/index.html
			if [ "$sk_debug" != 0 ]; then
				rsync -av homedir/${path}/ /home/${sk_domain}/public_html 2>&1 | 
    			while read sk_file_dm; do
       			 	sk_sync=$((sk_sync+1))
       			 	echo -en "-- $sk_sync restored files\r"
				done
			echo " "
			else
				rsync homedir/${path}/ /home/${sk_domain}//public_html
			fi
			chown $sk_cp_user:$sk_cp_user -R /home/${sk_domain}/public_html
			chmod 751 /home/${sk_domain}/public_html
			echo "$sk_domain" >> exclude_path
            
		fi
done

} 

get_domain_path < sk_sds2

#/usr/local/vesta/bin/v-add-domain $sk_cp_user $main_domain1
cyberpanel createWebsite --package Default --owner $usuario_painel --domainName $main_domain1 --email $sk_cp_user@$main_domain1 --php 5.6 --dkim 1 --openBasedir 1
 
# # need it for restore main domain
if [ ! -e exclude_path ];then
	touch exclude_path
fi
echo "Restore main domain: $main_domain1"
rm -f /home/${main_domain1}/${main_domain1}/public_html/index.html
if [ "$sk_debug" != 0 ]; then
	rsync -av --exclude-from='exclude_path' homedir/public_html/ /home/${main_domain1}/public_html 2>&1 | 
    		while read sk_file_dm; do
       			 sk_sync=$((sk_sync+1))
       			 echo -en "-- $sk_sync restored files\r"
			done
		echo " "
else
	rsync --exclude-from='exclude_path' homedir/public_html/ /home/${main_domain1}/public_html 2>&1
fi
chown $sk_cp_user:$sk_cp_user -R /home/${main_domain1}/public_html
chmod 751 /home/${main_domain1}/public_html
rm -f sk_sds2 sk_sds


# ### Start with Databases
tput setaf 2
echo "Processando banco de dados"
tput sgr0 
sed -i 's/\\//g' mysql.sql
sed -i "s/\`/'/g" mysql.sql

# ## User / Password
grep "GRANT USAGE ON" mysql.sql | awk -F "'" '{ print $2, $6 }' | uniq > user_password_db
# User and database
grep "GRANT" mysql.sql |grep -v "USAGE ON"  > u_db
cat u_db | awk -F "'" '{ print $2, $4 }' | sort | uniq  > uni_u_db
sed -i "s/$sk_dead_prefix //g" user_password_db


cat uni_u_db | while read db userdb
do
	grep -w $userdb user_password_db |while read user end_user_pass
		do
# default cpanel user has all database privileges
# if you use default user in your config files to connect with database
# you will need remove && [ "$userdb" != "$sk_cp_user" ] to restore main user, but
# this will cause database duplication in db.conf and will interfer with vestacp backups 
			if [ "$userdb" == "$user" ] && [ "$userdb" != "$sk_cp_user" ] && [ "$userdb" != "$sk_real_cp_user" ] ; then
				cyberpanel createDatabase --databaseWebsite ${main_domain1} --dbName $db --dbUsername $userdb --dbPassword $end_user_pass 
                #preciso criar depois excluir o banco para que o sql de criacao do cpanel funcione
                mysql -uroot -p"$mysql_root_pass" -D $db -e "DROP DATABASE $db"
		mysql -uroot -p"$mysql_root_pass" -e "UPDATE mysql.user SET Password='"$end_user_pass"' WHERE USER='"$userdb"' AND Host='localhost'";
		mysql -uroot -p"$mysql_root_pass" -e "GRANT ALL PRIVILEGES ON $db.* TO $userdb@localhost; FLUSH PRIVILEGES ;"
		echo "$end_user_pass /////////////////////////////////////"
            	#echo "DB='$db' DBUSER='$userdb' MD5='$end_user_pass' HOST='localhost' TYPE='mysql' CHARSET='UTF8' U_DISK='0' SUSPENDED='no' TIME='$TIME' DATE='$DATE'" >> /usr/local/vesta/data/users/${sk_cp_user}/db.conf
			fi
		done
done

# # Get database list
sk_db_list=$(grep -m 1 Database: mysql/*.create | awk '{ print  $5 }')
mysql -uroot -p"$mysql_root_pass" -e "SHOW DATABASES" > server_dbs
for sk_dbr in $sk_db_list
	do
		grep -w $sk_dbr server_dbs	
		if [ $? == "1" ]; then
			echo " Criando e restaurando ${sk_dbr} "
            mysql -uroot -p"$mysql_root_pass" < mysql/${sk_dbr}.create
			mysql -uroot -p"$mysql_root_pass" ${sk_dbr} < mysql/${sk_dbr}.sql
		else
			echo "Error: Cant restore database $sk_dbr alredy exists in mysql server"
		fi
done



##################
# mail
tput setaf 2
echo "Start Restoring Mails"
tput sgr0
sk_cod=$(date +%s) # Just for numbers and create another file if acccount was restored before.
sk_mdir=${sk_importer_in}/homedir/mail
cd $sk_mdir
for sk_maild in $(ls -1)
do
if [[ "$sk_maild" != "cur" && "$sk_maild" != "new" && "$sk_maild" != "tmp"  ]]; then
	if [ -d "$sk_maild" ]; then
		for sk_mail_account in $(ls $sk_maild/)
		 do
					
					echo "Create and restore mail account: $sk_mail_account@$sk_maild"
					sk_mail_pass1=$mysql_root_pass		
					#v-add-mail-account $sk_cp_user $sk_maild $sk_mail_account $sk_mail_pass1
					cyberpanel createEmail --domainName ${sk_maild} --userName $sk_mail_account --password $sk_mail_pass1
					mkdir -p /home/vmail/${main_domain1}/${sk_mail_account}/Maildir/
                     mv ${sk_maild}/${sk_mail_account}/* /home/vmail/${main_domain1}/${sk_mail_account}/Maildir/
					mv ${sk_maild}/${sk_mail_account}/.* /home/vmail/${main_domain1}/${sk_mail_account}/Maildir/
                     chown vmail:vmail -R /home/vmail/${main_domain1}/${sk_mail_account}/Maildir/
					echo "${sk_mail_account}@${sk_maild} | $sk_mail_pass1"	>> /root/sk_mail_password_${sk_cp_user}-${sk_cod}
		done
	fi
#else
# this only detect default dirs account new, cur, tmp etc
# maybe can do something with this, but on most cpanel default account have only spam.
fi
done


# # echo "All mail accounts restored"
# # ############# ssl functions <(°-°)>
# # tput setaf 2
# # echo "Restoring SSL for domains"
# # tput sgr0
# # mv  ${sk_importer_in}/sslkeys/* ${sk_importer_in}/sslcerts/
# # mv  ${sk_importer_in}/ssl/* ${sk_importer_in}/sslcerts/
# # sk_domains=$(v-list-web-domains $sk_cp_user plain |awk '{ print  $1 }')

# # for ssl in $sk_domains
# # do
# # 	if [ -e ${sk_importer_in}/sslcerts/${ssl}.key ]; then
# # 		echo "Found SSL for ${ssl}, restoring..."
# # 		v-add-web-domain-ssl $sk_cp_user $ssl ${sk_importer_in}/sslcerts/	 
# # 	fi
# # done

# function sk_restore_pass () {
# sk_actual_pass=$(grep -w "^$sk_cp_user:" /etc/shadow |tr ":" " " | awk '{ print  $2 }' )
# sk_new_pass=$(cat $sk_importer_in/shadow)
# # need replace I hope you have installed it as in most systems...  
# # sed is a hero but replace is easy and not need space // :D
# replace "$sk_cp_user:$sk_actual_pass" "$sk_cp_user:$sk_new_pass" -- /etc/shadow
# tput setaf 5
# echo "Old  cPanel password restored in $sk_cp_user account"
# tput sgr0
# }
# function sk_fix_mx () {
# tput setaf 2
# 	echo "Start With MX Records"
# tput sgr0
# cd $sk_importer_in/dnszones
# for sk_mx in $sk_domains 
# do
# 	if [ -e $sk_mx.db ]; then
# 		sk_id=$(grep MX /usr/local/vesta/data/users/${sk_cp_user}/dns/${sk_mx}.conf |tr "'" " " | cut -d " " -f 2)
# 		v-delete-dns-record $sk_cp_user $sk_mx $sk_id
# 		grep MX ${sk_mx}.db |  awk '{for(sk=NF;sk>=1;sk--) printf "%s ", $sk;print ""}' | while read value pri ns rest
# 			do
# 				if [ "$ns" == "MX" ];then
# 					if [ "$value" == "$sk_mx" ] || [ "$value" == "$sk_mx." ];then 
# 						value=mail.$value
# 					fi
# 					v-add-dns-record $sk_cp_user $sk_mx @ MX $value $pri
# 					if [[ "$?" -ge "1" ]]; then
# 						v-add-dns-record $sk_cp_user $sk_mx @ MX mail.${sk_mx} 0
# 					fi
# 					echo "MX fixed in $sk_mx"
# 				fi
# 			done
# 	fi	
# done
# }
# if [ "$2" == "MX" ];then
# # Need some fixed so run if you want try it, marked as experimental
# 	sk_fix_mx
# fi
# sk_restore_pass

echo "Remove tmp files"
rm -rf "/root/${sk_tmp}"
tput setaf 4
echo "##############################"
echo "cPanel Backup restored"
echo "Review your content and report any fail"
echo "I reset mail password not posible restore it yet."
echo "Check your new passwords runing: cat /root/sk_mail_password_${sk_cp_user}-${sk_cod}"
echo "##############################"
tput sgr0

