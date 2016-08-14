use IO::Socket;
use IO::Select;
use String::Util 'trim';

open (URLF, "<", "urls") or die("failed to open ./urls file");
chomp(@feed_urls = <URLF>); 
close(URLF);

$server = 'localhost';
$port = '6667';
$channels = '#rss';
$nick = 'rssbot';
$username = 'rssbot "" "" :rssbot';
$socket = IO::Socket::INET->new(
	PeerAddr => $server,
	PeerPort => $port,
	Porot => "tcp",
	Type => SOCK_STREAM
);

print $socket "user $username\n";
print $socket "nick $nick\n";
print $socket "join $channels\n";

$sel = IO::Select->new();
$sel->add($socket);

$SIG{'INT'} = sub {print "\nexiting...\n"; map {close $_} $sel->handles;};

while(@ready = $sel->can_read) {
	foreach $h (@ready) {
		if($h == $socket) {
			$linea = <$h>;
			print "RECV ### $linea";
			if($linea =~/^PING/i) {
				$linea =~ s/^ping\s+://;
				print $socket "PONG :$linea\n";
			}
			if($linea =~/JOIN/i) {
				# open feed filehandlers
				foreach $f (@feed_urls) {
					print "ADDF ### $f\n";
					open my $fh, "rsstail -Plu $f |" or next;
					$sel->add($fh);
				}
			}
		} else {
			$h->blocking(0);
			while(my $l = readline($h)) {
				print "SEND ### $l";
				if($l =~ /^Title: (.+)$/) {
					$title = trim $1;
					print $socket "privmsg $channels :$title"
				} else {
					# WARNING: HACK!
					# a huge assumption is made here:
					# we assume that the title has been printed (without a newline)
					# so the socket is still waiting for the EOL, which we print here:
					$l =~ s/Link: //;
					print $socket " ($l)\n";
				}
			}
			$h->blocking(1);
		}
	}
}
