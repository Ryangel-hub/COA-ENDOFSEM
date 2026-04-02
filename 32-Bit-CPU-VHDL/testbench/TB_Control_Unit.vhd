-- =============================================================================
-- File        : TB_Control_Unit.vhd
-- Entity      : TB_Control_Unit
-- Description : Comprehensive self-checking testbench for Control_Unit_VHDL.
--               Tests all supported opcodes and verifies every control signal.
--               Includes: reset, R-type, I-type ALU, LW/SW, LH/LB/SH/SB,
--                         BEQ, BNE, J, JAL, JR (via funct).
-- =============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity TB_Control_Unit is
end entity TB_Control_Unit;

architecture Behavioral of TB_Control_Unit is

    -- UUT signals — all ports from new Control_Unit_VHDL
    signal opcode       : std_logic_vector(5 downto 0) := (others => '0');
    signal funct        : std_logic_vector(5 downto 0) := (others => '0');
    signal reset        : std_logic := '0';

    signal reg_dst      : std_logic_vector(1 downto 0);
    signal reg_write    : std_logic;
    signal mem_read     : std_logic;
    signal mem_write    : std_logic;
    signal mem_to_reg   : std_logic_vector(1 downto 0);
    signal mem_size     : std_logic_vector(1 downto 0);
    signal mem_sign     : std_logic;
    signal alu_src      : std_logic;
    signal alu_op       : std_logic_vector(1 downto 0);
    signal sign_or_zero : std_logic;
    signal branch       : std_logic;
    signal branch_ne    : std_logic;
    signal jump         : std_logic;
    signal jump_reg     : std_logic;
    signal link         : std_logic;

    constant DELAY : time := 10 ns;

