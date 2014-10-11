
#
#  Multi::Maintenance  -  General maintenance functions
#

package Multi::Maintenance;

use strict;
use warnings;
use POE;
use PerlIO::gzip;
use VNDBUtil 'normalize_titles';


sub spawn {
  my $p = shift;
  POE::Session->create(
    package_states => [
      $p => [qw|
        _start shutdown set_daily daily set_monthly monthly log_stats
        vncache_inc tagcache traitcache vnpopularity vnrating cleangraphs cleansessions cleannotifications rmuncomfirmusers cleanthrottle 
        vncache_full usercache statscache logrotate
        vnsearch_check vnsearch_gettitles vnsearch_update
      |],
    ],
    heap => {
      daily => [qw|vncache_inc tagcache traitcache vnpopularity vnrating cleangraphs cleansessions cleannotifications rmuncomfirmusers cleanthrottle|],
      monthly => [qw|vncache_full usercache statscache logrotate|],
      vnsearch_checkdelay => 3600,
      @_,
    },
  );
}


sub _start {
  $_[KERNEL]->alias_set('maintenance');
  $_[KERNEL]->sig(shutdown => 'shutdown');
  $_[KERNEL]->yield('set_daily');
  $_[KERNEL]->yield('set_monthly');
  $_[KERNEL]->yield('vnsearch_check');
  $_[KERNEL]->post(pg => listen => vnsearch => 'vnsearch_check');
}


sub shutdown {
  $_[KERNEL]->delay('daily');
  $_[KERNEL]->delay('monthly');
  $_[KERNEL]->delay('vnsearch_check');
  $_[KERNEL]->alias_remove('maintenance');
}


sub set_daily {
  # run daily each day at 12:00 GMT
  $_[KERNEL]->alarm(daily => int((time+3)/86400+1)*86400 + 12*3600);
}


sub daily {
  $_[KERNEL]->call(core => log => 'Running daily cron: %s', join ', ', @{$_[HEAP]{daily}});

  # dispatch events that need to be run on a daily basis
  $_[KERNEL]->call($_[SESSION], $_) for (@{$_[HEAP]{daily}});

  # re-activate timer
  $_[KERNEL]->call($_[SESSION], 'set_daily');
}


sub set_monthly {
  # Calculate the UNIX timestamp of 12:00 GMT of the first day of the next month.
  # We do this by simply incrementing the timestamp with one day and checking gmtime()
  # for a month change. This might not be very reliable, but should be enough for
  # our purposes.
  my $nextday = int((time+3)/86400+1)*86400 + 12*3600;
  my $thismonth = (gmtime)[5]*100+(gmtime)[4]; # year*100 + month, for easy comparing
  $nextday += 86400 while (gmtime $nextday)[5]*100+(gmtime $nextday)[4] <= $thismonth;
  $_[KERNEL]->alarm(monthly => $nextday);
}


sub monthly {
  $_[KERNEL]->call(core => log => 'Running monthly cron: %s', join ', ', @{$_[HEAP]{monthly}});

  # dispatch events that need to be run on a monthly basis
  $_[KERNEL]->call($_[SESSION], $_) for (@{$_[HEAP]{monthly}});

  # re-activate timer
  $_[KERNEL]->call($_[SESSION], 'set_monthly');
}


sub log_stats { # num, res, action, time
  $_[KERNEL]->call(core => log => sprintf 'Finished %s in %.3fs (%d rows)', $_[ARG2], $_[ARG3], $_[ARG0]);
}


#
#  D A I L Y   J O B S
#


sub vncache_inc {
  # takes about 500ms to 5s to complete, depending on how many releases have
  # been released within the past 5 days
  $_[KERNEL]->post(pg => do => q|
    SELECT update_vncache(id)
      FROM (
        SELECT DISTINCT rv.vid
          FROM releases r
          JOIN releases_rev rr ON rr.id = r.latest
          JOIN releases_vn rv ON rv.rid = r.latest
         WHERE rr.released  > TO_CHAR(NOW() - '5 days'::interval, 'YYYYMMDD')::integer
           AND rr.released <= TO_CHAR(NOW(), 'YYYYMMDD')::integer
     ) AS r(id)
  |, undef, 'log_stats', 'vncache_inc');
}


