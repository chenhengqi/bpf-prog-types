OUTPUT := .output
CLANG ?= clang
BPFTOOL ?= bpftool
LIBBPF_SRC := $(abspath ./libbpf/src)
LIBBPF_OBJ := $(abspath $(OUTPUT)/libbpf.a)
INCLUDES := -I$(OUTPUT) -I./libbpf/include/uapi -I./bpf
CFLAGS := -g -O2 -Wall
BPF_SRC := bpf
BPF_OBJ := $(patsubst $(BPF_SRC)/%.bpf.c,%.o,$(wildcard $(BPF_SRC)/*.bpf.c))
ARCH=x86

ifeq ($(V),1)
	Q =
	msg =
else
	Q = @
	msg = @printf '  %-8s %s%s\n' "$(1)" "$(notdir $(2))" "$(if $(3), $(3))";
	MAKEFLAGS += --no-print-directory
endif

APPS = \
	socket_filter \
	#

.PHONY: all
all: $(APPS)

.PHONY: clean
clean:
	$(call msg,CLEAN)
	$(Q)rm -rf $(OUTPUT)

$(OUTPUT) $(OUTPUT)/libbpf:
	$(call msg,MKDIR,$@)
	$(Q)mkdir -p $@

$(APPS): %: $(BPF_OBJ) | $(OUTPUT)
	$(call msg,BINARY,$@)
	$(Q)go build -ldflags="-X 'main.bpfObj=$(OUTPUT)/$@.o'"		\
		     -o $(OUTPUT)/$@ $@/main.go

$(BPF_OBJ): %.o: $(BPF_SRC)/%.bpf.c $(LIBBPF_OBJ) | $(OUTPUT)
	$(call msg,BPF,$@)
	$(Q)$(CLANG) $(CFLAGS) -target bpf -D__TARGET_ARCH_$(ARCH)	\
		     $(INCLUDES) -c $(filter %.c,$^) -o $(OUTPUT)/$@

$(LIBBPF_OBJ): $(wildcard $(LIBBPF_SRC)/*.[ch]) | $(OUTPUT)/libbpf
	$(call msg,LIB,$@)
	$(Q)$(MAKE) -C $(LIBBPF_SRC) BUILD_STATIC_ONLY=1		\
		    OBJDIR=$(dir $@)/libbpf DESTDIR=$(dir $@)		\
		    INCLUDEDIR= LIBDIR= UAPIDIR=			\
		    install

gen-vmlinux:
	$(call msg,VMLINUX)
	$(Q)$(BPFTOOL) btf dump file /sys/kernel/btf/vmlinux format c > bpf/vmlinux.h