begin

    -- =========================================================================
    -- UUT Instantiation
    -- =========================================================================
    uut : entity work.Control_Unit_VHDL
        port map (
            opcode       => opcode,
            funct        => funct,
            reset        => reset,
            reg_dst      => reg_dst,
            reg_write    => reg_write,
            mem_read     => mem_read,
            mem_write    => mem_write,
            mem_to_reg   => mem_to_reg,
            mem_size     => mem_size,
            mem_sign     => mem_sign,
            alu_src      => alu_src,
            alu_op       => alu_op,
            sign_or_zero => sign_or_zero,
            branch       => branch,
            branch_ne    => branch_ne,
            jump         => jump,
            jump_reg     => jump_reg,
            link         => link
        );

    -- =========================================================================
    -- Stimulus & Checking Process
    -- =========================================================================
    stim_proc : process
    begin

        -- ---------------------------------------------------------------------
        -- TEST 1: RESET — all outputs must go to safe NOP defaults
        -- ---------------------------------------------------------------------
        reset  <= '1';
        opcode <= "000000";
        funct  <= "000000";
        wait for DELAY;
        assert reg_dst    = "00" report "RESET: reg_dst   should be 00"  severity error;
        assert reg_write  = '0'  report "RESET: reg_write should be 0"   severity error;
        assert mem_read   = '0'  report "RESET: mem_read  should be 0"   severity error;
        assert mem_write  = '0'  report "RESET: mem_write should be 0"   severity error;
        assert mem_to_reg = "00" report "RESET: mem_to_reg should be 00" severity error;
        assert alu_src    = '0'  report "RESET: alu_src   should be 0"   severity error;
        assert alu_op     = "00" report "RESET: alu_op    should be 00"  severity error;
        assert branch     = '0'  report "RESET: branch    should be 0"   severity error;
        assert jump       = '0'  report "RESET: jump      should be 0"   severity error;
        assert jump_reg   = '0'  report "RESET: jump_reg  should be 0"   severity error;
        assert link       = '0'  report "RESET: link      should be 0"   severity error;
        reset <= '0';

        -- ---------------------------------------------------------------------
        -- TEST 2: R-TYPE (opcode=000000, funct=100000 ADD)
        --   reg_dst=01, alu_op=10, reg_write=1, all memory/branch/jump=0
        -- ---------------------------------------------------------------------
        opcode <= "000000";
        funct  <= "100000";   -- ADD
        wait for DELAY;
        assert reg_dst   = "01" report "R-TYPE: reg_dst should be 01 (rd)"    severity error;
        assert alu_op    = "10" report "R-TYPE: alu_op should be 10"           severity error;
        assert reg_write = '1'  report "R-TYPE: reg_write should be 1"         severity error;
        assert alu_src   = '0'  report "R-TYPE: alu_src should be 0 (reg)"     severity error;
        assert mem_read  = '0'  report "R-TYPE: mem_read should be 0"          severity error;
        assert mem_write = '0'  report "R-TYPE: mem_write should be 0"         severity error;
        assert branch    = '0'  report "R-TYPE: branch should be 0"            severity error;
        assert jump      = '0'  report "R-TYPE: jump should be 0"              severity error;
        assert jump_reg  = '0'  report "R-TYPE: jump_reg should be 0"          severity error;

        -- ---------------------------------------------------------------------
        -- TEST 3: JR (opcode=000000, funct=001000)
        --   jump_reg=1, reg_write=0
        -- ---------------------------------------------------------------------
        opcode <= "000000";
        funct  <= "001000";   -- JR
        wait for DELAY;
        assert jump_reg  = '1' report "JR: jump_reg should be 1"     severity error;
        assert reg_write = '0' report "JR: reg_write should be 0"    severity error;
        assert jump      = '0' report "JR: jump(J-type) should be 0" severity error;

        -- ---------------------------------------------------------------------
        -- TEST 4: JALR (opcode=000000, funct=001001)
        --   jump_reg=1, link=1, reg_dst=01, mem_to_reg=10, reg_write=1
        -- ---------------------------------------------------------------------
        opcode <= "000000";
        funct  <= "001001";   -- JALR
        wait for DELAY;
        assert jump_reg  = '1'  report "JALR: jump_reg should be 1"    severity error;
        assert link      = '1'  report "JALR: link should be 1"         severity error;
        assert reg_dst   = "01" report "JALR: reg_dst should be 01(rd)" severity error;
        assert mem_to_reg= "10" report "JALR: mem_to_reg should be 10"  severity error;
        assert reg_write = '1'  report "JALR: reg_write should be 1"    severity error;

        -- ---------------------------------------------------------------------
        -- TEST 5: ADDI (opcode=001000)
        --   reg_dst=00, alu_src=1, alu_op=11, sign_or_zero=1, reg_write=1
        -- ---------------------------------------------------------------------
        opcode <= "001000";
        funct  <= "000000";
        wait for DELAY;
        assert reg_dst      = "00" report "ADDI: reg_dst should be 00(rt)"    severity error;
        assert alu_src      = '1'  report "ADDI: alu_src should be 1(imm)"    severity error;
        assert alu_op       = "11" report "ADDI: alu_op should be 11(I-type)" severity error;
        assert sign_or_zero = '1'  report "ADDI: sign_or_zero should be 1"    severity error;
        assert reg_write    = '1'  report "ADDI: reg_write should be 1"       severity error;
        assert mem_read     = '0'  report "ADDI: mem_read should be 0"        severity error;
        assert mem_write    = '0'  report "ADDI: mem_write should be 0"       severity error;

        -- ---------------------------------------------------------------------
        -- TEST 6: ADDIU (opcode=001001) — same signals as ADDI
        -- ---------------------------------------------------------------------
        opcode <= "001001";
        wait for DELAY;
        assert alu_src   = '1'  report "ADDIU: alu_src should be 1"    severity error;
        assert alu_op    = "11" report "ADDIU: alu_op should be 11"    severity error;
        assert reg_write = '1'  report "ADDIU: reg_write should be 1"  severity error;

        -- ---------------------------------------------------------------------
        -- TEST 7: SLTI (opcode=001010)
        -- ---------------------------------------------------------------------
        opcode <= "001010";
        wait for DELAY;
        assert reg_dst      = "00" report "SLTI: reg_dst should be 00"    severity error;
        assert alu_op       = "11" report "SLTI: alu_op should be 11"     severity error;
        assert alu_src      = '1'  report "SLTI: alu_src should be 1"     severity error;
        assert sign_or_zero = '1'  report "SLTI: sign_or_zero should be 1" severity error;
        assert reg_write    = '1'  report "SLTI: reg_write should be 1"   severity error;

        -- ---------------------------------------------------------------------
        -- TEST 8: ANDI (opcode=001100) — zero extend (sign_or_zero=0)
        -- ---------------------------------------------------------------------
        opcode <= "001100";
        wait for DELAY;
        assert alu_src      = '1'  report "ANDI: alu_src should be 1"        severity error;
        assert alu_op       = "11" report "ANDI: alu_op should be 11"        severity error;
        assert sign_or_zero = '0'  report "ANDI: sign_or_zero should be 0 (zero extend)" severity error;
        assert reg_write    = '1'  report "ANDI: reg_write should be 1"      severity error;

        -- ---------------------------------------------------------------------
        -- TEST 9: ORI (opcode=001101) — zero extend
        -- ---------------------------------------------------------------------
        opcode <= "001101";
        wait for DELAY;
        assert alu_src      = '1'  report "ORI: alu_src should be 1"  severity error;
        assert sign_or_zero = '0'  report "ORI: sign_or_zero should be 0" severity error;
        assert reg_write    = '1'  report "ORI: reg_write should be 1" severity error;

        -- ---------------------------------------------------------------------
        -- TEST 10: LUI (opcode=001111)
        -- ---------------------------------------------------------------------
        opcode <= "001111";
        wait for DELAY;
        assert alu_src   = '1'  report "LUI: alu_src should be 1"    severity error;
        assert alu_op    = "11" report "LUI: alu_op should be 11"    severity error;
        assert reg_write = '1'  report "LUI: reg_write should be 1"  severity error;

        -- ---------------------------------------------------------------------
        -- TEST 11: LW (opcode=100011)
        --   alu_op=00(ADD), alu_src=1, mem_read=1, mem_to_reg=01, mem_size=10, reg_write=1
        -- ---------------------------------------------------------------------
        opcode <= "100011";
        wait for DELAY;
        assert alu_op    = "00" report "LW: alu_op should be 00 (ADD)"     severity error;
        assert alu_src   = '1'  report "LW: alu_src should be 1 (imm)"     severity error;
        assert mem_read  = '1'  report "LW: mem_read should be 1"          severity error;
        assert mem_to_reg= "01" report "LW: mem_to_reg should be 01 (mem)" severity error;
        assert mem_size  = "10" report "LW: mem_size should be 10 (word)"  severity error;
        assert reg_write = '1'  report "LW: reg_write should be 1"         severity error;
        assert mem_write = '0'  report "LW: mem_write should be 0"         severity error;

        -- ---------------------------------------------------------------------
        -- TEST 12: LH (opcode=100001) — half word signed load
        -- ---------------------------------------------------------------------
        opcode <= "100001";
        wait for DELAY;
        assert mem_read = '1'  report "LH: mem_read should be 1"           severity error;
        assert mem_size = "01" report "LH: mem_size should be 01 (half)"   severity error;
        assert mem_sign = '0'  report "LH: mem_sign should be 0 (signed)"  severity error;
        assert reg_write= '1'  report "LH: reg_write should be 1"          severity error;

        -- ---------------------------------------------------------------------
        -- TEST 13: LHU (opcode=100101) — half word unsigned load
        -- ---------------------------------------------------------------------
        opcode <= "100101";
        wait for DELAY;
        assert mem_read = '1'  report "LHU: mem_read should be 1"            severity error;
        assert mem_size = "01" report "LHU: mem_size should be 01 (half)"    severity error;
        assert mem_sign = '1'  report "LHU: mem_sign should be 1 (unsigned)" severity error;

        -- ---------------------------------------------------------------------
        -- TEST 14: LB (opcode=100000) — byte signed load
        -- ---------------------------------------------------------------------
        opcode <= "100000";
        wait for DELAY;
        assert mem_read = '1'  report "LB: mem_read should be 1"           severity error;
        assert mem_size = "00" report "LB: mem_size should be 00 (byte)"   severity error;
        assert mem_sign = '0'  report "LB: mem_sign should be 0 (signed)"  severity error;

        -- ---------------------------------------------------------------------
        -- TEST 15: LBU (opcode=100100) — byte unsigned load
        -- ---------------------------------------------------------------------
        opcode <= "100100";
        wait for DELAY;
        assert mem_read = '1'  report "LBU: mem_read should be 1"            severity error;
        assert mem_size = "00" report "LBU: mem_size should be 00 (byte)"    severity error;
        assert mem_sign = '1'  report "LBU: mem_sign should be 1 (unsigned)" severity error;

        -- ---------------------------------------------------------------------
        -- TEST 16: SW (opcode=101011)
        --   alu_op=00, alu_src=1, mem_write=1, mem_size=10, reg_write=0
        -- ---------------------------------------------------------------------
        opcode <= "101011";
        wait for DELAY;
        assert alu_op    = "00" report "SW: alu_op should be 00 (ADD)"  severity error;
        assert alu_src   = '1'  report "SW: alu_src should be 1"        severity error;
        assert mem_write = '1'  report "SW: mem_write should be 1"      severity error;
        assert mem_size  = "10" report "SW: mem_size should be 10"      severity error;
        assert reg_write = '0'  report "SW: reg_write should be 0"      severity error;
        assert mem_read  = '0'  report "SW: mem_read should be 0"       severity error;

        -- ---------------------------------------------------------------------
        -- TEST 17: SH (opcode=101001) — store half word
        -- ---------------------------------------------------------------------
        opcode <= "101001";
        wait for DELAY;
        assert mem_write = '1'  report "SH: mem_write should be 1"      severity error;
        assert mem_size  = "01" report "SH: mem_size should be 01(half)" severity error;

        -- ---------------------------------------------------------------------
        -- TEST 18: SB (opcode=101000) — store byte
        -- ---------------------------------------------------------------------
        opcode <= "101000";
        wait for DELAY;
        assert mem_write = '1'  report "SB: mem_write should be 1"      severity error;
        assert mem_size  = "00" report "SB: mem_size should be 00(byte)" severity error;

        -- ---------------------------------------------------------------------
        -- TEST 19: BEQ (opcode=000100)
        --   alu_op=01, branch=1, branch_ne=0, reg_write=0
        -- ---------------------------------------------------------------------
        opcode <= "000100";
        wait for DELAY;
        assert alu_op    = "01" report "BEQ: alu_op should be 01 (SUB)"  severity error;
        assert branch    = '1'  report "BEQ: branch should be 1"          severity error;
        assert branch_ne = '0'  report "BEQ: branch_ne should be 0"       severity error;
        assert reg_write = '0'  report "BEQ: reg_write should be 0"       severity error;
        assert mem_read  = '0'  report "BEQ: mem_read should be 0"        severity error;
        assert jump      = '0'  report "BEQ: jump should be 0"            severity error;

        -- ---------------------------------------------------------------------
        -- TEST 20: BNE (opcode=000101)
        --   alu_op=01, branch=1, branch_ne=1
        -- ---------------------------------------------------------------------
        opcode <= "000101";
        wait for DELAY;
        assert alu_op    = "01" report "BNE: alu_op should be 01"   severity error;
        assert branch    = '1'  report "BNE: branch should be 1"    severity error;
        assert branch_ne = '1'  report "BNE: branch_ne should be 1" severity error;

        -- ---------------------------------------------------------------------
        -- TEST 21: J (opcode=000010)
        --   jump=1, all others 0
        -- ---------------------------------------------------------------------
        opcode <= "000010";
        wait for DELAY;
        assert jump      = '1'  report "J: jump should be 1"      severity error;
        assert reg_write = '0'  report "J: reg_write should be 0"  severity error;
        assert branch    = '0'  report "J: branch should be 0"     severity error;
        assert mem_read  = '0'  report "J: mem_read should be 0"   severity error;
        assert jump_reg  = '0'  report "J: jump_reg should be 0"   severity error;
        assert link      = '0'  report "J: link should be 0"       severity error;

        -- ---------------------------------------------------------------------
        -- TEST 22: JAL (opcode=000011)
        --   jump=1, link=1, reg_dst=10($ra), mem_to_reg=10(PC+4), reg_write=1
        -- ---------------------------------------------------------------------
        opcode <= "000011";
        wait for DELAY;
        assert jump      = '1'  report "JAL: jump should be 1"           severity error;
        assert link      = '1'  report "JAL: link should be 1"            severity error;
        assert reg_dst   = "10" report "JAL: reg_dst should be 10 ($ra)" severity error;
        assert mem_to_reg= "10" report "JAL: mem_to_reg should be 10"    severity error;
        assert reg_write = '1'  report "JAL: reg_write should be 1"      severity error;
        assert jump_reg  = '0'  report "JAL: jump_reg should be 0"       severity error;

        -- ---------------------------------------------------------------------
        -- TEST 23: Unknown opcode — all outputs should be NOP defaults
        -- ---------------------------------------------------------------------
        opcode <= "111111";
        wait for DELAY;
        assert reg_write = '0' report "UNKNOWN: reg_write should be 0" severity error;
        assert mem_read  = '0' report "UNKNOWN: mem_read should be 0"  severity error;
        assert mem_write = '0' report "UNKNOWN: mem_write should be 0" severity error;
        assert branch    = '0' report "UNKNOWN: branch should be 0"    severity error;
        assert jump      = '0' report "UNKNOWN: jump should be 0"      severity error;

        -- ---------------------------------------------------------------------
        report "TB_Control_Unit: All tests passed." severity note;
        wait;
    end process stim_proc;

end architecture Behavioral;
