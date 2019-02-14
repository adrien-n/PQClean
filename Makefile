# This -Wall was supported by the European Commission through the ERC Starting Grant 805031 (EPOQUE)
CFLAGS=-Wall -Wextra -Wpedantic -Werror -std=c99 -g $(EXTRAFLAGS)

ALL_SCHEMES=$(filter-out crypto_%.c, $(wildcard crypto_*/*))
COMMON_FILES = common/fips202.c common/sha2.c
RANDOM_IMPL = common/randombytes.c

default: help

.PHONY: require_scheme
require_scheme:
# assumes a SCHEME variable; e.g. make functest SCHEME=crypto_kem/kyber768
ifndef SCHEME
	$(error The SCHEME variable is not set. Example: SCHEME=crypto_kem/kyber768)
endif

bin/functest_$(subst /,_,$(SCHEME)): test/$(dir $(SCHEME))functest.c $(wildcard $(SCHEME)/clean/*.c) $(wildcard $(SCHEME)/clean/*.h) | require_scheme
	mkdir -p bin
	$(CC) $(CFLAGS) \
		-DPQCLEAN_NAMESPACE=$(shell echo PQCLEAN_$(subst -,,$(notdir $(SCHEME))) | tr a-z A-Z) \
		-iquote "./common/" \
		-iquote "$(SCHEME)/clean/" \
		-o bin/functest_$(subst /,_,$(SCHEME)) \
		$(SCHEME)/clean/*.c \
		$(COMMON_FILES) \
		$(RANDOM_IMPL) \
		$<

.PHONY: functest
functest: bin/functest_$(subst /,_,$(SCHEME))

.PHONY: run-functest
run-functest: bin/functest_$(subst /,_,$(SCHEME))
	./$<

.PHONY: run-valgrind
run-valgrind: bin/functest_$(subst /,_,$(SCHEME))
ifeq ($(shell uname -s),Linux)
	valgrind --leak-check=full --error-exitcode=1 $<
else
	@echo "Valgrind not supported on this platform."
endif

bin/sanitizer_$(subst /,_,$(SCHEME)): test/$(dir $(SCHEME))functest.c $(wildcard $(SCHEME)/clean/*.c) $(wildcard $(SCHEME)/clean/*.h) | require_scheme
	mkdir -p bin
	$(CC) $(CFLAGS) -fsanitize=address,undefined \
		-DPQCLEAN_NAMESPACE=$(shell echo PQCLEAN_$(subst -,,$(notdir $(SCHEME))) | tr a-z A-Z) \
		-iquote "./common/" \
		-iquote "$(SCHEME)/clean/" \
		-o bin/sanitizer_$(subst /,_,$(SCHEME)) \
		$(COMMON_FILES) \
		$(RANDOM_IMPL) \
		$(SCHEME)/clean/*.c \
		$<

.PHONY: sanitizer
sanitizer: bin/sanitizer_$(subst /,_,$(SCHEME))

bin/testvectors_$(subst /,_,$(SCHEME)): test/$(dir $(SCHEME))testvectors.c $(wildcard $(SCHEME)/clean/*.c) $(wildcard $(SCHEME)/clean/*.h) | require_scheme
	mkdir -p bin
	$(CC) $(CFLAGS) \
		-DPQCLEAN_NAMESPACE=$(shell echo PQCLEAN_$(subst -,,$(notdir $(SCHEME))) | tr a-z A-Z) \
		-iquote "./common/" \
		-iquote "$(SCHEME)/clean/" \
		-o bin/testvectors_$(subst /,_,$(SCHEME)) \
		$(COMMON_FILES) \
		common/notrandombytes.c \
		$(SCHEME)/clean/*.c \
		$<

.PHONY: testvectors
testvectors: bin/testvectors_$(subst /,_,$(SCHEME))

bin/shared_$(subst /,_,$(SCHEME))_clean.so: $(wildcard $(SCHEME)/clean/*.c) | require_scheme
	mkdir -p bin
	$(CC) $(CFLAGS) \
		-DPQCLEAN_NAMESPACE=$(shell echo PQCLEAN_$(subst -,,$(notdir $(SCHEME))) | tr a-z A-Z) \
		-nostdlib \
		-shared \
		-fPIC \
		-iquote "./common/" \
		-iquote "$(SCHEME)/clean/" \
		-o $@ \
		$^

.PHONY: clean
clean:
	rm -rf bin

.PHONY: format
format:
	find . -iname *.h -o -iname *.c | xargs clang-format -i -style=file

.PHONY: check-format
check-format:
	@for src in $(SOURCES) ; do \
		var=`clang-format "$(SRC_DIR)/$$src" | diff "$(SRC_DIR)/$$src" - | wc -l` ; \
		if [ $$var -ne 0 ] ; then \
			echo "$$src does not respect the coding style (diff: $$var lines)" ; \
			exit 1 ; \
		fi ; \
	done
	@echo "Style check passed"

.PHONY: tidy
tidy:
	$(MAKE) do-tidy

do-tidy: require_scheme
	clang-tidy \
		-quiet $(.TIDY_FIX) \
		$(SCHEME)/clean/*.c \
		common/*.c \
		-- -iquote "common/" -iquote "$(SCHEME)/clean"

.PHONY: apply-tidy
apply-tidy:
	$(MAKE) do-tidy .TIDY_FIX=-fix

# The below should be outlined with ts=8
.PHONY: help
help:
	@echo "make test-all				Run all tests"
	@echo "make functest SCHEME=scheme		Build functional tests for SCHEME"
	@echo "make functest-all			Build functional tests for all schemes"
	@echo "make run-functest SCHEME=scheme		Run functional tests for SCHEME"
	@echo "make run-functest-all			Run all functests"
	@echo "make run-testvectors SCHEME=scheme	Run testvector checks for SCHEME"
	@echo "make run-testvectors-all			Run all testvector checks"
	@echo "make run-sanitizer-all			Run address sanitizer for all schemes"
	@echo "make run-symbol-namespace SCHEME=scheme	Run symbol namespace checks for SCHEME"
	@echo "make run-symbol-namespace-all		Run all symbol namespace checks"
	@echo "make run-valgrind SCHEME=scheme		Run valgrind checks for SCHEME"
	@echo "make run-valgrind-all			Run valgrind checks all schemes"
	@echo "make clean				Clean up the bin/ folder"
	@echo "make format				Automatically formats all the source code"
	@echo "make tidy SCHEME=scheme  		Runs the clang-tidy linter against SCHEME"
	@echo "make apply-tidy SCHEME=scheme		Tries to automatically fix the issues found by clang-tidy in SCHEME"
	@echo "make tidy-all				Runs the clang-tidy linter against all schemes"
	@echo "make apply-tidy-all			Tidy up all schemes"
	@echo "make help				Displays this message"

.PHONY: functest-all
functest-all:
	@for scheme in $(ALL_SCHEMES); do \
	    $(MAKE) functest SCHEME=$$scheme || exit 1; \
	done

.PHONY: sanitizer-all
sanitizer-all:
	@for scheme in $(ALL_SCHEMES); do \
	    $(MAKE) sanitizer SCHEME=$$scheme || exit 1; \
	done

.PHONY: run-valgrind-all
run-valgrind-all:
	@for scheme in $(ALL_SCHEMES); do \
	    $(MAKE) run-valgrind SCHEME=$$scheme || exit 1; \
	done

.PHONY: run-testvectors
run-testvectors: test/check_tvectors.py | require_scheme
	python3 test/check_tvectors.py $(SCHEME) || exit 1; \

.PHONY: run-symbol-namespace
run-symbol-namespace: test/check_symbol_namespace.py | require_scheme
	python3 test/check_symbol_namespace.py $(SCHEME) || exit 1; \

.PHONY: run-testvectors-all
run-testvectors-all: test/check_tvectors.py
	@for scheme in $(ALL_SCHEMES); do \
	    python3 test/check_tvectors.py $$scheme || exit 1; \
	done

.PHONY: run-symbol-namespace-all
run-symbol-namespace-all:
	@for scheme in $(ALL_SCHEMES); do \
	    python3 test/check_symbol_namespace.py $$scheme || exit 1; \
	done

.PHONY: run-functest-all
run-functest-all: functest-all
	@for functest in $$(find bin/ -maxdepth 1 -name 'functest_*' -not -type d) ; do \
		echo ./$$functest ; \
		./$$functest || exit 1 ;\
	done
	@echo Tests completed

.PHONY: run-sanitizer-all
run-sanitizer-all: sanitizer-all
	@for sanitizer in $$(find bin/ -maxdepth 1 -name 'sanitizer_*' -not -type d) ; do \
		echo ./$$sanitizer ; \
		./$$sanitizer || exit 1 ;\
	done
	@echo Tests completed

.PHONY: check-license-files
check-license-files:
	@echo Checking that LICENSE files exist
	@for scheme in $(ALL_SCHEMES); do \
		echo Checking for  $$scheme/clean/LICENSE;\
		test -f $$scheme/clean/LICENSE || exit 1 ;\
	done

.PHONY: test-all
test-all: run-functest-all run-valgrind-all run-sanitizer-all run-testvectors-all run-symbol-namespace-all

.PHONY: tidy-all
tidy-all:
	@for scheme in $(ALL_SCHEMES); do \
		$(MAKE) tidy SCHEME=$$scheme || exit 1 ; \
	done

.PHONY: apply-tidy-all
apply-tidy-all:
	@for scheme in $(ALL_SCHEMES); do \
		$(MAKE) apply-tidy SCHEME=$$scheme; \
	done

.PHONY: check-metadata
check-metadata:
	python3 test/check_metadata.py
