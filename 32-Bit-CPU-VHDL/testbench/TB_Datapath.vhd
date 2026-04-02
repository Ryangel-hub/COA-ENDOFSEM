-- =============================================================================
-- File        : TB_Datapath.vhd
-- Entity      : TB_Datapath
-- Description : End-to-end self-checking testbench for MIPS_Datapath.
--               Runs the built-in ROM test program and verifies:
--                 - PC advances correctly each cycle
--                 - ALU results are correct
--                 - Register write-back values are correct
--                 - Branch is taken/not taken correctly
--                 - Jump redirects PC correctly
--                 - Memory store/load round-trips correctly
--
-- ROM program summary (from Instruction_Memory.vhd):
--   Cycle 1  PC=0x00: addi $t0, $zero, 10    → $t0=10
--   Cycle 2  PC=0x04: addi $t1, $zero, 20    → $t1=20
--   Cycle 3  PC=0x08: add  $t2, $t0, $t1    → $t2=30
--   Cycle 4  PC=0x0C: sub  $t3, $t1, $t0    → $t3=10
--   Cycle 5  PC=0x10: and  $t4, $t2, $t3    → $t4=30 AND 10=10
--   Cycle 6  PC=0x14: or   $s0, $t2, $t3    → $s0=30 OR 10=30
--   Cycle 7  PC=0x18: slt  $t0, $t0, $t1    → $t0=1 (10<20)
--   Cycle 8  PC=0x1C: beq  $t0,$t0,+2      → branch taken → PC=0x28
--   Cycle 9  PC=0x28: sw   $t2, 0($zero)   → MEM[0]=$t2=30
--   Cycle 10 PC=0x2C: lw   $s0, 0($zero)   → $s0=MEM[0]=30
--   Cycle 11 PC=0x30: j 0x0000000D         → PC=0x34
--   Cycle 12 PC=0x34: sll $t0,$t0,2        → $t0=1<<2=4
-- =============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity TB_Datapath is
end entity TB_Datapath;

architecture Behavioral of TB_Datapath is

    constant CLK_PERIOD : time := 10 ns;

    signal clk               : std_logic := '0';
    signal rst               : std_logic := '1';

    -- All observation ports from new MIPS_Datapath
    signal tb_pc             : std_logic_vector(31 downto 0);
    signal tb_instruction    : std_logic_vector(31 downto 0);
    signal tb_alu_result     : std_logic_vector(31 downto 0);
    signal tb_reg_write_data : std_logic_vector(31 downto 0);
    signal tb_reg_write_dest : std_logic_vector(4  downto 0);
    signal tb_reg_write_en   : std_logic;
    signal tb_mem_read_data  : std_logic_vector(31 downto 0);
    signal tb_branch_taken   : std_logic;
    signal tb_dbg_regs       : std_logic_vector(32*32-1 downto 0);

    -- Helper to extract a register from the debug vector
    function get_reg(dbg : std_logic_vector(32*32-1 downto 0); idx : integer)
        return std_logic_vector is
    begin
        return dbg((idx+1)*32-1 downto idx*32);
    end function;

