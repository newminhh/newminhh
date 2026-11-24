# Top-level reproducible build, packaging, VM, test & benchmark orchestration for newminhh

ifeq ($(origin CC),default)
  CC := clang
endif
CSTD ?= gnu23

PREFIX ?= /usr/local
DETECT_MUSL := $(shell test -e /lib/ld-musl-x32.so.1 && echo 1 || true)
ifeq ($(DETECT_MUSL),1)
  LIBDIR ?= $(PREFIX)/lib
else
  LIBDIR ?= $(PREFIX)/lib/x86_64-linux-gnux32
endif
BINDIR ?= $(PREFIX)/bin
DESTDIR ?=

VM_EXEC := ./vm/vm-exec.sh
REMOTE_ROOT ?= /root/newminhh

DETECT_DPKG_ARCH := $(shell dpkg --print-architecture 2>/dev/null)
DETECT_CC_X32 := $(shell $(CC) -dM -E - </dev/null 2>/dev/null | grep -q '__ILP32__' && echo x32 || true)

ifeq ($(DETECT_DPKG_ARCH),x32)
IN_X32 := 1
else ifeq ($(DETECT_CC_X32),x32)
IN_X32 := 1
else
IN_X32 := 0
endif

.DEFAULT_GOAL := build

.PHONY: all clean build install sync-vm patcher-registry \
	vm-up vm-verify vm-down \
	test-lookup test-part1 test-part2 test-part3 test-part4 test-part5 test-part6 test-part7 test bench help analyze

all: build

help:
	@echo "newminhh Makefile targets (detected IN_X32=$(IN_X32), CC=$(CC), CSTD=$(CSTD)):"
	@echo "  build            Build lookup, i386 corpus (host), and native x32 runtime/compat/corpus (VM or local x32)"
	@echo "  install          Install newminhh-lookup-gen, rules.d, libnewminhh_compat.so, libnewminhh_dbt.so, newminhh-run, bin/newminhh"
	@echo "  clean            Remove local (and remote VM, if reachable) build artifacts"
	@echo "  analyze          Run static analysis across lookup, compat, and DBT engines"
	@echo "  patcher-registry Regenerate src/patcher/re_patcher/_lookup_registry_gen.py from src/lookup/rules.d"
	@echo "  vm-up            Boot Debian x32 VM (newminhh-x32)"
	@echo "  vm-verify        Verify x32-only VM configuration (zero :i386 packages)"
	@echo "  vm-down          Shut down Debian x32 VM"
	@echo "  test-lookup      Run C23 lookup library, generator & 191-symbol parity tests"
	@echo "  test-part1       Run Part 1 corpus & baseline tests"
	@echo "  test-part2       Run Part 2 ABI compat wrapper tests"
	@echo "  test-part3       Run Part 3 static/hybrid patcher Level 1 tests"
	@echo "  test-part4       Run Part 4 runtime DBT tests"
	@echo "  test-part5       Run Part 5 clean build, CLI, Parts 1-4 regression & smaps/timing benchmarks"
	@echo "  test-part6       Run Part 6 Level 2A/2B symbolic GAS & specialized stub tests"
	@echo "  test-part7       Run Part 7 Level 3A/3C gated boost & decompile-assist tests"
	@echo "  test             Run full verification suite"
	@echo "  bench            Run Part 5 /proc/<pid>/smaps, RSS & execution timing benchmarks"

ifeq ($(IN_X32),1)

clean:
	$(MAKE) -C src/lookup clean
	$(MAKE) -C src/compat clean
	$(MAKE) -C src/dbt clean
	rm -rf tests/corpus/build/x32
	$(MAKE) -C tests/part2 clean
	$(MAKE) -C tests/part4 clean

build:
	$(MAKE) -C src/lookup CC="$(CC)" CSTD="$(CSTD)" all
	$(MAKE) -C src/compat CC="$(CC)" CSTD="$(CSTD)" all
	$(MAKE) -C src/dbt CC="$(CC)" CSTD="$(CSTD)" all
	$(MAKE) -C tests/corpus CC="$(CC)" CSTD="$(CSTD)" x32

