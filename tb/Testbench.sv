class common;
	static int num=9;
endclass

mailbox gen2drv  = new();
mailbox mon2scb  = new();
mailbox mon2cov  = new();

class transaction;
    rand bit enable;
    rand bit power_in;
    rand bit [31:0] max_counter;

   		 bit [31:0] count;
		 bit clock_req;
	     bit power_req;
    	 bit overflow_int;

    constraint c1 { enable == 1; }
    constraint c2 { power_in == 1; }
 	constraint c3 { max_counter == 5; }
endclass


class generator;
    transaction tx;

    task run();
   		repeat(common::num) begin
        	tx = new();
        	assert(tx.randomize())
        else
           	$fatal(1,"Randomization Failed");
       		gen2drv.put(tx);
      		@(posedge top.clk);
     	end
    endtask
endclass

interface cnt_if(input reg clk, rst);
    logic enable;
    logic power_in;
    logic [31:0] max_counter;
    logic [31:0] count;
	logic clock_req;
	logic power_req;
    logic overflow_int;
endinterface

class driver;
    transaction tx;
    virtual cnt_if vif;

    function new();
        vif = top.pif;
    endfunction

    task run();
        repeat(common::num)begin
            gen2drv.get(tx);
            @(posedge vif.clk);
            vif.enable      <= tx.enable;
            vif.power_in    <= tx.power_in;
            vif.max_counter <= tx.max_counter;
        end
    endtask
endclass


class monitor;
    transaction tx;
    virtual cnt_if vif;

    function new();
        vif = top.pif;
    endfunction

    task run();
        repeat(common::num)begin
            @(posedge vif.clk);
            #1;
            tx = new();
            tx.enable       = vif.enable;
            tx.power_in     = vif.power_in;
            tx.max_counter  = vif.max_counter;
            tx.count        = vif.count;
			tx.clock_req    = vif.clock_req;
			tx.power_req    = vif.power_req;
            tx.overflow_int = vif.overflow_int;
            mon2scb.put(tx);
            mon2cov.put(tx);
        end
    endtask
endclass


class scoreboard;
    transaction tx;
    bit [31:0] ref_count = 0;
    bit        ref_overflow = 0;
    bit [31:0] max_value;

    task run();
        repeat(common::num)begin
            mon2scb.get(tx);
            if (tx.max_counter != 0)
                max_value = tx.max_counter;
            else
                max_value = 50 * 86400;
          
            if (tx.count == ref_count && tx.overflow_int == ref_overflow) begin
                $display("PASS: count=%0d overflow=%0d", tx.count, tx.overflow_int);
            end
          
            else begin
                $display("FAIL");
                $display("DUT -> count=%0d overflow=%0d", tx.count, tx.overflow_int);
                $display("REF -> count=%0d overflow=%0d", ref_count, ref_overflow);
            end

            if (!tx.enable || !tx.power_in) begin
                ref_count = 0;
                ref_overflow = 0;
            end
          
            else begin
                if (ref_count == max_value) begin
                    ref_count = 0;
                    ref_overflow = 1;
                end
              
                else begin
                    ref_count = ref_count + 1;
                    ref_overflow = 0;
                end
            end
        end
    endtask
endclass

class coverage;
    transaction tx;
    covergroup counter_cg;
        ENABLE_CP : coverpoint tx.enable {
            bins ENABLE_ON  = {1};
        }

      
        POWER_CP : coverpoint tx.power_in {
            bins POWER_ON = {1};
        }


        OVERFLOW_CP : coverpoint tx.overflow_int {
            bins OVERFLOW_HIT = {1};
        }

      
        MAX_COUNTER_CP : coverpoint tx.max_counter {

            bins MAX_5 = {5};
        }

      
        ENABLE_POWER_CROSS :
        cross ENABLE_CP, POWER_CP;
    endgroup


    function new();
        counter_cg = new();
    endfunction

    task run();
        repeat(common::num) begin
            mon2cov.get(tx);
            this.tx = tx;
            counter_cg.sample();
            $display("--------------------------------");
            $display("Coverage = %0.2f%%",counter_cg.get_coverage());
            $display("--------------------------------");          
        end
            $display("--------------------------------");
			$display("FINAL COVERAGE = %0.2f%%",counter_cg.get_coverage());
			$display("--------------------------------");
    endtask
endclass

class agent;
    generator gen;
    driver drv;
    monitor mon;
    coverage cov;

    task run();
    	gen = new();
   		drv = new();
    	mon = new();
    	cov = new();
    				fork
       	 				gen.run();
       					drv.run();
     					mon.run();
        				cov.run();
   					join

	endtask
endclass


class environment;
    agent agn;
    scoreboard scb;

    task run();
        agn = new();
        scb = new();
        fork
            agn.run();
            scb.run();
        join
    endtask
endclass


module top;
    reg clk, rst;
    environment env;
    cnt_if pif(clk, rst);
  
    s2c_counter dut (
        .enable(pif.enable),
        .clock(pif.clk),
        .reset(pif.rst),
        .power_in(pif.power_in),
        .max_counter(pif.max_counter),
        .count(pif.count),
		.clock_req(pif.clock_req),
      .power_req(pif.power_req),
        .overflow_int(pif.overflow_int)
    );

    
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
  
    initial begin
        rst = 1;					
        pif.enable = 0;			
        pif.power_in = 0;
        pif.max_counter = 0;
        repeat(2) @(posedge clk);
        rst = 0;
        env = new();
        env.run();
    end

    initial begin
        #1000;
        $finish;
    end
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0,top);
  end
endmodule



  

  






