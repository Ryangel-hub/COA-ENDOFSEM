-- File        : ALU.vhd
-- Entity      : ALU_VHDL
-- Description : Full 32-bit combinational ALU for MIPS-like CPU.
--               Supports: ADD, ADDU, SUB, SUBU, AND, OR, XOR, NOR,
--                         SLT, SLTU, SLL, SRL, SRA, LUI,
--                         MFHI passthrough, MFLO passthrough.
--               Outputs : result, zero, negative, overflow, carry flags.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ALU_VHDL is
    port (
        -- Operand inputs
        a           : in  std_logic_vector(31 downto 0);   
        b           : in  std_logic_vector(31 downto 0);   
        shamt       : in  std_logic_vector(4  downto 0);   
        hi_in       : in  std_logic_vector(31 downto 0);   
        lo_in       : in  std_logic_vector(31 downto 0);   

        -- Operation select (4-bit)
        -- 0000=ADD  0001=SUB  0010=AND  0011=OR   0100=XOR  0101=NOR
        -- 0110=SLT  0111=SLTU 1000=SLL  1001=SRL  1010=SRA  1011=LUI
        -- 1100=MFHI 1101=MFLO 1110=ADDU 1111=SUBU
        alu_control : in  std_logic_vector(3  downto 0);

        -- Result and flags
        alu_result  : out std_logic_vector(31 downto 0);   -- Primary result
        zero        : out std_logic;                        -- Result == 0
        negative    : out std_logic;                        -- Result(31) == 1
        overflow    : out std_logic;                        -- Signed overflow
        carry_out   : out std_logic                         -- Unsigned carry out
    );
end entity ALU_VHDL;

architecture Behavioral of ALU_VHDL is

    -- Internal 33-bit result to capture carry
    signal result_33  : std_logic_vector(32 downto 0);
    signal result_32  : std_logic_vector(31 downto 0);
    signal ovf_flag   : std_logic;

begin

    -- Main ALU combinational process
    
    alu_proc : process(a, b, shamt, hi_in, lo_in, alu_control)
        variable va      : signed(31 downto 0);
        variable vb      : signed(31 downto 0);
        variable ua      : unsigned(31 downto 0);
        variable ub      : unsigned(31 downto 0);
        variable res     : std_logic_vector(31 downto 0);
        variable res33   : unsigned(32 downto 0);
        variable ovf     : std_logic;
        variable shift_a : unsigned(31 downto 0);
        variable shift_n : integer range 0 to 31;
    begin
        va      := signed(a);
        vb      := signed(b);
        ua      := unsigned(a);
        ub      := unsigned(b);
        res     := (others => '0');
        res33   := (others => '0');
        ovf     := '0';
        shift_n := to_integer(unsigned(shamt));

        case alu_control is

            -- ADD (signed, detect overflow)
            when "0000" =>
                res33 := ('0' & ua) + ('0' & ub);
                res   := std_logic_vector(res33(31 downto 0));
                -- Overflow: (+)+(+)=(-) or (-)+(-)=(+)
                if (a(31) = '0' and b(31) = '0' and res(31) = '1') or
                   (a(31) = '1' and b(31) = '1' and res(31) = '0') then
                    ovf := '1';
                end if;

            -- SUB (signed, detect overflow)
            when "0001" =>
                res33 := ('0' & ua) - ('0' & ub);
                res   := std_logic_vector(res33(31 downto 0));
                -- Overflow: (+)-(-)=(-) or (-) -(+)=(+)
                if (a(31) = '0' and b(31) = '1' and res(31) = '1') or
                   (a(31) = '1' and b(31) = '0' and res(31) = '0') then
                    ovf := '1';
                end if;

            -- AND
            when "0010" =>
                res := a and b;

            -- OR
            when "0011" =>
                res := a or b;

            -- XOR
            when "0100" =>
                res := a xor b;

            -- NOR
            when "0101" =>
                res := a nor b;

            -- SLT — Set Less Than (signed)
            when "0110" =>
                if va < vb then
                    res := x"00000001";
                else
                    res := x"00000000";
                end if;

            -- SLTU — Set Less Than Unsigned
            when "0111" =>
                if ua < ub then
                    res := x"00000001";
                else
                    res := x"00000000";
                end if;

            -- SLL — Shift Left Logical (uses shamt)
            when "1000" =>
                shift_a := unsigned(b);
                res := std_logic_vector(shift_left(shift_a, shift_n));

            -- SRL — Shift Right Logical (uses shamt)
            when "1001" =>
                shift_a := unsigned(b);
                res := std_logic_vector(shift_right(shift_a, shift_n));

            -- SRA — Shift Right Arithmetic (uses shamt, sign-fills)
            when "1010" =>
                res := std_logic_vector(shift_right(signed(b), shift_n));

            -- LUI — Load Upper Immediate (b[15:0] << 16)
            when "1011" =>
                res := b(15 downto 0) & x"0000";

            -- MFHI — Move From HI register
            when "1100" =>
                res := hi_in;

            -- MFLO — Move From LO register
            when "1101" =>
                res := lo_in;

            -- ADDU — Add Unsigned (no overflow exception)
            when "1110" =>
                res33 := ('0' & ua) + ('0' & ub);
                res   := std_logic_vector(res33(31 downto 0));
                -- carry_out set below from res33(32); no signed overflow

            -- SUBU — Subtract Unsigned (no overflow exception)
            when "1111" =>
                res33 := ('0' & ua) - ('0' & ub);
                res   := std_logic_vector(res33(31 downto 0));

            when others =>
                res := (others => '0');

        end case;

        result_32 <= res;
        result_33 <= std_logic_vector(res33);
        ovf_flag  <= ovf;

    end process alu_proc;


    -- Output assignments
    alu_result <= result_32;

    -- Zero flag: all bits of result are 0
    zero <= '1' when result_32 = x"00000000" else '0';

    -- Negative flag: MSB of result
    negative <= result_32(31);

    -- Signed overflow flag (only meaningful for ADD/SUB)
    overflow <= ovf_flag;

    -- Carry out: bit 32 of the 33-bit internal result
    carry_out <= result_33(32);

end architecture Behavioral;