install: build
	$(MAKE) -C src/lookup CC="$(CC)" CSTD="$(CSTD)" PREFIX="$(PREFIX)" BINDIR="$(BINDIR)" DESTDIR="$(DESTDIR)" install
	$(MAKE) -C src/compat CC="$(CC)" CSTD="$(CSTD)" PREFIX="$(PREFIX)" LIBDIR="$(LIBDIR)" DESTDIR="$(DESTDIR)" install
	$(MAKE) -C src/dbt CC="$(CC)" CSTD="$(CSTD)" PREFIX="$(PREFIX)" LIBDIR="$(LIBDIR)" BINDIR="$(BINDIR)" DESTDIR="$(DESTDIR)" install
	install -d "$(DESTDIR)$(BINDIR)"
	chmod +x "$(CURDIR)/bin/newminhh"
	ln -sf "$(abspath $(CURDIR)/bin/newminhh)" "$(DESTDIR)$(BINDIR)/newminhh"
	@if [ -z "$(DESTDIR)" ]; then ldconfig || true; fi

analyze:
	$(MAKE) -C src/lookup CC="$(CC)" CSTD="$(CSTD)" analyze
	$(MAKE) -C src/compat CC="$(CC)" CSTD="$(CSTD)" analyze
	$(MAKE) -C src/dbt CC="$(CC)" CSTD="$(CSTD)" analyze

test-lookup:
	$(MAKE) -C src/lookup CC="$(CC)" CSTD="$(CSTD)" check

patcher-registry:
	$(MAKE) -C src/lookup CC="$(CC)" CSTD="$(CSTD)" newminhh-lookup-gen
	./src/lookup/newminhh-lookup-gen --emit-py-registry src/lookup/rules.d -o src/patcher/re_patcher/_lookup_registry_gen.py --quiet

vm-up vm-verify vm-down:
	@echo "[newminhh] ERROR: '$@' must be invoked on the x86_64 host, not inside x32 guest." >&2
	@exit 1

test-part1:
	bash tests/corpus/run_part1_tests.sh --guest-run

test-part2:
	$(MAKE) -C src/lookup CC="$(CC)" CSTD="$(CSTD)" all
	$(MAKE) -C src/compat CC="$(CC)" CSTD="$(CSTD)" clean all install
	$(MAKE) -C tests/part2 CC="$(CC)" CSTD="$(CSTD)" clean all
	./tests/part2/test_compat

test-part3:
	@echo "[newminhh] ERROR: 'test-part3' must be invoked on the x86_64 host (requires Docker re-env:latest)." >&2
	@exit 1

test-part4:
	bash tests/part4/run_part4_tests.sh --guest-run

test-part5:
	bash tests/part5/run_part5_tests.sh --guest-run

test: test-part5

bench:
	bash tests/part5/run_part5_tests.sh --bench-only --guest-run

else

sync-vm:
	$(VM_EXEC) -- mkdir -p "$(REMOTE_ROOT)"
	tar -cf - Makefile README.md bin | $(VM_EXEC) -- tar -C "$(REMOTE_ROOT)" -xf -
	$(VM_EXEC) --sync src/common "$(REMOTE_ROOT)/src/common"
	$(VM_EXEC) --sync src/lookup "$(REMOTE_ROOT)/src/lookup"
	$(VM_EXEC) --sync src/compat "$(REMOTE_ROOT)/src/compat"
	$(VM_EXEC) --sync src/dbt "$(REMOTE_ROOT)/src/dbt"
	$(VM_EXEC) -- sh -c 'rm -f "$(REMOTE_ROOT)/src/lookup"/*.o "$(REMOTE_ROOT)/src/lookup"/*.a "$(REMOTE_ROOT)/src/lookup/newminhh-lookup-gen" "$(REMOTE_ROOT)/src/lookup/test_lookup" "$(REMOTE_ROOT)/src/compat"/*.o "$(REMOTE_ROOT)/src/compat"/*.so "$(REMOTE_ROOT)/src/dbt"/*.o "$(REMOTE_ROOT)/src/dbt"/*.so "$(REMOTE_ROOT)/src/dbt/newminhh-run"'
	$(VM_EXEC) --sync tests/lookup "$(REMOTE_ROOT)/tests/lookup"
	$(VM_EXEC) --sync tests/corpus "$(REMOTE_ROOT)/tests/corpus"
	$(VM_EXEC) --sync tests/part2 "$(REMOTE_ROOT)/tests/part2"
	$(VM_EXEC) --sync tests/part4 "$(REMOTE_ROOT)/tests/part4"
	$(VM_EXEC) --sync tests/part5 "$(REMOTE_ROOT)/tests/part5"

