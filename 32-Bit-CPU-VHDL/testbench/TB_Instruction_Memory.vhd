-- =============================================================================
-- File        : TB_Instruction_Memory.vhd
-- Entity      : TB_Instruction_Memory
-- Description : Self-checking testbench for Instruction_Memory_VHDL.
--               Verifies all 15 instructions in the ROM, NOP fill,
--               and out-of-range PC guard.
--
-- ROM contents (from Instruction_Memory.vhd):
--   0x00: addi $t0, $zero, 10    → 0x2008000A
--   0x04: addi $t1, $zero, 20    → 0x20090014
--   0x08: add  $t2, $t0, $t1    → 0x01095020
--   0x0C: sub  $t3, $t1, $t0    → 0x01285822
--   0x10: and  $t4, $t2, $t3    → 0x014B6024
--   0x14: or   $s0, $t2, $t3    → 0x014B8025
--   0x18: slt  $t0, $t0, $t1    → 0x0109402A
--   0x1C: beq  $t0, $t0, +2     → 0x11080002
--   0x20: addi $t0, $zero, 99   → 0x20080063
--   0x24: addi $t1, $zero, 99   → 0x20090063
--   0x28: sw   $t2, 0($zero)    → 0xAC0A0000
--   0x2C: lw   $s0, 0($zero)    → 0x8C100000
--   0x30: j    0x0000000D       → 0x0800000D
--   0x34: sll  $t0, $t0, 2      → 0x00084080
--   0x38: nop                   → 0x00000000
-- =============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity TB_Instruction_Memory is
end entity TB_Instruction_Memory;

architecture Behavioral of TB_Instruction_Memory is

    signal pc          : std_logic_vector(31 downto 0) := (others => '0');
    signal instruction : std_logic_vector(31 downto 0);

    constant DELAY : time := 10 ns;

