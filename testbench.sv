interface axi_if;
    logic clk, resetn;
    logic awvalid, awready;
    logic arvalid, arready;
    logic wvalid, wready;
    logic bready, bvalid;
    logic rvalid, rready;
    logic [31:0] awaddr, araddr, wdata, rdata;
    logic [1:0]  bresp, rresp;
endinterface


class transaction;

    randc bit        op;
    rand  bit [31:0] awaddr;
    rand  bit [31:0] wdata;
    rand  bit [31:0] araddr;
          bit [31:0] rdata;
          bit [1:0]  bresp;
          bit [1:0]  rresp;

    constraint valid_addr_range {
        awaddr < 128;
        araddr < 128;
    }

    constraint valid_data_range {
        wdata < 12;
    }

endclass


//////////////////////////////////

class generator;

    transaction tr;
    mailbox #(transaction) mbxgd;

    event done;
    event sconext;

    int count = 0;

    function new(mailbox #(transaction) mbxgd);
        this.mbxgd = mbxgd;
        tr = new();
    endfunction

    task run();
        for (int i = 0; i < count; i++)
        begin
            assert(tr.randomize())
            else $error("Randomization Failed");

            $display("[GEN] : OP : %0b awaddr : %0d wdata : %0d araddr : %0d",
                     tr.op, tr.awaddr, tr.wdata, tr.araddr);

            mbxgd.put(tr);
            @(sconext);
        end

        ->done;
    endtask

endclass


//////////////////////////////////

class driver;

    virtual axi_if vif;

    transaction tr;

    mailbox #(transaction) mbxgd;
    mailbox #(transaction) mbxdm;

    function new(
        mailbox #(transaction) mbxgd,
        mailbox #(transaction) mbxdm
    );
        this.mbxgd = mbxgd;
        this.mbxdm = mbxdm;
    endfunction


    ////////////////// Resetting System

    task reset();

        vif.resetn  <= 1'b0;

        vif.awvalid <= 1'b0;
        vif.awaddr  <= 0;

        vif.wvalid  <= 1'b0;
        vif.wdata   <= 0;

        vif.bready  <= 1'b0;

        vif.arvalid <= 1'b0;
        vif.araddr  <= 0;

        vif.rready  <= 1'b0;

        repeat (5) @(posedge vif.clk);

        vif.resetn <= 1'b1;

        $display("-----------------[DRV] : RESET DONE-----------------------------");

    endtask


    task write_data(input transaction tr);

        $display("[DRV] : OP : %0b awaddr : %0d wdata : %0d",
                 tr.op, tr.awaddr, tr.wdata);

        mbxdm.put(tr);

        vif.resetn  <= 1'b1;

        vif.awvalid <= 1'b1;
        vif.arvalid <= 1'b0;
        vif.araddr  <= 0;

        vif.awaddr  <= tr.awaddr;

        @(negedge vif.awready);

        vif.awvalid <= 1'b0;
        vif.awaddr  <= 0;

        vif.wvalid  <= 1'b1;
        vif.wdata   <= tr.wdata;

        @(negedge vif.wready);

        vif.wvalid  <= 1'b0;
        vif.wdata   <= 0;

        vif.bready  <= 1'b1;
        vif.rready  <= 1'b0;

        @(negedge vif.bvalid);

        vif.bready  <= 1'b0;

    endtask


    task read_data(input transaction tr);

        $display("[DRV] : OP : %0b araddr : %0d",
                 tr.op, tr.araddr);

        mbxdm.put(tr);

        vif.resetn  <= 1'b1;

        vif.awvalid <= 1'b0;
        vif.awaddr  <= 0;

        vif.wvalid  <= 1'b0;
        vif.wdata   <= 0;

        vif.bready  <= 1'b0;

        vif.arvalid <= 1'b1;
        vif.araddr  <= tr.araddr;

        @(negedge vif.arready);

        vif.araddr  <= 0;
        vif.arvalid <= 1'b0;

        vif.rready  <= 1'b1;

        @(negedge vif.rvalid);

        vif.rready  <= 1'b0;

    endtask


    task run();

        forever
        begin

            mbxgd.get(tr);

            @(posedge vif.clk);

            if (tr.op == 1'b1)
                write_data(tr);
            else
                read_data(tr);

        end

    endtask

endclass


///////////////////////////////////////////////////////

class monitor;

    virtual axi_if vif;

    transaction tr, trd;

    mailbox #(transaction) mbxms;
    mailbox #(transaction) mbxdm;

    function new(
        mailbox #(transaction) mbxms,
        mailbox #(transaction) mbxdm
    );
        this.mbxms = mbxms;
        this.mbxdm = mbxdm;
    endfunction


    task run();

        tr = new();

        forever
        begin

            @(posedge vif.clk);

            mbxdm.get(trd);

            if (trd.op == 1)
            begin

                tr.op     = trd.op;
                tr.awaddr = trd.awaddr;
                tr.wdata  = trd.wdata;

                @(posedge vif.bvalid);

                tr.bresp = vif.bresp;

                @(negedge vif.bvalid);

                $display("[MON] : OP : %0b awaddr : %0d wdata : %0d bresp : %0d",
                         tr.op, tr.awaddr, tr.wdata, tr.bresp);

                mbxms.put(tr);

            end
            else
            begin

                tr.op     = trd.op;
                tr.araddr = trd.araddr;

                @(posedge vif.rvalid);

                tr.rdata = vif.rdata;
                tr.rresp = vif.rresp;

                @(negedge vif.rvalid);

                $display("[MON] : OP : %0b araddr : %0d rdata : %0d rresp : %0d",
                         tr.op, tr.araddr, tr.rdata, tr.rresp);

                mbxms.put(tr);

            end

        end

    endtask

endclass


///////////////////////////////////////

class scoreboard;

    transaction tr;

    event sconext;

    mailbox #(transaction) mbxms;

    bit [31:0] temp;
    bit [31:0] data[128] = '{default:0};


    function new(mailbox #(transaction) mbxms);
        this.mbxms = mbxms;
    endfunction


    task run();

        forever
        begin

            mbxms.get(tr);

            if (tr.op == 1)
            begin

                $display("[SCO] : OP : %0b awaddr : %0d wdata : %0d bresp : %0d",
                         tr.op, tr.awaddr, tr.wdata, tr.bresp);

                if (tr.bresp == 3)
                begin
                    $display("[SCO] : DEC ERROR");
                end
                else
                begin
                    data[tr.awaddr] = tr.wdata;

                    $display("[SCO] : DATA STORED ADDR : %0d and DATA : %0d",
                             tr.awaddr, tr.wdata);
                end

            end
            else
            begin

                $display("[SCO] : OP : %0b araddr : %0d rdata : %0d rresp : %0d",
                         tr.op, tr.araddr, tr.rdata, tr.rresp);

                temp = data[tr.araddr];

                if (tr.rresp == 3)
                begin
                    $display("[SCO] : DEC ERROR");
                end
                else if ((tr.rresp == 0) && (tr.rdata == temp))
                begin
                    $display("[SCO] : DATA MATCHED");
                end
                else
                begin
                    $display("[SCO] : DATA MISMATCHED");
                end

            end

            $display("----------------------------------------------------");

            ->sconext;

        end

    endtask

endclass


///////////////////////////////////////////////////

module tb;

    monitor mon;
    generator gen;
    driver drv;
    scoreboard sco;

    event nextgm;

    mailbox #(transaction) mbxgd;
    mailbox #(transaction) mbxms;
    mailbox #(transaction) mbxdm;

    axi_if vif();


    axilite_s dut (
        .s_axi_aclk    (vif.clk),
        .s_axi_aresetn (vif.resetn),

        .s_axi_awvalid (vif.awvalid),
        .s_axi_awready (vif.awready),
        .s_axi_awaddr  (vif.awaddr),

        .s_axi_wvalid  (vif.wvalid),
        .s_axi_wready  (vif.wready),
        .s_axi_wdata   (vif.wdata),

        .s_axi_bvalid  (vif.bvalid),
        .s_axi_bready  (vif.bready),
        .s_axi_bresp   (vif.bresp),

        .s_axi_arvalid (vif.arvalid),
        .s_axi_arready (vif.arready),
        .s_axi_araddr  (vif.araddr),

        .s_axi_rvalid  (vif.rvalid),
        .s_axi_rready  (vif.rready),
        .s_axi_rdata   (vif.rdata),
        .s_axi_rresp   (vif.rresp)
    );


    initial begin
        vif.clk = 0;
    end

    always #5 vif.clk = ~vif.clk;


    initial begin

        mbxgd = new();
        mbxms = new();
        mbxdm = new();

        gen = new(mbxgd);
        drv = new(mbxgd, mbxdm);

        mon = new(mbxms, mbxdm);
        sco = new(mbxms);

        gen.count = 10;

        drv.vif = vif;
        mon.vif = vif;

        gen.sconext = nextgm;
        sco.sconext = nextgm;

    end


    initial begin

        drv.reset();

        fork
            gen.run();
            drv.run();
            mon.run();
            sco.run();
        join_any

        wait(gen.done.triggered);

        $finish;

    end


    initial begin

        $dumpfile("dump.vcd");
        $dumpvars;

    end

endmodule