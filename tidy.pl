use File::Find;
use File::Copy;
use Perl::Tidy;
use Term::ANSIColor qw(:constants);
use threads;
use threads::shared;
use Thread::Queue;
use Thread::Semaphore;
use Getopt::Long;
our $VERSION = '1.5';
our $mjobs   = 1;
our $quiet   = 0;
our $silent  = 0;
s/^-j(\d+)$/-j=$1/ foreach @ARGV;
GetOptions(
	'j|jobs:i' => \$mjobs,
	'h|help'   => \&help,
	'q|quiet'  => \$quiet,
	's|silent' => \$silent
) or &help;

sub help {
	print STDERR "tidy.pl v$VERSION\n
Usage
perl tidy.pl [OPTIONS]

Tidies all .pl, .pm and .t files in the current directory
        tree using .perltidyrc for the specification.

Options
-j[obs]     Specify the number of threads to use.
                    If a number is not given, use as many
                    threads as needed.
-h[elp]     Shows this help.
-q[uiet]    Prints less output.
-s[ilent]   No output at all.
";
	exit 255;
}
our %err : shared;
our $running : shared = 0;
our $sem = new Thread::Semaphore($mjobs) if $mjobs > 0;
our $iq = new Thread::Queue();
$| = 1;
our $diff : shared   = 0;
our $nerr : shared   = 0;
our $nfiles : shared = 0;
our @kids;
find({wanted => sub {
    if (/\.(?:(?:p[lm]x?)|t)$/) {
        s/^\.\///;
        return if $_ eq $0;
        my $pth=$_;
        return if $pth=~m#/blib/#;
        $pth=~s/^\.\///;
        my $mn=$pth;
        $mn=~s/\//::/g if $mn=~s/\.pm$//;
        {
            lock $running;
            if (($mjobs == 0 and ($running+1 >= scalar(@kids))) || $mjobs > scalar(@kids)) {
                push @kids, threads->new(\&worker,$iq,$sem,$mjobs);
            }
        }
        $iq->enqueue({
            src => $pth,
            tdy => $pth.'.tdy',
            mn  => $mn
        });
    }
},no_chdir => 1},'.');
$iq->enqueue(undef) foreach @kids;
$_->join() foreach @kids;

sub worker {
    while (defined(my $job=$_[0]->dequeue())) {
        my $errstr;
        $_[1]->down() if defined $_[1];
        {lock $running;$running++;}
        printf CYAN."\rTidying %-73s".RESET, $job->{mn} unless $silent;
        my $err=Perl::Tidy::perltidy(
            stderr      => \$errstr,
            argv => '-pro=.../.perltidyrc '.$job->{src},
            postfilter => \&postf
        );
        {lock $running;$running--;}
        $_[1]->up() if defined $_[1];
        chomp($errstr);
        if(!($errstr eq '')){
            $err = 1;
            lock %err;
        	$err{$job->{src}}=$errstr;
        }
        if ($err) {
            lock $nerr;
            $nerr++;
            printf RED."\r%-74s [FAIL]".RESET."\n", $job->{mn} unless $silent;
        }else{
            my $src=$job->{src};
            if (`diff -q '$src' '$src.tdy'`) {
                printf GREEN."\r%-74s [ OK ]\n".RESET, $job->{mn};
                copy($src.".tdy",$src);
                lock $diff;
                $diff++;
            }else{
                printf BLUE."\r%-74s [SAME]%s".RESET, $job->{mn}, ($quiet ? '' : "\n") unless $silent;
            }
        }
        unlink($job->{tdy});
        lock $nfiles;
        $nfiles++;
    }
}

if(scalar(keys %err) > 0){
	print BOLD RED "\r=====   Error Report   =====\n".RESET;
	print join "\n", map {sprintf BOLD.RED.' --- %s --- '.RESET."\n%s",$_,$err{$_}} keys %err;
	print BOLD RED "\n===== End Error Report =====\n".RESET;
}
printf(($nerr == 0 ? GREEN : RED)."\r%-81s".RESET."\n", (sprintf "%i file%s, %i changed, %i error%s, used %s thread%s",$nfiles,($nfiles > 1 ? 's' : ''),$diff,$nerr,($nerr > 1 ? 's' : ''),scalar(@kids),(scalar(@kids) > 1 ? 's' : ''))) unless $silent;
exit ($nerr)?1:0;
sub postf {
	my ($content) = @_;
	return $content;
}
