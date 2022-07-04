INCLUDES=-Isrc/zlib -Isrc/common
OBJDIRS=obj obj/common obj/mng2avi
MD = @mkdir.exe
MNG2PNGS_OBJS=obj/common/logerror.o obj/common/rc.o obj/common/memwatch.o \
	obj/mng2pngs/mng2pngs.o obj/mng2pngs/config.o 
PNGS2VDB_OBJS=obj/common/rc.o obj/common/logerror.o obj/common/memwatch.o \
	obj/pngs2vdb/pngs2vdb.o obj/pngs2vdb/md5.o obj/pngs2vdb/config.o 
MNG2AVI_OBJS=obj/common/rc.o obj/mng2avi/config.o obj/mng2avi/mng2avi.o \
	obj/common/logerror.o obj/common/md5.o

all: maketree mng2avi.exe

mng2avi.exe: $(MNG2AVI_OBJS)
	gcc -o $@ $^ src/zlib/libz.a
obj/mng2pngs/%.o: src/mng2pngs/%.c src/common/options.h 
	gcc -c $< -o $@ $(INCLUDES)
obj/common/%.o: src/common/%.c 
	gcc -c $< -o $@ $(INCLUDES)
obj/pngs2vdb/%.o: src/pngs2vdb/%.c src/common/options.h
	gcc -c $< -o $@ $(INCLUDES)
obj/mng2avi/%.o: src/mng2avi/%.c src/common/options.h
	gcc -c $< -o $@ $(INCLUDES)

$(sort $(OBJDIRS)):
	$(MD) $@

maketree: $(sort $(OBJDIRS))

