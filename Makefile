# Makefile: 基于 GNUMake 的自动化安装 UCHGd 的脚本。
#
# AUTHOR    Snakevil Zen <zhengyy@ucweb.com>
# COPYRIGHT © 2011 uc.cn.

# {{{ 基础约定

SHELL = /bin/sh

CP = 'cp' -af

SIGNATURE = by UCHGd automatically at

BACKUP_SUFFIX = ~backuped-by-UCHGd

HOOK_TYPES = changegroup commit incoming outgoing prechangegroup precommit \
    preoutgoing pretag pretxnchangegroup pretxncommit preupdate tag \
    update

USED_CMDS = awk basename expr hg id sudo useradd usermod wc stat mv grep \
	sort sed cat head mkdir touch date tail tar bzip2

# }}}

# {{{ 基础计算

AUTHOR = $(strip $(if $(wildcard $(HOME)/.ssh/id_rsa.pub), \
		$(shell 'awk' '{for(i=3;i<=NF;i++)j=j" "$$i;print substr(j, 2)}' '$(HOME)/.ssh/id_rsa.pub'), \
		$(shell 'awk' -F':' -v'host='`'hostname'` \
			'"$(USER)"==$$1{gsub(/,*$$/, "", $$5);print $$5" <"$$1"@"host">"}' /etc/passwd \
		) \
	) \
)