begin

    -- =========================================================================
    -- UUT Instantiation
    -- =========================================================================
    uut : entity work.MIPS_Datapath
        port map (
            clk               => clk,
            rst               => rst,
            tb_pc             => tb_pc,
            tb_instruction    => tb_instruction,
            tb_alu_result     => tb_alu_result,
            tb_reg_write_data => tb_reg_write_data,
            tb_reg_write_dest => tb_reg_write_dest,
            tb_reg_write_en   => tb_reg_write_en,
            tb_mem_read_data  => tb_mem_read_data,
            tb_branch_taken   => tb_branch_taken,
            tb_dbg_regs       => tb_dbg_regs
        );

    -- =========================================================================
    -- Clock Generator — free-running
    -- =========================================================================
    clk_gen : process
    begin
        loop
            clk <= '0'; wait for CLK_PERIOD / 2;
            clk <= '1'; wait for CLK_PERIOD / 2;
        end loop;
    end process clk_gen;

    -- =========================================================================
    -- Stimulus & Checking Process
    -- =========================================================================
    stim_proc : process
    begin

        -- Hold reset for 2 cycles
        rst <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        rst <= '0';
        wait for 2 ns;   -- let combinational logic settle after reset release

        -- =================================================================
        -- CYCLE 1 — PC=0x00: addi $t0, $zero, 10  → $t0=10 (reg 8)
        -- =================================================================
        assert tb_pc = x"00000000"
            report "CYC1 FAIL: Expected PC=0x00000000, got " & to_hstring(tb_pc)
            severity error;
        assert tb_instruction = x"2008000A"
            report "CYC1 FAIL: Expected instr=0x2008000A (addi $t0,$zero,10)"
            severity error;
        assert tb_alu_result = x"0000000A"
            report "CYC1 FAIL: ALU result expected 10 (0x0000000A), got " &
                   to_hstring(tb_alu_result)
            severity error;
        assert tb_reg_write_dest = "01000"   -- $t0 = reg 8
            report "CYC1 FAIL: Write dest expected reg 8 ($t0)"
            severity error;
        assert tb_reg_write_data = x"0000000A"
            report "CYC1 FAIL: Write data expected 0x0000000A"
            severity error;
        assert tb_reg_write_en = '1'
            report "CYC1 FAIL: reg_write_en should be 1"
            severity error;
        assert tb_branch_taken = '0'
            report "CYC1 FAIL: branch_taken should be 0"
            severity error;

        wait until rising_edge(clk);
        wait for 2 ns;

        -- =================================================================
        -- CYCLE 2 — PC=0x04: addi $t1, $zero, 20  → $t1=20 (reg 9)
        -- =================================================================
        assert tb_pc = x"00000004"
            report "CYC2 FAIL: Expected PC=0x00000004, got " & to_hstring(tb_pc)
            severity error;
        assert tb_alu_result = x"00000014"
            report "CYC2 FAIL: ALU result expected 20 (0x00000014), got " &
                   to_hstring(tb_alu_result)
            severity error;
        assert tb_reg_write_dest = "01001"   -- $t1 = reg 9
            report "CYC2 FAIL: Write dest expected reg 9 ($t1)"
            severity error;
        assert tb_reg_write_data = x"00000014"
            report "CYC2 FAIL: Write data expected 0x00000014"
            severity error;

        wait until rising_edge(clk);
        wait for 2 ns;

        -- =================================================================
        -- CYCLE 3 — PC=0x08: add $t2, $t0, $t1   → $t2=30 (reg 10)
        -- $t0=10, $t1=20, result=30=0x1E
        -- =================================================================
        assert tb_pc = x"00000008"
            report "CYC3 FAIL: Expected PC=0x00000008, got " & to_hstring(tb_pc)
            severity error;
        assert tb_alu_result = x"0000001E"
            report "CYC3 FAIL: ADD 10+20 expected 30 (0x0000001E), got " &
                   to_hstring(tb_alu_result)
            severity error;
        assert tb_reg_write_dest = "01010"   -- $t2 = reg 10
            report "CYC3 FAIL: Write dest expected reg 10 ($t2)"
            severity error;
        assert tb_reg_write_data = x"0000001E"
            report "CYC3 FAIL: Write data expected 0x0000001E (30)"
            severity error;

        wait until rising_edge(clk);
        wait for 2 ns;

        -- =================================================================
        -- CYCLE 4 — PC=0x0C: sub $t3, $t1, $t0   → $t3=10 (reg 11)
        -- $t1=20, $t0=10, result=10=0x0A
        -- =================================================================
        assert tb_pc = x"0000000C"
            report "CYC4 FAIL: Expected PC=0x0000000C, got " & to_hstring(tb_pc)
            severity error;
        assert tb_alu_result = x"0000000A"
            report "CYC4 FAIL: SUB 20-10 expected 10 (0x0000000A), got " &
                   to_hstring(tb_alu_result)
            severity error;
        assert tb_reg_write_dest = "01011"   -- $t3 = reg 11
            report "CYC4 FAIL: Write dest expected reg 11 ($t3)"
            severity error;

        wait until rising_edge(clk);
        wait for 2 ns;

        -- =================================================================
        -- CYCLE 5 — PC=0x10: and $t4, $t2, $t3   → $t4=30 AND 10=10 (reg 12)
        -- 30=0x1E=00011110, 10=0x0A=00001010, AND=00001010=10
        -- =================================================================
        assert tb_pc = x"00000010"
            report "CYC5 FAIL: Expected PC=0x00000010, got " & to_hstring(tb_pc)
            severity error;
        assert tb_alu_result = x"0000000A"
            report "CYC5 FAIL: AND 30&10 expected 10 (0x0000000A), got " &
                   to_hstring(tb_alu_result)
            severity error;
        assert tb_reg_write_dest = "01100"   -- $t4 = reg 12
            report "CYC5 FAIL: Write dest expected reg 12 ($t4)"
            severity error;

        wait until rising_edge(clk);
        wait for 2 ns;

        -- =================================================================
        -- CYCLE 6 — PC=0x14: or $s0, $t2, $t3    → $s0=30 OR 10=30 (reg 16)
        -- 0x1E OR 0x0A = 0x1E = 30
        -- =================================================================
        assert tb_pc = x"00000014"
            report "CYC6 FAIL: Expected PC=0x00000014, got " & to_hstring(tb_pc)
            severity error;
        assert tb_alu_result = x"0000001E"
            report "CYC6 FAIL: OR 30|10 expected 30 (0x0000001E), got " &
                   to_hstring(tb_alu_result)
            severity error;
        assert tb_reg_write_dest = "10000"   -- $s0 = reg 16
            report "CYC6 FAIL: Write dest expected reg 16 ($s0)"
            severity error;

        wait until rising_edge(clk);
        wait for 2 ns;

        -- =================================================================
        -- CYCLE 7 — PC=0x18: slt $t0, $t0, $t1   → $t0=1 (10<20)
        -- $t0 was 10, $t1=20 → 10<20 is true → result=1
        -- =================================================================
        assert tb_pc = x"00000018"
            report "CYC7 FAIL: Expected PC=0x00000018, got " & to_hstring(tb_pc)
            severity error;
        assert tb_alu_result = x"00000001"
            report "CYC7 FAIL: SLT 10<20 expected 1, got " &
                   to_hstring(tb_alu_result)
            severity error;
        assert tb_reg_write_dest = "01000"   -- $t0 = reg 8 (overwritten)
            report "CYC7 FAIL: Write dest expected reg 8 ($t0)"
            severity error;
        assert tb_reg_write_data = x"00000001"
            report "CYC7 FAIL: Write data expected 1"
            severity error;

        wait until rising_edge(clk);
        wait for 2 ns;

        -- =================================================================
        -- CYCLE 8 — PC=0x1C: beq $t0,$t0,+2
        -- $t0=1, comparing 1==1 → zero=1 → branch TAKEN → next PC=0x28
        -- reg_write_en=0 (branch does not write)
        -- =================================================================
        assert tb_pc = x"0000001C"
            report "CYC8 FAIL: Expected PC=0x0000001C (beq), got " & to_hstring(tb_pc)
            severity error;
        assert tb_branch_taken = '1'
            report "CYC8 FAIL: Branch should be taken (BEQ, $t0==$t0)"
            severity error;
        assert tb_reg_write_en = '0'
            report "CYC8 FAIL: reg_write_en should be 0 for branch"
            severity error;

        wait until rising_edge(clk);
        wait for 2 ns;

        -- =================================================================
        -- CYCLE 9 — PC=0x28: sw $t2, 0($zero)  — branch skipped 0x20,0x24
        -- Store $t2=30 to MEM[0]; reg_write_en=0
        -- =================================================================
        assert tb_pc = x"00000028"
            report "CYC9 FAIL: After branch, expected PC=0x00000028, got " &
                   to_hstring(tb_pc)
            severity error;
        assert tb_reg_write_en = '0'
            report "CYC9 FAIL: SW should not write register (reg_write_en=0)"
            severity error;
        -- ALU result is effective address: $zero + 0 = 0
        assert tb_alu_result = x"00000000"
            report "CYC9 FAIL: SW address expected 0x00000000, got " &
                   to_hstring(tb_alu_result)
            severity error;

        wait until rising_edge(clk);
        wait for 2 ns;

        -- =================================================================
        -- CYCLE 10 — PC=0x2C: lw $s0, 0($zero)
        -- Load MEM[0] (should be 30=0x1E) into $s0 (reg 16)
        -- =================================================================
        assert tb_pc = x"0000002C"
            report "CYC10 FAIL: Expected PC=0x0000002C, got " & to_hstring(tb_pc)
            severity error;
        assert tb_reg_write_en = '1'
            report "CYC10 FAIL: LW should have reg_write_en=1"
            severity error;
        assert tb_reg_write_dest = "10000"   -- $s0
            report "CYC10 FAIL: LW write dest expected reg 16 ($s0)"
            severity error;
        assert tb_reg_write_data = x"0000001E"
            report "CYC10 FAIL: LW write data expected 30 (0x0000001E) from memory, got " &
                   to_hstring(tb_reg_write_data)
            severity error;

        wait until rising_edge(clk);
        wait for 2 ns;

        -- =================================================================
        -- CYCLE 11 — PC=0x30: j 0x0000000D → next PC = 0x34
        -- No register write, no branch
        -- =================================================================
        assert tb_pc = x"00000030"
            report "CYC11 FAIL: Expected PC=0x00000030 (j), got " & to_hstring(tb_pc)
            severity error;
        assert tb_reg_write_en = '0'
            report "CYC11 FAIL: J should not write register"
            severity error;
        assert tb_branch_taken = '0'
            report "CYC11 FAIL: J is not a branch; branch_taken should be 0"
            severity error;

        wait until rising_edge(clk);
        wait for 2 ns;

        -- =================================================================
        -- CYCLE 12 — PC=0x34: sll $t0, $t0, 2
        -- $t0=1 (from slt), shift left 2 → result=4
        -- =================================================================
        assert tb_pc = x"00000034"
            report "CYC12 FAIL: After jump, expected PC=0x00000034, got " &
                   to_hstring(tb_pc)
            severity error;
        assert tb_alu_result = x"00000004"
            report "CYC12 FAIL: SLL 1<<2 expected 4 (0x00000004), got " &
                   to_hstring(tb_alu_result)
            severity error;
        assert tb_reg_write_dest = "01000"   -- $t0 = reg 8
            report "CYC12 FAIL: SLL write dest expected reg 8 ($t0)"
            severity error;
        assert tb_reg_write_data = x"00000004"
            report "CYC12 FAIL: SLL write data expected 4"
            severity error;

        wait until rising_edge(clk);
        wait for 2 ns;

        -- =================================================================
        -- FINAL: Verify debug register file reflects correct final state
        -- $t0 (reg 8) = 4 (after SLL)
        -- $t1 (reg 9) = 20
        -- $t2 (reg 10) = 30
        -- $t3 (reg 11) = 10
        -- =================================================================
        assert get_reg(tb_dbg_regs, 8)  = x"00000004"
            report "FINAL FAIL: $t0 (reg8) expected 4, got " &
                   to_hstring(get_reg(tb_dbg_regs, 8))
            severity error;
        assert get_reg(tb_dbg_regs, 9)  = x"00000014"
            report "FINAL FAIL: $t1 (reg9) expected 20, got " &
                   to_hstring(get_reg(tb_dbg_regs, 9))
            severity error;
        assert get_reg(tb_dbg_regs, 10) = x"0000001E"
            report "FINAL FAIL: $t2 (reg10) expected 30, got " &
                   to_hstring(get_reg(tb_dbg_regs, 10))
            severity error;
        assert get_reg(tb_dbg_regs, 11) = x"0000000A"
            report "FINAL FAIL: $t3 (reg11) expected 10, got " &
                   to_hstring(get_reg(tb_dbg_regs, 11))
            severity error;
        assert get_reg(tb_dbg_regs, 0)  = x"00000000"
            report "FINAL FAIL: $zero (reg0) must always be 0"
            severity error;

        -- =================================================================
        report "TB_Datapath: All cycle checks and final register checks passed." severity note;
        wait;
    end process stim_proc;

end architecture Behavioral;
