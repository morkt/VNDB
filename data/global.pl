
package VNDB;

our(%O, %S, $ROOT);


# options for TUWF
our %O = (
  db_login  => [ 'dbi:Pg:dbname=vndb', 'vndb', 'passwd' ],
  debug     => 1,
  logfile   => $ROOT.'/data/log/vndb.log',
  cookie_prefix   => 'vndb_',
  cookie_defaults => {
    domain => '.vndb.org',
    path   => '/',
  },
);


# VNDB-specific options (object_data)
our %S = (%S,
  version         => `cd $VNDB::ROOT; git describe` =~ /^(.+)$/ && $1,
  url             => 'http://vndb.org',   # Only used by Multi, web pages infer their own address
  url_static      => 'http://s.vndb.org',
  skin_default    => 'angel',
  global_salt     => 'any-private-string-here',
  form_salt       => 'a-different-private-string-here',
  scrypt_args     => [ 65536, 8, 1 ], # N, r, p
  scrypt_salt     => 'another-random-string',
  regen_static    => 0,
  source_url      => 'http://git.blicky.net/vndb.git/?h=master',
  admin_email     => 'contact@vndb.org',
  login_throttle  => [ 24*3600/10, 24*3600 ], # interval between attempts, max burst (10 a day)
  scr_size        => [ 136, 102 ], # w*h of screenshot thumbnails
  ch_size         => [ 256, 300 ], # max. w*h of char images
  cv_size         => [ 256, 400 ], # max. w*h of cover images
                     # bit flags (Flag 8 was used for staffedit)
  permissions     => {qw| board 1  boardmod 2  edit 4  staffedit 4  tag 16  dbmod 32  tagmod 64  usermod 128  affiliate 256 |},
  languages       => [qw|ar ca cs da de en es fi fr he hu id it ja ko nl no pl pt-br pt-pt ro ru sk sv tr uk vi zh|],
  producer_types  => [qw|co in ng|],
  discussion_boards => [qw|an db ge v p u|], # <- note that some properties of these boards are hard-coded
  vn_lengths      => [ 0..5 ],
  anime_types     => [qw|tv ova mov oth web spe mv|],
  board_edit_time => 7*24*3600,
  vn_relations    => {
  # id   => [ order, reverse ]
    seq  => [ 0, 'preq' ],
    preq => [ 1, 'seq'  ],
    set  => [ 2, 'set'  ],
    alt  => [ 3, 'alt'  ],
    char => [ 4, 'char' ],
    side => [ 5, 'par'  ],
    par  => [ 6, 'side' ],
    ser  => [ 7, 'ser'  ],
    fan  => [ 8, 'orig' ],
    orig => [ 9, 'fan'  ],
  },
  prod_relations  => {
    'old' => [ 0, 'new' ],
    'new' => [ 1, 'old' ],
    'spa' => [ 2, 'ori' ],
    'ori' => [ 3, 'spa' ],
    'sub' => [ 4, 'par' ],
    'par' => [ 5, 'sub' ],
    'imp' => [ 6, 'ipa' ],
    'ipa' => [ 7, 'imp' ],
  },
  age_ratings     => [-1, 0, 6..18],
  release_types   => [qw|complete partial trial|],
  # The 'unk' platform and medium are reserved for "unknown".
  platforms       => [qw|win dos lin mac ios and dvd bdp fmt gba gbc msx nds nes p88 p98 pce pcf psp ps1 ps2 ps3 ps4 psv drc sat sfc wii n3d x68 xb1 xb3 xbo web oth|],
  media           => {
   #DB     qty?
    cd  => 1,
    dvd => 1,
    gdr => 1,
    blr => 1,
    flp => 1,
    mrt => 1,
    mem => 1,
    umd => 1,
    nod => 1,
    in  => 0,
    otc => 0
  },
  resolutions     => [
    [ '_scrres_unknown', '' ],
    [ '_scrres_nonstandard', '' ],
    [ '640x480',      '4:3' ],
    [ '800x600',      '4:3' ],
    [ '1024x768',     '4:3' ],
    [ '1280x960',     '4:3' ],
    [ '1600x1200',    '4:3' ],
    [ '640x400',      '_scrres_ws' ],
    [ '960x600',      '_scrres_ws' ],
    [ '1024x576',     '_scrres_ws' ],
    [ '1024x600',     '_scrres_ws' ],
    [ '1024x640',     '_scrres_ws' ],
    [ '1280x720',     '_scrres_ws' ],
    [ '1280x800',     '_scrres_ws' ],
    [ '1920x1080',    '_scrres_ws' ],
  ],
  tag_categories  => [ qw|cont ero tech| ],
  voiced          => [ 0..4 ],
  animated        => [ 0..4 ],
  wishlist_status => [ 0..3 ],
  rlist_status    => [ 0..4 ], # 2 = hardcoded 'OK'
  vnlist_status   => [ 0..4 ],
  blood_types     => [qw| unknown o a b ab |],
  genders         => [qw| unknown m f b |],
  char_roles      => [qw| main primary side appears |],
  atom_feeds => { # num_entries, title, id
    announcements => [ 10, 'VNDB Site Announcements', '/t/an' ],
    changes       => [ 25, 'VNDB Recent Changes', '/hist' ],
    posts         => [ 25, 'VNDB Recent Posts', '/t' ],
  },
  staff_roles     => [qw|scenario chardesign art music songs director staff|],
);


# Multi-specific options (Multi also uses some options in %S and %O)
our %M = (
  log_dir   => $ROOT.'/data/log',
  log_level => 'trace',
  modules   => {
    #API         => {},  # disabled by default, not really needed
    #APIDump     => {},
    Feed        => {},
    RG          => {},
    #Anime       => {},  # disabled by default, requires AniDB username/pass
    Maintenance => {},
    #IRC         => {},  # disabled by default, no need to run an IRC bot when debugging
  },
);


# allow the settings to be overwritten in config.pl
require $ROOT.'/data/config.pl' if -f $ROOT.'/data/config.pl';

1;

