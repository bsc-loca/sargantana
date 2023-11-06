



CC=~/sw/riscv-vector-toolchain/bin/riscv64-unknown-elf-gcc 
FLAGS= -static -mcmodel=medany \
    	-fvisibility=hidden -nostdlib -nostartfiles \
    	-march=rv64imav -mabi=lp64 -Tlinker.ld -I../../user_extension
OBJDUMP=~/sw/riscv-vector-toolchain/bin/riscv64-unknown-elf-objdump -D

app=base_vector_test

simplevector: base_vector_test.S 
	$(CC)  $(FLAGS) -o base_vector_test base_vector_test.S

objdump:
	$(OBJDUMP) $(app) > $(app).objdump 

hex: 
	#elf2hex --bit-width 128 --input $(app) --output $(app).hex
	elf2hex 16 32768 $(app) > $(app).hex

clean: 
	rm $(app) $(app).hex $(app).objdump

all: simplevector objdump hex
