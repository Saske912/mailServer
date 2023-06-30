#
# This file is managed by iRedMail Team <support@iredmail.org> with Ansible,
# please do __NOT__ modify it manually.
#
#
# If you need to modify any settings in this file, please define your custom
# settings in /opt/iredmail/custom/amavisd/amavisd.conf to override settings
# in this file.
#

use strict;

# controls running of anti-virus/spam code: 0 -> enabled, 1 -> disabled.
@bypass_virus_checks_maps = 0;
@bypass_spam_checks_maps = 0;
# $bypass_decode_parts = 1;         # controls running of decoders&dearchivers

$daemon_user  = 'amavis';    # (no default;  customary: vscan or amavis), -u
$daemon_group = 'amavis';    # (no default;  customary: vscan or amavis), -g

# Set hostname.
$myhostname = "mail.my-flora.shop";
$mydomain = $myhostname;
$localhost_name = $myhostname;

#
# NOTE: $MYHOME/{tmp,var,db} must be created manually
#
$MYHOME = '/var/spool/amavisd';
$TEMPBASE = "/var/spool/amavisd/tmp";   # working directory, needs to exist, -T
$ENV{TMPDIR} = $TEMPBASE;   # environment variable TMPDIR, used by SA, etc.
$db_home = "/var/spool/amavisd/db";      # dir for bdb nanny/cache/snmp databases, -D
$QUARANTINEDIR = "/var/spool/amavisd/quarantine";     # -Q
$quarantine_subdir_levels = 2;  # add level of subdirs to disperse quarantine
# $release_format = 'resend';     # 'attach', 'plain', 'resend'
# $report_format  = 'arf';        # 'attach', 'plain', 'resend', 'arf'
# $daemon_chroot_dir = $MYHOME;   # chroot directory or undef, -R
# $helpers_home = "$MYHOME/var";  # working directory for SpamAssassin, -S

$lock_file = "/var/run/amavis/amavisd.lock";  # -L
$pid_file = "/var/run/amavis/amavisd.pid";   # -P

@local_domains_maps = 1;
@mynetworks = qw( 127.0.0.0/8 [::1] );

# Socket file, used by amavisd-release or amavis-milter.
$unix_socketname = "/var/run/amavis/amavisd.sock";

#
# BDB
#
$enable_db = 0;              # enable use of BerkeleyDB/libdb (SNMP and nanny)
$nanny_details_level = 2;    # nanny verbosity: 1: traditional, 2: detailed

$inet_socket_port = [10024, 10026, 10027, 9998];

$policy_bank{'MYNETS'} = {   # mail originating from @mynetworks
    originating => 1,  # is true in MYNETS by default, but let's make it explicit
    os_fingerprint_method => undef,  # don't query p0f for internal clients
    allow_disclaimers => 1, # enables disclaimer insertion if available
    enable_dkim_signing => 1,
};

# Postfix will re-route mail from authenticated users to this port.
$interface_policy{'10026'} = 'ORIGINATING';
$policy_bank{'ORIGINATING'} = {
    originating => 1,         # declare that mail was submitted by our smtp client
    allow_disclaimers => 1,   # enables disclaimer insertion if available
    enable_dkim_signing => 1,

    # notify administrator of locally originating malware
    virus_admin_maps => ["root\@$mydomain"],
    spam_admin_maps  => ["root\@$mydomain"],
    warnbadhsender   => 0,

    # force MTA conversion to 7-bit (e.g. before DKIM signing)
    smtpd_discard_ehlo_keywords => ['8BITMIME'],
    terminate_dsn_on_notify_success => 0,  # don't remove NOTIFY=SUCCESS option

    # Bypass checks
    #bypass_spam_checks_maps => [1],    # don't check spam
    #bypass_virus_checks_maps => [1],   # don't check virus
    #bypass_banned_checks_maps => [1],  # don't check banned file names and types
    #bypass_header_checks_maps => [1],  # don't check bad header
};

$interface_policy{'10027'} = 'MLMMJ';
$policy_bank{'MLMMJ'} = {
    originating => 1,           # declare that mail was submitted by our smtp client
    allow_disclaimers => 0,     # we use 'mlmmj-amime-receive' program to handle disclaimer/footer
    enable_dkim_signing => 1,   # enable DKIM signing for outbound
    virus_admin_maps => ["root\@$mydomain"],
    spam_admin_maps  => ["root\@$mydomain"],
    smtpd_discard_ehlo_keywords => ['8BITMIME'],
    terminate_dsn_on_notify_success => 0,  # don't remove NOTIFY=SUCCESS option
    # re-inject processed email to Postfix, with address mapping enabled.
    forward_method => 'smtp:[127.0.0.1]:10028',
    # Amavisd performs the checks for email sent to mailing list, so no need to
    # check again for outbound.
    bypass_spam_checks_maps => [1],     # don't check spam
    bypass_virus_checks_maps => [1],    # don't check virus
    bypass_banned_checks_maps => [1],   # don't check banned file names and types
    bypass_header_checks_maps => [1],   # don't check bad header
};

