-- =============================================================================
-- File        : Register_File.vhd
-- Entity      : Register_File_VHDL
-- Description : 32 x 32-bit general purpose register file.
--               - Two asynchronous (combinational) read ports
--               - One synchronous write port (rising clock edge)
--               - Register $zero (index 0) is hardwired to 0x00000000
--                 and can never be written
--               - Synchronous reset clears all registers to 0
--               - Optional debug port exposes full register array
-- =============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Register_File_VHDL is
    port (
        clk              : in  std_logic;
        reset            : in  std_logic;

        -- Write port (synchronous)
        reg_write_en     : in  std_logic;                      -- Write enable
        reg_write_dest   : in  std_logic_vector(4  downto 0);  -- Destination register (0–31)
        reg_write_data   : in  std_logic_vector(31 downto 0);  -- Data to write

        -- Read port 1 (asynchronous)
        reg_read_addr_1  : in  std_logic_vector(4  downto 0);  -- Register address
        reg_read_data_1  : out std_logic_vector(31 downto 0);  -- Register value

        -- Read port 2 (asynchronous)
        reg_read_addr_2  : in  std_logic_vector(4  downto 0);  -- Register address
        reg_read_data_2  : out std_logic_vector(31 downto 0);  -- Register value

        -- Debug: expose full register file (synthesis can optimise away if unused)
        dbg_reg_file     : out std_logic_vector(32*32-1 downto 0)
    );
end entity Register_File_VHDL;

architecture Behavioral of Register_File_VHDL is

    type reg_array_t is array (0 to 31) of std_logic_vector(31 downto 0);

    -- Initialise all registers to zero at elaboration time
    signal regs : reg_array_t := (others => (others => '0'));

begin

    -- =========================================================================
    -- SYNCHRONOUS WRITE + RESET
    -- Register 0 ($zero) is never written — enforced here.
    -- All registers cleared to 0 on synchronous reset.
    -- =========================================================================
    write_proc : process(clk)
        variable waddr : integer range 0 to 31;
    begin
        if rising_edge(clk) then
            if reset = '1' then
                regs <= (others => (others => '0'));
            else
                waddr := to_integer(unsigned(reg_write_dest));
                -- Guard: never write to $zero (register 0)
                if reg_write_en = '1' and waddr /= 0 then
                    regs(waddr) <= reg_write_data;
                end if;
            end if;
        end if;
    end process write_proc;

    -- =========================================================================
    -- ASYNCHRONOUS READ PORT 1
    -- $zero always returns 0 regardless of stored value.
    -- =========================================================================
    reg_read_data_1 <= (others => '0')
                        when reg_read_addr_1 = "00000"
                        else regs(to_integer(unsigned(reg_read_addr_1)));

    -- =========================================================================
    -- ASYNCHRONOUS READ PORT 2
    -- =========================================================================
    reg_read_data_2 <= (others => '0')
                        when reg_read_addr_2 = "00000"
                        else regs(to_integer(unsigned(reg_read_addr_2)));

    -- =========================================================================
    -- DEBUG OUTPUT
    -- Packs all 32 registers into one wide vector for waveform viewing.
    -- regs(0) occupies bits [31:0], regs(1) bits [63:32], etc.
    -- =========================================================================
    gen_debug : for i in 0 to 31 generate
        dbg_reg_file((i+1)*32-1 downto i*32) <= regs(i);
    end generate gen_debug;

end architecture Behavioral;
