znap
====
znap is a set of ZFS snapshot management and replication scripts written in /bin/sh

I write this for my personal usage and for some servers I help administrate. 
If anyone else finds this useful thats a big bonus, please tell me about it :) 

Features
========
Features and ideas for znap (in not very particular order):
- written in sh. portable, most Unix admins understand it.
- code should be easy to read and understand to such an extent that it can be 
  trusted to not do anything surprising.
- use zfs delegation to allow the script to run as an unprivileged user
- perform daily, weekly and monthly snapshots. snapshot-lifetime is given in days. 
  Snapshots are destroyed based on how many days they have lived, not how many 
  snapshots there are.
- one snapshot is taken every day. Monthly snapshots take presedence over weekly 
  snapshots which take presedence over daily snapshots.
- snapshots are done recursively from the root of a zpool
- creation-date is included in the snapshot name. The pattern they follow is 
  date_scriptname_type, eg. 201402110243_znap_daily. This is both computer and 
  human friendly. The time format is yyyymmddhhmm.
- all time related calculations are done by date(1), znap only compares integers 
  to figure out when a snapshot is too old.
- snapshots are removed with deferred destroy to make sure the script works with 
  zfs holds.
- per pool configuration. Found under znap.d directory in the config path. 
  the configuration files are named like tank.conf
- perform hourly snapshots with a separate script. snapshot-lifetime is given 
  in hours. Snapshots are destroyed based on how many hours they have lived, 
  not how many snasphots there are.
- ratelimits destroyal of old snapshots to make sure that the script doesn't 
  destroy too many old snapshots at a time. The script takes one snapshot 
  every time it is run, and it destroys maximum two old snapshots at a time 
  by default.
- have a sane default config.
- remote replication of snapshots over ssh implemented with a separate script.
  After sending all snapshots in the initial send, the script finds the newest 
  snapshots on the local and remote pools and sends an incremental zfs stream.


Unimplemented ideas
===================
I have some ideas for extending the script. Might implement them if I need them myself 
or if anyone asks nicely.
- generalize the script so that it can apply to datasets and not only pools.
- make different types of snapshots configurable. Be able to enable / disable daily, 
  weekly, monthly snapshots.
- quarterly snapshots.
- be able to make snapshots manually in addition to the daily ones. They could be 
  called admin snapshots and live for a year. It would be up to the admin to destroy 
  these snapshots.
- user logger(1) to log error conditions.
- add cron MAILTO variable so script output can be mailed to a configurable email.


Dependencies
============
- znapsend.sh depends on sudo


Install - znap.sh and znap-hourly.sh
====================================
Configure and install the script
```
# make install
```

Add an unprivileged _znap user (example from FreeBSD)
```
# adduser
Username: _znap
Full name: znap unprivileged user
Uid (Leave empty for default): 65000
Login group [_znap]:
Login group is _znap. Invite _znap into other groups? []:
Login class [default]:
Shell (sh csh tcsh git-shell nologin) [sh]: nologin
Home directory [/home/_znap]: /nonexistent
Home directory permissions (Leave empty for default):
Use password-based authentication? [yes]: no
Lock out the account after creation? [no]:
```

Delegate the proper ZFS rights to the _znap user
```
# zfs allow -u _znap destroy,mount,snapshot <pool> 
```

For daily, weekly, and monthly snapshots, add a line to /etc/crontab (one per pool)
```
2   2   *   *   *   _znap /bin/sh /usr/local/sbin/znap.sh <poolname>
```

For hourly snapshots, add a line to /etc/crontab (one per pool)
```
7   *   *   *   *   _znap /bin/sh /usr/local/sbin/znap-hourly.sh <poolname>
```

If you need different configs per pool just copy znap.conf into 
/usr/local/etc/znap.d/ and name it after the pool, ie. tank.conf.


Install - znapsend.sh
=====================
These actions should be carried out on both machines, both 
the local and the remote.

Add an unprivileged znapsend user (example from FreeBSD)
```
# adduser 
Username: znapsend
Full name: znapsend unprivileged user
Uid (Leave empty for default): 65001    
Login group [znapsend]: 
Login group is znapsend. Invite znapsend into other groups? []: 
Login class [default]: 
Shell (sh csh tcsh nologin) [sh]: 
Home directory [/home/znapsend]: /var/znapsend
Home directory permissions (Leave empty for default): 
Use password-based authentication? [yes]: no
Lock out the account after creation? [no]:
Username   : znapsend
Password   : <disabled>
Full Name  : znapsend unprivileged user
Uid        : 65001
Class      : 
Groups     : znapsend 
Home       : /var/znapsend
Home Mode  : 
Shell      : /bin/sh
Locked     : no
```

Create ssh keys
```
# su znapsend
$ ssh-keygen
```
Remember to copy each hosts znapsend public key to the others 
./ssh/authorized_keys file.

Delegate the proper rights to the znapsend user
```
# zfs allow -u znapsend hold,receive,release,send <pool>
```

Set up passwordless sudo for the znapsend used. Add this to 
/usr/local/etc/sudoers
```
znapsend ALL=(root) NOPASSWD: /sbin/zfs receive *
```

Set up a specific config for the pool you wish to replicate.
Just copy the znap.conf into znap.d/poolname.conf and set the
configuration options for replication. Unless you want to run 
as another user than znapsend you only need to set the config 
for remote host and remote pool.
```
REMOTE_USER='znapsend'
REMOTE_HOST=''
REMOTE_POOL=''
```

Perform the initial replication (could take some time)
```
# su znapsend
$ sh /usr/local/sbin/znapsend.sh <pool> initial
```

Schedule replication as often as you make new snapshots.
This example is for hourly snapshots. Add a line to /etc/crontab.
```
13   *   *   *   *   znapsend /bin/sh /usr/local/sbin/znapsend.sh <poolname>
```

Supported OSes
==============
Currently the only supported OS is FreeBSD because its what I run it on. 
It should be trivial to adapt it for use on other Unix platforms.

Ideas, requests, diffs, etc. will be happily accepted.


License
=======
Beer-ware (revision 42)


TODO
====
- make it a FreeBSD port
