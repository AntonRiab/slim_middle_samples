POSTGRES_DB=/var/lib/postgresql/9.6/main
OTHER_PARAM:="--with-debug"

CDIR:=$(shell pwd)

CSYS:=$(shell uname)
ifeq ($(CSYS),FreeBSD)
    PREFIX_CONF="--prefix=/usr/local/ --conf-path=$/usr/local/etc/nginx/nginx.conf"
else ifeq ($(CSYS),Linux)
    PREFIX_CONF="--prefix= --conf-path=/etc/nginx/nginx.conf"
endif

MAKEFLAGS += --jobs=1

define JL_CLEAN
TRUNCATE TABLE jrl_data;
TRUNCATE TABLE rst_data;
ALTER SEQUENCE jrl_data_s_id_seq RESTART WITH 1;
ALTER SEQUENCE rst_data_s_id_seq RESTART WITH 1;

TRUNCATE TABLE log_data;
ALTER SEQUENCE log_data_s_id_seq RESTART WITH 1;
endef
export JL_CLEAN

all: nginx_install ${POSTGRES_DB}/import install_db

.COPY: /var/lib/postgresql/9.6/main/import
	cp simple_data/* /var/lib/postgresql/9.6/main/import/
	chmod -R 777 /var/lib/postgresql/9.6/main/import

####<Nginx search and build>
nginx/auto/configure:
	git clone -q https://github.com/nginx/nginx nginx

nginx/ngx_pgcopy/config:
	git clone -q http://github.com/AntonRiab/ngx_pgcopy nginx/ngx_pgcopy

nginx/Makefile: nginx/auto/configure nginx/ngx_pgcopy/config
	@if [ -z ${PREFIX_CONF} ];then echo "Unknown system, use FreeBSD or Linux!" && exit 2; fi
	cd nginx && auto/configure "${PREFIX_CONF}" \
				"--without-http_gzip_module" \
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
	@if [ -s ./nginx/objs/nginx -a -n $(./nginx/objs/nginx -V | grep ngx_pgcopy) ];then ln -s ./nginx/objs/nginx ./ngx_execute; \
	 elif [ -s /usr/local/sbin/nginx -a -n $(/usr/local/sbin/nginx -V | grep ngx_pgcopy) ];then ln -s /usr/local/sbin/nginx ./ngx_execute; \
         elif [ -s /sbin/nginx -a -n $(/sbin/nginx -V | grep ngx_pgcopy) ];then ln -s /sbin/nginx ./ngx_execute; \
	 else echo "Error, no nginx with ngx_pgcopy, exit"; fi

nginx_clean:
	cd nginx && make clean

nginx/lua-nginx-module/config:
	git clone -q "https://github.com/openresty/lua-nginx-module" nginx/lua-nginx-module

nginx/ngx_devel_kit/config:
	git clone -q "https://github.com/simpl/ngx_devel_kit" nginx/ngx_devel_kit

ngx_execute_lua: nginx/auto/configure nginx/lua-nginx-module/config nginx/ngx_devel_kit/config nginx/ngx_pgcopy/config
	@echo "Build nginx with lua"
	export LUAJIT_LIB=/usr/lib/x86_64-linux-gnu
	export LUAJIT_INC=/usr/include/luajit-2.0
	cd nginx && auto/configure "${PREFIX_CONF}" \
				"--without-http_gzip_module" \
                                "--add-module=${CDIR}/nginx/ngx_pgcopy" \
                                "--pid-path=/var/run/nginx.pid" \
                                "--error-log-path=/var/log/nginx-error.log" \
                                "--http-log-path=/var/log/nginx-access.log" \
				"--with-ld-opt=-Wl,-rpath,/usr/lib/x86_64-linux-gnu" \
				"--add-module=${CDIR}/nginx/ngx_devel_kit" \
				"--add-module=${CDIR}/nginx/lua-nginx-module" \
				"--modules-path=${CDIR}/nginx/tmp" \
				"--http-client-body-temp-path=/tmp/http-client-body-temp-path" \
				"--without-http_fastcgi_module" \
				"--without-http_proxy_module" \
				"--without-http_uwsgi_module" \
				"--without-http_scgi_module" \
	&& make && cp ${CDIR}/nginx/objs/nginx ${CDIR}/ngx_execute_lua

nginx/njs/nginx/config:
	hg clone http://hg.nginx.org/njs nginx/njs

ngx_execute_njs: nginx/njs/nginx/config
	cd nginx && auto/configure "--prefix= --conf-path=${CDIR}/nginx.conf/nginx.conf" \
                                "--add-module=${CDIR}/nginx/ngx_pgcopy" \
                                "--pid-path=/var/run/nginx.pid" \
                                "--error-log-path=/var/log/nginx-error.log" \
                                "--http-log-path=/var/log/nginx-access.log" \
				"--modules-path=${CDIR}/nginx/tmp" \
				"--http-client-body-temp-path=/tmp/http-client-body-temp-path" \
				"--without-http_fastcgi_module" \
				"--without-http_proxy_module" \
				"--without-http_uwsgi_module" \
				"--without-http_scgi_module" \
				"--with-pcre-jit" \
				"--add-module=${CDIR}/nginx/njs/nginx" "${OTHER_PARAM}"\
	&& make && cp ${CDIR}/nginx/objs/nginx ${CDIR}/ngx_execute_njs

####</Nginx search and build>
####<Configure DataBase>
${POSTGRES_DB}/import:
	mkdir ${POSTGRES_DB}/import
	chmod 777 ${POSTGRES_DB}/import

install_db: .COPY
	sudo -u postgres psql -f ${CDIR}/sql/0.init.psql && \
	PGPASSWORD='123' psql -U testuser -d testdb -h 127.0.0.1 -c "CREATE extension hstore;" \
		-f ${CDIR}/sql/1.import.export.sql \
		-f ${CDIR}/sql/2.jrl.log.sql \
		-f ${CDIR}/sql/3.tests.sql

####</Configure DataBase>
####<Nginx configuration start>
####netstat -lp -o pid,port | awk '/:8880/{print $7};
nginx_kill:
	killall -9 ngx_execute 2> /dev/null; exit 0
	killall -9 ngx_execute_njs 2> /dev/null; exit 0
	killall -9 ngx_execute_lua 2> /dev/null; exit 0

ie.config: ngx_execute
	make nginx_kill
	./ngx_execute -c ${CDIR}/nginx.conf/import.export.nginx.conf

f.config: ngx_execute
	make nginx_kill
	./ngx_execute -c ${CDIR}/nginx.conf/filters.nginx.conf

jl.config: ngx_execute
	make nginx_kill
	./ngx_execute -c ${CDIR}/nginx.conf/journal.log.nginx.conf

lua.config: ngx_execute_lua
	make nginx_kill
	./ngx_execute_lua -c ${CDIR}/nginx.conf/lua.filters.nginx.conf

njs.config: ngx_execute_njs 
	make nginx_kill
	./ngx_execute_njs -c ${CDIR}/nginx.conf/njs.filters.nginx.conf

####</Nginx configuration start>
####<Show>
show_begin:
	@echo "***********************************************************************"
	@echo
	@echo "                           SHOW BEGIN                                  "
	@echo 
	@echo "***********************************************************************"

import_export_show: ngx_execute ie.config
	@echo "Current_dir $(CDIR)"
	sudo -u postgres psql -d testdb -c "TRUNCATE TABLE simple_data;"
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
	@echo "***********************************************************************"
	@echo "Prepare journal and log..."
	@echo "$$JL_CLEAN" | PGPASSWORD='123' psql -U testuser -d testdb -h 127.0.0.1 -f - > /dev/null
	@echo "JOURNAL PUT 0***********************************************************"
	curl -f -X PUT -T jornal_log_data/journal.0.data http://127.0.0.1:8880/journal
	@cat jornal_log_data/journal.0.data
	@echo
	@echo "JOURNAL GET 0***********************************************************"
	curl http://127.0.0.1:8880/journal
	@echo "JOURNAL PUT 1***********************************************************"
	curl -f -X PUT -T jornal_log_data/journal.1.data http://127.0.0.1:8880/journal
	@cat jornal_log_data/journal.1.data
	@echo
	@echo "JOURNAL GET 1***********************************************************"
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

show: show_begin import_export_show filter_show journal_log_show
	@echo "***********************************************************************"
	@echo
	@echo "                           SHOW COMPLITE                               "
	@echo 
	@echo "***********************************************************************"
####</Show>
likeiamlazy: nginx/objs/nginx install_db ngx_execute

cleandb:
	sudo -u postgres psql -c 'DROP DATABASE IF EXISTS testdb;'
	sudo -u postgres psql -c 'DROP USER IF EXISTS testuser;'

cleanall: cleandb
	rm -r nginx
	rm -r ${POSTGRES_DB}/import
	rm ngx_execute ngx_execute_njs
