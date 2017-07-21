CDIR:=$(shell pwd)

all: diff.out
	@printf "Compare with reference\n\n"
	@test -s diff.out && printf "\tTEST ERROR!" || echo "\tTEST PASS."

nginx.conf:
	@echo "Start nginx with test config..."
	@killall -9 nginx; nginx -c ${CDIR}/return.filters.nginx.conf
	@echo "ATTENTION: Before use this test, you need to run 'make show' in directory upper that!!!"

positive:
	curl -f "http://127.0.0.1:8880/t/simple_data/*" -o 1.out 2> /dev/null
	@echo >> 1.out
	curl -f "http://127.0.0.1:8880/t/simple_data/*?s_id=1" -o 2.out 2> /dev/null
	@echo >> 2.out
	curl -f "http://127.0.0.1:8880/t/simple_data/*?s_id=1&data0=one" -o 3.out 2> /dev/null
	@echo >> 3.out

negative:
	curl -f "http://127.0.0.1:8880/t/simple_data/*?s_id=1;drop%20table%20simple_data;" -o inj.out 2> /dev/null
	@echo >> inj.out

result.out: nginx.conf positive negative
	@echo "Make result.out"
	@$(shell rm result.out 2> /dev/null)
	@ls *.out | grep -v result | sed 's/^/cat /;s/$$/ >> result.out/' | sh -f -

diff.out: result.reference result.out
	diff result.reference result.out > diff.out

cleanall:
	rm *.out 2> /dev/null
