znap
====
znap is a ZFS snapshot management and peridic scrubbing script written in /bin/sh


goals
=====
I write this for my personal usage. If anyone else finds this useful thats a big bonus, 
please tell me about it :) 

Goals and ideas for znap:
- written in sh. portable, no dependencies and most Unix admins understand it.
- code should be easy to read and understand.
- perform daily, weekly and monthly snapshots.
- one snapshot is taken every day. Monthly snapshots take presedence over weekly 
  snapshots which take presedence over daily snapshots.
- snapshot-lifetime is given in days. Snapshots are destroyed based on how many 
  days they have lived, not how many snapshots there are.
- creation-date is included in the snapshot name. The pattern they follow is 
  date_scriptname_type, eg. 20140211_znap_daily. This is both computer and 
  human friendly.
- scrubbing is performed on the same weekday every month. This fits into a 
  weekly work schedule, eg. scrub the first sunday of every month.
- all time related calculations are done by date(1), znap only compares some 
  integers to figure out when a snapshot is too old.
- have a sane default config.


unimplemented ideas
===================
I have some ideas for extending the script. Might implement them if I need them myself 
or if anyone asks nicely.
- destroy snapshots with used = 0. Gets rid of unecessary snapshots. This process 
  should start with the oldest snapshots, ignore monthly snapshots and ignore 
  the newest snapshot.
- implement hourly snapshotting, preferably with a separate script to keep things 
  simple
- make scrubbing more configurable. Configure which week in a month the scrub should 
  be on, standard now is the first week. Enable configuration for weekly scrubbing, 
  maybe even scrubbing every two weeks, three weeks, etc.
- generalize the script so that it can apply to datasets and not only whole pools.


install
=======

FreeBSD
-------
    cp znap.sh /usr/local/sbin/
    chmod 555 /usr/local/sbin/znap.sh
    cp znap.conf /usr/local/etc/

Then add this line to /etc/crontab
    1   2   *   *   *   root   /bin/sh /usr/local/sbin/znap.sh <poolname>

Other
-----
Not implemented but ideas, requests, diffs, etc. will be happily accepted.

license
-------
Beer-ware (revision 42)
