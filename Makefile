PKG_DESCRIPTION = 'RocketChat protocol plugin for libpurple'
PKG_DEB_NAME = 'pidgin-rocketchat'
PKG_RPM_NAME = 'purple-rocketchat'

PIDGIN_TREE_TOP ?= ../pidgin-2.10.11
PIDGIN3_TREE_TOP ?= ../pidgin-main
LIBPURPLE_DIR ?= $(PIDGIN_TREE_TOP)/libpurple
WIN32_DEV_TOP ?= $(PIDGIN_TREE_TOP)/../win32-dev

WIN32_CC ?= $(WIN32_DEV_TOP)/mingw-4.7.2/bin/gcc

PROTOC_C ?= protoc-c
PKG_CONFIG ?= pkg-config

DIR_PERM = 0755
LIB_PERM = 0755
FILE_PERM = 0644

REVISION_ID = $(shell hg id -i)
REVISION_NUMBER = $(shell hg id -n)
ifneq ($(REVISION_ID),)
PLUGIN_VERSION ?= 0.9.$(shell date +%Y.%m.%d).git.r$(REVISION_NUMBER).$(REVISION_ID)
else
PLUGIN_VERSION ?= 0.9.$(shell date +%Y.%m.%d)
endif

GIT_COMMIT = $(shell git log -1 --pretty='format:%h')
ifneq ($(GIT_COMMIT),)
PLUGIN_VERSION = 0.9.$(shell date +%Y.%m.%d).git.$(GIT_COMMIT)
endif

CFLAGS	?= -O2 -g -pipe -Wall -DROCKETCHAT_PLUGIN_VERSION='"$(PLUGIN_VERSION)"'
LDFLAGS ?= -Wl,-z,relro 

# Do some nasty OS and purple version detection
ifeq ($(OS),Windows_NT)
  ROCKETCHAT_TARGET = librocketchat.dll
  ROCKETCHAT_DEST = "$(PROGRAMFILES)/Pidgin/plugins"
  ROCKETCHAT_ICONS_DEST = "$(PROGRAMFILES)/Pidgin/pixmaps/pidgin/protocols"
else

  UNAME_S := $(shell uname -s)

  #.. There are special flags we need for OSX
  ifeq ($(UNAME_S), Darwin)
    #
    #.. /opt/local/include and subdirs are included here to ensure this compiles
    #   for folks using Macports.  I believe Homebrew uses /usr/local/include
    #   so things should "just work".  You *must* make sure your packages are
    #   all up to date or you will most likely get compilation errors.
    #
    INCLUDES = -I/opt/local/include -lz $(OS)

    CC = gcc
  else
    CC ?= gcc
  endif

  ifeq ($(shell $(PKG_CONFIG) --exists purple-3 2>/dev/null && echo "true"),)
    ifeq ($(shell $(PKG_CONFIG) --exists purple 2>/dev/null && echo "true"),)
      ROCKETCHAT_TARGET = FAILNOPURPLE
      ROCKETCHAT_DEST =
	  ROCKETCHAT_ICONS_DEST =
    else
      ROCKETCHAT_TARGET = librocketchat.so
      ROCKETCHAT_DEST = $(DESTDIR)`$(PKG_CONFIG) --variable=plugindir purple`
	  ROCKETCHAT_ICONS_DEST = $(DESTDIR)`$(PKG_CONFIG) --variable=datadir purple`/pixmaps/pidgin/protocols
    endif
  else
    ROCKETCHAT_TARGET = librocketchat3.so
    ROCKETCHAT_DEST = $(DESTDIR)`$(PKG_CONFIG) --variable=plugindir purple-3`
	ROCKETCHAT_ICONS_DEST = $(DESTDIR)`$(PKG_CONFIG) --variable=datadir purple-3`/pixmaps/pidgin/protocols
  endif
endif

WIN32_CFLAGS = -I$(WIN32_DEV_TOP)/glib-2.28.8/include -I$(WIN32_DEV_TOP)/glib-2.28.8/include/glib-2.0 -I$(WIN32_DEV_TOP)/glib-2.28.8/lib/glib-2.0/include -I$(WIN32_DEV_TOP)/json-glib-0.14/include/json-glib-1.0 -I$(WIN32_DEV_TOP)/discount-2.2.1 -DENABLE_NLS -DROCKETCHAT_PLUGIN_VERSION='"$(PLUGIN_VERSION)"' -Wall -Wextra -Werror -Wno-deprecated-declarations -Wno-unused-parameter -fno-strict-aliasing -Wformat
WIN32_LDFLAGS = -L$(WIN32_DEV_TOP)/glib-2.28.8/lib -L$(WIN32_DEV_TOP)/json-glib-0.14/lib -lpurple -lintl -lglib-2.0 -lgobject-2.0 -ljson-glib-1.0 -g -ggdb -static-libgcc -lz -L$(WIN32_DEV_TOP)/discount-2.2.1 -lmarkdown
WIN32_PIDGIN2_CFLAGS = -I$(PIDGIN_TREE_TOP)/libpurple -I$(PIDGIN_TREE_TOP) $(WIN32_CFLAGS)
WIN32_PIDGIN3_CFLAGS = -I$(PIDGIN3_TREE_TOP)/libpurple -I$(PIDGIN3_TREE_TOP) -I$(WIN32_DEV_TOP)/gplugin-dev/gplugin $(WIN32_CFLAGS)
WIN32_PIDGIN2_LDFLAGS = -L$(PIDGIN_TREE_TOP)/libpurple $(WIN32_LDFLAGS)
WIN32_PIDGIN3_LDFLAGS = -L$(PIDGIN3_TREE_TOP)/libpurple -L$(WIN32_DEV_TOP)/gplugin-dev/gplugin $(WIN32_LDFLAGS) -lgplugin

