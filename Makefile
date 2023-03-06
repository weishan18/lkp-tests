ifeq ($(TARGET_DIR_BIN), )
    TARGET_DIR_BIN := /usr/local/bin
endif

all: subsystem install

subsystem:
	$(MAKE) -C bin/event wakeup

install:
	mkdir -p $(TARGET_DIR_BIN)
	ln -sf $(shell pwd)/bin/lkp $(TARGET_DIR_BIN)/lkp

.PHONY: doc
doc:
	lkp gen-doc > ./doc/tests.md

tests/%.md: tests/%.yaml
	lkp gen-doc $<

MONITOR_BUILD_DIR := lkp-monitors

build-monitor: subsystem
	install -d $(MONITOR_BUILD_DIR)
	install -d $(MONITOR_BUILD_DIR)/bin
	install bin/lkp $(MONITOR_BUILD_DIR)/bin
	install bin/run-local-monitor.sh $(MONITOR_BUILD_DIR)/bin
	install bin/post-run $(MONITOR_BUILD_DIR)/bin
	install -d $(MONITOR_BUILD_DIR)/bin/event
	install bin/event/wakeup $(MONITOR_BUILD_DIR)/bin/event
	install bin/event/wait $(MONITOR_BUILD_DIR)/bin/event
	install -d $(MONITOR_BUILD_DIR)/etc
	install etc/monitors_need_gzip -m 0644 $(MONITOR_BUILD_DIR)/etc
	install -d $(MONITOR_BUILD_DIR)/tests
	install tests/wrapper $(MONITOR_BUILD_DIR)/tests
	install tests/mytest $(MONITOR_BUILD_DIR)/tests
	install -d $(MONITOR_BUILD_DIR)/monitors
	cp -r monitors $(MONITOR_BUILD_DIR)
	install -d $(MONITOR_BUILD_DIR)/lib
	install lib/*.sh $(MONITOR_BUILD_DIR)/lib/
	install -d $(MONITOR_BUILD_DIR)/job-scripts
	cp job-scripts/* $(MONITOR_BUILD_DIR)/job-scripts
	tar -czf lkp-monitors.tar.gz $(MONITOR_BUILD_DIR)
	rm -rf $(MONITOR_BUILD_DIR)
