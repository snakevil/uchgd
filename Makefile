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

HOOK_FILES = $(foreach hook, $(wildcard hooks/*), \
	$(shell [ -x $(hook) ] && echo '$(hook)') \
)
HG_HOME = $(shell 'awk' -F':' '"hg"==$$1{print $$6}' /etc/passwd)

HG_HOME := $(if $(HG_HOME), $(HG_HOME), /home/hg)

HG_HOME := $(strip $(HG_HOME))

HG_REPOS = $(foreach file, $(wildcard $(HG_HOME)/repos/*), \
	$(shell [ -d '$(file)' ] && echo '$(file)') \
)

BACKUP_FILES =

DIST_FILE = dist./uchgd-$(strip $(if $(shell [ 'tip' = `'hg' parents --template '{tags}'` ] || echo 1), \
	$(shell 'hg' parents --template 'v{tags}'), \
	$(shell 'hg' parents --template 'nr{rev}') \
)).tar.gz

DEPARTS =

# }}}

# {{{ 终极目标：all

all: build/cmds-chk.log build/authorized_keys.all build/hgrc build/sshd_config \
		build/usermod.sh build/sample
	$(warning Runs '$@'...)
	$(CP) build/authorized_keys.all build/authorized_keys

# }}}

# {{{ 编译安装目标：check、clean、dept.*、install、installcheck、uninstall

define DEPART_MAKE_template
dept.$(strip $(1)): build/cmds-chk.log build/authorized_keys.$(strip $(1)) \
		build/hgrc build/sshd_config build/usermod.sh build/sample
	$$(warning Runs '$$@'...)
	$$(CP) build/authorized_keys.$(strip $(1)) build/authorized_keys

build/authorized_keys.$(strip $(1)): $$(wildcard pubkeys/$(strip $(1))/*.pub)
	$$(warning Generates '$$@'...)
	'mkdir' -p '$$(@D)'
	echo -n '### Generated by UCHGd automatically at ' > '$$@'
	'date' +'%c' >> '$$@'
	echo '' >> '$$@'
	$$(foreach pubkey, $$(sort $$^), \
		echo -n 'no-pty,no-port-forwarding,no-X11-forwarding,' >> '$$@'; \
		echo -n 'no-agent-forwarding,environment="USER=' >> '$$@'; \
		echo -n '$$(strip $$(basename $$(notdir $$(pubkey))))" ' >> '$$@'; \
		'cat' '$$(pubkey)' >> '$$@'; \
	)

DEPARTS += $(strip $(1))
endef

$(foreach depart, $(wildcard pubkeys/*), \
	$(if $(wildcard $(depart)/*.pub), \
		$(eval $(call DEPART_MAKE_template, $(notdir $(depart)))) \
	) \
)

#

check: build/cmds-chk.log
	$(warning Runs '$@'...)

clean:
	$(warning Runs '$@'...)
	$(RM) -R build

install: build/cmds-chk.log build/authorized_keys build/hgrc build/sshd_config \
		build/usermod.sh build/sample repos/sample.auth
	$(warning Runs '$@'...)
	'sudo' '$(SHELL)' build/usermod.sh
	'sudo' -u hg $(CP) -R -t '$(HG_HOME)/' hooks permq repos ucsh
	'sudo' [ ! -f '$(HG_HOME)/.ssh/authorized_keys' ] || { \
		'sudo' 'head' -n1 '$(HG_HOME)/.ssh/authorized_keys' | 'grep' -q '^### Generated $(SIGNATURE) ' \
			|| 'sudo' -u hg $(CP) '$(HG_HOME)/.ssh/authorized_keys' '$(HG_HOME)/.ssh/authorized_keys$(BACKUP_SUFFIX)'; \
	}
	'sudo' -u hg $(CP) build/authorized_keys '$(HG_HOME)/.ssh/'
	'sudo' -u hg $(CP) build/hgrc '$(HG_HOME)/.hgrc'
	[ -d '$(HG_HOME)/repos/sample' ] \
		|| 'sudo' -u hg $(CP) -R build/sample '$(HG_HOME)/repos/'
	'sudo' 'tail' -n5 '/etc/ssh/sshd_config' \
		| 'grep' -q '^### Added $(SIGNATURE) ' \
			|| 'sudo' $(CP) '/etc/ssh/sshd_config' \
				'/etc/ssh/sshd_config$(BACKUP_SUFFIX)'
	'sudo' $(CP) build/sshd_config /etc/ssh/sshd_config \
		&& 'sudo' 'chown' root:root /etc/ssh/sshd_config
	'sudo' /etc/init.d/ssh restart > /dev/null

installcheck: build/cmds-chk.log build/usermod.sh
	$(warning Runs '$@'...)

uninstall:
	$(warning Runs '$@'...)
	[ ! -f '/etc/ssh/sshd_config$(BACKUP_SUFFIX)' ] || { \
		'sudo' 'mv' -f '/etc/ssh/sshd_config$(BACKUP_SUFFIX)' '/etc/ssh/sshd_config'; \
		'sudo' /etc/init.d/ssh restart > /dev/null; \
	}
	[ -d '$(HG_HOME)' ] || exit 0
	cd '$(HG_HOME)' && 'sudo' $(RM) -R .hgrc hooks permq repos/sample.auth .ssh/authorized_keys ucsh
	'sudo' [ ! -f '$(HG_HOME)/.ssh/authorized_keys$(BACKUP_SUFFIX)' ] \
		|| 'sudo' 'mv' -f '$(HG_HOME)/.ssh/authorized_keys$(BACKUP_SUFFIX)' '$(HG_HOME)/.ssh/authorized_keys'
	read -p'Also destroy the `sample'"'"' repository? Type `yes'"'"' to do it: ' c \
		&& [ 'xyes' = 'x'`echo -n "$${c}"` ] \
		&& 'sudo' $(RM) -R '$(HG_HOME)/repos/sample' \
		|| exit 0

#

build/authorized_keys.all: $(wildcard pubkeys/*/*.pub)
	$(warning Generates '$@'...)
	'mkdir' -p '$(@D)'
	echo -n '### Generated by UCHGd automatically at ' > '$@'
	'date' +'%c' >> '$@'
	echo '' >> '$@'
	$(foreach pubkey, $(sort $^), \
		echo -n 'no-pty,no-port-forwarding,no-X11-forwarding,' >> '$@'; \
		echo -n 'no-agent-forwarding,environment="USER=' >> '$@'; \
		echo -n '$(strip $(basename $(notdir $(pubkey))))" ' >> '$@'; \
		'cat' '$(pubkey)' >> '$@'; \
	)

build/cmds-chk.log:
	$(warning Generates '$@'...)
	$(foreach cmd, which printf $(sort $(USED_CMDS)), \
		$(if $(shell 'which' $(cmd) 2> /dev/null), , \
			$(error Command '$(cmd)' cannot be found) \
		) \
	)
	'mkdir' -p '$(@D)'
	'which' which printf $(sort $(USED_CMDS)) > '$@'

build/dummy:
	$(warning Generates '$@'...)
	'mkdir' -p '$(@D)'
	$(RM) -R '$@'
	'hg' init '$@'
	cd $@ && 'hg' branch stable > /dev/null
	echo 'syntax: glob' > '$@/.hgignore'
	echo '.*' >> '$@/.hgignore'
	cd $@ && 'hg' add .hgignore
	cd $@ && 'hg' ci -m'PROJECT INITIALIZED' -u'Snakevil Zen <zhengyy@ucweb.com>'

build/hgrc: $(HOOK_FILES)
	$(warning Generates '$@'...)
	'mkdir' -p '$(@D)'
	echo -n '### Generated by UCHGd automatically at ' > '$@'
	'date' +'%c' >> '$@'
	echo '' >> '$@'
	echo '[hooks]' >> '$@'
	$(foreach hook, $(sort $(notdir $^)), \
		echo '$(strip $(hook)) = $(HG_HOME)/hooks/$(strip $(hook))' >> '$@'; \
	)

build/sample: build/dummy
	$(warning Generates '$@'...)
	'mkdir' -p '$(@D)'
	$(RM) -R '$@'
	'hg' init '$@'
	cd $(lastword $^) && 'hg' push $(abspath $@) > /dev/null

build/sshd_config: /etc/ssh/sshd_config
	$(warning Generates '$@'...)
	'mkdir' -p '$(@D)'
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
		' '$(lastword $^)' > '$@'

build/usermod.sh: /etc/passwd
	$(warning Generates '$@'...)
	'mkdir' -p '$(@D)'
	$(if $(shell 'awk' -F':' '"hg"==$$1{print}' /etc/passwd), \
		UID=`'awk' -F':' '"hg"==$$1{print $$3}' /etc/passwd`; \
		GID=`'awk' -F':' '"hg"==$$1{print $$4}' /etc/passwd`; \
		FULL=`'awk' -F':' '"hg"==$$1{print $$5}' /etc/passwd`; \
		HOME=`'awk' -F':' '"hg"==$$1{print $$6}' /etc/passwd`; \
		SHELL=`'awk' -F':' '"hg"==$$1{print $$7}' /etc/passwd`; \
		echo "'mkdir' -p '$${HOME}'" > '$@'; \
		echo "'chown' hg '$${HOME}'" >> '$@'; \
		echo "'sudo' -u hg 'mkdir' -p '$${HOME}/.ssh'" >> '$@'; \
		echo "'chmod' 700 '$${HOME}/.ssh'" >> '$@'; \
		[ 'xMercurial' = "x$${FULL}" ] || echo "'usermod' -c'Mercurial' hg" >> '$@'; \
		[ "$${HOME}/ucsh" = "$${SHELL}" ] || echo "'usermod' -s'$${HOME}/ucsh' hg" >> '$@'; \
	, \
		echo "'useradd' -c'Mercurial' -d'/home/hg' -s'/home/hg/ucsh' -l -m -r hg" > '$@'; \
		echo "'sudo' -u hg 'mkdir' -p '/home/hg/.ssh'" >> '$@'; \
		echo "'chmod' 700 '/home/hg/.ssh'" >> '$@'; \
	)

# }}}

# {{{ 备份目标：archive、archiveclean

define ARCHIVE_MAKE_template
export/$(strip $(2)): $(strip $(1))
	$$(warning Archives '$$^'...)
	'mkdir' -p $$(@D)
	'tar' cf '$$(basename $$@)' -C '$$(dir $$^)' '$$(notdir $$^)'
	[ ! -f '$$^.auth' ] || 'tar' rf '$$(basename $$@)' -C '$$(dir $$^)' '$$(notdir $$^).auth'
	'gzip' -9 '$$(basename $$@)'

BACKUP_FILES += export/$(strip $(2))
endef

$(foreach repos, $(HG_REPOS), \
	$(if $(shell cd '$(dir $(repos))' \
					&& 'hg' log -r'tip' --template '-rev{rev}~{node|short}' '$(notdir $(repos))' 2> /dev/null \
		), \
		$(eval $(call ARCHIVE_MAKE_template, $(repos), \
			$(addprefix $(notdir $(repos)), \
				$(addsuffix .tar.gz, \
					$(shell cd '$(dir $(repos))' \
						&& 'hg' log -r'tip' --template '-rev{rev}~{node|short}' '$(notdir $(repos))' 2> /dev/null \
					) \
				) \
			) \
		)) \
	) \
)

#

archive: $(BACKUP_FILES)
	$(warning Runs '$@'...)

archiveclean:
	$(warning Runs '$@'...)
	$(RM) -R export

restore: $(wildcard export/*-rev*~????????????.tar.gz)
	$(warning Runs '$@'...)
	$(if $(wildcard $(HG_HOME)/repos), , $(error 'UCHGd' should be installed first))
	$(foreach archive, $^, \
		$(if $(wildcard $(HG_HOME)/repos/$(shell 'tar' tf '$(archive)' | 'head' -n1)), , \
			'sudo' -u hg 'tar' zxf '$(archive)' -C '$(HG_HOME)/repos'; \
		) \
	)

# }}}

# {{{ 打包目标：dist、distclean

dist: $(DIST_FILE)
	$(warning Runs '$@'...)

distclean:
	$(warning Runs '$@'...)
	$(RM) -R dist.

#

$(DIST_FILE):
	$(warning Generates '$@'...)
	'mkdir' -p '$(@D)'
	'hg' archive -X '.*' '$(DIST_FILE)'

# }}}

# {{{ 帮助目标：help

help: help.make help.archive help.dist help.help

help.archive:
	@echo '* archive'; \
	echo '    备份 $(HG_HOME)/repos 目录下的所有非空版本库到 export 目录'; \
	echo '* archiveclean'; \
	echo '    清除历史备份数据'; \
	echo '* restore'; \
	echo '    从 export 目录还原 $(HG_HOME)/repos 目录中缺少的版本库'; \
	echo ''

help.dist:
	@echo '* dist'; \
	echo '    将 UCHGd 的当前版本打包到 dist. 目录'; \
	echo '* distclean'; \
	echo '    清除历史打包数据'; \
	echo ''

help.help:
	@echo '* help'; \
	echo '    查看完整的指令帮助'; \
	echo '* help.archive'; \
	echo '    查看备份还原相关的指令帮助'; \
	echo '* help.dist'; \
	echo '    查看打包发布相关的指令帮助'; \
	echo '* help.make'; \
	echo '    查看编译安装相关的指令帮助'; \
	echo ''

help.make:
	@echo '* all'; \
	echo '    编译；包含所有部门的人员信息'; \
	echo '* check'; \
	echo '    检查是否可编译'; \
	echo '* clean'; \
	echo '    清除编译产生的文件'; \
	[ -z '$(DEPARTS)' ] \
		|| for depart in $(DEPARTS); do \
			echo "* dept.$${depart}"; \
			echo "    编译；只包含 $${depart} 部门的人员信息"; \
		done; \
	echo '* install'; \
	echo '    安装；需要先编译'; \
	echo '* installcheck'; \
	echo '    检查是否可安装'; \
	echo '* uninstall'; \
	echo '    卸载'; \
	echo ''

# }}}

.PHONY:

# vim:ft=make:fenc=utf-8:ff=unix:tw=120:ts=4:sts=4:noet:ai:si
# vim:nowrap:sw=4:nu:nuw=4:so=5:fen:fdm=indent:fdl=0
