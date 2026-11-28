# Sunlight's prompt. Installed to both /etc/profile.d (login shells) and
# /etc/bash/bashrc.d (interactive non-login shells, e.g. su / sudo -s), so
# root -- which has no ~/.bashrc -- gets it either way; a normal user gets
# the same line from /etc/skel/.bashrc too. Read by every sh, so it only
# acts for interactive bash: the escapes are bash's. root's user@host is
# orange, a normal user's bright blue, so a root shell is obvious at a glance.
[ -n "$BASH_VERSION" ] || return 0
case $- in
*i*) ;;
*) return 0 ;;
esac
if [ "$(id -u)" -eq 0 ]; then
	_sl_uc='38;5;208'   # root: orange
else
	_sl_uc='94'         # user: bright blue
fi
PS1='\[\e[32m\]┌──(\[\e['"$_sl_uc"';1m\]\u\[\e['"$_sl_uc"'m\]@\[\e['"$_sl_uc"'m\]\h\[\e[0;32m\])-[\[\e[38;5;46;1m\]\w\[\e[0;32m\]] [\[\e[32m\]$?\[\e[32m\]]\n\[\e[32m\]╰─\[\e['"$_sl_uc"';1m\]\$ \[\e[0m\]'
unset _sl_uc
