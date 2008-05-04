
#
#  Multi::Maintenance  -  General maintenance functions
#

package Multi::Maintenance;

use strict;
use warnings;
use POE;
use PerlIO::gzip;


sub spawn {
  # WARNING: these maintenance tasks can block the process for a few seconds
  # 'maintenance all' doesn't include log rotation

  my $p = shift;
  POE::Session->create(
    package_states => [
      $p => [qw| _start cmd_maintenance vncache ratings prevcache integrity unkanime logrotate |], 
    ],
  );
}


sub _start {
  $_[KERNEL]->alias_set('maintenance');
  $_[KERNEL]->call(core => register => qr/^maintenance((?: (?:all|vncache|ratings|prevcache|integrity|unkanime|logrotate))+)$/, 'cmd_maintenance');
  
 # Perform all maintenance functions every day on 0:00
  $_[KERNEL]->post(core => addcron => '0 0 * * *', 'maintenance all');
 # rotate logs every 1st day of the month at 0:05
  $_[KERNEL]->post(core => addcron => '5 0 1 * *' => 'maintenance logrotate');
}


sub cmd_maintenance {
  local $_ = $_[ARG1];

  $_[KERNEL]->yield('vncache')   if /(?:vncache|all)/;
  $_[KERNEL]->yield('ratings')   if /(?:ratings|all)/;
  $_[KERNEL]->yield('prevcache') if /(?:prevcache|all)/;
  $_[KERNEL]->yield('integrity') if /(?:integrity|all)/;
  $_[KERNEL]->yield('unkanime')  if /(?:unkanime|all)/;
  $_[KERNEL]->yield('logrotate') if /logrotate/;

  $_[KERNEL]->post(core => finish => $_[ARG0]);
}


sub vncache {
  $_[KERNEL]->call(core => log => 3 => 'Updating c_* columns in the vn table...');
  $Multi::SQL->do('SELECT update_vncache(0)');
}


sub ratings {
  $_[KERNEL]->call(core => log => 3 => 'Recalculating VN ratings...');
  $Multi::SQL->do('SELECT calculate_rating()');
}


sub prevcache {
  $_[KERNEL]->call(core => log => 3 => 'Updating prev column in the changes table...');
  # this can take a while, maybe split these up in 3 queries?
  $Multi::SQL->do(q|SELECT update_prev('vn', ''), update_prev('releases', ''), update_prev('producers', '')|);
}


sub integrity {
  my $q = $Multi::SQL->prepare(q|
   SELECT 'r', id FROM releases_rev rr
     WHERE NOT EXISTS(SELECT 1 FROM releases_vn rv WHERE rr.id = rv.rid)
   UNION
   SELECT c.type::varchar, id FROM changes c
     WHERE (c.type = 0 AND NOT EXISTS(SELECT 1 FROM vn_rev vr WHERE vr.id = c.id))
        OR (c.type = 1 AND NOT EXISTS(SELECT 1 FROM releases_rev rr WHERE rr.id = c.id))
        OR (c.type = 2 AND NOT EXISTS(SELECT 1 FROM producers_rev pr WHERE pr.id = c.id))|);
  $q->execute();
  my $r = $q->fetchall_arrayref([]);
  if(@$r) {
    $_[KERNEL]->call(core => log => 1, '!DATABASE INCONSISTENCIES FOUND!: %s',
      join(', ', map { $_->[0].':'.$_->[1] } @$r));
  } else {
    $_[KERNEL]->call(core => log => 3, 'No database inconsistencies found');
  }
}


sub unkanime {
 # warn for VNs with a non-existing anidb id
 # (maybe do an automated edit or something in the future)

  my $q = $Multi::SQL->prepare(q|
    SELECT v.id, va.aid
    FROM vn_anime va
    JOIN vn v ON va.vid = v.latest
    JOIN anime a ON va.aid = a.id
    WHERE a.lastfetch < 0|);
  $q->execute();
  my $r = $q->fetchall_arrayref([]);
  my %aid = map { 
    my $a=$_;
    $a->[1] => join(',', map { $a->[1] == $_->[1] ? $_->[0] : () } @$r)
  } @$r;

  if(keys %aid) {
    $_[KERNEL]->call(core => log => 1, '!NON-EXISTING RELATED ANIME FOUND!: %s',
      join('; ', map { 'a'.$_.':v'.$aid{$_} } keys %aid)
    );
  } else {
    $_[KERNEL]->call(core => log => 3, 'No problems found with the related anime');
  }
}


sub logrotate {
  my $dir = sprintf '%s/old', $Multi::LOGDIR;
  mkdir $dir if !-d $dir;

  for (glob sprintf '%s/*', $Multi::LOGDIR) {
    next if /^\./ || /~$/ || !-f;
    my $f = /([^\/]+)$/ ? $1 : $_;
    my $n = sprintf '%s/%s.%04d-%02d-%02d.gz', $dir, $f, (localtime)[5]+1900, (localtime)[4]+1, (localtime)[3];
    if(-f $n) {
      $_[KERNEL]->call(core => log => 1, 'Logs already rotated earlier today!');
      return;
    }
    open my $I, '<', sprintf '%s/%s', $Multi::LOGDIR, $f;
    open my $O, '>:gzip', $n;
    print $O $_ while <$I>;
    close $O;
    close $I;
    open $I, '>', sprintf '%s/%s', $Multi::LOGDIR, $f;
    close $I;
  }
}


1;