sub tagcache {
  # takes about 9 seconds max, still OK
  $_[KERNEL]->post(pg => do => 'SELECT tag_vn_calc()', undef, 'log_stats', 'tagcache');
}


sub traitcache {
  # takes about 90 seconds, might want to optimize or split up
  $_[KERNEL]->post(pg => do => 'SELECT traits_chars_calc()', undef, 'log_stats', 'traitcache');
}


sub vnpopularity {
  # takes about 30 seconds
  $_[KERNEL]->post(pg => do => 'SELECT update_vnpopularity()', undef, 'log_stats', 'vnpopularity');
}


sub vnrating {
  # takes about 25 seconds, can be performed in ranges as well when necessary
  $_[KERNEL]->post(pg => do => q|
    UPDATE vn SET
      c_rating = (SELECT (
          ((SELECT COUNT(vote)::real/COUNT(DISTINCT vid)::real FROM votes)*(SELECT AVG(a)::real FROM (SELECT AVG(vote) FROM votes GROUP BY vid) AS v(a)) + SUM(vote)::real) /
          ((SELECT COUNT(vote)::real/COUNT(DISTINCT vid)::real FROM votes) + COUNT(uid)::real)
        ) FROM votes WHERE vid = id AND uid NOT IN(SELECT id FROM users WHERE ign_votes)
      ),
      c_votecount = COALESCE((SELECT count(*) FROM votes WHERE vid = id AND uid NOT IN(SELECT id FROM users WHERE ign_votes)), 0)
  |, undef, 'log_stats', 'vnrating');
}


sub cleangraphs {
  # should be pretty fast
  $_[KERNEL]->post(pg => do => q|
    DELETE FROM relgraphs vg
     WHERE NOT EXISTS(SELECT 1 FROM vn WHERE rgraph = vg.id)
       AND NOT EXISTS(SELECT 1 FROM producers WHERE rgraph = vg.id)
    |, undef, 'log_stats', 'cleangraphs');
}


sub cleansessions {
  $_[KERNEL]->post(pg => do =>
    q|DELETE FROM sessions WHERE lastused < NOW()-'1 month'::interval|,
    undef, 'log_stats', 'cleansessions');
}


sub cleannotifications {
  $_[KERNEL]->post(pg => do =>
    q|DELETE FROM notifications WHERE read < NOW()-'1 month'::interval|,
    undef, 'log_stats', 'cleannotifications');
}


sub rmuncomfirmusers {
  $_[KERNEL]->post(pg => do =>
    q|DELETE FROM users WHERE NOT email_confirmed AND registered < NOW()-'1 week'::interval|,
    undef, 'log_stats', 'rmunconfirmusers');
}


sub cleanthrottle {
  $_[KERNEL]->post(pg => do =>
    q|DELETE FROM login_throttle WHERE timeout < NOW()|,
    undef, 'log_stats', 'cleanthrottle');
}



#
#  M O N T H L Y   J O B S
#


sub vncache_full {
  # This takes about 4 to 5 minutes to complete, and should only be necessary in the
  # event that the daily vncache_inc cron hasn't been running for 5 subsequent days.
  $_[KERNEL]->post(pg => do => 'SELECT update_vncache(id) FROM vn', undef, 'log_stats', 'vncache_full');
}


sub usercache {
  # Shouldn't really be necessary, except c_changes could be slightly off when
  # hiding/unhiding DB items.
  # This query takes almost two hours to complete and tends to bring the entire
  # site down with it, so it's been disabled for now. Can be performed in
  # ranges though.
  return;
  $_[KERNEL]->post(pg => do => q|UPDATE users SET
    c_votes = COALESCE(
      (SELECT COUNT(vid)
      FROM votes
      WHERE uid = users.id
      GROUP BY uid
    ), 0),
    c_changes = COALESCE(
      (SELECT COUNT(id)
      FROM changes
      WHERE requester = users.id
      GROUP BY requester
    ), 0),
    c_tags = COALESCE(
      (SELECT COUNT(tag)
      FROM tags_vn
      WHERE uid = users.id
      GROUP BY uid
    ), 0)
  |, undef, 'log_stats', 'usercache');
}


