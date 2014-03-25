TEMPORARY_FILE=./znap.sh_install
CONFIG_PATH=/usr/local/etc
BIN_PATH=/usr/local/sbin

configure:
	sed "s|^CONFIG=.*|CONFIG='/usr/local/etc'|g" ./znap.sh > ${TEMPORARY_FILE}

install: configure
	install -C -o root -g wheel -m 555 ./znap.sh_install ${BIN_PATH}/znap.sh
	install -C -o root -g wheel -m 644 ./znap.conf ${CONFIG_PATH}
	mkdir -p ${CONFIG_PATH}/znap.d

clean:
	rm -f ${TEMPORARY_FILE}
