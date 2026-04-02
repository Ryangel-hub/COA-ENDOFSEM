-- =============================================================================
-- File        : ALU_Control.vhd
-- Entity      : ALU_Control_VHDL
-- Description : Decodes 2-bit ALUOp + 6-bit funct field into 4-bit ALU
--               control signal for the ALU_VHDL entity.
--
--   ALUOp encoding (from main Control Unit):
--     00 = Load/Store  → ADD
--     01 = BEQ/BNE     → SUB
--     10 = R-type      → decode funct field
--     11 = I-type ALU  → decode from opcode context (passed via funct)
--
--   ALU Control output (4-bit) matches ALU_VHDL alu_control port:
--     0000=ADD  0001=SUB  0010=AND  0011=OR   0100=XOR  0101=NOR
--     0110=SLT  0111=SLTU 1000=SLL  1001=SRL  1010=SRA  1011=LUI
--     1100=MFHI 1101=MFLO 1110=ADDU 1111=SUBU
-- =============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity ALU_Control_VHDL is
    port (
        ALUOp       : in  std_logic_vector(1 downto 0);  -- From main control unit
        ALU_Funct   : in  std_logic_vector(5 downto 0);  -- Instruction funct/opcode hint
        ALU_Control : out std_logic_vector(3 downto 0)   -- To ALU (expanded to 4-bit)
    );
end entity ALU_Control_VHDL;

architecture Behavioral of ALU_Control_VHDL is
begin

    decode_proc : process(ALUOp, ALU_Funct)
    begin
        case ALUOp is

            -- ----------------------------------------------------------------
            -- 00: Memory access (LW/SW) — always ADD for address calculation
            -- ----------------------------------------------------------------
            when "00" =>
                ALU_Control <= "0000";   -- ADD

            -- ----------------------------------------------------------------
            -- 01: Branch (BEQ/BNE) — always SUB for comparison
            -- ----------------------------------------------------------------
            when "01" =>
                ALU_Control <= "0001";   -- SUB

            -- ----------------------------------------------------------------
            -- 10: R-type — decode full 6-bit funct field
            -- ----------------------------------------------------------------
            when "10" =>
                case ALU_Funct is
                    when "100000" => ALU_Control <= "0000";  -- ADD  (signed)
                    when "100001" => ALU_Control <= "1110";  -- ADDU (unsigned)
                    when "100010" => ALU_Control <= "0001";  -- SUB  (signed)
                    when "100011" => ALU_Control <= "1111";  -- SUBU (unsigned)
                    when "100100" => ALU_Control <= "0010";  -- AND
                    when "100101" => ALU_Control <= "0011";  -- OR
                    when "100110" => ALU_Control <= "0100";  -- XOR
                    when "100111" => ALU_Control <= "0101";  -- NOR
                    when "101010" => ALU_Control <= "0110";  -- SLT  (signed)
                    when "101011" => ALU_Control <= "0111";  -- SLTU (unsigned)
                    when "000000" => ALU_Control <= "1000";  -- SLL
                    when "000010" => ALU_Control <= "1001";  -- SRL
                    when "000011" => ALU_Control <= "1010";  -- SRA
                    when "000100" => ALU_Control <= "1000";  -- SLLV (shift left, variable)
                    when "000110" => ALU_Control <= "1001";  -- SRLV (shift right logical, variable)
                    when "000111" => ALU_Control <= "1010";  -- SRAV (shift right arith, variable)
                    when "010000" => ALU_Control <= "1100";  -- MFHI
                    when "010010" => ALU_Control <= "1101";  -- MFLO
                    when "001000" => ALU_Control <= "0000";  -- JR   (ALU not used, ADD is safe)
                    when "001001" => ALU_Control <= "0000";  -- JALR (same)
                    when others   => ALU_Control <= "0000";  -- Default: ADD (safe NOP)
                end case;

            -- ----------------------------------------------------------------
            -- 11: I-type ALU — funct field carries opcode hint from CU
            --     ADDI/ADDIU → ADD, SLTI → SLT, SLTIU → SLTU,
            --     ANDI → AND, ORI → OR, XORI → XOR, LUI → LUI
            -- ----------------------------------------------------------------
            when "11" =>
                case ALU_Funct is
                    when "001000" => ALU_Control <= "0000";  -- ADDI
                    when "001001" => ALU_Control <= "1110";  -- ADDIU
                    when "001010" => ALU_Control <= "0110";  -- SLTI
                    when "001011" => ALU_Control <= "0111";  -- SLTIU
                    when "001100" => ALU_Control <= "0010";  -- ANDI
                    when "001101" => ALU_Control <= "0011";  -- ORI
                    when "001110" => ALU_Control <= "0100";  -- XORI
                    when "001111" => ALU_Control <= "1011";  -- LUI
                    when others   => ALU_Control <= "0000";  -- Default: ADD
                end case;

            when others =>
                ALU_Control <= "0000";   -- Safe default

        end case;
    end process decode_proc;

end architecture Behavioral;
