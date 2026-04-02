-- =============================================================================
-- File        : Datapath.vhd
-- Entity      : MIPS_Datapath
-- Description : Complete 32-bit single-cycle MIPS datapath.
--               Instantiates and connects all CPU sub-components:
--                 Instruction_Memory, Control_Unit, Register_File,
--                 Sign_Extender, ALU_Control, ALU, Data_Memory.
--
--               Supports:
--                 - All R-type: ADD/ADDU/SUB/SUBU/AND/OR/XOR/NOR/SLT/SLTU
--                 - Shift: SLL/SRL/SRA (fixed) and SLLV/SRLV/SRAV (variable)
--                 - I-type: ADDI/ADDIU/SLTI/SLTIU/ANDI/ORI/XORI/LUI
--                 - Memory: LW/LH/LHU/LB/LBU/SW/SH/SB
--                 - Branch: BEQ, BNE
--                 - Jump: J, JAL
--                 - Register jump: JR
--
--               Observation ports (tb_*) for simulation/testbench use.
-- =============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity MIPS_Datapath is
    port (
        clk               : in  std_logic;
        rst               : in  std_logic;

        -- Testbench / debug observation ports
        tb_pc             : out std_logic_vector(31 downto 0);
        tb_instruction    : out std_logic_vector(31 downto 0);
        tb_alu_result     : out std_logic_vector(31 downto 0);
        tb_reg_write_data : out std_logic_vector(31 downto 0);
        tb_reg_write_dest : out std_logic_vector(4  downto 0);
        tb_reg_write_en   : out std_logic;
        tb_mem_read_data  : out std_logic_vector(31 downto 0);
        tb_branch_taken   : out std_logic;
        tb_dbg_regs       : out std_logic_vector(32*32-1 downto 0)
    );
end entity MIPS_Datapath;

