znap
====
znap is a ZFS snapshot management and peridic scrubbing script written in /bin/sh


goals
=====
I write this for my personal usage and for some servers I help administer. If anyone 
else finds this useful thats a big bonus, please tell me about it :) 

Goals and ideas for znap (in no particular order):
- written in sh. portable, no dependencies and most Unix admins understand it.
- code should be easy to read and understand to such an extent that it can be 
  trusted to not do anything surprising.
- perform daily, weekly and monthly snapshots.
- snapshots are done recursively from the root of a zpool
- one snapshot is taken every day. Monthly snapshots take presedence over weekly 
  snapshots which take presedence over daily snapshots.
- snapshot-lifetime is given in days. Snapshots are destroyed based on how many 
  days they have lived, not how many snapshots there are.
- creation-date is included in the snapshot name. The pattern they follow is 
  date_scriptname_type, eg. 20140211_znap_daily. This is both computer and 
  human friendly.
- snapshots are removed with deferred destroy to make sure the script works with 
  zfs holds.
- scrubbing is performed on the same weekday every month. This fits into a 
  weekly work schedule, eg. scrub the first sunday of every month.
- all time related calculations are done by date(1), znap only compares integers 
  to figure out when a snapshot is too old.
- have a sane default config.
- use zfs delegation to allow the script to run as an unprivileged user
- per pool configuration. Found under znap.d directory in the config path in
  the form poolname.conf
- can perform weekly scrubbing if needed


unimplemented ideas
===================
I have some ideas for extending the script. Might implement them if I need them myself 
or if anyone asks nicely.
- implement hourly snapshotting, preferably with a separate script to keep things 
  simple
- make scrubbing more configurable. Configure which week in a month the scrub should 
  be on, standard now is the first week.
- generalize the script so that it can apply to datasets and not only whole pools.
- make different types of snapshots configurable. Be able to enable / disable daily, 
  weekly, monthly snapshots.
- quarterly snapshots.
- be able to make snapshots manually in addition to the daily ones. They could be 
  called admin snapshots and live for a year. It would be up to the admin to destroy 
  these snapshots.


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

Add a line to /etc/crontab (one per pool)
```
2   2   *   *   *   _znap /bin/sh /usr/local/sbin/znap.sh <poolname>
```

If you need different configs per pool just copy znap.conf into 
znap.d and name it after your pool, ie. tank.conf


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
- make it a FreeBSD port and get it into the ports tree
