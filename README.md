
# Numishare-Vagrant

A pre-packaged [Numishare](https://github.com/ewg118/numishare) for [Vagrant](https://www.vagrantup.com/) users.

## Pre-requisite

Install Vagrant.

Vagrant depends on a VM engine.  For local development on the Mac, I use
[VirtualBox](https://www.virtualbox.org/).  VirtualBox also works on Windows.
There are Vagrant providers
for [AWS VMs](https://github.com/mitchellh/vagrant-aws) and
[IBM Cloud](https://github.com/rofrano/vagrant-ibmcloud), among others, if
you wish to run Numishare on a cloud.

## Running Numishare

**Recommended: edit _vagrant/tomcat-users.xml_ to supply an admin password first.**

```bash
cd vagrant
vagrant up
```

Once Vagrant-Numishare is up and running, you may browse to Numishare at
[http://localhost:8080/orbeon/numishare/admin/](http://localhost:8080/orbeon/numishare/admin/).  From there you may create a **collection**.  When creating a collection, use the Tomcat role `collection1`.

You may also visit [http://localhost:8983/solr/#/numishare/core-overview](http://localhost:8983/solr/#/numishare/core-overview) and [http://localhost:8888/exist/](http://localhost:8888/exist/).

# Loading databases

After you have created a collection interactively you will be able to interactively add coins.

You may also add coins using an API.  The coins must be in [NUDS](http://nomisma.org/nuds) XML format.

```bash
EXIST_HOST=localhost:8888
COLLECTION=collection1
EXIST_USER=admin
EXIST_PASSWORD=...
for filename in nuds/*.xml; do
   curl -v --user "$EXIST_USER":"$EXIST_PASSWORD" http://"$EXIST_HOST"/exist/rest/db/"$COLLECTION"/objects/ --upload-file "$filename"
done 
```

If the data you wish to load isn't already in NUDS format you may be interested in contributing to [csv-nuds](https://github.com/esnible/csv-nuds), a project aiming to convert the [CSV](https://en.wikipedia.org/wiki/Comma-separated_values) output of spreadseets and databases into NUDS.

# Mantainence

To back up the database log in to http://localhost:8888/exist/apps/dashboard/admin#
Choose backup, zip.  You can download it via the browser after creating it.
The file is created in the _$EXIST_HOME/data/export_ directory.

