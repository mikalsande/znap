znap
====
znap is a ZFS snapshot management script written in /bin/sh


features
========
I write this for my personal usage and for some servers I help administrate. 

If anyone else finds this useful thats a big bonus, please tell me about it :) 

Features and ideas for znap (in not very particular order):
- written in sh. portable, no dependencies and most Unix admins understand it.
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
  date_scriptname_type, eg. 20140211_znap_daily. This is both computer and 
  human friendly.
- all time related calculations are done by date(1), znap only compares integers 
  to figure out when a snapshot is too old.
- snapshots are removed with deferred destroy to make sure the script works with 
  zfs holds.
- per pool configuration. Found under znap.d directory in the config path in
  the form poolname.conf
- have a sane default config.
- perform hourly snapshots, with a separate script. snapshot-lifetime is given 
  in hours.


unimplemented ideas
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
- add cron mail option so output can be mailed to a configurable email.
- add a script to do replication with zfs send / receive


install
=======

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
Scrubs should be scheduled at a time after znap.sh and znap-hourly.sh has 
run to ensure that snapshots aren't skipped because of scrubs.

If you need different configs per pool just copy znap.conf into 
/usr/local/etc/znap.d/ and name it after the pool, ie. tank.conf.


Supported OSes
--------------
Currently the only supported OS is FreeBSD because its what I run it on. 
It should be trivial to adapt it for use on other Unix platforms.

Ideas, requests, diffs, etc. will be happily accepted.


license
=======
Beer-ware (revision 42)


todo
====
- make it a FreeBSD port