architecture Structural of MIPS_Datapath is

    -- =========================================================================
    -- COMPONENT DECLARATIONS
    -- =========================================================================

    component Instruction_Memory_VHDL
        port (
            pc          : in  std_logic_vector(31 downto 0);
            instruction : out std_logic_vector(31 downto 0)
        );
    end component;

    component Control_Unit_VHDL
        port (
            opcode       : in  std_logic_vector(5 downto 0);
            funct        : in  std_logic_vector(5 downto 0);
            reset        : in  std_logic;
            reg_dst      : out std_logic_vector(1 downto 0);
            reg_write    : out std_logic;
            mem_read     : out std_logic;
            mem_write    : out std_logic;
            mem_to_reg   : out std_logic_vector(1 downto 0);
            mem_size     : out std_logic_vector(1 downto 0);
            mem_sign     : out std_logic;
            alu_src      : out std_logic;
            alu_op       : out std_logic_vector(1 downto 0);
            sign_or_zero : out std_logic;
            branch       : out std_logic;
            branch_ne    : out std_logic;
            jump         : out std_logic;
            jump_reg     : out std_logic;
            link         : out std_logic
        );
    end component;

    component Register_File_VHDL
        port (
            clk              : in  std_logic;
            reset            : in  std_logic;
            reg_write_en     : in  std_logic;
            reg_write_dest   : in  std_logic_vector(4  downto 0);
            reg_write_data   : in  std_logic_vector(31 downto 0);
            reg_read_addr_1  : in  std_logic_vector(4  downto 0);
            reg_read_data_1  : out std_logic_vector(31 downto 0);
            reg_read_addr_2  : in  std_logic_vector(4  downto 0);
            reg_read_data_2  : out std_logic_vector(31 downto 0);
            dbg_reg_file     : out std_logic_vector(32*32-1 downto 0)
        );
    end component;

    component Sign_Extender_VHDL
        port (
            sign_or_zero : in  std_logic;
            data_in      : in  std_logic_vector(15 downto 0);
            data_out     : out std_logic_vector(31 downto 0)
        );
    end component;

    component ALU_Control_VHDL
        port (
            ALUOp       : in  std_logic_vector(1 downto 0);
            ALU_Funct   : in  std_logic_vector(5 downto 0);
            ALU_Control : out std_logic_vector(3 downto 0)
        );
    end component;

    component ALU_VHDL
        port (
            a           : in  std_logic_vector(31 downto 0);
            b           : in  std_logic_vector(31 downto 0);
            shamt       : in  std_logic_vector(4  downto 0);
            hi_in       : in  std_logic_vector(31 downto 0);
            lo_in       : in  std_logic_vector(31 downto 0);
            alu_control : in  std_logic_vector(3  downto 0);
            alu_result  : out std_logic_vector(31 downto 0);
            zero        : out std_logic;
            negative    : out std_logic;
            overflow    : out std_logic;
            carry_out   : out std_logic
        );
    end component;

    component Data_Memory_VHDL
        port (
            clk        : in  std_logic;
            reset      : in  std_logic;
            address    : in  std_logic_vector(31 downto 0);
            write_data : in  std_logic_vector(31 downto 0);
            mem_write  : in  std_logic;
            mem_read   : in  std_logic;
            mem_size   : in  std_logic_vector(1 downto 0);
            mem_sign   : in  std_logic;
            read_data  : out std_logic_vector(31 downto 0)
        );
    end component;

    -- =========================================================================
    -- INSTRUCTION FIELD SIGNALS
    -- =========================================================================
    signal instruction     : std_logic_vector(31 downto 0);
    signal opcode_s        : std_logic_vector(5  downto 0);
    signal rs_s            : std_logic_vector(4  downto 0);
    signal rt_s            : std_logic_vector(4  downto 0);
    signal rd_s            : std_logic_vector(4  downto 0);
    signal shamt_s         : std_logic_vector(4  downto 0);
    signal funct_s         : std_logic_vector(5  downto 0);
    signal imm16_s         : std_logic_vector(15 downto 0);
    signal j_target_s      : std_logic_vector(25 downto 0);

    -- =========================================================================
    -- CONTROL SIGNALS
    -- =========================================================================
    signal ctrl_reg_dst      : std_logic_vector(1 downto 0);
    signal ctrl_reg_write    : std_logic;
    signal ctrl_mem_read     : std_logic;
    signal ctrl_mem_write    : std_logic;
    signal ctrl_mem_to_reg   : std_logic_vector(1 downto 0);
    signal ctrl_mem_size     : std_logic_vector(1 downto 0);
    signal ctrl_mem_sign     : std_logic;
    signal ctrl_alu_src      : std_logic;
    signal ctrl_alu_op       : std_logic_vector(1 downto 0);
    signal ctrl_sign_or_zero : std_logic;
    signal ctrl_branch       : std_logic;
    signal ctrl_branch_ne    : std_logic;
    signal ctrl_jump         : std_logic;
    signal ctrl_jump_reg     : std_logic;
    signal ctrl_link         : std_logic;

    -- =========================================================================
    -- DATAPATH SIGNALS
    -- =========================================================================
    -- Program counter
    signal PC              : std_logic_vector(31 downto 0) := (others => '0');
    signal PC_plus4        : std_logic_vector(31 downto 0);
    signal PC_next         : std_logic_vector(31 downto 0);

    -- Branch and jump targets
    signal branch_target   : std_logic_vector(31 downto 0);
    signal jump_target     : std_logic_vector(31 downto 0);
    signal branch_taken    : std_logic;

    -- Register file
    signal reg_data_1      : std_logic_vector(31 downto 0);
    signal reg_data_2      : std_logic_vector(31 downto 0);
    signal write_reg       : std_logic_vector(4  downto 0);
    signal write_data      : std_logic_vector(31 downto 0);

    -- Sign extender
    signal sign_ext_imm    : std_logic_vector(31 downto 0);

    -- ALU
    signal alu_ctrl_sig    : std_logic_vector(3  downto 0);
    signal alu_in_b        : std_logic_vector(31 downto 0);
    signal alu_shamt       : std_logic_vector(4  downto 0);
    signal alu_result_s    : std_logic_vector(31 downto 0);
    signal alu_zero        : std_logic;
    signal alu_negative    : std_logic;
    signal alu_overflow    : std_logic;
    signal alu_carry       : std_logic;

    -- HI/LO registers (for MULT/DIV passthrough, initialised to 0)
    signal hi_reg          : std_logic_vector(31 downto 0) := (others => '0');
    signal lo_reg          : std_logic_vector(31 downto 0) := (others => '0');

    -- Data memory
    signal mem_read_data_s : std_logic_vector(31 downto 0);

    -- Debug
    signal dbg_regs_s      : std_logic_vector(32*32-1 downto 0);

    -- ALU_Control funct hint: for I-type instructions, pass opcode as funct hint
    signal alu_funct_in    : std_logic_vector(5 downto 0);

