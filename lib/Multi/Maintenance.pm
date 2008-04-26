
#
#  Multi::Maintenance  -  General maintenance functions
#

package Multi::Maintenance;

use strict;
use warnings;
use POE;


sub spawn {
  my $p = shift;
  POE::Session->create(
    package_states => [
      $p => [qw| _start cmd_maintenance vncache ratings prevcache integrity |], 
    ],
  );
}


sub _start {
  $_[KERNEL]->alias_set('maintenance');
  $_[KERNEL]->call(core => register => qr/^maintenance((?: (?:all|vncache|ratings|prevcache|integrity))+)$/, 'cmd_maintenance');
  
 # Perform all maintenance functions every day on 0:00
  $_[KERNEL]->post(core => addcron => '0 0 * * *', 'maintenance all');
}


sub cmd_maintenance {
  local $_ = $_[ARG1];

  $_[KERNEL]->yield('vncache')   if /(vncache|all)/;
  $_[KERNEL]->yield('ratings')   if /(ratings|all)/;
  $_[KERNEL]->yield('prevcache') if /(prevcache|all)/;
  $_[KERNEL]->yield('integrity') if /(integrity|all)/;

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


1;


