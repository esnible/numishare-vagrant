#!/usr/bin/env bash

# This performs the instructions in the Numishare wiki to install.
# The script is slightly hardened to allow it to be re-run if Numishare is partly installed.

set -o errexit

TOMCAT_VERSION=tomcat9
ORBEON_TAG=tag-release-2021.1-ce
ORBEON_VERSION=orbeon-2021.1.202112312237-CE
SOLR_VERSION=8.11.1
EXIST_VERSION=eXist-6.0.1
EXIST_FILENAME=exist-distribution-6.0.1-unix.tar.bz2

TOMCAT_HOME=/var/lib/tomcat9

# Step
# https://github.com/ewg118/numishare/wiki/Installing-Tomcat

echo Downloading and Installing "$TOMCAT_VERSION"
if dpkg -S "$TOMCAT_VERSION" > /dev/null; then
   echo "$TOMCAT_VERSION" already installed
else
   apt-get update
   apt-get install --yes "$TOMCAT_VERSION" unzip
fi

# Step
# https://github.com/ewg118/numishare/wiki/Deploying-Orbeon

echo Downloading and Installing Orbeon "$ORBEON_TAG"
ORBEON_FILE="$ORBEON_VERSION".zip
if [ ! -f /opt/"$ORBEON_FILE" ]; then
   curl --location -o /opt/"$ORBEON_FILE" https://github.com/orbeon/orbeon-forms/releases/download/"$ORBEON_TAG"/"$ORBEON_FILE"
fi
unzip -u -d /opt /opt/"$ORBEON_FILE"

if [ ! -f "$TOMCAT_HOME"/webapps/orbeon.war ]; then
   cp /opt/"$ORBEON_VERSION"/orbeon.war "$TOMCAT_HOME"/webapps
fi

cat <<EOF > "$TOMCAT_HOME"/conf/Catalina/localhost/orbeon.xml
<Context path="/orbeon" docBase="/var/lib/tomcat9/webapps/orbeon">
   <Resources allowLinking="true" />
   <Valve className="org.apache.catalina.authenticator.BasicAuthenticator" changeSessionIdOnAuthentication="false">
   </Valve>
</Context>
EOF
chown tomcat:tomcat "$TOMCAT_HOME"/conf/Catalina/localhost/orbeon.xml
chmod 755 "$TOMCAT_HOME"/conf/Catalina/localhost # Let Vagrant user see config

# Sleep until Tomcat unzips orbeon.war
while [ ! -e "$TOMCAT_HOME"/webapps/orbeon/WEB-INF/resources/apps ]
do
  echo "Waiting for Tomcat to unzip orbeon.war"
  sleep 2
done


ls -l "$TOMCAT_HOME"/webapps/orbeon/WEB-INF/resources/config
chmod 755 "$TOMCAT_HOME"/webapps/orbeon # Let Vagrant user see config
chmod 755 "$TOMCAT_HOME"/webapps/orbeon/WEB-INF # Let Vagrant user see config
chmod 755 "$TOMCAT_HOME"/webapps/orbeon/WEB-INF/resources # Let Vagrant user see config
chmod 755 "$TOMCAT_HOME"/webapps/orbeon/WEB-INF/resources/apps

cat <<EOF > "$TOMCAT_HOME"/webapps/orbeon/WEB-INF/resources/config/properties-local.xml
<properties xmlns:xs="http://www.w3.org/2001/XMLSchema"
            xmlns:oxf="http://www.orbeon.com/oxf/processors">
   <property as="xs:anyURI" name="oxf.epilogue.theme" value="oxf:/config/theme-plain.xsl"/>
   <property as="xs:string" name="oxf.fr.authentication.container.roles" value="ulpia numishare-admin"/>
</properties>
EOF
chown tomcat:tomcat "$TOMCAT_HOME"/webapps/orbeon/WEB-INF/resources/config/properties-local.xml

mkdir "$TOMCAT_HOME"/logs || true

# service tomcat9 restart
# /usr/share/tomcat9/bin/startup.sh 

# Step
# https://github.com/ewg118/numishare/wiki/Cloning-the-Github-Numishare-Repository

echo Downloading and Installing Numishare
NUMISHARE_HOME=/usr/local/projects/numishare
if [ ! -d /usr/local/projects/numishare ]; then
   mkdir -p /usr/local/projects
   cd /usr/local/projects
   git clone https://github.com/ewg118/numishare.git
fi
ln --force --symbolic "$NUMISHARE_HOME" "$TOMCAT_HOME"/webapps/orbeon/WEB-INF/resources/apps/

# http://localhost:8080/orbeon/numishare/ will be Numishare
# http://localhost:8080/orbeon/numishare/admin/ will be the admin panel

# Step
# https://github.com/ewg118/numishare/wiki/Deploying-Solr