sub statscache {
  # Shouldn't really be necessary, the triggers in PgSQL should keep these up-to-date nicely.
  # But it takes less a second to complete, anyway.
  $_[KERNEL]->post(pg => do => $_) for(
    q|UPDATE stats_cache SET count = (SELECT COUNT(*) FROM users)-1 WHERE section = 'users'|,
    q|UPDATE stats_cache SET count = (SELECT COUNT(*) FROM vn        WHERE hidden = FALSE) WHERE section = 'vn'|,
    q|UPDATE stats_cache SET count = (SELECT COUNT(*) FROM releases  WHERE hidden = FALSE) WHERE section = 'releases'|,
    q|UPDATE stats_cache SET count = (SELECT COUNT(*) FROM producers WHERE hidden = FALSE) WHERE section = 'producers'|,
    q|UPDATE stats_cache SET count = (SELECT COUNT(*) FROM chars     WHERE hidden = FALSE) WHERE section = 'chars'|,
    q|UPDATE stats_cache SET count = (SELECT COUNT(*) FROM tags      WHERE state = 2)      WHERE section = 'tags'|,
    q|UPDATE stats_cache SET count = (SELECT COUNT(*) FROM traits    WHERE state = 2)      WHERE section = 'traits'|,
    q|UPDATE stats_cache SET count = (SELECT COUNT(*) FROM threads   WHERE hidden = FALSE) WHERE section = 'threads'|,
    q|UPDATE stats_cache SET count = (SELECT COUNT(*) FROM threads_posts WHERE hidden = FALSE
        AND EXISTS(SELECT 1 FROM threads WHERE threads.id = tid AND threads.hidden = FALSE)) WHERE section = 'threads_posts'|
  );
}


sub logrotate {
  my $dir = sprintf '%s/old', $VNDB::M{log_dir};
  mkdir $dir if !-d $dir;

  for (glob sprintf '%s/*', $VNDB::M{log_dir}) {
    next if /^\./ || /~$/ || !-f;
    my $f = /([^\/]+)$/ ? $1 : $_;
    my $n = sprintf '%s/%s.%04d-%02d-%02d.gz', $dir, $f, (localtime)[5]+1900, (localtime)[4]+1, (localtime)[3];
    if(-f $n) {
      $_[KERNEL]->call(core => log => 'Logs already rotated earlier today!');
      return;
    }
    open my $I, '<', sprintf '%s/%s', $VNDB::M{log_dir}, $f;
    open my $O, '>:gzip', $n;
    print $O $_ while <$I>;
    close $O;
    close $I;
    open $I, '>', sprintf '%s/%s', $VNDB::M{log_dir}, $f;
    close $I;
  }
  $_[KERNEL]->call(core => log => 'Logs rotated.');
}


#
#  V N   S E A R C H   C A C H E
#


sub vnsearch_check {
  $_[KERNEL]->call(pg => query =>
    'SELECT id FROM vn WHERE c_search IS NULL LIMIT 1',
    undef, 'vnsearch_gettitles');
}


sub vnsearch_gettitles { # num, res
  return $_[KERNEL]->delay('vnsearch_check', $_[HEAP]{vnsearch_checkdelay}) if $_[ARG0] == 0;
  my $id = $_[ARG1][0]{id};

  # fetch the titles
  $_[KERNEL]->call(pg => query => q{
    SELECT vr.title, vr.original, vr.alias
      FROM vn v
      JOIN vn_rev vr ON vr.id = v.latest
     WHERE v.id = ?
    UNION
    SELECT rr.title, rr.original, NULL
      FROM releases r
      JOIN releases_rev rr ON rr.id = r.latest
      JOIN releases_vn rv ON rv.rid = r.latest
     WHERE rv.vid = ?
       AND NOT r.hidden
  }, [ $id, $id ], 'vnsearch_update', $id);
}


sub vnsearch_update { # num, res, vid, time
  my($res, $id, $time) = @_[ARG1..ARG3];
  my @t = map +($_->{title}, $_->{original}), @$res;
  # alias fields are a bit special
  for (@$res) {
    push @t, split /[\n,]/, $_->{alias} if $_->{alias};
  }
  my $t = normalize_titles(@t);
  $_[KERNEL]->call(core => log => 'Updated search cache for v%d', $id);
  $_[KERNEL]->call(pg => do =>
    q|UPDATE vn SET c_search = ? WHERE id = ?|,
    [ $t, $id ], 'vnsearch_check');
}


1;

