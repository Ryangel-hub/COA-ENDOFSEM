-- =============================================================================
-- File        : Instruction_Memory.vhd
-- Entity      : Instruction_Memory_VHDL
-- Description : 32-bit combinational instruction ROM (read-only).
--               - 1024 word capacity (4096 byte address space)
--               - Word-aligned: address bits [11:2] index the ROM
--               - Returns NOP (x"00000000") for out-of-range PC
--               - Pre-loaded with a small MIPS test program
--               - In synthesis, replace ROM initialisation with
--                 $readmemh() or BRAM primitives as needed
-- =============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Instruction_Memory_VHDL is
    port (
        pc          : in  std_logic_vector(31 downto 0);  -- Byte address (word-aligned)
        instruction : out std_logic_vector(31 downto 0)   -- 32-bit instruction word
    );
end entity Instruction_Memory_VHDL;

architecture Behavioral of Instruction_Memory_VHDL is

    constant ROM_DEPTH : integer := 1024;
    type rom_t is array (0 to ROM_DEPTH - 1) of std_logic_vector(31 downto 0);

    -- =========================================================================
    -- TEST PROGRAM — small MIPS routine exercising key instructions
    --
    -- Encoding reference (MIPS R-type): op(6) rs(5) rt(5) rd(5) shamt(5) funct(6)
    -- Encoding reference (MIPS I-type): op(6) rs(5) rt(5) imm(16)
    -- Encoding reference (MIPS J-type): op(6) target(26)
    --
    -- Register aliases used:
    --   $t0=8  $t1=9  $t2=10  $t3=11  $t4=12  $s0=16  $sp=29  $ra=31
    --
    -- Program:
    --   0x00: addi $t0, $zero, 10       -- $t0 = 10
    --   0x04: addi $t1, $zero, 20       -- $t1 = 20
    --   0x08: add  $t2, $t0, $t1        -- $t2 = $t0 + $t1 = 30
    --   0x0C: sub  $t3, $t1, $t0        -- $t3 = $t1 - $t0 = 10
    --   0x10: and  $t4, $t2, $t3        -- $t4 = $t2 & $t3
    --   0x14: or   $s0, $t2, $t3        -- $s0 = $t2 | $t3
    --   0x18: slt  $t0, $t0, $t1        -- $t0 = ($t0 < $t1) = 1
    --   0x1C: beq  $t0, $t0, +2         -- branch forward 2 instructions (to 0x28)
    --   0x20: addi $t0, $zero, 99       -- (skipped by branch)
    --   0x24: addi $t1, $zero, 99       -- (skipped by branch)
    --   0x28: sw   $t2, 0($zero)        -- MEM[0] = $t2
    --   0x2C: lw   $s0, 0($zero)        -- $s0 = MEM[0]
    --   0x30: j    0x00000034           -- jump to 0x34
    --   0x34: sll  $t0, $t0, 2          -- $t0 = $t0 << 2
    --   0x38: nop                       -- NOP (end of demo program)
    -- =========================================================================
    constant ROM : rom_t := (
        --  addi $t0, $zero, 10   →  op=001000 rs=00000 rt=01000 imm=0x000A
        0  => x"2008000A",
        --  addi $t1, $zero, 20   →  op=001000 rs=00000 rt=01001 imm=0x0014
        1  => x"20090014",
        --  add  $t2, $t0, $t1   →  op=000000 rs=01000 rt=01001 rd=01010 shamt=0 funct=100000
        2  => x"01095020",
        --  sub  $t3, $t1, $t0   →  op=000000 rs=01001 rt=01000 rd=01011 shamt=0 funct=100010
        3  => x"01285822",
        --  and  $t4, $t2, $t3   →  op=000000 rs=01010 rt=01011 rd=01100 shamt=0 funct=100100
        4  => x"014B6024",
        --  or   $s0, $t2, $t3   →  op=000000 rs=01010 rt=01011 rd=10000 shamt=0 funct=100101
        5  => x"014B8025",
        --  slt  $t0, $t0, $t1   →  op=000000 rs=01000 rt=01001 rd=01000 shamt=0 funct=101010
        6  => x"0109402A",
        --  beq  $t0, $t0, +2    →  op=000100 rs=01000 rt=01000 imm=0x0002
        7  => x"11080002",
        --  addi $t0, $zero, 99  →  (branch target skips these two)
        8  => x"20080063",
        --  addi $t1, $zero, 99
        9  => x"20090063",
        --  sw   $t2, 0($zero)   →  op=101011 rs=00000 rt=01010 imm=0x0000
        10 => x"AC0A0000",
        --  lw   $s0, 0($zero)   →  op=100011 rs=00000 rt=10000 imm=0x0000
        11 => x"8C100000",
        --  j    0x0000000D      →  op=000010 target=0x0000000D (word addr 13 = byte 0x34)
        12 => x"0800000D",
        --  sll  $t0, $t0, 2     →  op=000000 rs=00000 rt=01000 rd=01000 shamt=00010 funct=000000
        13 => x"00084080",
        --  nop
        14 => x"00000000",
        -- Remaining entries are NOP
        others => x"00000000"
    );

begin

    -- =========================================================================
    -- Combinational fetch:
    -- PC is a byte address; divide by 4 (shift right 2) to get word index.
    -- Bits [11:2] give a 10-bit index into the 1024-word ROM.
    -- =========================================================================
    fetch_proc : process(pc)
        variable word_idx : integer range 0 to ROM_DEPTH - 1;
    begin
        -- Check alignment and range
        if unsigned(pc) < to_unsigned(ROM_DEPTH * 4, 32) then
            word_idx    := to_integer(unsigned(pc(11 downto 2)));
            instruction <= ROM(word_idx);
        else
            instruction <= x"00000000";  -- NOP for out-of-range PC
        end if;
    end process fetch_proc;

end architecture Behavioral;
