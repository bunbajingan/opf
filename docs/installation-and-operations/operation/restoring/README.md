---
sidebar_navigation:
  title: Restoring
  priority: 8
---

# Restoring an OpenProject backup

## Package-based installation (DEB/RPM)

Assuming you have a backup of all the OpenProject files at hand (see the [Backing up](../backing-up) guide), here is how you would restore your OpenProject installation from that backup.

As a reference, we will assume you have the following dumps on your server, located in `/var/db/openproject/backup`:

```bash
ubuntu@ip-10-0-0-228:/home/ubuntu# sudo ls -al /var/db/openproject/backup/
total 1680
drwxr-xr-x 2 openproject openproject    4096 Nov 19 21:00 .
drwxr-xr-x 6 openproject openproject    4096 Nov 19 21:00 ..
-rw-r----- 1 openproject openproject 1361994 Nov 19 21:00 attachments-20191119210038.tar.gz
-rw-r----- 1 openproject openproject    1060 Nov 19 21:00 conf-20191119210038.tar.gz
-rw-r----- 1 openproject openproject     126 Nov 19 21:00 git-repositories-20191119210038.tar.gz
-rw-r----- 1 openproject openproject  332170 Nov 19 21:00 postgresql-dump-20191119210038.pgdump
-rw-r----- 1 openproject openproject     112 Nov 19 21:00 svn-repositories-20191119210038.tar.gz
```

### Stop the processes

First, it is a good idea to stop the OpenProject instance:

```bash
sudo service openproject stop
```

### Restoring assets

Untar the attachments to their destination:

```bash
sudo tar xzf /var/db/openproject/backup/attachments-20191119210038.tar.gz -C /var/db/openproject/files
```

Untar the configuration files to their destination:

```bash
sudo tar xzf /var/db/openproject/backup/conf-20191119210038.tar.gz -C /etc/openproject/conf.d/
```

Untar the repositories to their destination:

```bash
sudo tar xzf /var/db/openproject/backup/git-repositories-20191119210038.tar.gz -C /var/db/openproject/git
sudo tar xzf /var/db/openproject/backup/svn-repositories-20191119210038.tar.gz -C /var/db/openproject/svn
```

### Restoring the database

Note: in this section, the `<dbusername>`, `<dbhost>` and `<dbname>` variables that appear below have to be replaced with
the values that are contained in the `DATABASE_URL` setting of your
installation.

> _If you are moving OpenProject to a new server and want to import the backup there, this
will be the `DATABASE_URL` of your **new** installation on that server._

First, ensure the connection details about your database is the one you want to restore

```bash
sudo openproject config:get DATABASE_URL
#=> e.g.: postgres://<dbusername>:<dbpassword>@<dbhost>:<dbport>/<dbname>
```

Then, to restore the PostgreSQL dump please use the `pg_restore` command utility. **WARNING:** The command `--clean --if-exists` is used and it will drop objects in the database and you will lose all changes in this database! Double-check that the database URL above is the database you want to restore to. 

This is necessary since the backups of OpenProject does not clean statements to remove existing options and will lead to duplicate index errors when trying to restore to an existing database. The alternative is to drop/recreate the database manually (see below), if you have the permissions to do so.

```bash
sudo pg_restore --clean --if-exists --dbname $(sudo openproject config:get DATABASE_URL) postgresql-dump-20200804094017.pgdump
```

#### Troubleshooting

**Restore fails with something like 'Error while PROCESSING TOC [...] cannot drop constraint'**

In this case you will have to drop and re-create the database, and then import it again.
If you have access to the postgres user, it's simply a matter of starting the psql console like this:

```bash
sudo su - postgres -c psql
```

And once in there drop and re-create the database.
Ensure that the new database has the correct name and owner.
You can get these values from the `DATABASE_URL` as shown above.

```psql
DROP DATABASE openproject; CREATE DATABASE openproject OWNER openproject;
```

Once done you can exit the psql console by entering `\q`.
Now you can restore the database as seen above.

### Restart the OpenProject processes

Finally, restart all your processes as follows:

```bash
sudo service openproject restart
```

## Docker-based installation

For Docker-based installations, assuming you have a backup as per the procedure described in the [Backing up](../backing-up) guide, you simply need to restore files into the correct folders (when using the all-in-one container), or restore the docker volumes (when using the Compose file), then start OpenProject using the normal docker or docker-compose command.

### Restoring a dump

Let's assume you want to restore a database dump given in a file, say `openproject.sql`.

If you are using docker-compose this is what you do after you started everything for the first time using `docker-compose up -d`:

1. Stop the OpenProject container using `docker-compose stop web worker`.
2. Drop the existing, seeded database using `docker exec -it db_1 psql -U postgres -c 'drop database openproject;`
3. Recreate the database using `docker exec -it db_1 psql -U postgres -c 'create database openproject owner openproject;`
4. Copy the dump onto the container: `docker cp openproject.sql db_1:/`
5. Source the dump with psql on the container: `docker exec -it db_1 psql -U postgres` followed by `\i openproject.sql`
6. Delete the dump on the container: `docker exec -it db_1 rm openproject.sql`
7. Restart the web and worker processes: `docker-compose start web worker`

This assumes that the database container is called `db_1`. Find out the actual name on your host using `docker ps | postgres`.

#### All-in-one container

Given a SQL dump `openproject.sql` we can create a new OpenProject container using it with the following steps.

1. Create the pgdata folder to be mounted in the OpenProject container.
2. Initialize the database.
3. Restore the dump.
4. Start the OpenProject container mounting the pgdata folder.

1)

First we create the folder to be mounted by our OpenProject container.
While we're at we also create the assets folder which should be mounted too.

```
mkdir /var/lib/openproject/{pgdata,assets}
```

2)

Next we need to initialize the database.

```
docker run --rm -v /var/lib/openproject/pgdata:/var/openproject/pgdata -it openproject/community:10
```

As soon as you see `CREATE ROLE` and `Migrating to ToV710AggregatedMigrations (10000000000000)` or lots of `create_table` in the container's output
you can kill it by pressing Ctrl + C. This then initialized the database under `/var/lib/openproject/pgdata`.

3)

Now we can restore the database. For this we mount the initialized `pgdata` folder using the postgres docker container.

```
docker run --rm -d --name postgres -v /var/lib/openproject/pgdata:/var/lib/postgresql/data postgres:9.6
```

Once the container is ready you can copy your SQL dump onto it and start `psql`.

```
docker cp openproject.sql postgres:/
docker exec -it postgres psql -U postgres
```

In `psql` you then restore dump like this:

```
DROP DATABASE openproject;
CREATE DATABASE openproject OWNER openproject;

\c openproject
\i openproject.sql
```

Once this has finished you can quit `psql` (using `\q`) and the container (`exit`) and stop it using `docker stop postgres`.
Now you have to fix the permissions that were changed by the postgres container so OpenProject can use the files again.

```
chown -R 102 /var/lib/openproject/pgdata
```

Your `pgdata` directory is now ready to be mounted by your final OpenProject container.

4)

Start the container as described in the [installation section](../../installation/docker/#recommended-usage) mounting `/var/lib/openproject/pgdata`.
