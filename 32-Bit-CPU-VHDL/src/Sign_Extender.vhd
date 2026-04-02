-- =============================================================================
-- File        : Sign_Extender.vhd
-- Entity      : Sign_Extender_VHDL
-- Description : 16-to-32-bit immediate value extender.
--               - sign_or_zero = '0' → sign extension  (for ADDI, LW, SW, BEQ…)
--               - sign_or_zero = '1' → zero extension  (for ANDI, ORI, XORI)
--               - Purely combinational, no clock required
--               - Uses IEEE NUMERIC_STD resize for clean synthesis
-- =============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Sign_Extender_VHDL is
    port (
        sign_or_zero : in  std_logic;                      -- '0'=sign extend, '1'=zero extend
        data_in      : in  std_logic_vector(15 downto 0);  -- 16-bit immediate from instruction
        data_out     : out std_logic_vector(31 downto 0)   -- 32-bit extended result
    );
end entity Sign_Extender_VHDL;

architecture Behavioral of Sign_Extender_VHDL is
begin

    extend_proc : process(sign_or_zero, data_in)
    begin
        if sign_or_zero = '0' then
            -- Sign extension: replicate MSB into upper 16 bits
            -- resize(signed(...)) correctly propagates the sign bit
            data_out <= std_logic_vector(resize(signed(data_in), 32));
        else
            -- Zero extension: fill upper 16 bits with 0
            data_out <= std_logic_vector(resize(unsigned(data_in), 32));
        end if;
    end process extend_proc;

end architecture Behavioral;
