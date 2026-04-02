-- =============================================================================
-- File        : Control_Unit.vhd
-- Entity      : Control_Unit_VHDL
-- Description : Main control unit for 32-bit single-cycle MIPS CPU.
--               Decodes 6-bit opcode and generates all datapath control
--               signals. Supports R-type, I-type, and J-type instructions.
--
--   reg_dst   : "00"=rt, "01"=rd, "10"=$ra(31)  (write-back destination)
--   mem_to_reg: "00"=ALU result, "01"=memory, "10"=PC+4 (for JAL)
--   alu_op    : "00"=ADD, "01"=SUB, "10"=R-type, "11"=I-type ALU
-- =============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity Control_Unit_VHDL is
    port (
        opcode       : in  std_logic_vector(5 downto 0);  -- Instruction [31:26]
        funct        : in  std_logic_vector(5 downto 0);  -- Instruction [5:0] for JR detect
        reset        : in  std_logic;                     -- Synchronous reset

        -- Register file control
        reg_dst      : out std_logic_vector(1 downto 0);  -- Dest reg select
        reg_write    : out std_logic;                      -- Write enable to reg file

        -- Memory control
        mem_read     : out std_logic;                      -- Data memory read
        mem_write    : out std_logic;                      -- Data memory write
        mem_to_reg   : out std_logic_vector(1 downto 0);  -- Write-back source select
        mem_size     : out std_logic_vector(1 downto 0);  -- 00=byte,01=half,10=word
        mem_sign     : out std_logic;                      -- 0=signed, 1=unsigned extend

        -- ALU control
        alu_src      : out std_logic;                      -- 0=reg, 1=immediate
        alu_op       : out std_logic_vector(1 downto 0);  -- ALU operation class
        sign_or_zero : out std_logic;                      -- Immediate: 0=zero, 1=sign extend

        -- Branch / Jump control
        branch       : out std_logic;                      -- BEQ/BNE branch
        branch_ne    : out std_logic;                      -- 1=BNE, 0=BEQ
        jump         : out std_logic;                      -- J/JAL unconditional jump
        jump_reg     : out std_logic;                      -- JR/JALR register jump
        link         : out std_logic                       -- JAL/JALR: save PC+4 to $ra
    );
end entity Control_Unit_VHDL;

architecture Behavioral of Control_Unit_VHDL is

    -- Internal procedure to set all outputs to safe NOP defaults
    -- (VHDL doesn't support procedures setting ports directly in
    --  a process, so we use a local variable bundle approach instead)

