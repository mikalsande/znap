CONFIG_PATH=/usr/local/etc
BINARY_PATH=/usr/local/sbin

configure:
	sed "s|^CONFIG=.*|CONFIG='${CONFIG_PATH}'|g" ./znap.sh > ./znap.sh_install
	sed "s|^CONFIG=.*|CONFIG='${CONFIG_PATH}'|g" ./znap-hourly.sh > ./znap-hourly.sh_install

install: configure
	install -C -o root -g wheel -m 555 ./znap.sh_install ${BINARY_PATH}/znap.sh
	install -C -o root -g wheel -m 555 ./znap-hourly.sh_install ${BINARY_PATH}/znap-hourly.sh
	install -C -o root -g wheel -m 644 ./znap.conf ${CONFIG_PATH}
	mkdir -p ${CONFIG_PATH}/znap.d

clean:
	rm -f ./znap.sh_install
	rm -f ./znap-hourly.sh_install
