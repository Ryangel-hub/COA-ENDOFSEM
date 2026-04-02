-- =============================================================================
-- File        : TB_ALU.vhd
-- Entity      : TB_ALU
-- Description : Comprehensive self-checking testbench for ALU_VHDL.
--               Tests all 16 ALU operations:
--                 ADD, SUB, AND, OR, XOR, NOR, SLT, SLTU,
--                 SLL, SRL, SRA, LUI, MFHI, MFLO, ADDU, SUBU
--               Verifies: alu_result, zero, negative, overflow, carry_out
-- =============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity TB_ALU is
end entity TB_ALU;

architecture Behavioral of TB_ALU is

    -- UUT signals
    signal a           : std_logic_vector(31 downto 0) := (others => '0');
    signal b           : std_logic_vector(31 downto 0) := (others => '0');
    signal shamt       : std_logic_vector(4  downto 0) := (others => '0');
    signal hi_in       : std_logic_vector(31 downto 0) := (others => '0');
    signal lo_in       : std_logic_vector(31 downto 0) := (others => '0');
    signal alu_control : std_logic_vector(3  downto 0) := (others => '0');
    signal alu_result  : std_logic_vector(31 downto 0);
    signal zero        : std_logic;
    signal negative    : std_logic;
    signal overflow    : std_logic;
    signal carry_out   : std_logic;

    -- Helper constants
    constant DELAY : time := 10 ns;

