-- =============================================================================
-- File        : TB_Data_Memory.vhd
-- Entity      : TB_Data_Memory
-- Description : Comprehensive self-checking testbench for Data_Memory_VHDL.
--               Tests:
--                 - Word (32-bit) write and read
--                 - Half-word (16-bit) write and signed/unsigned read
--                 - Byte (8-bit) write and signed/unsigned read
--                 - Out-of-range address guard (returns 0x00000000)
--                 - Synchronous reset clears memory
--                 - Read with mem_read=0 returns 0x00000000
-- =============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity TB_Data_Memory is
end entity TB_Data_Memory;

architecture Behavioral of TB_Data_Memory is

    signal clk        : std_logic := '0';
    signal reset      : std_logic := '0';
    signal address    : std_logic_vector(31 downto 0) := (others => '0');
    signal write_data : std_logic_vector(31 downto 0) := (others => '0');
    signal mem_write  : std_logic := '0';
    signal mem_read   : std_logic := '0';
    signal mem_size   : std_logic_vector(1 downto 0) := "10";
    signal mem_sign   : std_logic := '0';
    signal read_data  : std_logic_vector(31 downto 0);

    constant CLK_PERIOD : time := 10 ns;

    -- Helper: drive a write, then check read on next cycle
    -- (write is sync, read is async — read available immediately after write completes)