$interface_policy{'SOCK'} = 'AM.PDP-SOCK'; # only applies with $unix_socketname

# Use with amavis-release over a socket or with Petr Rehor's amavis-milter.c
# (with amavis-milter.c from this package or old amavis.c client use 'AM.CL'):
$policy_bank{'AM.PDP-SOCK'} = {
    protocol => 'AM.PDP',
    auth_required_release => 0,  # do not require secret_id for amavisd-release
};

$sa_tag_level_deflt  = 2.0;  # add spam info headers if at, or above that level
$sa_tag2_level_deflt = 6.2;  # add 'spam detected' headers at that level
$sa_kill_level_deflt = 6.9;  # triggers spam evasive actions (e.g. blocks mail)
$sa_dsn_cutoff_level = 10;   # spam level beyond which a DSN is not sent
$sa_crediblefrom_dsn_cutoff_level = 18; # likewise, but for a likely valid From
#$sa_quarantine_cutoff_level = 25; # spam level beyond which quarantine is off

$sa_mail_body_size_limit = 400*1024; # don't waste time on SA if mail is larger
$sa_local_tests_only = 0;    # only tests which do not require internet access?

$virus_admin               = undef;                    # notifications recip.

$mailfrom_notify_admin     = undef;                    # notifications sender
$mailfrom_notify_recip     = undef;                    # notifications sender
$mailfrom_notify_spamadmin = undef;                    # notifications sender
$mailfrom_to_quarantine = ''; # null return path; uses original sender if undef

@addr_extension_virus_maps      = ('virus');
@addr_extension_banned_maps     = ('banned');
@addr_extension_spam_maps       = ('spam');
@addr_extension_bad_header_maps = ('badh');
# $recipient_delimiter = '+';  # undef disables address extensions altogether
# when enabling addr extensions do also Postfix/main.cf: recipient_delimiter=+

$path = '/usr/local/sbin:/usr/local/bin:/usr/sbin:/sbin:/usr/bin:/bin';
# $dspam = 'dspam';

$MAXLEVELS = 14;
$MAXFILES = 3000;
$MIN_EXPANSION_QUOTA =      100*1024;  # bytes  (default undef, not enforced)
$MAX_EXPANSION_QUOTA = 500*1024*1024;  # bytes  (default undef, not enforced)

# Prepend '[SPAM] ' to subject of spam message.
$sa_spam_modifies_subj = 1;
$sa_spam_subject_tag = '';

$defang_virus  = 1;  # MIME-wrap passed infected mail
$defang_banned = 0;  # MIME-wrap passed mail containing banned name
# for defanging bad headers only turn on certain minor contents categories:
$defang_by_ccat{CC_BADH.",3"} = 1;  # NUL or CR character in header
$defang_by_ccat{CC_BADH.",5"} = 1;  # header line longer than 998 characters
$defang_by_ccat{CC_BADH.",6"} = 1;  # header field syntax error

@keep_decoded_original_maps = (new_RE(
    # let virus scanner (clamav) see full original message (can be slow)
    # this setting is required if we're going to use third-party clamav
    # signatures. for example, Sanesecurity signatures.
    # FYI: http://sanesecurity.com/support/signature-testing/
    #qr'^MAIL$',

    qr'^MAIL-UNDECIPHERABLE$', # same as ^MAIL$ if mail is undecipherable
    qr'^(ASCII(?! cpio)|text|uuencoded|xxencoded|binhex)'i,
    #qr'^Zip archive data',     # don't trust Archive::Zip
));

# ENVELOPE SENDER SOFT-WHITELISTING / SOFT-BLACKLISTING

