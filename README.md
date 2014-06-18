# SimpleDeftNote

SimpleDeftNote is a script that can help you synchronise an
[Emacs Deft][deft] directory with [Simplenote][sn].

Of note, this software is not created by or endorsed by
[Automattic][automattic], the makers of Simplenote, or anyone else for
that matter.

This is script loosely based on [SimplenoteSync][sns].

## Dependancies

The following CPAN modules are needed:

* `Crypt::SSLeay` - needed for https.
* `JSON` and optionally `JSON::XS` - needed to parse JSON replies.

## Configuration

Install [deft][deft] and configure `.emacs` with the follwing lines:

	(require 'deft)
	(setq deft-extension "txt")
	(setq deft-directory "~/mynotes/")
	(setq deft-text-mode 'markdown-mode)

Create a `$HOME/.sdn.ini` with the following entries:

	email = e-mail address
	passwd = my_simple_note_password

## Description

After configuring *SimpleDeftNote* will attempt to synchronize the
information in both places.

Sync infomration is stored in `.sdn.db`.

When performing the first synchronization, it's best to start with an
empty local folder (or an empty collection of notes on Simplenote),
and then start adding files(or notes) afterwards.

## Warning

Please note that this software is still in development stages --- I
STRONGLY urge you to backup all of your data before running to ensure
nothing is lost.

If you run SimpleDeftNote on an empty local folder without a ".sdn.db"
file, the net result will be to copy the remote notes to the local
folder, effectively performing a backup.

## Features


## TODO

- Tag support

## Copyright And License

Copyright (C) 2014 A Liu Ly

This program is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the
Free Software Foundation; either version 2 of the License, or (at your
option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
Public License for more details.

You should have received a copy of the GNU General Public License along
with this program; if not, write to the Free Software Foundation, Inc.
59 Temple Place, Suite 330 Boston, MA 02111-1307 USA

[deft]: http://jblevins.org/projects/deft/ "Deft"
[sn]: http://simplenote.com/ "The simplest way to keep notes."
[sns]: http://github.com/fletcher/SimplenoteSync "SimplenoteSync"
[automattic]: http://automattic.com/ "Automattic"
