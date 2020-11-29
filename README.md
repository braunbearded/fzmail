# fzmail

fzmail is a terminal based mail client. It allows you to work on your mails
(create mails, reply, forward, etc.) like any other mail client but in your
loved terminal.
fzmail heavily relies on fzf as its front end. This makes it possible to search,
jump, move mail, etc. by arrow keys or by fuzzy searching.
Emails can be displayed in more detail in your favorite text editor or browser.

## Installation

Install Requirements and copy the shell script `fzmail.sh` somewhere and make
it executable.

## Status

THIS IS EARLY ALPHA!!!
BREAKING CHANGES ARE LIKELY TO HAPPEND!!!
DONT USE IT ON ANY REAL EMAILS!!!

## Requirements

### Software

- [fzf (as gui)](https://github.com/junegunn/fzf)
- [msmtp (send mail alternative)](https://marlam.de/msmtp/)
- [mblaze (handling mail in maildir format)](https://github.com/leahneukirchen/mblaze)
- general gnu tools
- nvim (default editor, can be easly changed in the script on top of the file)


### mail-profiles

For example see [mail-profiles-example](https://github.com/braunbearded/fzmail/blob/main/mail-profiles-example)
Default location in `$HOME/mail-profiles`.

## Semi requirements

fzmail operates only on mails in maildir format, so you need some way to download
your mails in this format.
I use [isync](https://isync.sourceforge.io/).

## Licence
MIT