@score_sender_maps = ({ # a by-recipient hash lookup table,
                        # results from all matching recipient tables are summed

# ## per-recipient personal tables  (NOTE: positive: black, negative: white)
# 'user1@example.com'  => [{'bla-mobile.press@example.com' => 10.0}],
# 'user3@example.com'  => [{'.ebay.com'                 => -3.0}],
# 'user4@example.com'  => [{'cleargreen@cleargreen.com' => -7.0,
#                           '.cleargreen.com'           => -5.0}],

  ## site-wide opinions about senders (the '.' matches any recipient)
  '.' => [  # the _first_ matching sender determines the score boost

   new_RE(  # regexp-type lookup table, just happens to be all soft-blacklist
    [qr'^(bulkmail|offers|cheapbenefits|earnmoney|foryou)@'i         => 5.0],
    [qr'^(greatcasino|investments|lose_weight_today|market\.alert)@'i=> 5.0],
    [qr'^(money2you|MyGreenCard|new\.tld\.registry|opt-out|opt-in)@'i=> 5.0],
    [qr'^(optin|saveonlsmoking2002k|specialoffer|specialoffers)@'i   => 5.0],
    [qr'^(stockalert|stopsnoring|wantsome|workathome|yesitsfree)@'i  => 5.0],
    [qr'^(your_friend|greatoffers)@'i                                => 5.0],
    [qr'^(inkjetplanet|marketopt|MakeMoney)\d*@'i                    => 5.0],
   ),

   #read_hash("/var/amavis/sender_scores_sitewide"),

   { # a hash-type lookup table (associative array)
     'nobody@cert.org'                        => -3.0,
     'cert-advisory@us-cert.gov'              => -3.0,
     'owner-alert@iss.net'                    => -3.0,
     'slashdot@slashdot.org'                  => -3.0,
     'securityfocus.com'                      => -3.0,
     'ntbugtraq@listserv.ntbugtraq.com'       => -3.0,
     'security-alerts@linuxsecurity.com'      => -3.0,
     'mailman-announce-admin@python.org'      => -3.0,
     'amavis-user-admin@lists.sourceforge.net'=> -3.0,
     'amavis-user-bounces@lists.sourceforge.net' => -3.0,
     'spamassassin.apache.org'                => -3.0,
     'notification-return@lists.sophos.com'   => -3.0,
     'owner-postfix-users@postfix.org'        => -3.0,
     'owner-postfix-announce@postfix.org'     => -3.0,
     'owner-sendmail-announce@lists.sendmail.org'   => -3.0,
     'sendmail-announce-request@lists.sendmail.org' => -3.0,
     'donotreply@sendmail.org'                => -3.0,
     'ca+envelope@sendmail.org'               => -3.0,
     'noreply@freshmeat.net'                  => -3.0,
     'owner-technews@postel.acm.org'          => -3.0,
     'ietf-123-owner@loki.ietf.org'           => -3.0,
     'cvs-commits-list-admin@gnome.org'       => -3.0,
     'rt-users-admin@lists.fsck.com'          => -3.0,
     'clp-request@comp.nus.edu.sg'            => -3.0,
     'surveys-errors@lists.nua.ie'            => -3.0,
     'emailnews@genomeweb.com'                => -5.0,
     'yahoo-dev-null@yahoo-inc.com'           => -3.0,
     'returns.groups.yahoo.com'               => -3.0,
     'clusternews@linuxnetworx.com'           => -3.0,
     lc('lvs-users-admin@LinuxVirtualServer.org')    => -3.0,
     lc('owner-textbreakingnews@CNNIMAIL12.CNN.COM') => -5.0,

     # soft-blacklisting (positive score)
     'sender@example.net'                     =>  3.0,
     '.example.net'                           =>  1.0,

   },
  ],  # end of site-wide tables
});


@decoders = (
  ['mail', \&do_mime_decode],
# [[qw(asc uue hqx ync)], \&do_ascii],  # not safe
  ['F',    \&do_uncompress, ['unfreeze', 'freeze -d', 'melt', 'fcat'] ],
  ['Z',    \&do_uncompress, ['uncompress', 'gzip -d', 'zcat'] ],
  ['gz',   \&do_uncompress, 'gzip -d'],
  ['gz',   \&do_gunzip],
  ['bz2',  \&do_uncompress, 'bzip2 -d'],
  ['xz',   \&do_uncompress,
           ['xzdec', 'xz -dc', 'unxz -c', 'xzcat'] ],
  ['lzma', \&do_uncompress,
           ['lzmadec', 'xz -dc --format=lzma',
            'lzma -dc', 'unlzma -c', 'lzcat', 'lzmadec'] ],
  ['lrz',  \&do_uncompress,
           ['lrzip -q -k -d -o -', 'lrzcat -q -k'] ],
  ['lzo',  \&do_uncompress, 'lzop -d'],
  ['lz4',  \&do_uncompress, ['lz4c -d'] ],
  ['rpm',  \&do_uncompress, ['rpm2cpio.pl', 'rpm2cpio'] ],
  [['cpio','tar'], \&do_pax_cpio, ['pax', 'gcpio', 'cpio'] ],
           # ['/usr/local/heirloom/usr/5bin/pax', 'pax', 'gcpio', 'cpio']
  ['deb',  \&do_ar, 'ar'],
# ['a',    \&do_ar, 'ar'],  # unpacking .a seems an overkill
  ['rar',  \&do_unrar, ['unrar', 'rar'] ],
  ['arj',  \&do_unarj, ['unarj', 'arj'] ],
  ['arc',  \&do_arc,   ['nomarch', 'arc'] ],
  ['zoo',  \&do_zoo,   ['zoo', 'unzoo'] ],
# ['doc',  \&do_ole,   'ripole'],  # no ripole package so far
  ['cab',  \&do_cabextract, 'cabextract'],
# ['tnef', \&do_tnef_ext, 'tnef'],  # use internal do_tnef() instead
  ['tnef', \&do_tnef],
# ['lha',  \&do_lha,   'lha'],  # not safe, use 7z instead
# ['sit',  \&do_unstuff, 'unstuff'],  # not safe
  [['zip','kmz'], \&do_7zip,  ['7za', '7z'] ],
  [['zip','kmz'], \&do_unzip],
  ['7z',   \&do_7zip,  ['7zr', '7za', '7z'] ],
  [[qw(gz bz2 Z tar)],
           \&do_7zip,  ['7za', '7z'] ],
  [[qw(xz lzma jar cpio arj rar swf lha iso cab deb rpm)],
           \&do_7zip,  '7z' ],
  ['exe',  \&do_executable, ['unrar','rar'], 'lha', ['unarj','arj'] ],
);
$pax = 'pax';

