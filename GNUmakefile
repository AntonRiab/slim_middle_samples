POSTGRES_DB=/var/lib/postgresql/9.6/main

CDIR:=$(shell pwd)

CSYS:=$(shell uname)
ifeq ($(CSYS),FreeBSD)
    PREFIX_CONF="--prefix=/usr/local/ --conf-path=$/usr/local/etc/nginx/nginx.conf"
else ifeq ($(CSYS),Linux)
    PREFIX_CONF="--prefix=/ --conf-path=/etc/nginx/nginx.conf"
endif

MAKEFLAGS += --jobs=1

all: nginx_install ${POSTGRES_DB}/import install_db


.COPY: /var/lib/postgresql/9.6/main/import
	cp simple_data/* /var/lib/postgresql/9.6/main/import/
	chmod -R 777 /var/lib/postgresql/9.6/main/import

####<Nginx install>
nginx/Makefile:
	@if [ -z ${PREFIX_CONF} ];then echo "Unknown system, use FreeBSD or Linux!" && exit 2; fi
	git clone -q https://github.com/nginx/nginx nginx
	git clone -q http://github.com/AntonRiab/ngx_pgcopy nginx/ngx_pgcopy
	cd nginx && auto/configure "${PREFIX_CONF}" \
                                "--add-module=${CDIR}/nginx/ngx_pgcopy" \
                                "--pid-path=/var/run/nginx.pid" \
                                "--error-log-path=/var/log/nginx-error.log" \
                                "--http-log-path=/var/log/nginx-access.log" || rm ${CDIR}/nginx/Makefile

nginx/objs/nginx: nginx/Makefile
	@echo "Make nginx"
	@cd nginx && make

nginx_install: nginx/objs/nginx
	@$(shell killall -9 nginx 2> /dev/null)
	@cp nginx/objs/nginx /sbin/nginx

ngx_execute:
	@echo "Search nginx executive file..."
	@if [ -s ./nginx/objs/nginx ];then ln -s ./nginx/objs/nginx ./ngx_execute; \
	 elif [ test -s /usr/local/sbin/nginx ];then ln -s /usr/local/sbin/nginx ./ngx_execute; \
         elif [ test -s /sbin/nginx ];then ln -s /sbin/nginx ./ngx_execute; fi

####</Nginx install>
####<Configure DataBase>
${POSTGRES_DB}/import:
	mkdir ${POSTGRES_DB}/import
	chmod 777 ${POSTGRES_DB}/import

install_db: .COPY
	sudo -u postgres psql -f 0.init.psql && \
        psql -U testuser -d testdb -h 127.0.0.1 \
		-f 1.import.export.sql \
		-f 2.jrl.log.sql \
		-f 3.tests.sql

####</Configure DataBase>
####<Nginx configuration start>
ie.config: ngx_execute
	@killall -9 ngx_execute; ./ngx_execute -c ${CDIR}/import.export.nginx.conf

f.config: ngx_execute
	@killall -9 ngx_execute; ./ngx_execute -c ${CDIR}/filters.nginx.conf

jl.config: ngx_execute
	@killall -9 ngx_execute; ./ngx_execute -c ${CDIR}/journal.log.nginx.conf
####</Nginx configuration start>
####<Show>
import_export_show: ngx_execute ie.config
	@echo "Current_dir $(CDIR)"
	@sudo -u postgres psql -d testdb -c "TRUNCATE TABLE simple_data;"
	@echo
	@echo "PUT CSV*****************************************************************"
	curl -f -X PUT -T simple_data/data.csv http://127.0.0.1:8880/csv/simple_data
	@cat simple_data/data.csv
	@echo
	@echo "PUT JSON****************************************************************"
	curl -f -X PUT -T simple_data/data.json http://127.0.0.1:8880/json/simple_data
	@cat simple_data/data.json
	@echo
	@echo "PUT XML*****************************************************************"
	curl -f -X PUT -T simple_data/data.xml http://127.0.0.1:8880/xml/simple_data
	@cat simple_data/data.xml
	@echo
	@echo "GET CSV*****************************************************************"
	curl http://127.0.0.1:8880/csv/simple_data
	@echo "GET JSON****************************************************************"
	curl http://127.0.0.1:8880/json/simple_data
	@echo
	@echo "GET XML*****************************************************************"
	curl http://127.0.0.1:8880/xml/simple_data

filter_show: ngx_execute f.config
	@echo "GET FILTER s_id=1*******************************************************"
	curl http://127.0.0.1:8880/t/simple_data/*?s_id=1

journal_log_show: ngx_execute jl.config
	@sudo -u postgres psql -d testdb -f clean.journal_log.sql
	@echo "JOURNAL PUT 0***********************************************************"
	curl -f -X PUT -T jornal_log_data/journal.0.data http://127.0.0.1:8880/journal
	@cat jornal_log_data/journal.0.data
	@echo
	@echo "JOURNAL GET*************************************************************"
	curl http://127.0.0.1:8880/journal
	@echo "JOURNAL PUT 1***********************************************************"
	curl -f -X PUT -T jornal_log_data/journal.1.data http://127.0.0.1:8880/journal
	@cat jornal_log_data/journal.1.data
	@echo
	@echo "JOURNAL GET*************************************************************"
	curl http://127.0.0.1:8880/journal
	@echo
	@echo "LOG PUT 0***************************************************************"
	curl -f -X PUT -T jornal_log_data/log.0.data http://127.0.0.1:8880/log
	@cat jornal_log_data/log.0.data
	@echo
	@echo "LOG GET 0***************************************************************"
	curl http://127.0.0.1:8880/log
	@echo "LOG PUT 1***************************************************************"
	curl -f -X PUT -T jornal_log_data/log.1.data http://127.0.0.1:8880/log
	@cat jornal_log_data/log.1.data
	@echo
	@echo "LOG GET 1***************************************************************"
	curl http://127.0.0.1:8880/log
	@echo

show: import_export_show filter_show journal_log_show
####</Show>
likeiamlazy: nginx/objs/nginx install_db ngx_execute

cleandb:
	sudo -u postgres psql -c 'DROP DATABASE IF EXISTS testdb;'
	sudo -u postgres psql -c 'DROP USER IF EXISTS testuser;'

cleanall: cleandb
	rm -r ${POSTGRES_DB}/import
	rm ngx_execute
	rm -r nginx
