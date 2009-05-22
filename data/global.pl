
package VNDB;

our(%O, %S, $ROOT);


# options for YAWF
our %O = (
  db_login  => [ 'dbi:Pg:dbname=vndb', 'vndb', 'passwd' ],
  debug     => 1,
  logfile   => $ROOT.'/data/log/vndb.log',
);


# VNDB-specific options (object_data)
our %S = (%S,
  version         => `cd $VNDB::ROOT; git describe` =~ /^(.+)$/ && $1,
  url             => 'http://vndb.org',
  url_static      => 'http://s.vndb.org',
  site_title      => 'Yet another VNDB clone',
  skin_default    => 'angel',
  cookie_domain   => '.vndb.org',
  cookie_key      => 'any-private-string-here',
  source_url      => 'http://git.blicky.net/vndb.git/?h=master',
  admin_email     => 'contact@vndb.org',
  sharedmem_key   => 'VNDB',
  user_ranks      => [
       # rankname   allowed actions                                   # DB number
    [qw| visitor    hist                                                     |], # 0
    [qw| banned     hist                                                     |], # 1
    [qw| loser      hist board                                               |], # 2
    [qw| user       hist board edit tag                                      |], # 3
    [qw| mod        hist board boardmod edit tag mod lock del tagmod         |], # 4
    [qw| admin      hist board boardmod edit tag mod lock del tagmod usermod |], # 5
  ],
  languages       => {
    cs  => q|Czech|,
    da  => q|Danish|,
    de  => q|German|,
    en  => q|English|,
    es  => q|Spanish|,
    fi  => q|Finnish|,
    fr  => q|French|,
    it  => q|Italian|,
    ja  => q|Japanese|,
    ko  => q|Korean|,
    nl  => q|Dutch|,
    no  => q|Norwegian|,
    pl  => q|Polish|,
    pt  => q|Portuguese|,
    ru  => q|Russian|,
    sv  => q|Swedish|,
    tr  => q|Turkish|,
    zh  => q|Chinese|,
  },
  producer_types  => {
    co => 'Company',
    in => 'Individual',
    ng => 'Amateur group',
  },
  discussion_boards => {
    an => 'Announcements',    # 0   - usage restricted to boardmods
    db => 'VNDB Discussions', # 0
    v  => 'Visual novels',    # vid
    p  => 'Producers',        # pid
    u  => 'Users',            # uid
  },
  vn_lengths      => [
    [ 'Unkown',     '',              '' ],
    [ 'Very short', '< 2 hours',     'OMGWTFOTL, A Dream of Summer' ],
    [ 'Short',      '2 - 10 hours',  'Narcissu, Planetarian' ],
    [ 'Medium',     '10 - 30 hours', 'Kana: Little Sister' ],
    [ 'Long',       '30 - 50 hours', 'Tsukihime' ],
    [ 'Very long',  '> 50 hours',    'Clannad' ],
  ],
  categories      => {
    g => [ 'Gameplay', {
      aa => 'NVL',     # 0..1
      ab => 'ADV',     # 0..1
      ac => "Act\x{200B}ion",      # Ugliest. Hack. Ever.
      rp => 'RPG',
      st => 'Strategy',
      si => 'Simulation',
    }, 2 ],
    p => [ 'Plot', {        # 0..1
      li => 'Linear',
      br => 'Branching',
    }, 3 ],
    e => [ 'Elements', {
      ac => 'Action',
      co => 'Comedy',
      dr => 'Drama',
      fa => 'Fantasy',
      ho => 'Horror',
      my => 'Mystery',
      ro => 'Romance',
      sc => 'School Life',
      sf => 'SciFi', 
      sj => 'Shoujo Ai',
      sn => 'Shounen Ai',
    }, 1 ],
    t => [ 'Time', {        # 0..1
      fu => 'Future',
      pa => 'Past', 
      pr => 'Present',
    }, 4 ],
    l => [ 'Place', {       # 0..1
      ea => 'Earth', 
      fa => "Fant\x{200B}asy world",
      sp => 'Space',
    }, 5 ],
    h => [ 'Protagonist', { # 0..1
      fa => 'Male',
      fe => "Fem\x{200B}ale",
    }, 6 ],
    s => [ 'Sexual content', {
      aa => 'Sexual content',
      be => 'Bestiality',
      in => 'Incest',
      lo => 'Lolicon',
      sh => 'Shotacon',
      ya => 'Yaoi',
      yu => 'Yuri',
      ra => 'Rape',
    }, 7 ],
  },
  anime_types     => [
    # VNDB          AniDB
    [ 'unknown',    'unknown',    ],
    [ 'TV',         'TV Series'   ],
    [ 'OVA',        'OVA'         ],
    [ 'Movie',      'Movie'       ],
    [ 'unknown',    'Other'       ],
    [ 'unknown',    'Web'         ],
    [ 'TV Special', 'TV Special'  ],
    [ 'unknown',    'Music Video' ],
  ],
  vn_relations    => [
    # Name,           Reverse--
    [ 'Sequel',              0 ],
    [ 'Prequel',             1 ],
    [ 'Same setting',        0 ],
    [ 'Alternative setting', 0 ],
    [ 'Alternative version', 0 ],
    [ 'Same characters',     0 ],
    [ 'Side story',          0 ],
    [ 'Parent story',        1 ],
    [ 'Summary',             0 ],
    [ 'Full story',          1 ],
    [ 'Other',               0 ],
  ],
  age_ratings     => {
    -1 => [ 'Unknown' ],
    0  => [ 'All ages' ,'CERO A' ],
    6  => [ '6+' ],
    7  => [ '7+' ],
    8  => [ '8+' ],
    9  => [ '9+' ],
    10 => [ '10+' ],
    11 => [ '11+' ],
    12 => [ '12+', 'CERO B' ],
    13 => [ '13+' ],
    14 => [ '14+' ],
    15 => [ '15+', 'CERO C' ],
    16 => [ '16+' ],
    17 => [ '17+', 'CERO D' ],
    18 => [ '18+', 'CERO Z' ],
  },
  release_types   => [
    'Complete',
    'Partial',
    'Trial'
  ],
  platforms       => {
    win => 'Windows',
    lin => 'Linux',
    mac => 'Mac OS',
    dvd => 'DVD Player',
    gba => "Game Boy Ad\x{200B}vance",
    msx => 'MSX',
    nds => 'Nintendo DS',
    nes => 'Famicom',
    psp => 'Playstation Portable',
    ps1 => 'Playstation 1',
    ps2 => 'Playstation 2',
    ps3 => 'Playstation 3',
    drc => 'Dreamcast',
    sfc => 'Super Nintendo',
    wii => 'Nintendo Wii',
    xb3 => 'Xbox 360',
    oth => 'Other'
  },
  media           => {
   #DB       display            qty
    cd  => [ 'CD',                1 ],
    dvd => [ 'DVD',               1 ],
    gdr => [ 'GD',                1 ],
    blr => [ 'Blu-ray',           1 ],
    flp => [ 'Floppy',            1 ],
    mrt => [ 'Cartridge',         1 ],
    mem => [ 'Memory card',       1 ],
    umd => [ 'UMD',               1 ],
    nod => [ 'Nintendo Optical Disk', 1 ],
    in  => [ 'Internet download', 0 ],
    otc => [ 'Other',             0 ],
  },
  resolutions     => [
    [ 'Unknown',         '' ],
    [ '640x480',         '4:3' ],
    [ '800x600',         '4:3' ],
    [ '1024x768',        '4:3' ],
    [ '640x400',         'widescreen' ],
    [ '1024x640',        'widescreen' ],
    [ '1280x720',        'widescreen' ],
    [ '480x272 (PSP)',   'other' ],
    [ '2x256x192 (NDS)', 'other' ],
    [ '640x448 (TV)',    'other' ], # really?
    [ 'Custom',          'other' ],
  ],
  voiced          => [
    'Unknown',
    'Unvoiced',
    'Only ero scenes voiced',
    'Partially voiced',
    'Fully voiced',
  ],
  votes           => [
    'worst ever',
    'awful',
    'bad',
    'weak',
    'so-so',
    'decent',
    'good',
    'very good',
    'excellent',
    'masterpiece',
  ],
  wishlist_status => [
    'high',
    'medium',
    'low',
    'blacklist',
  ],
  # note: keep these synchronised in script.js
  vn_rstat        => [
    'Unknown',
    'Pending',
    'Obtained', # hardcoded
    'On loan',
    'Deleted',
  ],
  vn_vstat        => [
    'Unknown',
    'Playing',
    'Finished', # hardcoded
    'Stalled',
    'Dropped',
  ],
);


# Multi-specific options (Multi also uses some options in %S and %O)
our %M = (
  log_dir   => $ROOT.'/data/log',
  log_level => 3,        # 3: dbg, 2: wrn, 1: err
  modules   => {
    RG          => {},
    Image       => {},
    Sitemap     => {},
    #Anime       => {},  # disabled by default, requires AniDB username/pass
    Maintenance => {},
    #IRC         => {},  # disabled by default, no need to run an IRC bot when debugging
  },
);


# allow the settings to be overwritten in config.pl
require $ROOT.'/data/config.pl' if -f $ROOT.'/data/config.pl';

1;