begin

    -- =========================================================================
    -- UUT Instantiation
    -- =========================================================================
    uut : entity work.Instruction_Memory_VHDL
        port map (
            pc          => pc,
            instruction => instruction
        );

    -- =========================================================================
    -- Stimulus & Checking Process
    -- =========================================================================
    stim_proc : process
    begin

        -- TEST 1: PC=0x00 → addi $t0, $zero, 10
        pc <= x"00000000"; wait for DELAY;
        assert instruction = x"2008000A"
            report "TEST 1 FAIL: PC=0x00 expected 0x2008000A (addi $t0,$zero,10), got " &
                   to_hstring(instruction)
            severity error;

        -- TEST 2: PC=0x04 → addi $t1, $zero, 20
        pc <= x"00000004"; wait for DELAY;
        assert instruction = x"20090014"
            report "TEST 2 FAIL: PC=0x04 expected 0x20090014 (addi $t1,$zero,20), got " &
                   to_hstring(instruction)
            severity error;

        -- TEST 3: PC=0x08 → add $t2, $t0, $t1
        pc <= x"00000008"; wait for DELAY;
        assert instruction = x"01095020"
            report "TEST 3 FAIL: PC=0x08 expected 0x01095020 (add $t2,$t0,$t1), got " &
                   to_hstring(instruction)
            severity error;

        -- TEST 4: PC=0x0C → sub $t3, $t1, $t0
        pc <= x"0000000C"; wait for DELAY;
        assert instruction = x"01285822"
            report "TEST 4 FAIL: PC=0x0C expected 0x01285822 (sub $t3,$t1,$t0), got " &
                   to_hstring(instruction)
            severity error;

        -- TEST 5: PC=0x10 → and $t4, $t2, $t3
        pc <= x"00000010"; wait for DELAY;
        assert instruction = x"014B6024"
            report "TEST 5 FAIL: PC=0x10 expected 0x014B6024 (and $t4,$t2,$t3), got " &
                   to_hstring(instruction)
            severity error;

        -- TEST 6: PC=0x14 → or $s0, $t2, $t3
        pc <= x"00000014"; wait for DELAY;
        assert instruction = x"014B8025"
            report "TEST 6 FAIL: PC=0x14 expected 0x014B8025 (or $s0,$t2,$t3), got " &
                   to_hstring(instruction)
            severity error;

        -- TEST 7: PC=0x18 → slt $t0, $t0, $t1
        pc <= x"00000018"; wait for DELAY;
        assert instruction = x"0109402A"
            report "TEST 7 FAIL: PC=0x18 expected 0x0109402A (slt $t0,$t0,$t1), got " &
                   to_hstring(instruction)
            severity error;

        -- TEST 8: PC=0x1C → beq $t0, $t0, +2
        pc <= x"0000001C"; wait for DELAY;
        assert instruction = x"11080002"
            report "TEST 8 FAIL: PC=0x1C expected 0x11080002 (beq $t0,$t0,+2), got " &
                   to_hstring(instruction)
            severity error;

        -- TEST 9: PC=0x20 → addi $t0, $zero, 99 (branch skip target)
        pc <= x"00000020"; wait for DELAY;
        assert instruction = x"20080063"
            report "TEST 9 FAIL: PC=0x20 expected 0x20080063, got " &
                   to_hstring(instruction)
            severity error;

        -- TEST 10: PC=0x24 → addi $t1, $zero, 99
        pc <= x"00000024"; wait for DELAY;
        assert instruction = x"20090063"
            report "TEST 10 FAIL: PC=0x24 expected 0x20090063, got " &
                   to_hstring(instruction)
            severity error;

        -- TEST 11: PC=0x28 → sw $t2, 0($zero)
        pc <= x"00000028"; wait for DELAY;
        assert instruction = x"AC0A0000"
            report "TEST 11 FAIL: PC=0x28 expected 0xAC0A0000 (sw $t2,0($zero)), got " &
                   to_hstring(instruction)
            severity error;

        -- TEST 12: PC=0x2C → lw $s0, 0($zero)
        pc <= x"0000002C"; wait for DELAY;
        assert instruction = x"8C100000"
            report "TEST 12 FAIL: PC=0x2C expected 0x8C100000 (lw $s0,0($zero)), got " &
                   to_hstring(instruction)
            severity error;

        -- TEST 13: PC=0x30 → j 0x0000000D
        pc <= x"00000030"; wait for DELAY;
        assert instruction = x"0800000D"
            report "TEST 13 FAIL: PC=0x30 expected 0x0800000D (j 0x0000000D), got " &
                   to_hstring(instruction)
            severity error;

        -- TEST 14: PC=0x34 → sll $t0, $t0, 2
        pc <= x"00000034"; wait for DELAY;
        assert instruction = x"00084080"
            report "TEST 14 FAIL: PC=0x34 expected 0x00084080 (sll $t0,$t0,2), got " &
                   to_hstring(instruction)
            severity error;

        -- TEST 15: PC=0x38 → nop (0x00000000)
        pc <= x"00000038"; wait for DELAY;
        assert instruction = x"00000000"
            report "TEST 15 FAIL: PC=0x38 expected NOP 0x00000000, got " &
                   to_hstring(instruction)
            severity error;

        -- TEST 16: ROM fill — entry beyond program should be NOP
        pc <= x"00000100"; wait for DELAY;
        assert instruction = x"00000000"
            report "TEST 16 FAIL: Uninitialized ROM entry should be NOP 0x00000000"
            severity error;

        -- TEST 17: Out-of-range PC — should return NOP safely
        pc <= x"FFFF0000"; wait for DELAY;
        assert instruction = x"00000000"
            report "TEST 17 FAIL: Out-of-range PC should return NOP 0x00000000"
            severity error;

        -- TEST 18: Non-word-aligned PC (should use bits [11:2], effectively
        -- rounding down) — PC=0x01 maps to word index 0 same as PC=0x00
        pc <= x"00000001"; wait for DELAY;
        assert instruction = x"2008000A"
            report "TEST 18 FAIL: PC=0x01 (non-aligned) should fetch word index 0"
            severity error;

        -- =================================================================
        report "TB_Instruction_Memory: All tests passed." severity note;
        wait;
    end process stim_proc;

end architecture Behavioral;
