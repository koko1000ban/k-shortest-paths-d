# build mode: 32bit or 64bit
ifeq (,$(MODEL))
	MODEL := 32
endif

ifeq (,$(DMD))
	DMD := dmd
endif

LIB     = libproto3.a
DFLAGS  = -Isrc -m$(MODEL) -w -d -property

ifeq ($(BUILD),debug)
	DFLAGS += -g -debug
else
	DFLAGS += -O -release -nofloat -inline
endif

# NAMES = $(wildcard src/*)
NAMES = engine graph
FILES = $(addsuffix .d, $(NAMES))
SRCS  = $(addprefix src/, $(FILES))
BUILD_DIR = build

$(LIB):
	$(DMD) $(DFLAGS) -lib -of$(LIB) -od$(BUILD_DIR) $(SRCS)

clean:
	rm -rf $(BUILD_DIR)

MAIN_FILE=test/empty.d
check:
	echo 'import engine; void main(){}' > $(MAIN_FILE)
	$(DMD) $(DFLAGS) -unittest -of$(LIB) -od$(BUILD_DIR) $(SRCS) -run $(MAIN_FILE)
	rm $(MAIN_FILE)