clean:
	$(MAKE) -C src/lookup clean
	$(MAKE) -C src/compat clean
	$(MAKE) -C src/dbt clean
	$(MAKE) -C tests/corpus clean
	$(MAKE) -C tests/part2 clean
	$(MAKE) -C tests/part4 clean
	@if [ -f vm/.state/id_ed25519 ] && $(VM_EXEC) --ip >/dev/null 2>&1; then \
		$(VM_EXEC) -- bash -c "if [ -f $(REMOTE_ROOT)/Makefile ]; then $(MAKE) -C $(REMOTE_ROOT) clean; fi; rm -rf $(REMOTE_ROOT)/tests/corpus/build"; \
	fi

build:
	$(MAKE) -C src/lookup CC="$(CC)" CSTD="$(CSTD)" all
	$(MAKE) patcher-registry
	$(MAKE) -C tests/corpus CC="$(CC)" CSTD="$(CSTD)" i386
	$(MAKE) sync-vm
	$(VM_EXEC) -- make -C "$(REMOTE_ROOT)" CC="$(CC)" CSTD="$(CSTD)" PREFIX="$(PREFIX)" LIBDIR="$(LIBDIR)" BINDIR="$(BINDIR)" build

patcher-registry:
	$(MAKE) -C src/lookup CC="$(CC)" CSTD="$(CSTD)" newminhh-lookup-gen
	./src/lookup/newminhh-lookup-gen --emit-py-registry src/lookup/rules.d -o src/patcher/re_patcher/_lookup_registry_gen.py --quiet

install: build
	$(VM_EXEC) -- make -C "$(REMOTE_ROOT)" CC="$(CC)" CSTD="$(CSTD)" PREFIX="$(PREFIX)" LIBDIR="$(LIBDIR)" BINDIR="$(BINDIR)" DESTDIR="$(DESTDIR)" install

analyze:
	$(MAKE) -C src/lookup CC="$(CC)" CSTD="$(CSTD)" analyze
	$(MAKE) -C src/compat CC="$(CC)" CSTD="$(CSTD)" analyze
	$(MAKE) -C src/dbt CC="$(CC)" CSTD="$(CSTD)" analyze

test-lookup:
	$(MAKE) -C src/lookup CC="$(CC)" CSTD="$(CSTD)" check
	bash tests/lookup/registry_parity.sh

test-part6:
	bash tests/part6/run_part6_tests.sh

test-part7:
	bash tests/part7/run_part7_tests.sh

vm-up:
	bash vm/vm-up.sh

vm-verify:
	bash vm/vm-verify-x32.sh

vm-down:
	bash vm/vm-down.sh

test-part1:
	bash tests/corpus/run_part1_tests.sh

test-part2:
	bash tests/part2/run_part2_tests.sh

test-part3:
	bash tests/part3/run_part3_tests.sh

test-part4:
	bash tests/part4/run_part4_tests.sh

test-part5:
	bash tests/part5/run_part5_tests.sh

test:
	bash tests/part5/run_part5_tests.sh

bench:
	bash tests/part5/run_part5_tests.sh --bench-only

endif