begin

    ctrl_decode : process(reset, opcode, funct)
    begin
        -- ----------------------------------------------------------------
        -- Default all outputs to NOP/safe values first.
        -- This prevents accidental latches and makes each case minimal.
        -- ----------------------------------------------------------------
        reg_dst      <= "00";
        reg_write    <= '0';
        mem_read     <= '0';
        mem_write    <= '0';
        mem_to_reg   <= "00";
        mem_size     <= "10";   -- default word
        mem_sign     <= '0';
        alu_src      <= '0';
        alu_op       <= "00";
        sign_or_zero <= '0';
        branch       <= '0';
        branch_ne    <= '0';
        jump         <= '0';
        jump_reg     <= '0';
        link         <= '0';

        if reset = '1' then
            null;  -- All defaults already applied above

        else
            case opcode is

                -- ------------------------------------------------------------
                -- R-TYPE (opcode = 000000)
                -- Covers: ADD, ADDU, SUB, SUBU, AND, OR, XOR, NOR,
                --         SLT, SLTU, SLL, SRL, SRA, SLLV, SRLV, SRAV,
                --         MFHI, MFLO, MULT, MULTU, DIV, DIVU, JR, JALR
                -- ------------------------------------------------------------
                when "000000" =>
                    -- Check for register-jump instructions via funct
                    if funct = "001000" then
                        -- JR: jump to RS, no write-back
                        jump_reg  <= '1';
                        reg_write <= '0';
                    elsif funct = "001001" then
                        -- JALR: jump to RS, write PC+4 to RD
                        jump_reg  <= '1';
                        link      <= '1';
                        reg_dst   <= "01";   -- write to rd
                        mem_to_reg<= "10";   -- write PC+4
                        reg_write <= '1';
                    else
                        -- All standard R-type arithmetic/logic/shift
                        reg_dst   <= "01";   -- destination = rd
                        alu_op    <= "10";   -- R-type ALU decode
                        reg_write <= '1';
                    end if;

                -- ------------------------------------------------------------
                -- ADDI (001000): rt = rs + sign_ext(imm)
                -- ------------------------------------------------------------
                when "001000" =>
                    reg_dst      <= "00";   -- dest = rt
                    alu_src      <= '1';   -- B = immediate
                    alu_op       <= "11";  -- I-type ALU, pass opcode hint
                    sign_or_zero <= '1';   -- sign extend
                    reg_write    <= '1';

                -- ------------------------------------------------------------
                -- ADDIU (001001): rt = rs + sign_ext(imm), no overflow
                -- ------------------------------------------------------------
                when "001001" =>
                    reg_dst      <= "00";
                    alu_src      <= '1';
                    alu_op       <= "11";
                    sign_or_zero <= '1';
                    reg_write    <= '1';

                -- ------------------------------------------------------------
                -- SLTI (001010): rt = (rs < sign_ext(imm)) ? 1 : 0 signed
                -- ------------------------------------------------------------
                when "001010" =>
                    reg_dst      <= "00";
                    alu_src      <= '1';
                    alu_op       <= "11";
                    sign_or_zero <= '1';
                    reg_write    <= '1';

                -- ------------------------------------------------------------
                -- SLTIU (001011): unsigned version
                -- ------------------------------------------------------------
                when "001011" =>
                    reg_dst      <= "00";
                    alu_src      <= '1';
                    alu_op       <= "11";
                    sign_or_zero <= '1';
                    reg_write    <= '1';

                -- ------------------------------------------------------------
                -- ANDI (001100): rt = rs AND zero_ext(imm)
                -- ------------------------------------------------------------
                when "001100" =>
                    reg_dst      <= "00";
                    alu_src      <= '1';
                    alu_op       <= "11";
                    sign_or_zero <= '0';   -- zero extend for bitwise
                    reg_write    <= '1';

                -- ------------------------------------------------------------
                -- ORI (001101): rt = rs OR zero_ext(imm)
                -- ------------------------------------------------------------
                when "001101" =>
                    reg_dst      <= "00";
                    alu_src      <= '1';
                    alu_op       <= "11";
                    sign_or_zero <= '0';
                    reg_write    <= '1';

                -- ------------------------------------------------------------
                -- XORI (001110): rt = rs XOR zero_ext(imm)
                -- ------------------------------------------------------------
                when "001110" =>
                    reg_dst      <= "00";
                    alu_src      <= '1';
                    alu_op       <= "11";
                    sign_or_zero <= '0';
                    reg_write    <= '1';

                -- ------------------------------------------------------------
                -- LUI (001111): rt = imm << 16
                -- ------------------------------------------------------------
                when "001111" =>
                    reg_dst      <= "00";
                    alu_src      <= '1';
                    alu_op       <= "11";
                    sign_or_zero <= '0';
                    reg_write    <= '1';

                -- ------------------------------------------------------------
                -- LW (100011): rt = MEM[rs + sign_ext(imm)]
                -- ------------------------------------------------------------
                when "100011" =>
                    reg_dst      <= "00";
                    alu_src      <= '1';
                    alu_op       <= "00";  -- ADD for address
                    sign_or_zero <= '1';
                    mem_read     <= '1';
                    mem_to_reg   <= "01";  -- from memory
                    mem_size     <= "10";  -- word
                    mem_sign     <= '0';
                    reg_write    <= '1';

                -- ------------------------------------------------------------
                -- LH (100001): load half word signed
                -- ------------------------------------------------------------
                when "100001" =>
                    reg_dst      <= "00";
                    alu_src      <= '1';
                    alu_op       <= "00";
                    sign_or_zero <= '1';
                    mem_read     <= '1';
                    mem_to_reg   <= "01";
                    mem_size     <= "01";  -- half word
                    mem_sign     <= '0';   -- signed extend
                    reg_write    <= '1';

                -- ------------------------------------------------------------
                -- LHU (100101): load half word unsigned
                -- ------------------------------------------------------------
                when "100101" =>
                    reg_dst      <= "00";
                    alu_src      <= '1';
                    alu_op       <= "00";
                    sign_or_zero <= '1';
                    mem_read     <= '1';
                    mem_to_reg   <= "01";
                    mem_size     <= "01";
                    mem_sign     <= '1';   -- zero extend (unsigned)
                    reg_write    <= '1';

                -- ------------------------------------------------------------
                -- LB (100000): load byte signed
                -- ------------------------------------------------------------
                when "100000" =>
                    reg_dst      <= "00";
                    alu_src      <= '1';
                    alu_op       <= "00";
                    sign_or_zero <= '1';
                    mem_read     <= '1';
                    mem_to_reg   <= "01";
                    mem_size     <= "00";  -- byte
                    mem_sign     <= '0';
                    reg_write    <= '1';

                -- ------------------------------------------------------------
                -- LBU (100100): load byte unsigned
                -- ------------------------------------------------------------
                when "100100" =>
                    reg_dst      <= "00";
                    alu_src      <= '1';
                    alu_op       <= "00";
                    sign_or_zero <= '1';
                    mem_read     <= '1';
                    mem_to_reg   <= "01";
                    mem_size     <= "00";
                    mem_sign     <= '1';
                    reg_write    <= '1';

                -- ------------------------------------------------------------
                -- SW (101011): MEM[rs + sign_ext(imm)] = rt
                -- ------------------------------------------------------------
                when "101011" =>
                    alu_src      <= '1';
                    alu_op       <= "00";
                    sign_or_zero <= '1';
                    mem_write    <= '1';
                    mem_size     <= "10";

                -- ------------------------------------------------------------
                -- SH (101001): store half word
                -- ------------------------------------------------------------
                when "101001" =>
                    alu_src      <= '1';
                    alu_op       <= "00";
                    sign_or_zero <= '1';
                    mem_write    <= '1';
                    mem_size     <= "01";

                -- ------------------------------------------------------------
                -- SB (101000): store byte
                -- ------------------------------------------------------------
                when "101000" =>
                    alu_src      <= '1';
                    alu_op       <= "00";
                    sign_or_zero <= '1';
                    mem_write    <= '1';
                    mem_size     <= "00";

                -- ------------------------------------------------------------
                -- BEQ (000100): branch if rs == rt (ALU SUB, check zero)
                -- ------------------------------------------------------------
                when "000100" =>
                    alu_op       <= "01";  -- SUB for comparison
                    sign_or_zero <= '1';
                    branch       <= '1';
                    branch_ne    <= '0';

                -- ------------------------------------------------------------
                -- BNE (000101): branch if rs != rt
                -- ------------------------------------------------------------
                when "000101" =>
                    alu_op       <= "01";
                    sign_or_zero <= '1';
                    branch       <= '1';
                    branch_ne    <= '1';

                -- ------------------------------------------------------------
                -- BLEZ (000110): branch if rs <= 0
                -- ------------------------------------------------------------
                when "000110" =>
                    alu_op       <= "01";
                    sign_or_zero <= '1';
                    branch       <= '1';

                -- ------------------------------------------------------------
                -- BGTZ (000111): branch if rs > 0
                -- ------------------------------------------------------------
                when "000111" =>
                    alu_op       <= "01";
                    sign_or_zero <= '1';
                    branch       <= '1';

                -- ------------------------------------------------------------
                -- J (000010): unconditional jump
                -- ------------------------------------------------------------
                when "000010" =>
                    jump <= '1';

                -- ------------------------------------------------------------
                -- JAL (000011): jump and link — save PC+4 to $ra (reg 31)
                -- ------------------------------------------------------------
                when "000011" =>
                    jump         <= '1';
                    link         <= '1';
                    reg_dst      <= "10";   -- dest = $ra = register 31
                    mem_to_reg   <= "10";   -- write PC+4 to $ra
                    reg_write    <= '1';

                -- ------------------------------------------------------------
                -- Unknown/unimplemented opcode — NOP (all defaults)
                -- ------------------------------------------------------------
                when others =>
                    null;

            end case;
        end if;
    end process ctrl_decode;

end architecture Behavioral;