begin

    -- =========================================================================
    -- INSTRUCTION FIELD DECODE (concurrent)
    -- =========================================================================
    opcode_s   <= instruction(31 downto 26);
    rs_s       <= instruction(25 downto 21);
    rt_s       <= instruction(20 downto 16);
    rd_s       <= instruction(15 downto 11);
    shamt_s    <= instruction(10 downto 6);
    funct_s    <= instruction(5  downto 0);
    imm16_s    <= instruction(15 downto 0);
    j_target_s <= instruction(25 downto 0);

    -- =========================================================================
    -- PC ARITHMETIC
    -- =========================================================================
    PC_plus4 <= std_logic_vector(unsigned(PC) + 4);

    -- Branch target: PC+4 + sign_ext(imm16) << 2
    branch_target <= std_logic_vector(
        unsigned(PC_plus4) +
        unsigned(sign_ext_imm(29 downto 0) & "00")
    );

    -- Jump target: {PC+4[31:28], j_target[25:0], "00"}
    jump_target <= PC_plus4(31 downto 28) & j_target_s & "00";

    -- Branch condition: BEQ takes if zero=1; BNE takes if zero=0
    branch_taken <= ctrl_branch and
                    (alu_zero xnor ctrl_branch_ne);
                    -- BEQ: branch_ne=0 → xnor with zero → taken when zero='1'
                    -- BNE: branch_ne=1 → xnor with zero → taken when zero='0'

    -- =========================================================================
    -- PC NEXT SELECT (combinational)
    -- Priority: JR > J/JAL > branch > PC+4
    -- =========================================================================
    pc_next_proc : process(
        ctrl_jump_reg, ctrl_jump, branch_taken,
        reg_data_1, jump_target, branch_target, PC_plus4
    )
    begin
        if ctrl_jump_reg = '1' then
            PC_next <= reg_data_1;          -- JR/JALR: target in RS
        elsif ctrl_jump = '1' then
            PC_next <= jump_target;          -- J/JAL
        elsif branch_taken = '1' then
            PC_next <= branch_target;        -- BEQ/BNE
        else
            PC_next <= PC_plus4;             -- Sequential
        end if;
    end process pc_next_proc;

    -- =========================================================================
    -- PC REGISTER (synchronous)
    -- =========================================================================
    pc_reg_proc : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                PC <= x"00000000";
            else
                PC <= PC_next;
            end if;
        end if;
    end process pc_reg_proc;

    -- =========================================================================
    -- REGISTER DESTINATION MUX
    -- "00"=rt (I-type), "01"=rd (R-type), "10"=$ra=31 (JAL)
    -- =========================================================================
    write_reg <= rt_s    when ctrl_reg_dst = "00" else
                 rd_s    when ctrl_reg_dst = "01" else
                 "11111";   -- $ra for JAL

    -- =========================================================================
    -- ALU SOURCE B MUX
    -- 0=register (RT), 1=sign/zero extended immediate
    -- =========================================================================
    alu_in_b <= reg_data_2 when ctrl_alu_src = '0' else sign_ext_imm;

    -- =========================================================================
    -- SHIFT AMOUNT SOURCE
    -- Variable shift (SLLV/SRLV/SRAV) uses RS[4:0]; fixed uses shamt field
    -- Detect variable shift: funct[2] = '1' for SLLV/SRLV/SRAV
    -- =========================================================================
    alu_shamt <= reg_data_1(4 downto 0) when (funct_s(2) = '1' and opcode_s = "000000")
                 else shamt_s;

    -- =========================================================================
    -- ALU_CONTROL FUNCT INPUT
    -- For R-type: use actual funct field
    -- For I-type ALU (ALUOp="11"): pass opcode as hint so ALU_Control
    --   can distinguish ADDI/ANDI/ORI/LUI etc.
    -- =========================================================================
    alu_funct_in <= funct_s when ctrl_alu_op = "10" else opcode_s;

    -- =========================================================================
    -- WRITE-BACK DATA MUX
    -- "00"=ALU result, "01"=data memory, "10"=PC+4 (JAL link)
    -- =========================================================================
    write_data <= alu_result_s    when ctrl_mem_to_reg = "00" else
                  mem_read_data_s when ctrl_mem_to_reg = "01" else
                  PC_plus4;          -- JAL saves return address

    -- =========================================================================
    -- OBSERVATION / TESTBENCH PORTS
    -- =========================================================================
    tb_pc             <= PC;
    tb_instruction    <= instruction;
    tb_alu_result     <= alu_result_s;
    tb_reg_write_data <= write_data;
    tb_reg_write_dest <= write_reg;
    tb_reg_write_en   <= ctrl_reg_write;
    tb_mem_read_data  <= mem_read_data_s;
    tb_branch_taken   <= branch_taken;
    tb_dbg_regs       <= dbg_regs_s;

    -- =========================================================================
    -- COMPONENT INSTANTIATIONS
    -- =========================================================================

    u_imem : Instruction_Memory_VHDL
        port map (
            pc          => PC,
            instruction => instruction
        );

    u_ctrl : Control_Unit_VHDL
        port map (
            opcode       => opcode_s,
            funct        => funct_s,
            reset        => rst,
            reg_dst      => ctrl_reg_dst,
            reg_write    => ctrl_reg_write,
            mem_read     => ctrl_mem_read,
            mem_write    => ctrl_mem_write,
            mem_to_reg   => ctrl_mem_to_reg,
            mem_size     => ctrl_mem_size,
            mem_sign     => ctrl_mem_sign,
            alu_src      => ctrl_alu_src,
            alu_op       => ctrl_alu_op,
            sign_or_zero => ctrl_sign_or_zero,
            branch       => ctrl_branch,
            branch_ne    => ctrl_branch_ne,
            jump         => ctrl_jump,
            jump_reg     => ctrl_jump_reg,
            link         => ctrl_link
        );

    u_regfile : Register_File_VHDL
        port map (
            clk              => clk,
            reset            => rst,
            reg_write_en     => ctrl_reg_write,
            reg_write_dest   => write_reg,
            reg_write_data   => write_data,
            reg_read_addr_1  => rs_s,
            reg_read_data_1  => reg_data_1,
            reg_read_addr_2  => rt_s,
            reg_read_data_2  => reg_data_2,
            dbg_reg_file     => dbg_regs_s
        );

    u_sext : Sign_Extender_VHDL
        port map (
            sign_or_zero => ctrl_sign_or_zero,
            data_in      => imm16_s,
            data_out     => sign_ext_imm
        );

    u_alu_ctrl : ALU_Control_VHDL
        port map (
            ALUOp       => ctrl_alu_op,
            ALU_Funct   => alu_funct_in,
            ALU_Control => alu_ctrl_sig
        );

    u_alu : ALU_VHDL
        port map (
            a           => reg_data_1,
            b           => alu_in_b,
            shamt       => alu_shamt,
            hi_in       => hi_reg,
            lo_in       => lo_reg,
            alu_control => alu_ctrl_sig,
            alu_result  => alu_result_s,
            zero        => alu_zero,
            negative    => alu_negative,
            overflow    => alu_overflow,
            carry_out   => alu_carry
        );

    u_dmem : Data_Memory_VHDL
        port map (
            clk        => clk,
            reset      => rst,
            address    => alu_result_s,
            write_data => reg_data_2,
            mem_write  => ctrl_mem_write,
            mem_read   => ctrl_mem_read,
            mem_size   => ctrl_mem_size,
            mem_sign   => ctrl_mem_sign,
            read_data  => mem_read_data_s
        );

end architecture Structural;