# Mark Spam/Virus with third-party clamav signatures: SaneSecurity.
#   *) The order matters, first match wins. Set to 'undef' to keep as infected
#   *) Anything declared as undefined will be marked as a virus
@virus_name_to_spam_score_maps =(new_RE(
    # SaneSecurity + Foxhole
    [ qr'^Sanesecurity\.(Malware|Badmacro|Foxhole|Rogue|Trojan)\.' => undef ],
    [ qr'^Sanesecurity\.MalwareHash\.'    => undef ],
    [ qr'^Sanesecurity.TestSig_'          => undef ],
    [ qr'^Sanesecurity\.'                 => 0.1 ],

    # winnow
    [ qr'^winnow\.(Exploit|Trojan|malware)\.'     => undef ],
    [ qr'^winnow\.(botnet|compromised|trojan)'    => undef ],
    [ qr'^winnow\.(exe|ms|JS)\.'                  => undef ],
    [ qr'^winnow\.phish\.'                        => 3.0 ],
    [ qr'^winnow\.'                               => 0.1 ],

    # bofhland
    [ qr'^Bofhland\.Malware\.'                    => undef ],
    [ qr'^BofhlandMWFile'                         => undef ],
    [ qr'^Bofhland\.Phishing\.'                   => 3.0 ],
    [ qr'^Bofhland\.'                             => 0.1 ],

    # porcupine.ndb
    [ qr'^Porcupine\.(Malware|Trojan)\.'          => undef ],
    [ qr'^Porcupine\.(Junk|Spammer)\.'            => 3.0 ],
    [ qr'^Porcupine\.Phishing\.'                  => 3.0 ],
    [ qr'^Porcupine\.'                            => 0.01 ],

    # phishtank.ndb
    [ qr'^PhishTank\.Phishing\.'                  => 3.0 ],

    # SecuriteInfo
    [ qr'^SecuriteInfo\.com\.Spam'                => 3.0 ],

    # Others
    [ qr'^Structured\.(SSN|CreditCardNumber)\b'            => 0.1 ],
    [ qr'^(Heuristics\.)?Phishing\.'                       => 0.1 ],
    [ qr'^(Email|HTML)\.Phishing\.(?!.*Sanesecurity)'      => 0.1 ],
    [ qr'^Email\.Spam\.Bounce(\.[^., ]*)*\.Sanesecurity\.' => 0   ],
    [ qr'^Email\.Spammail\b'                               => 0.1 ],
    [ qr'^MSRBL-(Images|SPAM)\b'                           => 0.1 ],
    [ qr'^VX\.Honeypot-SecuriteInfo\.com\.Joke'            => 0.1 ],
    [ qr'^VX\.not-virus_(Hoax|Joke)\..*-SecuriteInfo\.com(\.|\z)' => 0.1 ],
    [ qr'^Email\.Spam.*-SecuriteInfo\.com(\.|\z)'          => 0.1 ],
    [ qr'^Safebrowsing\.'                                  => 0.1 ],
    [ qr'^INetMsg\.SpamDomain'                             => 0.1 ],
    [ qr'^Doppelstern\.(Spam|Scam|Phishing|Junk|Lott|Loan)'=> 0.1 ],
    [ qr'^ScamNailer\.'                                    => 0.1 ],
    [ qr'^HTML/Bankish'                                    => 0.1 ],
    [ qr'(-)?SecuriteInfo\.com(\.|\z)'                     => undef ],
    [ qr'^MBL_NA\.UNOFFICIAL'                              => 0.1 ],
    [ qr'^MBL_'                                            => undef ],
));

