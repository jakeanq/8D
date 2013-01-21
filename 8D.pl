use strict;
use warnings;
$| = 1;
use Term::ANSIColor qw( :constants );
use IPC::Run qw(:all);
use Data::Dumper;
our @bots;
our @world;
print BOLD BRIGHT_BLUE;
print << 'BANNER';
 .d8888b.  8888888b. 
d88P  Y88b 888  "Y88b
Y88b. d88P 888    888
 "Y88888"  888    888
.d8P""Y8b. 888    888
888    888 888    888
Y88b..d88P 888  .d88P
 "Y8888P"  8888888P"
BANNER

print CLEAR BRIGHT_BLUE;
print << 'BANNER';
Copyright 2012 Jake Bott
Creative Commons
CC-BY-SA
BANNER

print CLEAR;

sub sigint {
	print BRIGHT_RED "\nCaught SIGINT, cleaning up processes\n";
	print CLEAR;
	foreach (@bots) {
		signal($_->{bot}, "TERM");
		finish($_->{bot});
	}
	print BRIGHT_RED "Done\n";
	print CLEAR;
}
$SIG{'INT'} = 'sigint';

our $worldsize = 5;
our $teamsize  = 4;
print "Using teams of $teamsize\nUsing world of size $worldsize\n";

my $dd = 0;
foreach my $i (0 .. $worldsize) {
	foreach my $j (0 .. $worldsize) {
		foreach my $k (0 .. $worldsize) {
			foreach my $l (0 .. $worldsize) {
				printf "Generating world... %3i%%\r", (($dd / (($worldsize + 1)**4)) * 100);
				$dd++;
				foreach my $m (0 .. $worldsize) {
					foreach my $n (0 .. $worldsize) {
						foreach my $o (0 .. $worldsize) {
							foreach my $p (0 .. $worldsize) {
								my $type = int rand 80;
								if ($type < 40) {
									$world[$i]->[$j]->[$k]->[$l]->[$m]->[$n]->[$o]->[$p] = "B0";    # B# = Block
								} else {
									$world[$i]->[$j]->[$k]->[$l]->[$m]->[$n]->[$o]->[$p] = "A";     # A = Air
								}
							}
						}
					}
				}
			}
		}
	}
}

printf "Generating world... %3i%%\r", 100;
print "\n";                                                                                         #print $dd;

sub findbots {
	my ($arr) = @_;
	foreach (@bots) {
		return \$_ if $_{location} ~~ $arr;
	}
}

sub worldgs {
	my ($arr, $val) = @_;

	$world[ $arr->[0] ]->[ $arr->[1] ]->[ $arr->[2] ]->[ $arr->[3] ]->[ $arr->[4] ]->[ $arr->[5] ]->[ $arr->[6] ]->[ $arr->[7] ] = $val if defined $val;
	#print Dumper $arr;
	return $world[ $arr->[0] ]->[ $arr->[1] ]->[ $arr->[2] ]->[ $arr->[3] ]->[ $arr->[4] ]->[ $arr->[5] ]->[ $arr->[6] ]->[ $arr->[7] ];
}

sub pumpbots {
	foreach (@bots) {
		pump($_->{bots}) while length $_{IN};
	}
}

