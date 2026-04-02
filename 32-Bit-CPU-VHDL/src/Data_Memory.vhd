-- =============================================================================
-- File        : Data_Memory.vhd
-- Entity      : Data_Memory_VHDL
-- Description : 32-bit byte-addressable data memory (RAM).
--               - 4096 bytes (1024 words) of storage
--               - Supports word (32-bit), half-word (16-bit), byte (8-bit) access
--               - Synchronous write, asynchronous (combinational) read
--               - Signed and unsigned extension on sub-word reads
--               - Word-aligned and byte-addressed
--               - Initialised to zero on reset
-- =============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Data_Memory_VHDL is
    port (
        clk          : in  std_logic;
        reset        : in  std_logic;

        -- Address and data
        address      : in  std_logic_vector(31 downto 0);  -- Byte address
        write_data   : in  std_logic_vector(31 downto 0);  -- Data to write

        -- Control
        mem_write    : in  std_logic;                       -- Write enable
        mem_read     : in  std_logic;                       -- Read enable
        mem_size     : in  std_logic_vector(1 downto 0);   -- 00=byte,01=half,10=word
        mem_sign     : in  std_logic;                       -- 0=sign extend, 1=zero extend

        -- Output
        read_data    : out std_logic_vector(31 downto 0)   -- Data read from memory
    );
end entity Data_Memory_VHDL;

architecture Behavioral of Data_Memory_VHDL is

    -- Byte-addressable memory: 4096 bytes = 1024 x 32-bit words
    constant MEM_BYTES : integer := 4096;
    type byte_mem_t is array (0 to MEM_BYTES - 1) of std_logic_vector(7 downto 0);
    signal mem : byte_mem_t := (others => (others => '0'));

    -- Internal read result before sign extension
    signal raw_read : std_logic_vector(31 downto 0);

begin

    -- =========================================================================
    -- SYNCHRONOUS WRITE PROCESS
    -- Writes on rising clock edge when mem_write = '1'
    -- Supports byte, half-word, and word granularity
    -- =========================================================================
    write_proc : process(clk)
        variable byte_addr : integer;
    begin
        if rising_edge(clk) then
            if reset = '1' then
                mem <= (others => (others => '0'));
            elsif mem_write = '1' then
                byte_addr := to_integer(unsigned(address));

                case mem_size is
                    -- Byte write: write only lowest byte
                    when "00" =>
                        if byte_addr < MEM_BYTES then
                            mem(byte_addr) <= write_data(7 downto 0);
                        end if;

                    -- Half-word write: write 2 bytes (big-endian)
                    when "01" =>
                        if byte_addr + 1 < MEM_BYTES then
                            mem(byte_addr)     <= write_data(15 downto 8);
                            mem(byte_addr + 1) <= write_data(7  downto 0);
                        end if;

                    -- Word write: write 4 bytes (big-endian)
                    when "10" | "11" =>
                        if byte_addr + 3 < MEM_BYTES then
                            mem(byte_addr)     <= write_data(31 downto 24);
                            mem(byte_addr + 1) <= write_data(23 downto 16);
                            mem(byte_addr + 2) <= write_data(15 downto 8);
                            mem(byte_addr + 3) <= write_data(7  downto 0);
                        end if;

                    when others => null;
                end case;
            end if;
        end if;
    end process write_proc;

    -- =========================================================================
    -- ASYNCHRONOUS (COMBINATIONAL) READ PROCESS
    -- Reads immediately from memory array based on address and size
    -- =========================================================================
    read_proc : process(mem_read, address, mem_size, mem_sign, mem)
        variable byte_addr : integer;
        variable b0, b1, b2, b3 : std_logic_vector(7 downto 0);
    begin
        raw_read <= (others => '0');

        if mem_read = '1' then
            -- Convert address to integer with safe bounds checking
            if unsigned(address) < MEM_BYTES then
                byte_addr := to_integer(unsigned(address));

                case mem_size is
                    -- --------------------------------------------------------
                    -- Byte read: read 1 byte, sign or zero extend to 32 bits
                    -- --------------------------------------------------------
                    when "00" =>
                        b0 := mem(byte_addr);
                        if mem_sign = '1' then
                            -- Zero extend
                            raw_read <= x"000000" & b0;
                        else
                            -- Sign extend
                            raw_read <= (31 downto 8 => b0(7)) & b0;
                        end if;

                    -- --------------------------------------------------------
                    -- Half-word read: read 2 bytes, sign or zero extend
                    -- --------------------------------------------------------
                    when "01" =>
                        if byte_addr + 1 < MEM_BYTES then
                            b0 := mem(byte_addr);
                            b1 := mem(byte_addr + 1);
                            if mem_sign = '1' then
                                raw_read <= x"0000" & b0 & b1;
                            else
                                raw_read <= (31 downto 16 => b0(7)) & b0 & b1;
                            end if;
                        end if;

                    -- --------------------------------------------------------
                    -- Word read: read 4 bytes (big-endian), no extension needed
                    -- --------------------------------------------------------
                    when "10" | "11" =>
                        if byte_addr + 3 < MEM_BYTES then
                            b0 := mem(byte_addr);
                            b1 := mem(byte_addr + 1);
                            b2 := mem(byte_addr + 2);
                            b3 := mem(byte_addr + 3);
                            raw_read <= b0 & b1 & b2 & b3;
                        end if;

                    when others =>
                        raw_read <= (others => '0');
                end case;

            end if;
        end if;
    end process read_proc;

    -- Output the read data directly
    read_data <= raw_read;

end architecture Behavioral;
