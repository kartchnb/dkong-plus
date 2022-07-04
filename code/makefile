# Compiler flags
ASM_DIR =               ../tasm
ASM =                   wine $(ASM_DIR)/tasm.exe
OPT =                   -c -b -fFF -g3 -t80 -l

#Environmental variables
TASMTABS =              $(ASM_DIR)

SPLIT =                 4096

BIN_DIR =		bin
ROM_DIR	= 		../MAME/roms/dkong
DKONG =                 dkong
LST =                   $(BIN_DIR)/$(DKONG).lst
SRC =                   $(DKONG).asm
BIN =                   $(BIN_DIR)/$(DKONG).bin
BIN1 =			c_5et_g.bin
BIN2 = 			c_5ct_g.bin
BIN3 = 			c_5bt_g.bin
BIN4 = 			c_5at_g.bin
ORG_BIN =		$(BIN_DIR)/$(DKONG).org.bin

$(BIN): $(SRC)
	export TASMTABS=../tasm
	$(ASM) $(OPT) $(SRC) $(BIN)
	
clean:	
	rm -f $(BIN) $(LST)
	
combine: 
	cat $(BIN_DIR)/$(BIN1) $(BIN_DIR)/$(BIN2) $(BIN_DIR)/$(BIN3) $(BIN_DIR)/$(BIN4) > $(BIN)
	
split:  $(BIN)
	split -b $(SPLIT) $(BIN)
	rm $(BIN_DIR)/$(BIN1)
	rm $(BIN_DIR)/$(BIN2)
	rm $(BIN_DIR)/$(BIN3)
	rm $(BIN_DIR)/$(BIN4)
	mv xaa $(BIN_DIR)/$(BIN1)
	mv xab $(BIN_DIR)/$(BIN2)
	mv xac $(BIN_DIR)/$(BIN3)
	mv xad $(BIN_DIR)/$(BIN4)

diff: $(BIN)
	cmp -l $(BIN) $(ORG_BIN)
        
install: split
	rm $(ROM_DIR)/$(BIN1)
	rm $(ROM_DIR)/$(BIN2)
	rm $(ROM_DIR)/$(BIN3)
	rm $(ROM_DIR)/$(BIN4)
	cp $(BIN_DIR)/$(BIN1) $(ROM_DIR)
	cp $(BIN_DIR)/$(BIN2) $(ROM_DIR)
	cp $(BIN_DIR)/$(BIN3) $(ROM_DIR)
	cp $(BIN_DIR)/$(BIN4) $(ROM_DIR)
