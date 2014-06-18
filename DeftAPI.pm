package DeftAPI;
use strict;
use warnings;
our $VERSION = "1.00";
use Class::Struct;
use Time::Local;

use Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(tstamp timeval genFileName read_file write_file);


struct('DeftAPI::Note' => [
	   'create' => '$',	# Creation date
	   'modify' => '$',	# last modification date
	   'body' => '$',	# original (downloaded) text
	   'name' => '$',	# base filename
       ]);

######################################################################
sub tstamp {
    my ($now) = @_;
    $now = time unless ($now);
    my @d = gmtime($now);
    return sprintf('%04d-%02d-%02d %02d:%02d:%02d',
		   $d[5]+1900,$d[4]+1,$d[3],$d[2],$d[1],$d[0]);
}

sub timeval {
    my ($s) = @_;
    $s =~ /(\d\d\d\d)-(\d\d)-(\d\d)\s*(\d\d):(\d\d):(\d\d)/;
    return timegm($6,$5,$4,$3,$2-1,$1);
}

sub genFileName {
    my ($dir,$cdate,$ext) = @_;
    $cdate = tstamp(0) unless ($cdate);
    my $f = sub_string(sub_string($cdate,':','.'),' ','_').$ext;
    my $cnt = 0;
    while (-f "$dir/$f") {
	$cnt++;
	$f = sub_string($cdate,':','.').'-'.$cnt.$ext;
    }
    return $f;
}

sub write_file {
    my ($fn,$tx,$tm) = @_;
    open(my $fh,'>',$fn) || die "$fn: $!\n";
    print $fh $tx;
    close($fh);
    if ($tm) {
	my $mtime = timeval($tm);
	utime($mtime,$mtime,$fn);
    }
}

sub read_file {
    my ($fn) = @_;
    open(my $fh,'<',$fn) || die "$fn: $!\n";
    my $t = '';
    while (<$fh>) { $t .= $_; }
    close($fh);
    return $t;
}

######################################################################

sub sub_string {
    my ($ln,$a,$b) = @_;
    for (my $i=0; ($i = index($ln,$a,$i)) != -1 ; $i+=length($b)) {
	substr($ln,$i,length($a)) = $b;
    }
    return $ln;
}

sub quote_string {
    return "'".sub_string(sub_string(shift,'\\','\\\\'),"'","\\'")."'";
}


sub dump_data {
    my ($fn,$tab) = @_;
    open(my $fh,'>',$fn) || die "$fn: $!\n";
    print $fh "{\n";
    while (my ($k,$v) = each %$tab) {
	print $fh quote_string($k),"=> [\n";
	foreach my $j (@$v) {
	    print $fh quote_string($j),",\n";
	}
	print $fh "],\n";
    }
    print $fh "}\n";
    close($fh);
}

sub load_data {
    my $r = eval read_file(shift);
    die "$@\n" if ($@);
    while (my ($a,$b) = each %$r) {
	bless($b,'DeftAPI::Note');
    }
    return $r;
}


sub new {
    my ($class, %args) = @_;
    my $self = bless({},$class);

    my $k;
    foreach  $k (qw(dbfile)) {
	if (exists $args{$k}) {
	    $self->{$k} = $args{$k};
	} else {
	    die "DeftAPI: Must specify dbfile\n";
	}
    }
    if (-f $self->{dbfile}) {
	$self->{data} = load_data($self->{dbfile});
    } else {
	$self->{data} = {};
    }

    return $self;
}

sub isNote {
    my ($self,$key) = @_;
    return $self->{data}->{$key} ? 1 : 0;
}

sub getNote {
    my ($self,$key) = @_;
    return $self->{data}->{$key};
}


sub delNote {
    my ($self,$key) = @_;
    return unless ($self->{data}->{$key});
    delete $self->{data}->{$key};
    dump_data($self->{dbfile},$self->{data});
}



sub putNote {
    my ($self,%args) = @_;
    my $k;
    foreach $k (qw(key file body)) {
	if (!exists $args{$k}) {
	    die "putNote: Must specify key file body\n";
	}
    }
    my $key = $args{key};
    my $file = $args{file};

    die "Unable to putNote: No key specified\n" unless ($key);

    if ($self->{data}->{$key}) {
	$self->{data}->{$key}->create($args{create}) if ($args{create});
	$self->{data}->{$key}->modify($args{modify}) if ($args{modify});
	$self->{data}->{$key}->body($args{body});
	$self->{data}->{$key}->name($file);
    } else {
	$args{create} = tstamp(0) unless ($args{create});
	$args{modify} = tstamp(0) unless ($args{modify});
	$self->{data}->{$key} = DeftAPI::Note->new(
	    'create' => $args{create},
	    'modify' => $args{modify},
	    'body' => $args{body},
	    'name' => $file,
	    );
    }
    dump_data($self->{dbfile},$self->{data});
}

sub getKeys {
    my ($self) = @_;
    return [ keys %{$self->{data}} ];
}

sub getNameIndex {
    my ($self) = @_;
    my $res = {};
    while (my ($k,$v) = each %{$self->{data}}) {
	$res->{$v->name} = $k;
    }
    return $res;
}

1;
