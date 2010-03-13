
package VNDB::Func;

use strict;
use warnings;
use YAWF ':html';
use Exporter 'import';
use POSIX 'strftime', 'ceil', 'floor';
use VNDBUtil;
our @EXPORT = (@VNDBUtil::EXPORT, qw| liststat clearfloat cssicon tagscore mt minage |);


# Argument: hashref with rstat and vstat
# Returns: empty string if not in list, otherwise colour-encoded list status
sub liststat {
  my $l = shift;
  return '' if !$l;
  my $rs = mt('_rlst_rstat_'.$l->{rstat});
  $rs = qq|<b class="done">$rs</b>| if $l->{rstat} == 2; # Obtained
  $rs = qq|<b class="todo">$rs</b>| if $l->{rstat} < 2; # Unknown/pending
  my $vs = mt('_rlst_vstat_'.$l->{vstat});
  $vs = qq|<b class="done">$vs</b>| if $l->{vstat} == 2; # Finished
  $vs = qq|<b class="todo">$vs</b>| if $l->{vstat} == 0 || $l->{vstat} == 4; # Unknown/dropped
  return "$rs / $vs";
}


# Clears a float, to make sure boxes always have the correct height
sub clearfloat {
  div class => 'clearfloat', '';
}


# Draws a CSS icon, arguments: class, title
sub cssicon {
  acronym class => "icons $_[0]", title => $_[1];
   lit '&nbsp;';
  end;
}


# Tag score in html tags, argument: score, users
sub tagscore {
  my $s = shift;
  div class => 'taglvl', style => sprintf('width: %.0fpx', ($s-floor($s))*10), ' ' if $s < 0 && $s-floor($s) > 0;
  for(-3..3) {
    div(class => "taglvl taglvl0", sprintf '%.1f', $s), next if !$_;
    if($_ < 0) {
      if($s > 0 || floor($s) > $_) {
        div class => "taglvl taglvl$_", ' ';
      } elsif(floor($s) != $_) {
        div class => "taglvl taglvl$_ taglvlsel", ' ';
      } else {
        div class => "taglvl taglvl$_ taglvlsel", style => sprintf('width: %.0fpx', 10-($s-$_)*10), ' ';
      }
    } else {
      if($s < 0 || ceil($s) < $_) {
        div class => "taglvl taglvl$_", ' ';
      } elsif(ceil($s) != $_) {
        div class => "taglvl taglvl$_ taglvlsel", ' ';
      } else {
        div class => "taglvl taglvl$_ taglvlsel", style => sprintf('width: %.0fpx', 10-($_-$s)*10), ' ';
      }
    }
  }
  div class => 'taglvl', style => sprintf('width: %.0fpx', (ceil($s)-$s)*10), ' ' if $s > 0 && ceil($s)-$s > 0;
}


# short wrapper around maketext()
# (not thread-safe, in the same sense as YAWF::XML. But who cares about threads, anyway?)
sub mt {
  return $YAWF::OBJ->{l10n}->maketext(@_);
}


sub minage {
  my($a, $ex) = @_;
  my $str = !defined($a) ? mt '_minage_null' : !$a ? mt '_minage_all' : mt '_minage_age', $a;
  $ex = !defined($a) ? '' : {
     0 => 'CERO A',
    12 => 'CERO B',
    15 => 'CERO C',
    17 => 'CERO D',
    18 => 'CERO Z',
  }->{$a} if $ex;
  return $str if !$ex;
  return $str.' '.mt('_minage_example', $ex);
}


1;