@av_scanners = (
    ['clamav-socket',
    \&ask_daemon, ["CONTSCAN {}\n", "/tmp/clamd.socket"],
    qr/\bOK$/m, qr/\bFOUND$/m,
    qr/^.*?: (?!Infected Archive)(.*) FOUND$/m ],
);

#@av_scanners_backup = (
#    ['clamav-clamscan', 'clamscan',
#    "--stdout --disable-summary -r --tempdir=$TEMPBASE {}", [0], [1],
#    qr/^.*?: (?!Infected Archive)(.*) FOUND$/ ],
#);

#
# Port used to release quarantined mails.
#
$interface_policy{'9998'} = 'AM.PDP-INET';
$policy_bank{'AM.PDP-INET'} = {
    protocol => 'AM.PDP',       # select Amavis policy delegation protocol
    auth_required_release => 1,    # 0 - don't require secret_id for amavisd-release
    #log_level => 4,
    #always_bcc_by_ccat => {CC_CLEAN, 'admin@example.com'},
};

#########################
# Default action applied to detected spam/virus/banned/bad-header, and how to
# quarantine them
#
# Available actions:
#   - D_PASS: Mail will pass to recipients, regardless of bad contents.
#             If a quarantine is configured, a copy of the mail will go there.
#             Note that including a recipient in a @*_lovers_maps is
#             functionally equivalent to setting '*_destiny = D_PASS;'
#             for that recipient.
#
#   - D_BOUNCE: Mail will not be delivered to its recipients. A non-delivery
#               notification (bounce) will be created and sent to the sender.
#
#   - D_REJECT: Mail will not be delivered to its recipients. Amavisd will
#               send the typical 55x reject response to the upstream MTA and
#               that MTA may create a reject notice (bounce) and return it to
#               the sender.
#               This notice is not as informative as the one created using
#               D_BOUNCE, so usually D_BOUNCE is preferred over D_REJECT.
#               If a quarantine is configured, a copy of the mail will go
#               there, if not mail message will be lost, but the sender should
#               be notified their message was rejected.
#
#   - D_DISCARD: Mail will not be delivered to its recipients and the sender
#                normally will NOT be notified.
#                If a quarantine is configured, a copy of the mail will go
#                there, if not mail message will be lost. Note that there are
#                additional settings available that can send notifications to
#                persons that normally may not be notified when an undesirable
#                message is found, so it is possible to notify the sender even
#                when using D_DISCARD.
#
# Where to store quarantined mail message:
#
#   - 'local:spam-%i-%m', quarantine mail on local file system.
#   - 'sql:', quarantine mail in SQL server specified in @storage_sql_dsn.
#   - undef, do not quarantine mail.

# SPAM.
$final_spam_destiny = D_DISCARD;
$spam_quarantine_method = 'sql:';
$spam_quarantine_to = 'spam-quarantine';

# Virus
$final_virus_destiny = D_DISCARD;
$virus_quarantine_method = 'sql:';
$virus_quarantine_to = 'virus-quarantine';

# Banned
$final_banned_destiny = D_DISCARD;
$banned_files_quarantine_method = 'sql:';
$banned_quarantine_to = 'banned-quarantine';

# Bad header.
$final_bad_header_destiny = D_DISCARD;
$bad_header_quarantine_method = 'sql:';
$bad_header_quarantine_to = 'bad-header-quarantine';

#########################
# Quarantine CLEAN mails.
# Don't forget to enable clean quarantine in policy bank 'MYUSERS'.
#
#$clean_quarantine_method = 'sql:';
#$clean_quarantine_to = 'clean-quarantine';

# a string to prepend to Subject (for local recipients only) if mail could
# not be decoded or checked entirely, e.g. due to password-protected archives
#$undecipherable_subject_tag = '***UNCHECKED*** ';  # undef disables it
$undecipherable_subject_tag = undef;
# Hope to fix 'nested MAIL command' issue on high load server.
$smtp_connection_cache_enable = 0;

# The default set of header fields to be signed can be controlled
# by setting %signed_header_fields elements to true (to sign) or
# to false (not to sign). Keys must be in lowercase, e.g.:
# 0 -> off
# 1 -> on
$signed_header_fields{'received'} = 0;
$signed_header_fields{'to'} = 1;
$signed_header_fields{'from'} = 1;
$signed_header_fields{'subject'} = 1;
$signed_header_fields{'message-id'} = 1;
$signed_header_fields{'content-type'} = 1;
$signed_header_fields{'date'} = 1;
$signed_header_fields{'mime-version'} = 1;

#
# DKIM
#
# Enable DKIM verification globally.
$enable_dkim_verification = 1;

# Disable DKIM signing globally, because it's controlled per policy bank.
#$enable_dkim_signing = 1;

