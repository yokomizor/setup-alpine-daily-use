# setup-alpine-daily-use

The `setup-alpine-daily-use` script sets a fresh [Alpine] system up for daily
use (e.g checking emails, browsing the web). Its purpose is to make it easier to
reset my systems to a fresh state periodically.

I wrote this script mostly to myself. It will configure the system according to
my personal preferences, meaning it will most likely not suit your needs.
Yet, you might learn a thing or two by just reading the source code.

If you are just looking for a way to get started with Alpine, you should check
the [Alpine Wiki] instead.

Note that the script is supposed to be executed in a fresh system.  Instructions
on how to achieve that can be found at: 

* [Alpine Installation](https://wiki.alpinelinux.org/wiki/Installation).
* [Alpine Installation on ARM](https://wiki.alpinelinux.org/wiki/Alpine_on_ARM),
* [Alpine Installation on Raspberry Pi](https://wiki.alpinelinux.org/wiki/Raspberry_Pi),
* [Alpine Installation on Raspberry Pi 4](https://wiki.alpinelinux.org/wiki/Raspberry_Pi_4_-_Persistent_system_acting_as_a_NAS_and_Time_Machine).
* The Makefile in this repository (check variables and call `make flashdrive`).


## Usage

```console
$ wget -O /usr/sbin/setup-alpine-daily-use https://raw.githubusercontent.com/yokomizor/setup-alpine-daily-use/master/setup-alpine-daily-use
$ chmod +x /usr/sbin/setup-alpine-daily-use
$ setup-alpine-daily-use -h
usage: setup-alpine-daily-use [-h] [-d] [-u username] [-r git remote repository] [-l git local path]

options:
 -d  Don't assign a password to daily use user
 -h  Show this help
 -l  Daily use user dotfiles git local path
 -r  Daily use user dotfiles git remote repository uri
 -u  Daily use user username
```

All parameters are optional. You will be asked when needed.


**What is going to be installed?**

Most notably:

* Graphical user interface using [sway] ([Wayland]).
  No login manager will be installed though. Just call `sway` by hand whenever
  you need graphics.

* Custom us-intl keyboard layout with the hardcoded kdb option ctrl:swapcaps for
  those who have realized that CAPSLOCK, besides not being very useful, sits in
  the VIP row in the keyboard club. A popular approach to achieve the same goal
  is through `setxkbmap`. Such approach is not suitable for tty usage.

* tmux, vim, mutt, git, gpg, wg-quick, iptables, tor...
  just take a look into the source code. It should be reasonably
  understandable.

* It will disable ipv6.

* It will also create a user for daily use, and fetch dotfiles from
  a git repository.


[Alpine]: https://www.alpinelinux.org/
[Alpine Wiki]: https://wiki.alpinelinux.org/wiki/Main_Page
[sway]: https://swaywm.org/
[Wayland]: https://wayland.freedesktop.org/
