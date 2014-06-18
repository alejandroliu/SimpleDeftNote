#!/usr/bin/perl -w
#
use FindBin;
use lib "$FindBin::Bin";
use SimpleNoteAPI;
use DeftAPI;
use strict;
use warnings;
use File::Temp qw(tempfile);

#
# Read config files
#
my ($notesdir,$ext,$ext2,$dbfile);

if (open(my $fh,'<',$ENV{HOME}.'/.emacs')) {
    while (<$fh>) {
	if (/setq\s+deft-extension\s+"(.*)"/) {
	    $ext = '.'.$1;
	    $ext2 = '.CONFLICT'.$ext;
	}
	if (/setq\s+deft-directory\s+"(.*)"/) {
	    $notesdir = $1;
	    if (substr($notesdir,0,1) eq '~') {
		substr($notesdir,0,1) = $ENV{HOME};
	    }
	}
    }
    close($fh);
}
die "Missing deft configuration in ~/.emacs\n" unless ($notesdir && $ext);
$dbfile = $notesdir.'/.sdn.db';


my ($email,$passwd);
if (open(my $fh,'<',$ENV{HOME}.'/.sdn.ini')) {
    while (<$fh>) {
	if (/^\s*email\s*=\s*(.*)\s*/) {
	    $email = $1;
	}
	if (/^\s*passwd\s*=\s*(.*)\s*/) {
	    $passwd = $1;
	}
    }
    close($fh);
}
die "Missing email/passwd in ~/.sdn.ini\n" unless ($email && $passwd);

my $sns = SimpleNoteAPI->new('email'=>$email,'passwd'=>$passwd);
my $dff = DeftAPI->new('dbfile'=>$dbfile);

my $remidx = $sns->getIndex();

# -- scan server notes for changes...
while (my ($k,$v) = each %$remidx) {
    if ($dff->isNote($k)) {
	# Note exists... check changes...
	check_changes($k,$v,$sns,$dff,$notesdir);
    } else {
	next if ($v->deleted); # Note was deleted...
	download_new_note($k,$sns,$dff,$notesdir);
    }
}
# -- scan local index for changes
my $locidx = $dff->getKeys();
if ($locidx) {
    foreach my $k (@$locidx) {
	next if ($remidx->{$k}); # This case should have been handled above
	my $n = $dff->getNote($k);
	# This note does not exist in remote... so it was deleted
	print STDERR "Delete local note: ",$n->name,"\n";
	unlink($notesdir.'/'.$n->name);
	$dff->delNote($k);
    }
}

my $namidx = $dff->getNameIndex();

opendir(my $dh,$notesdir) || die "$notesdir: $!\n";
while (defined (my $f = readdir($dh))) {
    next if ($f eq '.' || $f eq '..' 
	     || -d "$notesdir/$f"
	     || -l "$notesdir/$f"
	     || (! -f "$notesdir/$f")
	     || substr($f,-length($ext)) ne $ext);
    next if (substr($f,-length($ext2)) eq $ext2);


    next if ($namidx->{$f});	# This case should have been handled earlier
    my $mtime = tstamp((stat("notesdir/$f"))[9]);
    my $t = read_file("$notesdir/$f");
    my $key = $sns->putNote($mtime,$t);
    print STDERR "Created new server note: $key\n";
    $dff->putNote(key=>$key,
		  file=>$f,
		  body=>$t,
		  create=>$mtime,
		  modify=>$mtime);
}
closedir($dh);



sub check_changes {
    my ($k,$v,$sns,$dff,$notesdir) = @_;

    my $lnot = $dff->getNote($k);
    my $f = $notesdir.'/'.$lnot->name;

    if (-f $f) {
	handle_existing_note($k,$v,$sns,$dff,$notesdir,$lnot,$f);
    } else {
	handle_deleted_note($k,$v,$sns,$dff,$notesdir,$lnot,$f);
    }
}