HOOK_FILES = $(foreach hook, $(wildcard hooks/*), \
	$(shell [ -x $(hook) ] && echo '$(hook)') \
)

HG_HOME = $(shell 'awk' -F':' '"hg"==$$1{print $$6}' /etc/passwd)
export HG_HOME := $(strip $(if $(HG_HOME), $(HG_HOME), /home/hg))

DEPARTS = $(notdir $(foreach depart, $(wildcard pubkeys/*), \
		$(if $(wildcard $(depart)/*.pub), $(depart)) \
	) \
)

# }}}

# {{{ 终极目标：all

all: build/cmds-chk.log $(addprefix build/authorized_keys.dept-, $(DEPARTS)) \
		build/hgrc build/sshd_config build/usermod.sh
	$(warning Runs '$@'...)
	'cat' build/authorized_keys.dept-* > build/authorized_keys

# }}}

# {{{ 编译性 GNU 标准目标：check、clean

check: build/cmds-chk.log
	$(warning Runs '$@'...)

ifneq "$(strip $(wildcard build/*))" ""

clean:
	$(warning Runs '$@'...)
	$(RM) -R build

endif

# }}}

# {{{ 安装性 GNU 标准目标：install、installcheck、uninstall

ifeq "$(strip $(wildcard build/authorized_keys))" "build/authorized_keys"

install: build/authorized_keys build/cmds-chk.log build/hgrc build/sshd_config \
		build/usermod.sh repos/sample.auth
	$(warning Runs '$@'...)
	'sudo' '$(SHELL)' build/usermod.sh
	$(if $(shell 'sudo' [ -f '$(HG_HOME)/.ssh/authorized_keys' ] && echo 1), \
		$(if $(shell 'sudo' 'head' -n1 '$(HG_HOME)/.ssh/authorized_keys' 2> /dev/null \
				| 'grep' '^### Generated $(SIGNATURE) '), , \
			'sudo' -u hg 'mv' -f '$(HG_HOME)/.ssh/authorized_keys' '$(HG_HOME)/.ssh/authorized_keys$(BACKUP_SUFFIX)' \
		) \
	)
	'sudo' -u hg $(CP) -R -t '$(HG_HOME)/' create hooks permq ucsh
	'sudo' -u hg $(CP) build/authorized_keys '$(HG_HOME)/.ssh/'
	'sudo' -u hg $(CP) build/hgrc '$(HG_HOME)/.hgrc'
	$(foreach file, $(wildcard $(HG_HOME)/repos/*), \
		$(if $(and $(wildcard $(file)/.hg/store), \
				$(shell [ '$(notdir $(file))' = `'basename' '$(file)' .hg` ] && echo 1) \
			), \
			'sudo' 'mv' -f '$(file)' '$(file).hg'; \
		) \
	)
	$(if $(wildcard $(HG_HOME)/repos/sample.hg), , \
		$(if $(wildcard $(HG_HOME)/repos/sample), , \
			cd '$(HG_HOME)' && 'sudo' -u hg -H ./create sample by '$(AUTHOR)' \
		) \
	)
	$(if $(wildcard $(HG_HOME)/repos/sample.auth), , \
		'sudo' -u hg $(CP) repos/sample.auth '$(HG_HOME)/repos/' \
	)
	$(if $(shell 'tail' -n5 /etc/ssh/sshd_config | 'grep' '^### Added $(SIGNATURE) '), , \
		'sudo' 'mv' -f /etc/ssh/sshd_config '/etc/ssh/sshd_config$(BACKUP_SUFFIX)' \
	)
	'sudo' $(CP) build/sshd_config /etc/ssh/sshd_config
	'sudo' 'chown' root:root /etc/ssh/sshd_config
	'sudo' /etc/init.d/ssh restart > /dev/null

installcheck: build/cmds-chk.log build/usermod.sh
	$(warning Runs '$@'...)

endif

ifeq "$(strip $(wildcard $(HG_HOME)/ucsh))" "$(HG_HOME)/ucsh"

uninstall:
	$(warning Runs '$@'...)
	$(if $(wildcard /etc/ssh/sshd_config$(BACKUP_SUFFIX)), \
		'sudo' 'mv' -f '/etc/ssh/sshd_config$(BACKUP_SUFFIX)' /etc/ssh/sshd_config; \
		'sudo' /etc/init.d/ssh restart > /dev/null; \
	)
	$(if $(shell 'sudo' [ -f '$(HG_HOME)/.ssh/authorized_keys$(BACKUP_SUFFIX)' ] && echo 1), \
		'sudo' -u hg 'mv' -f '$(HG_HOME)/.ssh/authorized_keys$(BACKUP_SUFFIX)' '$(HG_HOME)/.ssh/authorized_keys' \
	)
	$(if $(shell read -p'> Also destroy the `sample'"'"' repository? Type `yes'"'"' to do it: ' c \
			&& [ 'xyes' = 'x'`echo -n "$${c}"` ] && echo 1 \
		), \
		cd '$(HG_HOME)/repos' && 'sudo' $(RM) -R sample.hg sample.auth \
	)
	cd '$(HG_HOME)' && 'sudo' $(RM) -R create .hgrc hooks permq .ssh/authorized_keys ucsh

endif

# }}}

# {{{ 动态自定义目标：dept.*、build/authorized_keys.dept-*

define DEPT_MAKE_template
dept.$(strip $(1)): build/cmds-chk.log build/authorized_keys.dept-$(strip $(1)) \
		build/hgrc build/sshd_config build/usermod.sh
	$$(warning Runs '$$@'...)
	$$(CP) build/authorized_keys.dept-$(strip $(1)) build/authorized_keys

build/authorized_keys.dept-$(strip $(1)): $$(wildcard pubkeys/$(strip $(1))/*.pub)
	$$(warning Generates '$$@'...)
	'mkdir' -p $$(@D)
	echo -n '### Generated by UCHGd automatically at ' > '$$@'
	'date' +'%c' >> '$$@'
	echo '' >> '$$@'
	$$(foreach pubkey, $$(sort $$^), \
		echo -n 'no-pty,no-port-forwarding,no-X11-forwarding,' >> '$$@'; \
		echo -n 'no-agent-forwarding,environment="USER=' >> '$$@'; \
		echo -n '$$(strip $$(basename $$(notdir $$(pubkey))))" ' >> '$$@'; \
		'cat' '$$(pubkey)' >> '$$@'; \
	)
endef

$(foreach depart, $(DEPARTS), \
	$(eval $(call DEPT_MAKE_template, $(depart))) \
)

# }}}

# {{{ 自定义目标：build/cmds-chk.log

build/cmds-chk.log:
	$(warning Generates '$@'...)
	$(foreach cmd, which printf $(sort $(USED_CMDS)), \
		$(if $(shell 'which' $(cmd) 2> /dev/null), , \
			$(error Command '$(cmd)' cannot be found) \
		) \
	)
	'mkdir' -p $(@D)
	'which' which printf $(sort $(USED_CMDS)) > $@

# }}}

# {{{ 自定义目标：build/hgrc

build/hgrc: $(HOOK_FILES)
	$(warning Generates '$@'...)
	'mkdir' -p $(@D)
	echo -n '### Generated by UCHGd automatically at ' > $@
	'date' +'%c' >> $@
	echo '' >> $@
	echo '[hooks]' >> $@
	$(foreach hook, $(sort $(notdir $^)), \
		echo '$(strip $(hook)) = $(HG_HOME)/hooks/$(strip $(hook))' >> $@; \
	)

# }}}

# {{{ 自定义目标：build/sshd_config

build/sshd_config: /etc/ssh/sshd_config
	$(warning Generates '$@'...)
	'mkdir' -p $(@D)
	date=`'date' +'%c'`; \
	'awk' -F'Snakevil Zen' -v"now=$${date}" ' \
		/^#+[ \t]*Added[ \t]+by[ \t]+UCHGd/ { \
			skip = 2; \
			uchgd = 1; \
			print "### Added by UCHGd automatically at "now; \
		} \
		!uchgd && /^[ \t]*GSSAPIAuthentication[ \t]+no([ \t]|$$)/ { \
				gaa = 1; \
		} \
		!uchgd && /^[ \t]*GSSAPIAuthentication[ \t]+yes([ \t]|$$)/ { \
			skip = 1; \
			gaa = 0; \
			print "#"$$0; \
		} \
		!uchgd && /^[ \t]*PermitUserEnvironment[ \t]+no([ \t]|$$)/ { \
			skip = 1; \
			pue = 0; \
			print "#"$$0; \
		} \
		!uchgd && /^[ \t]*PermitUserEnvironment[ \t]+yes([ \t]|$$)/ { \
			pue = 1; \
		} \
		!uchgd && /^[ \t]*UseDNS[ \t]+no([ \t]|$$)/ { \
			ud = 1; \
		} \
		!uchgd && /^[ \t]*UseDNS[ \t]+yes([ \t]|$$)/ { \
			skip = 1; \
			ud = 0; \
			print "#"$$0; \
		} \
		!skip{print} \
		{if(1==skip)skip=0} \
		END { \
			if (!uchgd) { \
				print ""; \
				print "### Added by UCHGd automatically at "now; \
				print ""; \
			} \
			if (!gaa) \
				print "GSSAPIAuthentication no"; \
			if (!pue) \
				print "PermitUserEnvironment yes"; \
			if (!ud) \
				print "UseDNS no"; \
		} \
		' $^ > $@

# }}}

# {{{ 自定义目标：build/usermod.sh

build/usermod.sh: /etc/passwd
	$(warning Generates '$@'...)
	'mkdir' -p $(@D)
	$(if $(shell 'awk' -F':' '"hg"==$$1{print}' /etc/passwd), \
		UID=`'awk' -F':' '"hg"==$$1{print $$3}' /etc/passwd`; \
		GID=`'awk' -F':' '"hg"==$$1{print $$4}' /etc/passwd`; \
		FULL=`'awk' -F':' '"hg"==$$1{print $$5}' /etc/passwd`; \
		HOME=`'awk' -F':' '"hg"==$$1{print $$6}' /etc/passwd`; \
		SHELL=`'awk' -F':' '"hg"==$$1{print $$7}' /etc/passwd`; \
		echo "'mkdir' -p '$${HOME}'" > $@; \
		echo "'chown' hg '$${HOME}'" >> $@; \
		echo "'sudo' -u hg 'mkdir' -p '$${HOME}/.ssh'" >> $@; \
		echo "'chmod' 700 '$${HOME}/.ssh'" >> $@; \
		[ 'xMercurial' = "x$${FULL}" ] || echo "'usermod' -c'Mercurial' hg" >> $@; \
		[ "$${HOME}/ucsh" = "$${SHELL}" ] || echo "'usermod' -s'$${HOME}/ucsh' hg" >> $@; \
	, \
		echo "'useradd' -c'Mercurial' -d'/home/hg' -s'/home/hg/ucsh' -l -m -r hg" > $@; \
		echo "'sudo' -u hg 'mkdir' -p /home/hg/.ssh" >> $@; \
		echo "'chmod' 700 /home/hg/.ssh" >> $@; \
	)

# }}}

include Makefile~*.mk

.PHONY:

# vim:ft=make:fenc=utf-8:ff=unix:tw=120:ts=4:sts=4:noet:ai:si
# vim:nowrap:sw=4:nu:nuw=4:so=5:fen:fdm=indent:fdl=0