# Add dkim_key here.
%{ for domain in domains ~}
dkim_key("${domain.name}", "${domain.selector}", "/opt/iredmail/custom/amavisd/dkim/${domain.name}.pem");
%{ endfor ~}

@dkim_signature_options_bysender_maps = ({
    # 'd' defaults to a domain of an author/sender address,
    # 's' defaults to whatever selector is offered by a matching key

    # Per-domain dkim key
%{ for domain in domains ~}
    "${domain.name}"  => { d => "${domain.name}", a => 'rsa-sha256', ttl => 10*24*3600 },
%{ endfor ~}
    #'.' => {d => 'my-flora.shop',
    #        a => 'rsa-sha256',
    #        c => 'relaxed/simple',
    #        ttl => 30*24*3600 },
});

#
# Disclaimer settings
#
# Enable singing disclaimer in outgoing mails.
$defang_maps_by_ccat{+CC_CATCHALL} = [ 'disclaimer' ];

# Program used to signing disclaimer in outgoing mails.
$altermime = '/usr/bin/altermime';

# Disclaimer in plain text formart.
@altermime_args_disclaimer = qw(--disclaimer=/opt/iredmail/custom/postfix/disclaimer/_OPTION_.txt --disclaimer-html=/opt/iredmail/custom/postfix/disclaimer/_OPTION_.html --force-for-bad-html);

@disclaimer_options_bysender_maps = ({
    # Per-domain, per-user disclaimer setting:
    # '<domain>' => /path/to/disclaimer.txt,
    # '<email>' => /path/to/disclaimer.txt,

    # Catch-all disclaimer setting: /etc/postfix/disclaimer/default.txt
    '.' => 'default',
},);

$sql_allow_8bit_address = 1;
$timestamp_fmt_mysql = 1;   # if using MySQL *and* msgs.time_iso is TIMESTAMP;

# Reporting and quarantining.
@storage_sql_dsn = (['DBI:mysql:database=amavisd;host=127.0.0.1;port=3306', 'amavisd', '${amavispass}']);

# Lookup for per-recipient, per-domain and global policy.
@lookup_sql_dsn = @storage_sql_dsn;

# Don't send email with subject "UNCHECKED contents in mail FROM xxx".
delete $admin_maps_by_ccat{&CC_UNCHECKED};

# Do not notify administrator about SPAM/VIRUS from remote servers.
$virus_admin = undef;
$spam_admin = undef;
$banned_admin = undef;
$bad_header_admin = undef;

#
# Pre-define some policy banks.
#
# You can assign certain policy banks to clients/senders you want to whitelist
# with parameter `@client_ipaddr_policy` and @author_to_policy_bank_maps.
$policy_bank{'FULL_WHITELIST'} = {
    bypass_spam_checks_maps => [1],
    spam_lovers_maps => [1],
    bypass_decode_parts => 1,
    bypass_virus_checks_maps => [1],
    virus_lovers_maps => [1],
    bypass_banned_checks_maps => [1],
    banned_files_lovers_maps  => [1],
    bypass_header_checks_maps => [1],
    bad_header_lovers_maps => [1],
};

$policy_bank{'NO_SPAM_CHECK'} = {
    bypass_spam_checks_maps => [1],
    spam_lovers_maps => [1],
};

$policy_bank{'NO_VIRUS_CHECK'} = {
    bypass_decode_parts => 1,
    bypass_virus_checks_maps => [1],
    virus_lovers_maps => [1],
};

$policy_bank{'NO_BANNED_CHECK'} = {
    bypass_banned_checks_maps => [1],
    banned_files_lovers_maps  => [1],
};

$policy_bank{'NO_BAD_HEADER_CHECK'} = {
    bypass_header_checks_maps => [1],
    bad_header_lovers_maps => [1],
};

#$policy_bank{'MILD_WHITELIST'} = {
#    score_sender_maps => [ { '.' => [-1.8] } ],
#};

#
# Logging
#
$do_syslog = 1;             # log via syslogd (preferred)
$syslog_facility = 'mail';  # Syslog facility as a string
$log_level = 0;             # Amavisd log level.
                            # Verbosity: 0, 1, 2, 3, 4, 5.
$sa_debug = 0;              # SpamAssassin debugging (require $log_level).
                            # Default if off (0).