sub handle_existing_note {
    my ($k,$v,$sns,$dff,$notesdir,$lnot,$f) = @_;

    my $mtime = tstamp((stat($f))[9]);
    if ($v->deleted) {
	if ($mtime ne $lnot->modify) {
	    # Deleted on server, but modified locally
	    warn "Note: ".$lnot->name.
		"\nDeleted on server but modified locally\nRESTORING";
	    my $t = read_file($f);
	    my $key = $sns->putNote($mtime,$t);
	    print STDERR "Re-created server note as $key\n";
	    $dff->putNote(key=>$key,
			  file=>$lnot->name,
			  body=>$t,
			  create=>$mtime,
			  modify=>$mtime);
	    $dff->delNote($k);
	} else {
	    print STDERR "Delete note: ",$lnot->name,"\n";
	    unlink($f);
	    $sns->delNote($k);
	}
	return;
    }
    # No changes...
    return if ($mtime eq $lnot->modify
	       && $lnot->modify eq $v->modify);

    # Only local changes...
    if ($mtime ne $lnot->modify && $lnot->modify eq $v->modify) {
	my $t = read_file($f);
	if ($lnot->body eq $t) {
	    # Make sure we eliminate false positives!
	    $mtime = timeval($lnot->modify);
	    utime($mtime,$mtime,$f);
	    return;
	}

	print STDERR "Uploading note: ",$lnot->name,"\n";

	$sns->putNote($mtime,$t,$k);
	$dff->putNote(key=>$k,
		      file=>$lnot->name,
		      body=>$t,
		      modify=>$mtime);
	return;
    }

    # Only remote changes
    if ($mtime eq $lnot->modify && $lnot->modify ne $v->modify) {
	# Updated on server...
	print STDERR "Downloading note: ",$lnot->name,"\n";
	my $not = $sns->getNote($k);
	if (ref($not)) {
	    $dff->putNote(key=>$k,
			  file=>$lnot->name,
			  body=>$not->body,
			  modify=>$not->modify);
	    write_file($f,$not->body,$not->modify);
	    return;
	} else {
	    warn $lnot->name.": $not\n";
	}
	return;
    }

    # Conflicted changes
    if ($mtime ne $lnot->modify && $lnot->modify ne $v->modify) {
	warn "Note: ".$lnot->name.
	    "\nConflicted changes\n";
	my $rnot = $sns->getNote($k);
	unless (ref($rnot)) {
	    warn $lnot->name.": $rnot\n";
	    return;
	}
	print STDERR "Merging changes for: ",$lnot->name,"\n";
	my ($fh1,$fn1) = tempfile();
	my ($fh2,$fn2) = tempfile();

	print $fh1 $lnot->body;
	print $fh2 $rnot->body;
	close($fh1); close($fh2);

	open(my $diff,'-|','diff3','--merge',
	     $f,$fn1,$fn2) || die "diff3: $!\n";
	my $new = '';
	while (<$diff>) {
	    $new .= $_;
	}
	close($diff);
	unlink($fn1);unlink($fn2);
	write_file($f,$new);
	$mtime = tstamp((stat($f))[9]);
	$sns->putNote($mtime,$new,$k);
	$dff->putNote(key=>$k,
		      file=>$lnot->name,
		      body=>$new,
		      modify=>$mtime);
    }
}

sub handle_deleted_note {
    my ($k,$v,$sns,$dff,$notesdir,$lnot,$f) = @_;

    # Note was deleted remote and locally
    if ($v->deleted) {
	print STDERR "Delete note index: ",$lnot->name,"\n";
	$dff->delNote($k);
	return;
    }

    # Note was deleted locally but NOT remotely
    if ($v->modify eq $lnot->modify) {
	print STDERR "Deleting server note: ",$lnot->name,"\n";
	$sns->delNote($k);
	$dff->delNote($k);
	return;
    }

    # Note was deleted locally AND modified remotely...
    warn "Note: ".$lnot->name.
	"\nConflicted changes -- deleted locally modified remotely\n";
    download_new_note($k,$sns,$dff,$notesdir);
}


sub download_new_note {
    my ($k,$sns,$dff,$notesdir) = @_;

    # Note does NOT exist download, 
    my $note = $sns->getNote($k);

    unless (ref($note)) {
	warn "$k: $note\n";
	return;
    }
    # Create new note
    my $fn = genFileName($notesdir,$note->create,$ext);
    write_file("$notesdir/$fn",$note->body,$note->modify);
    print STDERR "Downloaded new note as: ",$fn,"\n";

    $dff->putNote('key'=> $k,
		  'create' => $note->create,
		  'modify' => $note->modify,
		  'file' => $fn,
		  'body' => $note->body);
}


__END__