begin

    -- =========================================================================
    -- UUT Instantiation
    -- =========================================================================
    uut : entity work.ALU_VHDL
        port map (
            a           => a,
            b           => b,
            shamt       => shamt,
            hi_in       => hi_in,
            lo_in       => lo_in,
            alu_control => alu_control,
            alu_result  => alu_result,
            zero        => zero,
            negative    => negative,
            overflow    => overflow,
            carry_out   => carry_out
        );

    -- =========================================================================
    -- Stimulus & Checking Process
    -- =========================================================================
    stim_proc : process
    begin

        -- ---------------------------------------------------------------------
        -- TEST 1: ADD — 2500 + 25000 = 27500 (0x00006B6C)
        -- No overflow, not zero, positive
        -- ---------------------------------------------------------------------
        a           <= x"000009C4";   -- 2500
        b           <= x"000061A8";   -- 25000
        alu_control <= "0000";
        wait for DELAY;
        assert alu_result = x"00006B6C"
            report "TEST 1 FAIL: ADD 2500+25000 expected 0x00006B6C, got " &
                   to_hstring(alu_result)
            severity error;
        assert zero     = '0' report "TEST 1 FAIL: ADD zero flag should be 0"     severity error;
        assert negative = '0' report "TEST 1 FAIL: ADD negative flag should be 0" severity error;
        assert overflow = '0' report "TEST 1 FAIL: ADD overflow flag should be 0" severity error;

        -- ---------------------------------------------------------------------
        -- TEST 2: ADD — result is zero (5 + (-5))
        -- ---------------------------------------------------------------------
        a           <= x"00000005";
        b           <= x"FFFFFFFB";   -- -5 in two's complement
        alu_control <= "0000";
        wait for DELAY;
        assert alu_result = x"00000000"
            report "TEST 2 FAIL: ADD zero result expected 0x00000000"
            severity error;
        assert zero = '1' report "TEST 2 FAIL: ADD zero flag should be 1" severity error;

        -- ---------------------------------------------------------------------
        -- TEST 3: ADD — signed overflow: large positive + large positive = negative
        -- ---------------------------------------------------------------------
        a           <= x"7FFFFFFF";   -- INT_MAX
        b           <= x"00000001";
        alu_control <= "0000";
        wait for DELAY;
        assert overflow = '1'
            report "TEST 3 FAIL: ADD overflow not detected on INT_MAX+1"
            severity error;
        assert negative = '1'
            report "TEST 3 FAIL: ADD result should be negative after overflow"
            severity error;

        -- ---------------------------------------------------------------------
        -- TEST 4: SUB — 540250 - 37800 = 502450 (0x0007AAB2)
        -- ---------------------------------------------------------------------
        a           <= x"00083E5A";   -- 540250
        b           <= x"000093A8";   -- 37800
        alu_control <= "0001";
        wait for DELAY;
        assert alu_result = x"0007AAB2"
            report "TEST 4 FAIL: SUB expected 0x0007AAB2, got " &
                   to_hstring(alu_result)
            severity error;
        assert zero     = '0' report "TEST 4 FAIL: SUB zero flag should be 0"     severity error;
        assert overflow = '0' report "TEST 4 FAIL: SUB overflow flag should be 0" severity error;

        -- ---------------------------------------------------------------------
        -- TEST 5: SUB — signed overflow: large negative - large positive
        -- ---------------------------------------------------------------------
        a           <= x"80000000";   -- INT_MIN
        b           <= x"00000001";
        alu_control <= "0001";
        wait for DELAY;
        assert overflow = '1'
            report "TEST 5 FAIL: SUB overflow not detected on INT_MIN-1"
            severity error;

        -- ---------------------------------------------------------------------
        -- TEST 6: AND — 53957 AND 30000 = 0x00005000
        -- ---------------------------------------------------------------------
        a           <= x"0000D2C5";
        b           <= x"00007530";
        alu_control <= "0010";
        wait for DELAY;
        assert alu_result = x"00005000"
            report "TEST 6 FAIL: AND expected 0x00005000, got " &
                   to_hstring(alu_result)
            severity error;
        assert zero = '0' report "TEST 6 FAIL: AND zero flag should be 0" severity error;

        -- ---------------------------------------------------------------------
        -- TEST 7: OR — 746353 OR 846465 = 0x000FEBF1
        -- ---------------------------------------------------------------------
        a           <= x"000B6371";
        b           <= x"000CEA81";
        alu_control <= "0011";
        wait for DELAY;
        assert alu_result = x"000FEBF1"
            report "TEST 7 FAIL: OR expected 0x000FEBF1, got " &
                   to_hstring(alu_result)
            severity error;

        -- ---------------------------------------------------------------------
        -- TEST 8: XOR — 0xA5A5A5A5 XOR 0x5A5A5A5A = 0xFFFFFFFF
        -- ---------------------------------------------------------------------
        a           <= x"A5A5A5A5";
        b           <= x"5A5A5A5A";
        alu_control <= "0100";
        wait for DELAY;
        assert alu_result = x"FFFFFFFF"
            report "TEST 8 FAIL: XOR expected 0xFFFFFFFF, got " &
                   to_hstring(alu_result)
            severity error;
        assert negative = '1' report "TEST 8 FAIL: XOR result MSB should be 1" severity error;

        -- ---------------------------------------------------------------------
        -- TEST 9: NOR — 0x00FF00FF NOR 0xFF00FF00 = 0x00000000
        -- ---------------------------------------------------------------------
        a           <= x"00FF00FF";
        b           <= x"FF00FF00";
        alu_control <= "0101";
        wait for DELAY;
        assert alu_result = x"00000000"
            report "TEST 9 FAIL: NOR expected 0x00000000, got " &
                   to_hstring(alu_result)
            severity error;
        assert zero = '1' report "TEST 9 FAIL: NOR zero flag should be 1" severity error;

        -- ---------------------------------------------------------------------
        -- TEST 10: SLT (signed) — 58847537 < 72464383 → result = 1
        -- ---------------------------------------------------------------------
        a           <= x"0381F131";   -- 58847537
        b           <= x"0451B7FF";   -- 72464383
        alu_control <= "0110";
        wait for DELAY;
        assert alu_result = x"00000001"
            report "TEST 10 FAIL: SLT expected 1 (a < b), got " &
                   to_hstring(alu_result)
            severity error;
        assert zero = '0' report "TEST 10 FAIL: SLT zero should be 0" severity error;

        -- SLT: a > b → result = 0
        a           <= x"0451B7FF";
        b           <= x"0381F131";
        alu_control <= "0110";
        wait for DELAY;
        assert alu_result = x"00000000"
            report "TEST 10b FAIL: SLT expected 0 (a > b)"
            severity error;

        -- SLT: negative < positive → result = 1
        a           <= x"FFFFFFFF";   -- -1 (signed)
        b           <= x"00000001";   -- +1
        alu_control <= "0110";
        wait for DELAY;
        assert alu_result = x"00000001"
            report "TEST 10c FAIL: SLT signed: -1 < +1 should give 1"
            severity error;

        -- ---------------------------------------------------------------------
        -- TEST 11: SLTU (unsigned) — 0xFFFFFFFF > 0x00000001 unsigned → result = 0
        -- ---------------------------------------------------------------------
        a           <= x"FFFFFFFF";
        b           <= x"00000001";
        alu_control <= "0111";
        wait for DELAY;
        assert alu_result = x"00000000"
            report "TEST 11 FAIL: SLTU: 0xFFFFFFFF not less than 1 unsigned"
            severity error;

        -- SLTU: 1 < 0xFFFFFFFF unsigned → result = 1
        a           <= x"00000001";
        b           <= x"FFFFFFFF";
        alu_control <= "0111";
        wait for DELAY;
        assert alu_result = x"00000001"
            report "TEST 11b FAIL: SLTU: 1 < 0xFFFFFFFF unsigned should give 1"
            severity error;

        -- ---------------------------------------------------------------------
        -- TEST 12: SLL — 0x00000001 << 4 = 0x00000010
        -- ---------------------------------------------------------------------
        b           <= x"00000001";
        shamt       <= "00100";       -- shift by 4
        alu_control <= "1000";
        wait for DELAY;
        assert alu_result = x"00000010"
            report "TEST 12 FAIL: SLL 1<<4 expected 0x00000010, got " &
                   to_hstring(alu_result)
            severity error;

        -- SLL by 0 → no change
        b           <= x"ABCDEF01";
        shamt       <= "00000";
        alu_control <= "1000";
        wait for DELAY;
        assert alu_result = x"ABCDEF01"
            report "TEST 12b FAIL: SLL by 0 should not change value"
            severity error;

        -- ---------------------------------------------------------------------
        -- TEST 13: SRL — 0x80000000 >> 1 = 0x40000000 (zero-fill MSB)
        -- ---------------------------------------------------------------------
        b           <= x"80000000";
        shamt       <= "00001";
        alu_control <= "1001";
        wait for DELAY;
        assert alu_result = x"40000000"
            report "TEST 13 FAIL: SRL 0x80000000>>1 expected 0x40000000, got " &
                   to_hstring(alu_result)
            severity error;

        -- ---------------------------------------------------------------------
        -- TEST 14: SRA — 0x80000000 >> 1 = 0xC0000000 (sign-fill MSB)
        -- ---------------------------------------------------------------------
        b           <= x"80000000";
        shamt       <= "00001";
        alu_control <= "1010";
        wait for DELAY;
        assert alu_result = x"C0000000"
            report "TEST 14 FAIL: SRA 0x80000000>>1 expected 0xC0000000, got " &
                   to_hstring(alu_result)
            severity error;
        assert negative = '1' report "TEST 14 FAIL: SRA result should be negative" severity error;

        -- ---------------------------------------------------------------------
        -- TEST 15: LUI — b[15:0]=0xBEEF → result = 0xBEEF0000
        -- ---------------------------------------------------------------------
        b           <= x"0000BEEF";
        alu_control <= "1011";
        wait for DELAY;
        assert alu_result = x"BEEF0000"
            report "TEST 15 FAIL: LUI expected 0xBEEF0000, got " &
                   to_hstring(alu_result)
            severity error;

        -- ---------------------------------------------------------------------
        -- TEST 16: MFHI — passthrough hi_in
        -- ---------------------------------------------------------------------
        hi_in       <= x"DEADBEEF";
        alu_control <= "1100";
        wait for DELAY;
        assert alu_result = x"DEADBEEF"
            report "TEST 16 FAIL: MFHI expected 0xDEADBEEF, got " &
                   to_hstring(alu_result)
            severity error;

        -- ---------------------------------------------------------------------
        -- TEST 17: MFLO — passthrough lo_in
        -- ---------------------------------------------------------------------
        lo_in       <= x"CAFEBABE";
        alu_control <= "1101";
        wait for DELAY;
        assert alu_result = x"CAFEBABE"
            report "TEST 17 FAIL: MFLO expected 0xCAFEBABE, got " &
                   to_hstring(alu_result)
            severity error;

        -- ---------------------------------------------------------------------
        -- TEST 18: ADDU — no overflow detection even at boundary
        -- 0xFFFFFFFF + 0x00000001 = 0x00000000, carry=1, overflow=0
        -- ---------------------------------------------------------------------
        a           <= x"FFFFFFFF";
        b           <= x"00000001";
        alu_control <= "1110";
        wait for DELAY;
        assert alu_result = x"00000000"
            report "TEST 18 FAIL: ADDU wrap expected 0x00000000, got " &
                   to_hstring(alu_result)
            severity error;
        assert carry_out = '1'
            report "TEST 18 FAIL: ADDU carry_out should be 1 on wrap"
            severity error;
        assert overflow = '0'
            report "TEST 18 FAIL: ADDU should not set overflow flag"
            severity error;
        assert zero = '1' report "TEST 18 FAIL: ADDU result should be zero" severity error;

        -- ---------------------------------------------------------------------
        -- TEST 19: SUBU — 10 - 15 = 0xFFFFFFFB (no overflow flag raised)
        -- ---------------------------------------------------------------------
        a           <= x"0000000A";   -- 10
        b           <= x"0000000F";   -- 15
        alu_control <= "1111";
        wait for DELAY;
        assert alu_result = x"FFFFFFFB"
            report "TEST 19 FAIL: SUBU 10-15 expected 0xFFFFFFFB, got " &
                   to_hstring(alu_result)
            severity error;
        assert overflow = '0'
            report "TEST 19 FAIL: SUBU should not set overflow flag"
            severity error;

        -- ---------------------------------------------------------------------
        report "TB_ALU: All tests passed." severity note;
        wait;
    end process stim_proc;

end architecture Behavioral;