# Ban attachment file based on file type and MIME type.
$banned_filename_re = new_RE(
    ### BLOCKED ANYWHERE
    # qr'^UNDECIPHERABLE$',  # is or contains any undecipherable components
    qr'^\.(exe-ms|dll)$',                   # banned file(1) types, rudimentary
    # qr'^\.(exe|lha|cab|dll)$',              # banned file(1) types

    ### BLOCK THE FOLLOWING, EXCEPT WITHIN UNIX ARCHIVES:
    # [ qr'^\.(gz|bz2)$'             => 0 ],  # allow any in gzip or bzip2
    [ qr'^\.(rpm|cpio|tar)$'       => 0 ],  # allow any in Unix-type archives

    qr'.\.(pif|scr)$'i,                     # banned extensions - rudimentary
    # qr'^\.zip$',                            # block zip type

    ### BLOCK THE FOLLOWING, EXCEPT WITHIN ARCHIVES:
    # [ qr'^\.(zip|rar|arc|arj|zoo)$'=> 0 ],  # allow any within these archives

    qr'^application/x-msdownload$'i,        # block these MIME types
    qr'^application/x-msdos-program$'i,
    qr'^application/hta$'i,

    # qr'^message/partial$'i,         # rfc2046 MIME type
    # qr'^message/external-body$'i,   # rfc2046 MIME type

    # qr'^(application/x-msmetafile|image/x-wmf)$'i,  # Windows Metafile MIME type
    # qr'^\.wmf$',                            # Windows Metafile file(1) type

    # block certain double extensions in filenames
    qr'^(?!cid:).*\.[^./]*[A-Za-z][^./]*\.\s*(exe|vbs|pif|scr|bat|cmd|com|cpl|dll)[.\s]*$'i,

    # qr'\{[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}\}?'i, # Class ID CLSID, strict
    # qr'\{[0-9a-z]{4,}(-[0-9a-z]{4,}){0,7}\}?'i, # Class ID extension CLSID, loose

    qr'.\.(exe|vbs|pif|scr|cpl)$'i,             # banned extension - basic
    # qr'.\.(exe|vbs|pif|scr|cpl|bat|cmd|com)$'i, # banned extension - basic+cmd
    # qr'.\.(ade|adp|app|bas|bat|chm|cmd|com|cpl|crt|emf|exe|fxp|grp|hlp|hta|
    #        inf|ini|ins|isp|js|jse|lib|lnk|mda|mdb|mde|mdt|mdw|mdz|msc|msi|
    #        msp|mst|ocx|ops|pcd|pif|prg|reg|scr|sct|shb|shs|sys|vb|vbe|vbs|vxd|
    #        wmf|wsc|wsf|wsh)$'ix,                # banned extensions - long
    # qr'.\.(asd|asf|asx|url|vcs|wmd|wmz)$'i,     # consider also
    # qr'.\.(ani|cur|ico)$'i,                 # banned cursors and icons filename
    # qr'^\.ani$',                            # banned animated cursor file(1) type
    # qr'.\.(mim|b64|bhx|hqx|xxe|uu|uue)$'i,  # banned extension - WinZip vulnerab.
);
# See http://support.microsoft.com/default.aspx?scid=kb;EN-US;q262631
# and http://www.cknow.com/vtutor/vtextensions.htm


# Amavisd on some Linux/BSD distribution use $banned_namepath_re instead of
# $banned_filename_re above.
#
# Sample input for $banned_namepath_re:
#
#   P=p003\tL=1\tM=multipart/mixed\nP=p002\tL=1/2\tM=application/octet-stream\tT=dat\tN=my_docum.zip
#   P=p003,L=1,M=multipart/mixed | P=p002,L=1/2,M=application/zip,T=zip,N=FedEx_00628727.zip | P=p005,L=1/2/2,T=asc,N=FedEx_00628727.doc.wsf
#
# What it means:
#   - T: type. e.g. zip archive.
#   - M: MIME type. e.g. application/octet-stream.
#   - N: suggested (MIME) name. e.g. my_docum.zip.