begin

    -- =========================================================================
    -- UUT Instantiation
    -- =========================================================================
    uut : entity work.Data_Memory_VHDL
        port map (
            clk        => clk,
            reset      => reset,
            address    => address,
            write_data => write_data,
            mem_write  => mem_write,
            mem_read   => mem_read,
            mem_size   => mem_size,
            mem_sign   => mem_sign,
            read_data  => read_data
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

        -- Apply reset to ensure clean state
        reset <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        reset <= '0';

        -- =================================================================
        -- TEST 1: WORD WRITE then READ at address 0x00000008
        -- =================================================================
        address    <= x"00000008";
        write_data <= x"00000400";
        mem_write  <= '1';
        mem_read   <= '0';
        mem_size   <= "10";    -- word
        wait until rising_edge(clk);
        wait for 1 ns;         -- let sync write complete

        mem_write <= '0';
        mem_read  <= '1';
        wait for 2 ns;         -- async read settles
        assert read_data = x"00000400"
            report "TEST 1 FAIL: Word read at 0x08 expected 0x00000400, got " &
                   to_hstring(read_data)
            severity error;

        -- =================================================================
        -- TEST 2: WORD WRITE then READ at address 0x00000010
        -- =================================================================
        address    <= x"00000010";
        write_data <= x"00068EB8";
        mem_write  <= '1';
        mem_read   <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;

        mem_write <= '0';
        mem_read  <= '1';
        wait for 2 ns;
        assert read_data = x"00068EB8"
            report "TEST 2 FAIL: Word read at 0x10 expected 0x00068EB8, got " &
                   to_hstring(read_data)
            severity error;

        -- =================================================================
        -- TEST 3: WORD — zero result (check zero is stored correctly)
        -- =================================================================
        address    <= x"00000020";
        write_data <= x"00000000";
        mem_write  <= '1';
        mem_read   <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;

        mem_write <= '0';
        mem_read  <= '1';
        wait for 2 ns;
        assert read_data = x"00000000"
            report "TEST 3 FAIL: Word zero write/read failed"
            severity error;

        -- =================================================================
        -- TEST 4: BYTE WRITE then SIGNED READ (negative byte 0xAB → sign extended)
        -- 0xAB = 10101011 → sign extended = 0xFFFFFFAB
        -- =================================================================
        address    <= x"00000030";
        write_data <= x"000000AB";
        mem_write  <= '1';
        mem_read   <= '0';
        mem_size   <= "00";    -- byte
        wait until rising_edge(clk);
        wait for 1 ns;

        mem_write <= '0';
        mem_read  <= '1';
        mem_sign  <= '0';      -- signed extend
        wait for 2 ns;
        assert read_data = x"FFFFFFAB"
            report "TEST 4 FAIL: Byte signed read expected 0xFFFFFFAB, got " &
                   to_hstring(read_data)
            severity error;

        -- =================================================================
        -- TEST 5: BYTE WRITE then UNSIGNED READ (0xAB → zero extended = 0x000000AB)
        -- =================================================================
        address   <= x"00000030";
        mem_write <= '0';
        mem_read  <= '1';
        mem_size  <= "00";
        mem_sign  <= '1';      -- zero extend (unsigned)
        wait for 2 ns;
        assert read_data = x"000000AB"
            report "TEST 5 FAIL: Byte unsigned read expected 0x000000AB, got " &
                   to_hstring(read_data)
            severity error;

        -- =================================================================
        -- TEST 6: HALF-WORD WRITE then SIGNED READ
        -- Write 0xBEEF at address 0x40 → sign extend to 0xFFFFBEEF
        -- =================================================================
        address    <= x"00000040";
        write_data <= x"0000BEEF";
        mem_write  <= '1';
        mem_read   <= '0';
        mem_size   <= "01";    -- half word
        mem_sign   <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;

        mem_write <= '0';
        mem_read  <= '1';
        wait for 2 ns;
        assert read_data = x"FFFFBEEF"
            report "TEST 6 FAIL: Half signed read expected 0xFFFFBEEF, got " &
                   to_hstring(read_data)
            severity error;

        -- =================================================================
        -- TEST 7: HALF-WORD WRITE then UNSIGNED READ
        -- 0xBEEF zero extended → 0x0000BEEF
        -- =================================================================
        address   <= x"00000040";
        mem_write <= '0';
        mem_read  <= '1';
        mem_size  <= "01";
        mem_sign  <= '1';      -- zero extend
        wait for 2 ns;
        assert read_data = x"0000BEEF"
            report "TEST 7 FAIL: Half unsigned read expected 0x0000BEEF, got " &
                   to_hstring(read_data)
            severity error;

        -- =================================================================
        -- TEST 8: POSITIVE byte sign extension (0x7F → 0x0000007F)
        -- 0x7F = 0111 1111 → MSB is 0, sign extend fills with 0
        -- =================================================================
        address    <= x"00000050";
        write_data <= x"0000007F";
        mem_write  <= '1';
        mem_read   <= '0';
        mem_size   <= "00";
        mem_sign   <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;

        mem_write <= '0';
        mem_read  <= '1';
        wait for 2 ns;
        assert read_data = x"0000007F"
            report "TEST 8 FAIL: Positive byte sign extend expected 0x0000007F, got " &
                   to_hstring(read_data)
            severity error;

        -- =================================================================
        -- TEST 9: READ with mem_read=0 should return 0x00000000
        -- =================================================================
        address   <= x"00000008";  -- has 0x00000400 written from test 1
        mem_read  <= '0';
        mem_write <= '0';
        mem_size  <= "10";
        wait for 2 ns;
        assert read_data = x"00000000"
            report "TEST 9 FAIL: Read with mem_read=0 should return 0x00000000"
            severity error;

        -- =================================================================
        -- TEST 10: OUT-OF-RANGE address — should return 0x00000000
        -- =================================================================
        address    <= x"FFFFFFF0";  -- way out of 4096-byte range
        mem_read   <= '1';
        mem_size   <= "10";
        wait for 2 ns;
        assert read_data = x"00000000"
            report "TEST 10 FAIL: Out-of-range read should return 0x00000000"
            severity error;

        -- =================================================================
        -- TEST 11: RESET clears previously written data
        -- =================================================================
        mem_read  <= '0';
        mem_write <= '0';
        reset     <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        reset     <= '0';

        address   <= x"00000008";   -- previously held 0x00000400
        mem_read  <= '1';
        mem_size  <= "10";
        wait for 2 ns;
        assert read_data = x"00000000"
            report "TEST 11 FAIL: After reset, address 0x08 should read 0x00000000"
            severity error;

        -- =================================================================
        report "TB_Data_Memory: All tests passed." severity note;
        wait;
    end process stim_proc;

end architecture Behavioral;