echo Downloading and Installing Solr "$SOLR_VERSION"
SOLR_FILENAME=solr-"$SOLR_VERSION".tgz
SOLR_HOME=/opt/solr-"$SOLR_VERSION"
if [ ! -f /opt/"$SOLR_FILENAME" ]; then
   curl --location -o /opt/"$SOLR_FILENAME" https://www.apache.org/dyn/closer.lua/lucene/solr/"$SOLR_VERSION"/"$SOLR_FILENAME"?action=download
fi
cd /opt
tar xzf /opt/"$SOLR_FILENAME"
if [ ! -f /etc/init.d/solr ]; then
   "$SOLR_HOME"/bin/install_solr_service.sh /opt/"$SOLR_FILENAME"
fi

# The previous gives me a bit of a warning:
# Mar 11 02:11:26 vagrant solr[18084]: *** [WARN] *** Your open file limit is currently 1024.
# Mar 11 02:11:26 vagrant solr[18084]:  It should be set to 65000 to avoid operational disruption.
# TODO: investigate "ulimit -n 65000"

# curl -v localhost:8983

sudo chown -R solr:solr "$NUMISHARE_HOME"/solr-home/1.6/

ln --force -s "$NUMISHARE_HOME"/solr-home/1.6/ /var/solr/data/numishare

# At this point the Solr UI is up at http://localhost:8983/solr/#/
# Create a new core named numishare with an instanceDir of numishare, a dataDir of data (relative path to the instanceDir), config of solrconfig.xml and schema of schema.xml.
curl 'http://localhost:8983/solr/admin/cores?action=CREATE&name=numishare&instanceDir=numishare&dataDir=data&numShards=2&replicationFactor=2'

# I can now see http://localhost:8983/solr/#/numishare/core-overview
# The instructions say I should be able to see http://localhost:8983/solr/numishare/
# I am not sure if that is correct.

# https://github.com/ewg118/numishare/wiki/Deploying-eXist

# This downloads the .tar.bz2.  (The install instructions suggest the .jar.)
echo Downloading and Installing eXist "$EXIST_VERSION"
if [ ! -f /opt/"$EXIST_FILENAME" ]; then
   curl --location -o /opt/"$EXIST_FILENAME" https://github.com/eXist-db/exist/releases/download/"$EXIST_VERSION"/"$EXIST_FILENAME"
fi
EXIST_HOME=/opt/exist
mkdir -p $EXIST_HOME
tar xjf /opt/"$EXIST_FILENAME" -C $EXIST_HOME --strip-components=1

groupadd --force existdb
adduser --system --shell /sbin/nologin existdb
chown -R existdb:existdb $EXIST_HOME

# Fails with "java.io.IOException: Failed to bind to 0.0.0.0/0.0.0.0:8080" because Tomcat running
# $EXIST_HOME/bin/startup.sh

# Edit $EXIST_HOME/etc/jetty/jetty-http.xml to use :8888
# See http://exist-db.org/exist/apps/doc/troubleshooting.xml#port-conflicts
sed -i.bak s/8080/8888/g $EXIST_HOME/etc/jetty/jetty-http.xml

cat <<EOF > /etc/systemd/system/existdb.service
[Unit]
Description=eXist-db Server
Documentation=https://exist-db.org/exist/apps/doc/
After=syslog.target

[Service]
Type=simple
User=existdb
Group=existdb
ExecStart=$EXIST_HOME/bin/startup.sh

[Install]
WantedBy=multi-user.target
EOF

chown existdb:existdb /etc/systemd/system/existdb.service

systemctl daemon-reload && sudo systemctl enable existdb

sudo systemctl start existdb

# TODO: Follow set password instructions at https://github.com/ewg118/numishare/wiki/Deploying-eXist

# See
# https://github.com/ewg118/numishare/wiki/Tomcat-Authentication
cp /vagrant/tomcat-users.xml $TOMCAT_HOME/conf/tomcat-users.xml
cp $TOMCAT_HOME/webapps/orbeon/WEB-INF/web.xml $TOMCAT_HOME/webapps/orbeon/WEB-INF/web.xml.bak
cp /vagrant/web.xml $TOMCAT_HOME/webapps/orbeon/WEB-INF/web.xml

# Skipped https://github.com/ewg118/numishare/wiki/Enabling-Apache-Proxypass

mkdir -p "$TOMCAT_HOME"/webapps/orbeon/WEB-INF/resources/apps/themes
chown tomcat:tomcat "$TOMCAT_HOME"/webapps/orbeon/WEB-INF/resources/apps/themes
ln -s "$NUMISHARE_HOME"/ui "$TOMCAT_HOME"/webapps/orbeon/WEB-INF/resources/apps/themes/default
