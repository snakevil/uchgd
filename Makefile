# Makefile: 基于 GNUMake 的自动化安装 UCHGd 的脚本。
#
# AUTHOR    Snakevil Zen <zhengyy@ucweb.com>
# COPYRIGHT © 2011 uc.cn.

HOOK_TYPES = changegroup commit incoming outgoing prechangegroup precommit \
    preoutgoing pretag pretxnchangegroup pretxncommit preupdate tag \
    update

USED_CMDS = awk basename expr hg id sudo useradd usermod wc stat mv grep

UCHGd: check user.hg repos/sample authorized_keys hgrc

authorized_keys: $(sort $(wildcard pubkeys/*.pub))
	$(info GATHERING PUBKEYS)
	@$(RM) authorized_keys; \
	'touch' authorized_keys; \
	_item_echo() { \
		local hint=" $$1"; \
		local result="$$2"; \
		local len=`echo -n "$${hint}" | 'wc' -c`; \
		len=`'expr' 65 - "$${len}"`; \
		'printf' '%s' "$${hint}"; \
		[ -n "$${result}" ] && 'printf' "%$${len}s" "$${result}"; \
		echo ''; \
	}; \
	hint='seeks pubkeys...'; \
	[ 0 -eq $(words $^) ] && { \
		_item_echo "$${hint}" 'none'; \
		echo 'ABORTED!'; \
		exit 1; \
	} || { \
		_item_echo "$${hint}" '$(words $^) found'; \
		for file in $^; do \
			name=`'basename' "$${file}" '.pub'`; \
			clob=`'cat' "$${file}"`; \
			clob="environment=\"USER=$${name}\" $${clob}"; \
			clob="no-pty,no-port-forwarding,no-X11-forwarding,no-agent-forwarding,$${clob}"; \
			echo "$${clob}" >> authorized_keys; \
			_item_echo ' +' "$${name} "; \
		done; \
	}; \
	echo ''

check:
	$(if $(shell 'which' which 2> /dev/null), , \
		$(error Command 'which' cannot found) \
	)
	$(if $(shell 'which' printf 2> /dev/null), , \
		$(error Command 'printf' cannot found) \
	)
	$(info CHECKING USED COMMANDS)
	@_item_echo() { \
		local hint=" $$1"; \
		local result="$$2"; \
		local len=`echo -n "$${hint}" | 'wc' -c`; \
		len=`'expr' 65 - "$${len}"`; \
		'printf' '%s' "$${hint}"; \
		[ -n "$${result}" ] && 'printf' "%$${len}s" "$${result}"; \
		echo ''; \
	}; \
	for cmd in $(sort $(USED_CMDS)); do \
		reason=`'which' "$${cmd}" 2> /dev/null`; \
		[ -n "$${reason}" ] || reason='not found'; \
		_item_echo 'checks whether `'"$${cmd}' exists..." "$${reason}"; \
	done; \
	echo '';

clean:
	$(RM) authorized_keys hgrc
	$(RM) -R repos/sample
	@echo ''

hgrc: $(sort $(wildcard hooks/*))
	$(info GATHERING HOOKS)
	@echo '[hooks]' > hgrc; \
	_item_echo() { \
		local hint=" $$1"; \
		local result="$$2"; \
		local len=`echo -n "$${hint}" | 'wc' -c`; \
		len=`'expr' 65 - "$${len}"`; \
		'printf' '%s' "$${hint}"; \
		[ -n "$${result}" ] && 'printf' "%$${len}s" "$${result}"; \
		echo ''; \
	}; \
	HOME=`'awk' -F':' '"hg"==$$1{print $$6}' /etc/passwd`; \
	[ '/' = "$(PWD)" ] || PWD="$(PWD)/"; \
	for type in $(HOOK_TYPES); do \
		hint='seeks `'"$${type}'"' hooks...'; \
		[ -f "hooks/$${type}" ] && found="hooks/$${type}\n" || found=''; \
		files=`'ls' "hooks/$${type}."* 2> /dev/null`; \
		[ -n "$${files}" ] && found="$${found}$${files}"; \
		[ -z "$${found}" ] && _item_echo "$${hint}" 'none' || { \
			_item_echo "$${hint}" `echo "$${found}" | 'wc' -l`' found'; \
			for file in "$${found}"; do \
				name=`'basename' "$${file}"`; \
				_item_echo ' +' '`'"$${name}' "; \
				echo "$${name} = $${HOME}/hooks/$${name}" >> hgrc; \
			done; \
		}; \
		found=; \
	done; \
	echo ''

install: check
	$(if $(and $(wildcard authorized_keys), $(wildcard hgrc), $(shell id hg 2> /dev/null)), , \
		$(error Run 'make' first) \
	)
	$(info INSTALLING)
	@_item_echo() { \
		local hint=" $$1"; \
		local result="$$2"; \
		local len=`echo -n "$${hint}" | 'wc' -c`; \
		len=`'expr' 65 - "$${len}"`; \
		'printf' '%s' "$${hint}"; \
		[ -n "$${result}" ] && 'printf' "%$${len}s" "$${result}"; \
		echo ''; \
	}; \
	_item_echo ' * `root'"'"' privilleges maybe required by `sudo'"'"' *'; \
	hint='checks whether `openssh-server'"'"' installed...'; \
	[ -f /etc/ssh/sshd_config -a -r /etc/ssh/sshd_config ] \
		&& _item_echo "$${hint}" 'yes' \
		|| { \
			_item_echo "$${hint}" 'no'; \
			echo 'ABORTED!'; \
			exit 1; \
		}; \
	hint='checks whether option `PermitUserEnvironment'"'"' turned on...'; \
	`'grep' '^PermitUserEnvironment\s*yes$$' /etc/ssh/sshd_config > /dev/null 2>&1` \
		&& _item_echo "$${hint}" 'yes' \
		|| { \
			_item_echo "$${hint}" 'no'; \
			hint='modifies `sshd_config'"'..."; \
			reason=`cd /etc/ssh \
				&& 'sudo' 'cp' -af sshd_config sshd_config~backup-by-uchgd 2>&1 \
				&& 'sudo' 'chown' "$${USER}" sshd_config 2>&1 \
				&& echo '' >> sshd_config \
				&& echo '# Added by UCHGd' >> sshd_config \
				&& echo 'PermitUserEnvironment yes' >> sshd_config \
				&& 'sudo' 'chown' root sshd_config 2>&1 \
			`; \
			[ 0 -eq $$? ] && _item_echo "$${hint}" 'succeed' || { \
				_item_echo "$${hint}" 'failed'; \
				echo "ABORTED! $${reason}"; \
				exit 1; \
			}; \
		}; \
	HOME=`'awk' -F':' '"hg"==$$1{print $$6}' /etc/passwd`; \
	_item_echo 'reads home folder...' "$${HOME}"; \
	hint='copies necessary scripts...'; \
	reason=`'sudo' 'cp' -af hgrc "$${HOME}/.hgrc" 2>&1 \
		&& 'sudo' 'cp' -af -t "$${HOME}" ucsh hooks permq 2>&1 \
		&& 'sudo' 'cp' -an -t "$${HOME}" repos 2>&1 \
		&& 'sudo' 'mkdir' -p "$${HOME}/.ssh" 2>&1 \
		&& 'sudo' 'cp' -af authorized_keys "$${HOME}/.ssh/" 2>&1 \
		&& cd "$${HOME}" \
		&& 'sudo' 'chown' -R hg:hg .hgrc ucsh hooks permq .ssh repos 2>&1 \
		&& 'sudo' 'chmod' 700 .ssh 2>&1 \
	`; \
	[ 0 -eq $$? ] && _item_echo "$${hint}" 'done' || { \
		_item_echo "$${hint}" 'halt'; \
		echo "ABORTED! $${reason}"; \
		exit 1; \
	}; \
	hint='checks `sample'"'"' repository...'; \
	[ -d "$${HOME}/repos/sample/.hg" ] && _item_echo "$${hint}" 'yes' || { \
		_item_echo "$${hint}" 'no'; \
		hint='creates `sample'"'"' repository...'; \
		reason=`'sudo' 'cp' -afR repos/sample "$${HOME}/repos/sample" 2>&1 \
			&& 'sudo' 'chown' -R hg:hg "$${HOME}/repos/sample" 2>&1 \
		`; \
		[ 0 -eq $$? ] && _item_echo "$${hint}" 'succeed' || { \
			_item_echo "$${hint}" 'failed'; \
			echo "WARNING! $${reason}"; \
		}; \
	}; \
	echo 'DONE.'

repos/sample:
	$(info GENERATING 'sample' REPOSITORY)
	@_item_echo() { \
		local hint=" $$1"; \
		local result="$$2"; \
		local len=`echo -n "$${hint}" | 'wc' -c`; \
		len=`'expr' 65 - "$${len}"`; \
		'printf' '%s' "$${hint}"; \
		[ -n "$${result}" ] && 'printf' "%$${len}s" "$${result}"; \
		echo ''; \
	}; \
	hint='generates local dummy repository...'; \
	reason=`$(RM) -R dummy \
		&& 'hg' init dummy 2>&1 \
		&& cd dummy \
		&& 'hg' branch stable 2>&1 \
		&& echo 'syntax: glob' > .hgignore \
		&& echo '.*' >> .hgignore \
		&& 'hg' add .hgignore 2>&1 \
		&& 'hg' ci -m'PROJECT INITIALIZED' -u'Snakevil Zen <zhengyy@ucweb.com>' 2>&1 \
	`; \
	[ 0 -eq $$? ] && _item_echo "$${hint}" 'succeed' || { \
		_item_echo "$${hint}" 'failed'; \
		echo "ABORTED! $${reason}"; \
		exit 1; \
	}; \
	hint='generates `sample'"'"' repository...'; \
	reason=`$(RM) -R repos/sample \
		&& 'hg' init repos/sample 2>&1 \
		&& cd dummy \
		&& 'hg' push ../repos/sample 2>&1 \
	`; \
	[ 0 -eq $$? ] && _item_echo "$${hint}" 'succeed' || { \
		_item_echo "$${hint}" 'failed'; \
		echo "ABORTED! $${reason}"; \
		exit 1; \
	}; \
	hint='clears expired dummy respository...'; \
	reason=`$(RM) -R dummy`; \
	[ 0 -eq $$? ] && _item_echo "$${hint}" 'succeed' || { \
		_item_echo "$${hint}" 'failed'; \
		echo "ABORTED! $${reason}"; \
		exit 1; \
	}; \
	echo ''

user.hg:
	$(info VALIDATING USER 'hg')
	@_item_echo() { \
		local hint=" $$1"; \
		local result="$$2"; \
		local len=`echo -n "$${hint}" | 'wc' -c`; \
		len=`'expr' 65 - "$${len}"`; \
		'printf' '%s' "$${hint}"; \
		[ -n "$${result}" ] && 'printf' "%$${len}s" "$${result}"; \
		echo ''; \
	}; \
	_item_echo ' * `root'"'"' privilleges maybe required by `sudo'"'"' *'; \
	UID=`'awk' -F':' '"hg"==$$1{print $$3}' /etc/passwd`; \
	GID=`'awk' -F':' '"hg"==$$1{print $$4}' /etc/passwd`; \
	FULL=`'awk' -F':' '"hg"==$$1{print $$5}' /etc/passwd`; \
	HOME=`'awk' -F':' '"hg"==$$1{print $$6}' /etc/passwd`; \
	SHELL=`'awk' -F':' '"hg"==$$1{print $$7}' /etc/passwd`; \
	hint='checks whether user `hg'"'"' exists...'; \
	[ -n "$${UID}" ] && { \
		_item_echo "$${hint}" 'yes'; \
		_item_echo 'checks group...' `'id' -gn hg`; \
		_item_echo 'checks user'"'"'s home folder...' "$${HOME}"; \
		hint='checks whether home folder exists...'; \
		[ -d "$${HOME}" ] && { \
			_item_echo "$${hint}" 'yes'; \
			OWNSHIP=`'stat' -c'%U:%G' "$${HOME}"`; \
			_item_echo 'checks ownship of home folder...' "$${OWNSHIP}"; \
			[ 'hg:hg' = "$${OWNSHIP}" ] || { \
				hint='fixes ownship of home folder to `hg:hg'"'..."; \
				reason=`'sudo' 'chown' -R hg:hg "$${HOME}" 2>&1`; \
				[ 0 -eq $$?] && _item_echo "$${hint}" 'succeed' || { \
					_item_echo "$${hint}" 'failed'; \
					echo "ABORTED! $${reason}"; \
					exit 1; \
				}; \
			}; \
		} || { \
			_item_echo "$${hint}" 'no'; \
			hint='creates home folder...'; \
			reason=`'sudo' -u hg 'mkdir' -p "$${HOME}" 2>&1`; \
			[ 0 -eq $$? ] && _item_echo "$${hint}" 'succeed' || { \
				_item_echo "$${hint}" 'failed'; \
				echo "ABORTED! $${reason}"; \
				exit 1; \
			}; \
		}; \
		hint=''; \
		_item_echo 'checks user'"'"'s fullname...' "$${FULL}"; \
		[ 'sMercurial' = "s$${FULL}" ] || { \
			FULL='Mercurial'; \
			cmd=" -c'$${FULL}' "; \
			hint='fixes user'"'"'s fullname'; \
		}; \
		_item_echo 'checks user'"'"'s login shell...' "$${SHELL}"; \
		[ "s$${HOME}/ucsh" = "s$${SHELL}" ] || { \
			SHELL="$${HOME}/ucsh"; \
			cmd="$${cmd} -s'$${SHELL}' "; \
			[ -n "$${hint}" ] && hint="$${hint} and login shell..." \
				|| hint='fixes user'"'"'s login shell...'; \
		}; \
		[ -z "$${cmd}" ] || { \
			reason=`eval "'sudo' 'usermod' $${cmd} hg 2>&1"`; \
			[ 0 -eq $$? ] && _item_echo "$${hint}" 'succeed' || { \
				_item_echo "$${hint}" 'failed'; \
				echo "ABORTED! $${reason}"; \
				exit 1; \
			}; \
		}; \
	} || { \
		_item_echo "$${hint}" 'no'; \
		FULL='Mercurial'; \
		for dir in '/home' '/srv' '/var' '/tmp'; do \
			[ -d "$${dir}" ] && { \
				HOME="$${dir}/hg"; \
				break; \
			}; \
		done; \
		SHELL="$${HOME}/ucsh"; \
		hint='creates user account...'; \
		reason=`'sudo' 'useradd' -c"$${FULL}" -d"$${HOME}" -s"$${SHELL}" -l -m -r hg 2>&1`; \
		[ 0 -eq $$? ] && _item_echo "$${hint}" 'succeed' || { \
			_item_echo "$${hint}" 'failed'; \
			echo "ABORTED! $${reason}"; \
			exit 1; \
		}; \
	}; \
	echo ''

.PHONY: UCHGd check install

# vim:ft=make:fenc=utf-8:ff=unix:tw=120:ts=4:sts=4:noet:ai:si
# vim:nowrap:sw=4:nu:nuw=4:so=5:fen:fdm=indent:fdl=0
