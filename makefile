# =========================== Paths & tools ===========================
CMPUT429DIR ?= /cshome/cmput429
HIP_PATH    ?= $(CMPUT429DIR)/TheRock/build
HIPCC       ?= $(HIP_PATH)/bin/hipcc
A5GEM_PATH    ?= $(CMPUT429DIR)/429-resources/gem5
GEM5GPU     ?= $(A5GEM_PATH)/build/VEGA_X86/gem5.fast

# =========================== Sim config ==============================
PYTHON_CONFIG = $(A5GEM_PATH)/configs/example/gpufs/mi200.py
#DISK_IMAGE    = $(CMPUT429DIR)/gem5-resources/src/x86-ubuntu-gpu-ml/disk-image/x86-ubuntu-gpu-ml
#KERNEL        = $(CMPUT429DIR)/gem5-resources/src/x86-ubuntu-gpu-ml/vmlinux-gpu-ml
DISK_IMAGE    = $(CMPUT429DIR)/x86-ubuntu-gpu.gz
KERNEL        = $(CMPUT429DIR)/linux-vm-kernel-gpu.gz
#KERNEL        = $(CMPUT429DIR)/429-resources/benchmarks/429bin/gpufs-kernel
COMMON_OPTS   = --disk-image $(DISK_IMAGE) --kernel $(KERNEL)

# =========================== Dirs & discovery ========================
SRC_DIRS ?= thread-divergence memory-coalesing
BIN_DIR ?= bin
SIMS_DIR ?= sims

SRCS := $(foreach d,$(SRC_DIRS),$(wildcard $(d)/*.hip))
APPS := $(basename $(notdir $(SRCS)))
BINS := $(addprefix $(BIN_DIR)/,$(APPS))
SIMS_DONE := $(addprefix $(SIMS_DIR)/,$(addsuffix /.done,$(APPS)))

VPATH := $(SRC_DIRS)

# =========================== Architecture ===========================
OFFLOAD_ARCHS ?= gfx942 gfx90a
OFFLOAD_FLAGS := $(foreach a,$(OFFLOAD_ARCHS),--offload-arch=$(a))

# =========================== Build flags =============================
CXXFLAGS := -x hip \
            -I$(A5GEM_PATH)/include \
            -I$(A5GEM_PATH)/util/m5/src \
            -I$(A5GEM_PATH) \
            $(OFFLOAD_FLAGS) \
            -fno-unroll-loops \
            -DGPUFS \
            -O1

# Avoid PIE when linking with non-PIC libm5.a
LDFLAGS  := -L$(A5GEM_PATH)/util/m5/build/x86/out -lm5 -Wl,-no-pie

# =========================== Phony ==============================
.PHONY: all build run clean clean_bins clean_sims run-%

# Default: build & simulate everything
all: $(SIMS_DONE)

# Build only
build: $(BINS)

# Simulate everything (alias)
run: $(SIMS_DONE)

# =========================== Compile =============================
$(BIN_DIR)/%: %.hip | $(BIN_DIR)
	$(HIPCC) $(CXXFLAGS) $< -o $@ $(LDFLAGS)

$(BIN_DIR):
	mkdir -p $@

# =========================== Simulate ============================
# sims/<app>/.done depends on bin/<app>
$(SIMS_DIR)/%/.done: $(BIN_DIR)/%
	mkdir -p $(@D)
	$(GEM5GPU) -d $(@D) $(PYTHON_CONFIG) $(COMMON_OPTS) --app $<
	@touch $@

# Run a single app: make run-<app>
run-%: $(SIMS_DIR)/%/.done

# =========================== Clean ===============================
clean: clean_bins clean_sims

clean_bins:
	rm -rf $(BIN_DIR)

clean_sims:
	rm -rf $(SIMS_DIR)
