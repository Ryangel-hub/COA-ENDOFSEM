-- =============================================================================
-- File        : TB_Register_File.vhd
-- Entity      : TB_Register_File
-- Description : Comprehensive self-checking testbench for Register_File_VHDL.
--               Tests:
--                 - Synchronous reset clears all registers
--                 - Write and read back all tested registers
--                 - $zero (reg 0) is hardwired and cannot be written
--                 - Simultaneous dual-port reads
--                 - Write-enable = 0 does not modify register
--                 - Write to reg 31 ($ra) works correctly
--                 - Debug port exposes correct values
-- =============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity TB_Register_File is
end entity TB_Register_File;

architecture Behavioral of TB_Register_File is

    signal clk             : std_logic := '0';
    signal reset           : std_logic := '0';   -- NOTE: port is "reset" not "rst"
    signal reg_write_en    : std_logic := '0';
    signal reg_write_dest  : std_logic_vector(4  downto 0) := (others => '0');
    signal reg_write_data  : std_logic_vector(31 downto 0) := (others => '0');
    signal reg_read_addr_1 : std_logic_vector(4  downto 0) := (others => '0');
    signal reg_read_data_1 : std_logic_vector(31 downto 0);
    signal reg_read_addr_2 : std_logic_vector(4  downto 0) := (others => '0');
    signal reg_read_data_2 : std_logic_vector(31 downto 0);
    signal dbg_reg_file    : std_logic_vector(32*32-1 downto 0);

    constant CLK_PERIOD : time := 10 ns;

    -- Helper: extract one 32-bit register from the debug vector
    -- reg i is in bits [(i+1)*32-1 : i*32]
    function get_reg(dbg : std_logic_vector(32*32-1 downto 0); idx : integer)
        return std_logic_vector is
    begin
        return dbg((idx+1)*32-1 downto idx*32);
    end function;

