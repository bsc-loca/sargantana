import cocotb
import random

from cocotb.triggers import Timer, FallingEdge, RisingEdge


async def gen_clock(dut):
    while True:
        dut.clk_i.value = 0
        await Timer(1, unit='ns')
        dut.clk_i.value = 1
        await Timer(1, unit='ns')


async def cycle(dut):
    await RisingEdge(dut.clk_i)


async def reset(dut):
    dut.rstn_i.value = 0
    dut.flush_i.value = 0
    dut.icache_valid_i.value = 0
    dut.f1_valid_i.value = 0
    dut.data_i.value = 0
    dut.addr_i.value = 0

    await Timer(5, unit='ns')

    dut.rstn_i.value = 1
    await cycle(dut)


async def send_fetch(dut, addr, data, ic_valid=1, f1_valid=1, flush=0):
    dut.addr_i.value = addr
    dut.data_i.value = data
    dut.icache_valid_i.value = ic_valid
    dut.f1_valid_i.value = f1_valid
    dut.flush_i.value = flush
    await cycle(dut)

async def invalidate_inputs(dut):
    dut.icache_valid_i.value = 0
    dut.f1_valid_i.value = 0
    await cycle(dut)

async def end_test():
    await Timer(5, unit='ns')

def check(dut, exp_valid, exp_data, exp_pc, exp_next=0):
    got_valid = int(dut.valid_o.value)
    got_data = int(dut.data_o.value)
    got_pc = int(dut.pc_o.value)
    got_next = int(dut.req_next_32b_o.value)

    assert got_valid == exp_valid, f"valid mismatch: DUT: {got_valid} != exp: {exp_valid}"

    if exp_valid:
        assert got_data == exp_data, f"data mismatch: DUT: {hex(got_data)} != exp: {hex(exp_data)}"
        assert got_pc == exp_pc, f"pc mismatch: DUT: {hex(got_pc)} != exp: {hex(exp_pc)}"
        assert got_next == exp_next, f"request next mismatch: DUT: {got_next} != exp: {exp_next}"

@cocotb.test()
async def test_aligned_32b(dut):
    cocotb.start_soon(gen_clock(dut))
    await reset(dut)

    addr = 0x80000000
    data = 0xDEADBEEF

    await send_fetch(dut, addr, data)

    check(dut, 1, 0xDEADBEEF, 0x80000000, exp_next=1)

    addr = 0x80000004
    data = 0xBEEFBEEF

    await send_fetch(dut, addr, data)

    check(dut, 1, 0xBEEFBEEF, 0x80000004, exp_next=1)

    await invalidate_inputs(dut)

    await end_test()

@cocotb.test()
async def test_aligned_16b(dut):
    cocotb.start_soon(gen_clock(dut))
    await reset(dut)

    addr = 0x80000000
    data = 0x12345678

    await send_fetch(dut, addr, data)

    check(dut, 1, 0x00005678, 0x80000000)

    await send_fetch(dut, addr, data)
    check(dut, 1, 0x00001234, 0x80000002, exp_next=1)

    addr = 0x80000004
    data = 0x43218765

    await send_fetch(dut, addr, data)

    check(dut, 1, 0x00008765, 0x80000004)

    await send_fetch(dut, addr, data)

    check(dut, 1, 0x00004321, 0x80000006, exp_next=1)

    await invalidate_inputs(dut)

    await end_test()

@cocotb.test()
async def test_one_unaligned(dut):
    cocotb.start_soon(gen_clock(dut))
    await reset(dut)

    addr = 0x80000000
    data = 0xBEEF5678

    await send_fetch(dut, addr, data)

    check(dut, 1, 0x00005678, 0x80000000)

    addr = 0x80000004
    data = 0x4321DEAD

    await send_fetch(dut, addr, data)

    check(dut, 1, 0xDEADBEEF, 0x80000002, exp_next=1)

    await send_fetch(dut, addr, data)

    check(dut, 1, 0x00004321, 0x80000006, exp_next=1)

    await invalidate_inputs(dut)

    await end_test()

@cocotb.test()
async def test_two_unaligned(dut):
    cocotb.start_soon(gen_clock(dut))
    await reset(dut)

    addr = 0x80000000
    data = 0xBEEF5678

    await send_fetch(dut, addr, data)

    check(dut, 1, 0x00005678, 0x80000000)

    addr = 0x80000004
    data = 0xB00BDEAD

    await send_fetch(dut, addr, data)

    check(dut, 1, 0xDEADBEEF, 0x80000002, exp_next=1)

    addr = 0x80000008
    data = 0x4321FACE

    await send_fetch(dut, addr, data)

    check(dut, 1, 0xFACEB00B, 0x80000006, exp_next=1)

    await send_fetch(dut, addr, data)
    
    check(dut, 1, 0x00004321, 0x8000000A, exp_next=1)

    await invalidate_inputs(dut)

    await end_test()

@cocotb.test()
async def test_one_unaligned_with_miss(dut):
    cocotb.start_soon(gen_clock(dut))
    await reset(dut)

    addr = 0x80000000
    data = 0xBEEF5678

    await send_fetch(dut, addr, data)

    check(dut, 1, 0x00005678, 0x80000000)

    for _ in range(5):
        await send_fetch(dut, addr, data, ic_valid=0)

        check(dut, 0, 0, 0x80000002, exp_next=1)

    addr = 0x80000004
    data = 0x4321DEAD

    await send_fetch(dut, addr, data)

    check(dut, 1, 0xDEADBEEF, 0x80000002, exp_next=1)

    await send_fetch(dut, addr, data)

    check(dut, 1, 0x00004321, 0x80000006, exp_next=1)

    await invalidate_inputs(dut)

    await end_test()