$banned_namepath_re = new_RE(

    #[qr'T=(rar|arc|arj|zoo|gz|bz2)(,|\t)'xmi => 'DISCARD'],     # Compressed file types
    [qr'T=x-(msdownload|msdos-program|msmetafile)(,|\t)'xmi => 'DISCARD'],
    [qr'T=(hta)(,|\t)'xmi => 'DISCARD'],

    # Dangerous mime types
    [qr'T=(9|386|LeChiffre|aaa|abc|aepl|ani|aru|atm|aut|b64|bat|bhx|bin|bkd|blf|bll|bmw|boo|bps|bqf|breaking_bad|buk|bup|bxz|cc|ccc|ce0|ceo|cfxxe|chm|cih|cla|class|cmd|com|cpl|crinf|crjoker|crypt|cryptolocker|cryptowall|ctbl|cxq|cyw|dbd|delf|dev|dlb|dli|dll|dllx|dom|drv|dx|dxz|dyv|dyz|ecc|exe|exe-ms|exe1|exe_renamed|exx|ezt|ezz|fag|fjl|fnr|fuj|good|gzquar|hlp|hlw|hqx|hsq|hts|iva|iws|jar|js|kcd|keybtc@inbox_com|let|lik|lkh|lnk|locky|lok|lol!|lpaq5|magic|mfu|micro|mim|mjg|mjz|nls|oar|ocx|osa|ozd|pcx|pgm|php2|php3|pid|pif|plc|pr|pzdc|qit|qrn|r5a|rhk|rna|rsc_tmp|s7p|scr|shs|ska|smm|smtmp|sop|spam|ssy|swf|sys|tko|tps|tsa|tti|ttt|txs|upa|uu|uue|uzy|vb|vba|vbe|vbs|vbx|vexe|vxd|vzr|wlpginstall|ws|wsc|wsf|wsh|wss|xdu|xir|xlm|xlv|xnt|xnxx|xtbl|xxe|xxx|xyz|zix|zvz|zzz)(,|\t)'xmi => 'DISCARD'],

    # Dangerous file name extensions
    [qr'N=.*\.(9|386|LeChiffre|aaa|abc|aepl|ani|aru|atm|aut|b64|bat|bhx|bin|bkd|blf|bll|bmw|boo|bps|bqf|breaking_bad|buk|bup|bxz|cc|ccc|ce0|ceo|cfxxe|chm|cih|cla|class|cmd|com|cpl|crinf|crjoker|crypt|cryptolocker|cryptowall|ctbl|cxq|cyw|dbd|delf|dev|dlb|dli|dll|dllx|dom|drv|dx|dxz|dyv|dyz|ecc|exe|exe-ms|exe1|exe_renamed|exx|ezt|ezz|fag|fjl|fnr|fuj|good|gzquar|hlp|hlw|hqx|hsq|hts|iva|iws|jar|js|kcd|keybtc@inbox_com|let|lik|lkh|lnk|locky|lok|lol!|lpaq5|magic|mfu|micro|mim|mjg|mjz|nls|oar|ocx|osa|ozd|pcx|pgm|php2|php3|pid|pif|plc|pr|pzdc|qit|qrn|r5a|rhk|rna|rsc_tmp|s7p|scr|shs|ska|smm|smtmp|sop|spam|ssy|swf|sys|tko|tps|tsa|tti|ttt|txs|upa|uu|uue|uzy|vb|vba|vbe|vbs|vbx|vexe|vxd|vzr|wlpginstall|ws|wsc|wsf|wsh|wss|xdu|xir|xlm|xlv|xnt|xnxx|xtbl|xxe|xxx|xyz|zix|zvz|zzz)$'xmi => 'DISCARD'],
);

# Define some useful rules.
%banned_rules = (
    # Allow all Microsoft Office documents.
    'ALLOW_MS_OFFICE'   => new_RE([qr'.\.(doc|docx|xls|xlsx|ppt|pptx)$'i => 0]),

    # Allow Microsoft Word, Excel, PowerPoint documents separately.
    'ALLOW_MS_WORD'     => new_RE([qr'.\.(doc|docx)$'i => 0]),
    'ALLOW_MS_EXCEL'    => new_RE([qr'.\.(xls|xlsx)$'i => 0]),
    'ALLOW_MS_PPT'      => new_RE([qr'.\.(ppt|pptx)$'i => 0]),

    # Default rule.
    'DEFAULT' => $banned_filename_re,
);

# $bounce_killer_score defaults to 100, it will cause quota exceed notification
# email sent by Dovecot quarantined by Amavisd.
$penpals_bonus_score = undef;
$bounce_killer_score = 0;

# Selectively disable some of the header checks
#
# Duplicate or multiple occurrence of a header field
$allowed_header_tests{'multiple'} = 0;

# Missing some headers. e.g. 'Date:'
$allowed_header_tests{'missing'} = 0;

# Listen on specified addresses.
$inet_socket_bind = ['0.0.0.0'];

# Set ACL
@inet_acl = qw(127.0.0.1 [::1]);

# Use default verbose log template.
$log_templ = $log_verbose_templ;

$notify_method  = 'smtp:[127.0.0.1]:10025';
$forward_method = 'smtp:[127.0.0.1]:10025';

# Num of pre-forked children.
# WARNING: it must match (equal to or larger than) the number set in
# `maxproc` column in Postfix master.cf for the `smtp-amavis` transport.
$max_servers = 1;

# Include custom config files.
include_optional_config_files('/opt/iredmail/custom/amavisd/amavisd.conf');

1;  # insure a defined return

#
# This file is managed by iRedMail Team <support@iredmail.org> with Ansible,
# please do __NOT__ modify it manually.
#
#
# If you need to modify any settings in this file, please define your custom
# settings in /opt/iredmail/custom/amavisd/amavisd.conf to override settings
# in this file.
#