begin

    -- =========================================================================
    -- UUT Instantiation
    -- =========================================================================
    uut : entity work.Register_File_VHDL
        port map (
            clk              => clk,
            reset            => reset,
            reg_write_en     => reg_write_en,
            reg_write_dest   => reg_write_dest,
            reg_write_data   => reg_write_data,
            reg_read_addr_1  => reg_read_addr_1,
            reg_read_data_1  => reg_read_data_1,
            reg_read_addr_2  => reg_read_addr_2,
            reg_read_data_2  => reg_read_data_2,
            dbg_reg_file     => dbg_reg_file
        );

    -- =========================================================================
    -- Clock Generator
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

        -- ---------------------------------------------------------------
        -- TEST 1: RESET — all registers must be 0 after reset
        -- ---------------------------------------------------------------
        reset <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        reset <= '0';

        -- Sample a few registers via read ports
        reg_read_addr_1 <= "00001";  -- $at
        reg_read_addr_2 <= "11111";  -- $ra
        wait for 2 ns;
        assert reg_read_data_1 = x"00000000"
            report "TEST 1 FAIL: After reset, $at should be 0x00000000"
            severity error;
        assert reg_read_data_2 = x"00000000"
            report "TEST 1 FAIL: After reset, $ra should be 0x00000000"
            severity error;

        -- ---------------------------------------------------------------
        -- TEST 2: WRITE reg 1 = 0x001D8BCA, read back
        -- ---------------------------------------------------------------
        reg_write_en   <= '1';
        reg_write_dest <= "00001";
        reg_write_data <= x"001D8BCA";
        wait until rising_edge(clk);
        wait for 1 ns;

        reg_read_addr_1 <= "00001";
        wait for 2 ns;
        assert reg_read_data_1 = x"001D8BCA"
            report "TEST 2 FAIL: Reg 1 expected 0x001D8BCA, got " &
                   to_hstring(reg_read_data_1)
            severity error;

        -- ---------------------------------------------------------------
        -- TEST 3: WRITE reg 3 = 0x0082B16F, read back
        -- ---------------------------------------------------------------
        reg_write_dest <= "00011";
        reg_write_data <= x"0082B16F";
        wait until rising_edge(clk);
        wait for 1 ns;

        reg_read_addr_2 <= "00011";
        wait for 2 ns;
        assert reg_read_data_2 = x"0082B16F"
            report "TEST 3 FAIL: Reg 3 expected 0x0082B16F, got " &
                   to_hstring(reg_read_data_2)
            severity error;

        -- ---------------------------------------------------------------
        -- TEST 4: WRITE reg 5 = 0x0C25BB60
        -- ---------------------------------------------------------------
        reg_write_dest <= "00101";
        reg_write_data <= x"0C25BB60";
        wait until rising_edge(clk);
        wait for 1 ns;

        reg_read_addr_1 <= "00101";
        wait for 2 ns;
        assert reg_read_data_1 = x"0C25BB60"
            report "TEST 4 FAIL: Reg 5 expected 0x0C25BB60, got " &
                   to_hstring(reg_read_data_1)
            severity error;

        -- ---------------------------------------------------------------
        -- TEST 5: WRITE reg 7 = 0x013B23D4
        -- ---------------------------------------------------------------
        reg_write_dest <= "00111";
        reg_write_data <= x"013B23D4";
        wait until rising_edge(clk);
        wait for 1 ns;

        reg_read_addr_2 <= "00111";
        wait for 2 ns;
        assert reg_read_data_2 = x"013B23D4"
            report "TEST 5 FAIL: Reg 7 expected 0x013B23D4, got " &
                   to_hstring(reg_read_data_2)
            severity error;

        -- ---------------------------------------------------------------
        -- TEST 6: DUAL-PORT READ — read reg 1 and reg 3 simultaneously
        -- ---------------------------------------------------------------
        reg_write_en    <= '0';
        reg_read_addr_1 <= "00001";
        reg_read_addr_2 <= "00011";
        wait for 2 ns;
        assert reg_read_data_1 = x"001D8BCA"
            report "TEST 6 FAIL: Dual read port 1 (reg 1) expected 0x001D8BCA"
            severity error;
        assert reg_read_data_2 = x"0082B16F"
            report "TEST 6 FAIL: Dual read port 2 (reg 3) expected 0x0082B16F"
            severity error;

        -- ---------------------------------------------------------------
        -- TEST 7: DUAL-PORT READ — reg 5 and reg 7 simultaneously
        -- ---------------------------------------------------------------
        reg_read_addr_1 <= "00101";
        reg_read_addr_2 <= "00111";
        wait for 2 ns;
        assert reg_read_data_1 = x"0C25BB60"
            report "TEST 7 FAIL: Dual read port 1 (reg 5) expected 0x0C25BB60"
            severity error;
        assert reg_read_data_2 = x"013B23D4"
            report "TEST 7 FAIL: Dual read port 2 (reg 7) expected 0x013B23D4"
            severity error;

        -- ---------------------------------------------------------------
        -- TEST 8: $ZERO (reg 0) — always reads 0, cannot be written
        -- ---------------------------------------------------------------
        -- Try to write a non-zero value to reg 0
        reg_write_en   <= '1';
        reg_write_dest <= "00000";
        reg_write_data <= x"DEADBEEF";
        wait until rising_edge(clk);
        wait for 1 ns;
        reg_write_en <= '0';

        reg_read_addr_1 <= "00000";
        wait for 2 ns;
        assert reg_read_data_1 = x"00000000"
            report "TEST 8 FAIL: $zero must always read 0x00000000, got " &
                   to_hstring(reg_read_data_1)
            severity error;

        -- ---------------------------------------------------------------
        -- TEST 9: WRITE ENABLE = 0 must NOT modify register
        -- ---------------------------------------------------------------
        reg_write_en   <= '0';
        reg_write_dest <= "00001";   -- reg 1 currently holds 0x001D8BCA
        reg_write_data <= x"FFFFFFFF";
        wait until rising_edge(clk);
        wait for 1 ns;

        reg_read_addr_1 <= "00001";
        wait for 2 ns;
        assert reg_read_data_1 = x"001D8BCA"
            report "TEST 9 FAIL: Write-enable=0 must not change reg 1; expected 0x001D8BCA"
            severity error;

        -- ---------------------------------------------------------------
        -- TEST 10: WRITE reg 31 ($ra) — highest register index
        -- ---------------------------------------------------------------
        reg_write_en   <= '1';
        reg_write_dest <= "11111";   -- $ra = reg 31
        reg_write_data <= x"BADDCAFE";
        wait until rising_edge(clk);
        wait for 1 ns;

        reg_read_addr_2 <= "11111";
        wait for 2 ns;
        assert reg_read_data_2 = x"BADDCAFE"
            report "TEST 10 FAIL: $ra (reg 31) expected 0xBADDCAFE, got " &
                   to_hstring(reg_read_data_2)
            severity error;
        reg_write_en <= '0';

        -- ---------------------------------------------------------------
        -- TEST 11: DEBUG PORT — verify reg 5 in packed debug vector
        -- ---------------------------------------------------------------
        assert get_reg(dbg_reg_file, 5) = x"0C25BB60"
            report "TEST 11 FAIL: Debug port reg 5 expected 0x0C25BB60"
            severity error;

        -- Verify debug port shows reg 0 as zero
        assert get_reg(dbg_reg_file, 0) = x"00000000"
            report "TEST 11b FAIL: Debug port reg 0 expected 0x00000000"
            severity error;

        -- ---------------------------------------------------------------
        -- TEST 12: RESET clears ALL registers (including reg 31)
        -- ---------------------------------------------------------------
        reset <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        reset <= '0';

        reg_read_addr_1 <= "11111";  -- $ra was BADDCAFE
        reg_read_addr_2 <= "00001";  -- reg 1 was 001D8BCA
        wait for 2 ns;
        assert reg_read_data_1 = x"00000000"
            report "TEST 12 FAIL: After reset, $ra should be 0x00000000"
            severity error;
        assert reg_read_data_2 = x"00000000"
            report "TEST 12 FAIL: After reset, reg 1 should be 0x00000000"
            severity error;

        -- ---------------------------------------------------------------
        report "TB_Register_File: All tests passed." severity note;
        wait;
    end process stim_proc;

end architecture Behavioral;
