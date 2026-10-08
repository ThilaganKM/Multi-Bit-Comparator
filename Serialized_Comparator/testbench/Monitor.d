module Monitor;

import esdl;
import esdl.intf.verilator.verilated;
import esdl.intf.verilator.trace;
import uvm;
import std.stdio;
import std.string: format;

import Item;
import Interface;
import Scoreboard;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//Monitor
//Fetches and reads output from the DUT
class monitor: uvm_monitor
{
    mixin uvm_component_utils;

    intf vif;
    item comp;
    //The UVM_BIULD syntax simplifies and automates the build phase
    //Useful for simple things like ports
    @UVM_BUILD
    {
        //The analysis port takes the output values and sends them to the scoreboard for evaluation
        uvm_analysis_port!item mon_analysis_port;
    }

    this(string name, uvm_component parent = null) 
    { 
        super(name, parent);

        uvm_config_db!intf.get(this, "", "vif", vif); 
        assert(vif !is null);
    }

    //The build_phase function is more customizable than UVM_BUILD
    //override void build_phase(uvm_phase phase) {}

    override void run_phase(uvm_phase phase)
    {
        super.run_phase(phase);

            //Instantiating new item to fetch the values from interface

        comp = item.type_id.create("comp");
        bool prev_solved = false; // for edge detection
        while(true)
        {
            /** 
             * Synchronization of clock cycles is design specific
             This can also be put inside a loop if needed
             */
            
            //Checking for solved at each clock cycle
            wait(vif.clock.posedge());
            
            if(vif.solved && !prev_solved)//sample only on rising edge
            {
                //Reading the input values for reference
                comp.a = vif.a_in;
                comp.b = vif.b_in;

                //Reading the output values for checking
                comp.less_than = vif.less_than;
                comp.greater_than = vif.greater_than;
                comp.equal_to = vif.equal_to;

                uvm_info("MONITOR", "Output values obtained", UVM_LOW);

                //Writing the item to the scoreboard for checking
                mon_analysis_port.write(comp);
            }
            prev_solved = cast(bool) vif.solved;
        }
    }
}