sub chteam {
	return 0 if (scalar(@bots) == 0);
	my $nnn = $bots[0]->{teamid};
	foreach (@bots) {
		if ($_->{teamid} != $nnn) {
			return 1;
		}
	}
	return 0;
}
my $tid = 0;
my $id  = 0;
foreach my $progname (@ARGV) {
	for (my $i = 0 ; $i < $teamsize ; $i++) {
		my %bot;
		print GREEN "Adding bot '$progname' with id $id to team $tid\n";
		$bot{botname}  = $progname;
		$bot{teamid}   = $tid;
		$bot{id}       = $id;
		$bot{bot}      = start([$progname], \$bot{IN}, \($bot{OUT}));
		$bot{location} = [
			int rand($worldsize), int rand($worldsize), int rand($worldsize), int rand($worldsize),
			int rand($worldsize), int rand($worldsize), int rand($worldsize), int rand($worldsize) ];
		worldgs $bot{location}, "A";
		$bot{health} = 100;
		$bot{IN} .= "TEAM$tid\nID$id\n";
		pumpbots;
		push @bots, \%bot;
		$id++;
	}
	$tid++;
}
print CLEAR;
my $turns   = 0;
my $tstring = '';
while (chteam) {
	my $v = scalar @bots;
	$tstring = CLEAR "Turn $turns - Bots left: " . $v;
	print "$tstring\r";

	while (--$v) {
		my $z = int rand($v + 1);
		($bots[$v], $bots[$z]) = ($bots[$z], $bots[$v]);
	}
	foreach my $bot (@bots) {
		my @loc = @{ $bot->{location} };
		$bot->{IN} .= "ENVIRONS\n";
		my $c = 'I';
		for (my $t = 0 ; $t < 8 ; $t++) {
			my $q;
			$loc[$t]--;
			$q = findbots(\@loc);
			$bot->{IN} .= $c . '-=' . (($q) ? "BOT TEAM" . $q->{teamid} . " ID" . $q->{id} . " HEALTH" . $q->{health} . "\n" : worldgs(\@loc));
			$loc[$t] += 2;
			$bot->{IN} .= $c . '+=' . (($q) ? "BOT TEAM" . $q->{teamid} . " ID" . $q->{id} . "\n" : worldgs(\@loc));
			$loc[$t]--;
			$c++;
		}
		$bot->{IN} .= "STATS\nHEALTH" . $bot->{health} . "\n";
	}
	pumpbots;
	foreach my $bot (@bots) {
		my @tokens = split / +/, $bot->{OUT};
		if (scalar(@tokens) == 0) {
			sleep 1;
			my @tokens = split / +/, $bot->{OUT};
			next if scalar(@tokens) == 0;
		}
		my $command = shift @tokens;
		my ($dimension, $d3) = split "", shift;
		$bot->{OUT} = join " ", @tokens;
		$command = uc $command;
		my $direction = ($d3 eq '+') ? 1 : -1;
		my $d2 = uc $dimension;
		$dimension = ord($d2) - ord('I');
		$dimension = 0 if $dimension < 0;
		$dimension = 7 if $dimension > 7;
		my @arr;
		if ($command eq "MOVE") {
			@arr = @$bot->{location};
			$arr[$dimension] += $direction;
			if ($arr[$dimension] < 0 || $arr[$dimension] >= $worldsize) {
				$bot->{IN} .= "ERROR\n";
				next;
			}
			if (findbots \@arr || worldgs \@arr ne "A") {
				$bot->{IN} .= "ERROR\n";
				next;
			}
			$bot->{location} = @arr;
		} elsif ($command eq "ATTACK") {
			@arr = @$bot->{location};
			$arr[$dimension] += $direction;
			if ($arr[$dimension] < 0 || $arr[$dimension] >= $worldsize) {
				$bot->{IN} .= "ERROR\n";
				next;
			}
			my $q = worldgs \@arr;
			if ($q ne "A") {
				worldgs \@arr, "A";
			} else {
				$q = findbots \@arr;
				$q->{health} -= 20 + int rand 40;
				print YELLOW "Bot " . $bot->{id} . " hit bot " . $q->{id} . "\n";
				print CLEAR "$tstring\r";
			}
		} elsif ($command eq "LOOK") {
			@arr = @$bot->{location};
			$arr[$dimension] += 2 * $direction;
			if ($arr[$dimension] < 0 || $arr[$dimension] >= $worldsize) {
				$bot->{IN} .= "ERROR\n";
				next;
			}
			my $q = findbots(\@arr);
			$bot->{IN} .= $d2 . '-=' . (($q) ? "BOT TEAM" . $q->{teamid} . " ID" . $q->{id} . " HEALTH" . $q->{health} . "\n" : worldgs(\@arr));
		} elsif ($command =~ /PLACE/) {
			$command =~ s/PLACE//;
			@arr = @$bot->{location};
			$arr[$dimension] += $direction;
			if ($arr[$dimension] < 0 || $arr[$dimension] >= $worldsize) {
				$bot->{IN} .= "ERROR\n";
				next;
			}
			if (findbots \@arr || worldgs \@arr ne "A") {
				$bot->{IN} .= "ERROR\n";
				next;
			}
			worldgs \@arr, "B$command";
		} else {
			$bot->{IN} .= "ERROR\n";
		}
	}
	foreach (@bots) {
		if ($_->{health} <= 0) {
			print RED "Bot " . $_->{tid} . " died\n";
			print CLEAR "$tstring\r";
			$_->{IN} .= "DIED\n";
			finish($_->{bot});
		}
	}
	$turns++;
}
if (scalar @bots <= 0){
print YELLOW "No more bots!\nExiting...\n" . CLEAR;
}
foreach my $bot (@bots) {
	print BRIGHT_GREEN "Bot '" . $bot->{botname} . "' (ID: ".$bot->{id}.") from team " . $bot->{teamid} . " Wins!\n";
	$bot->{IN} .= "WIN!\n";
	pumpbots;
	finish($bot->{bot});
}