C_FILES := 
PURPLE_COMPAT_FILES := 
PURPLE_C_FILES := librocketchat.c $(C_FILES)



.PHONY:	all install FAILNOPURPLE clean install-icons deb rpm checkpackaging

all: $(ROCKETCHAT_TARGET)

librocketchat.so: $(PURPLE_C_FILES) $(PURPLE_COMPAT_FILES)
	$(CC) -fPIC $(CFLAGS) -shared -o $@ $^ $(LDFLAGS) `$(PKG_CONFIG) purple glib-2.0 json-glib-1.0 --libs --cflags`  $(INCLUDES) -Ipurple2compat -g -ggdb -lmarkdown

librocketchat3.so: $(PURPLE_C_FILES)
	$(CC) -fPIC $(CFLAGS) -shared -o $@ $^ $(LDFLAGS) `$(PKG_CONFIG) purple-3 glib-2.0 json-glib-1.0 --libs --cflags` $(INCLUDES)  -g -ggdb -lmarkdown

librocketchat.dll: $(PURPLE_C_FILES) $(PURPLE_COMPAT_FILES)
	$(WIN32_CC) -O0 -g -ggdb -shared -o $@ $^ $(WIN32_PIDGIN2_CFLAGS) $(WIN32_PIDGIN2_LDFLAGS) -Ipurple2compat

librocketchat3.dll: $(PURPLE_C_FILES) $(PURPLE_COMPAT_FILES)
	$(WIN32_CC) -O0 -g -ggdb -shared -o $@ $^ $(WIN32_PIDGIN3_CFLAGS) $(WIN32_PIDGIN3_LDFLAGS)

install: $(ROCKETCHAT_TARGET) install-icons
	mkdir -m $(DIR_PERM) -p $(ROCKETCHAT_DEST)
	install -m $(LIB_PERM) -p $(ROCKETCHAT_TARGET) $(ROCKETCHAT_DEST)

install-icons: rocketchat16.png rocketchat22.png rocketchat48.png
	mkdir -m $(DIR_PERM) -p $(ROCKETCHAT_ICONS_DEST)/16
	mkdir -m $(DIR_PERM) -p $(ROCKETCHAT_ICONS_DEST)/22
	mkdir -m $(DIR_PERM) -p $(ROCKETCHAT_ICONS_DEST)/48
	install -m $(FILE_PERM) -p rocketchat16.png $(ROCKETCHAT_ICONS_DEST)/16/rocketchat.png
	install -m $(FILE_PERM) -p rocketchat22.png $(ROCKETCHAT_ICONS_DEST)/22/rocketchat.png
	install -m $(FILE_PERM) -p rocketchat48.png $(ROCKETCHAT_ICONS_DEST)/48/rocketchat.png

# Requires FPM: https://github.com/jordansissel/fpm
# Use a temp DESTDIR target, no sudo required: make DESTDIR=/tmp/pluginpackage deb
deb: checkpackaging install
	fpm -s dir -t deb -n $(PKG_DEB_NAME) -v $(PLUGIN_VERSION) -C $(DESTDIR) \
	    -d libpurple0 -d libglib2.0-0 -d libjson-glib-1.0-0 -d libmarkdown2 \
	    --description $(PKG_DESCRIPTION)

# Requires FPM: https://github.com/jordansissel/fpm
# Use a temp DESTDIR target, no sudo required: make DESTDIR=/tmp/pluginpackage rpm
rpm: checkpackaging install
	fpm -s dir -t rpm -n $(PKG_RPM_NAME) -v $(PLUGIN_VERSION) -C $(DESTDIR) \
	    -d libpurple -d glib2 -d json-glib -d libmarkdown2
	    --description $(PKG_DESCRIPTION)

checkpackaging:
ifeq ($(DESTDIR),)
	@echo " *** ERROR: to build packages, use a temp DESTDIR target, no sudo required:"
	@echo " ***        make DESTDIR=/tmp/pluginpackage ..."
	@exit 1
endif

FAILNOPURPLE:
	echo "You need libpurple development headers installed to be able to compile this plugin"

clean:
	rm -f $(ROCKETCHAT_TARGET) 

