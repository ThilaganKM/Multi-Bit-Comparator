module Test;

import esdl;
import esdl.intf.verilator.verilated;
import esdl.intf.verilator.trace;
import uvm;
import std.stdio;
import std.string: format;

import Interface;
import Environment;
import Sequence;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//Test
//Instantiates an environment, sets up virtual interface handles for sub components and starts a top level sequence
class test: uvm_test
{
    mixin uvm_component_utils;

    this(string name, uvm_component parent = null) { super(name, parent); }

    intf vif;
    
    env comp_env;

    override void build_phase(uvm_phase phase)
    {
        super.build_phase(phase);

        comp_env = env.type_id.create("comp_env", this);

        uvm_info("TEST", "Test is done building", UVM_HIGH);
    }
    
    override void run_phase(uvm_phase phase)
    {
        uvm_info("TEST", "Starting test", UVM_MEDIUM);
        
        //Set maximum duration for which the test will run
        phase.get_objection().set_drain_time(this, 60.nsec);

        //Object is created
        phase.raise_objection(this);

        seq comp_seq = seq.type_id.create("comp_seq");

        uvm_info("TEST", "Test has started", UVM_MEDIUM);
        
        //Sequence is randomized
        //comp_seq.randomize();
        
        //Setting the path for the sequence to start: Environment -> Agent -> Sequencer
        comp_seq.start(comp_env.comp_agent.comp_sequencer);

        //Object is killed
        phase.drop_objection(this);
        
        uvm_info("TEST", "Test is complete", UVM_MEDIUM);
    }
}
