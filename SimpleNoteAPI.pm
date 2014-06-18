package SimpleNoteAPI;
use strict;
use warnings;
our $VERSION = "1.00";
use MIME::Base64;
use LWP::UserAgent;
use Net::SSL;
use JSON;
use Class::Struct;

struct('SimpleNoteAPI::Index' => [
	   'deleted' => '$',
	   'modify' => '$',
       ]);
struct('SimpleNoteAPI::Note' => [
	   'create' => '$',
	   'modify' => '$',
	   'body' => '$',
       ]);



BEGIN {
    $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;
}

my $flag_network_traffic = 1;


sub trim_stamp {
    my ($in) = @_;
    $in =~ s/\.\d+$//;
    return $in;
}

sub token {
    my ($self) = @_;
    unless ($self->{token}) {
	my $content = encode_base64('email='.$self->{email}.
				    '&password='.$self->{passwd});
	warn "Network: get token\n" if $flag_network_traffic;
	my $resp = $self->{ua}->post($self->{url}.'login',Content => $content);
	if ($resp->content =~ /Invalid argument/) {
	    die "Problem connecting to Service\n".$resp->content."\n";
	}
	$self->{token} = $resp->content;
    }
    return $self->{token};
}


sub new {
    my ($class, %args) = @_;
    my $self = bless({},$class);
    $self->{url} = 'https://simple-note.appspot.com/api/';
    my $k;

    foreach $k (qw(url)) {
	if (exists $args{$k}) {
	    $self->{$k} = $args{$k};
	}
    }
    foreach  $k (qw(email passwd)) {
	if (exists $args{$k}) {
	    $self->{$k} = $args{$k};
	} else {
	    die "SimpleNoteAPI: Must specify email and passwd\n";
	}
    }
    my $ua = LWP::UserAgent->new;
    $ua->env_proxy();
    $self->{ua} = $ua;
    return $self
}

sub ua {
    my $self = shift;
    my $verb = shift;
    my $urlpath = shift;
    $self->token();
    if ($verb eq 'get') {
	return $self->{ua}->get($self->{url}.$urlpath,@_);
    } elsif ($verb eq 'post') {
	return $self->{ua}->post($self->{url}.$urlpath,@_);
    }
    die "Invalid verb: $verb\n";
}

sub getIndex {
    my $self = shift;

#    ### DEBUG
#    if (open(my $fh,'<','index.dump')) {
#	my $tx = '';
#	while (<$fh>) { $tx .= $_; }
#	close($fh);
#	our $VAR1;
#	eval $tx;
#	if ($@) { die "$@\n"; }
#	return $VAR1;
#    }
#    ### DEBUG

    warn "Network: get note index\n" if $flag_network_traffic;
    my $resp = $self->ua('get',
			 'index?auth='.$self->token.'&email='.$self->{email});
    my $lst = decode_json($resp->content);
    my $res = {};
    foreach my $e (@$lst) {
	$res->{$e->{key}} = SimpleNoteAPI::Index->new(
	    'deleted'=> $e->{deleted} ? 1 : 0,
	    'modify' => trim_stamp($e->{modify}));
    }
    return $res;
}

sub putNote {
    my ($self,$modified,$txt,$key) = @_;
    if ($key) {
	# Updating ol note
	warn "Network: update note \"$key\"\n" if $flag_network_traffic;
	my $resp = $self->ua('post','note?key='.$key.
			     '&auth='.$self->token.
			     '&email='.$self->{email}.
			     '&modify='.$modified,
			     Content=>encode_base64($txt));
    } else {
	# Creating new note...
	warn "Network: create note\n" if $flag_network_traffic;
	my $resp = $self->ua('post','note?auth='.$self->token.
			     '&email='.$self->{email}.
			     '&modify='.$modified.
			     '&create='.$modified,
			     Content=>encode_base64($txt));
	$key = $resp->content;
    }
    return $key;
}

sub getNote {
    my ($self,$key) = @_;

#    ### DEBUG
#    if (open(my $fh,'<','notes.dump')) {
#	my $tx = '';
#	while (<$fh>) { $tx .= $_; }
#	close($fh);
#	our $VAR1;
#	eval $tx;
#	if ($@) { die "$@\n"; }
#	return $VAR1->{$key} if ($VAR1->{$key});
#    }
#    ### DEBUG


    # retrieve note
    warn "Network: retrieve existing note \"$key\"\n" if $flag_network_traffic;

    my $resp = $self->ua('get','note?key='.$key.
			     '&auth='.$self->token.
			     '&email='.$self->{email}.
			     '&encode=base64');
    my $txt = decode_base64($resp->content);
    return 'not-found' if ($txt eq '');
    return 'note-deleted' if ($resp->header('note-deleted') eq 'True');

    return SimpleNoteAPI::Note->new(
	'create' => trim_stamp($resp->header('note-createdate')),
	'modify' => trim_stamp($resp->header('note-modifydate')),
	'body' => $txt);
}

sub deleteNote {
    my ($self,$key) = @_;
    warn "Network: delete note \"$key\"\n" if $flag_network_traffic;
    my $resp = $self->{ua}->get($self->url.'delete?key='.$key.
				'&auth='.$self->token.
				'&email='.$self->{email});
}


1;
