/* -*- P4_16 -*- */

#include <core.p4>
#include <v1model.p4>

/*
 * Define the types the program will recognize
 */

 // Mac address type
 typedef bit<48> macAddr_t;
 typedef bit<32> int_32;


/*
 * Define the constants the program will use
 */
const bit<8> char_w = 0x77;   // 'w'
const bit<8> char_o = 0x6f;   // 'o'
const bit<8> char_r = 0x72;   // 'r'
const bit<8> char_d = 0x64;   // 'd'


/*
 * Define the headers the program will recognize
 */

// Standard Ethernet header
header ethernet_t {
    bit<48> dstAddr;
    bit<48> srcAddr;
    bit<16> etherType;
}

// FSS header
header fss_t {
    int_32 first_find_pos;
    int_32 find_count;
    int_32 length;
    bit<2048> sentence;
}

// Header for the looping
header loop_t {
    int_32 current_pos;
    int_32 state;
    bit<9> origin_port;
    bit<7> padding;
}

/*
 * All headers, used in the program needs to be assembled into a single struct.
 * We only need to declare the type, but there is no need to instantiate it,
 * because it is done "by the architecture", i.e. outside of P4 functions
 */
struct headers {
    ethernet_t   ethernet;
    fss_t        fss;
    loop_t       loop;
}

/*
 * All metadata, globally used in the program, also needs to be assembled
 * into a single struct. As in the case of the headers, we only need to
 * declare the type, but there is no need to instantiate it,
 * because it is done "by the architecture", i.e. outside of P4 functions
 */
struct metadata {
    /* In our case it is empty */
}

/*************************************************************************
 ***********************  P A R S E R  ***********************************
 *************************************************************************/
parser MyParser(packet_in packet,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t standard_metadata) {

      state start{
          packet.extract(hdr.ethernet);
          packet.extract(hdr.fss);
          packet.extract(hdr.loop);
          transition accept;
      }
}

/*************************************************************************
 ************   C H E C K S U M    V E R I F I C A T I O N   *************
 *************************************************************************/
control MyVerifyChecksum(inout headers hdr,
                         inout metadata meta) {
    apply { }
}

/*************************************************************************
 **************  I N G R E S S   P R O C E S S I N G   *******************
 *************************************************************************/
control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {

    /*
     * This P4 program simulates a for loop using recirculation, in order to search for 
     *     a predefined word.
     *
     * This table implements the code for the main cycle of the loop.
     *
     * The phrase that the P4 program will search for is 'word'
     *
     *        State             Char          To What State
     * +-----------------+-----------------+-----------------+
     * |        0        |        w        |        1        |
     * +-----------------+-----------------+-----------------+
     * |        1        |        o        |        2        |
     * +-----------------+-----------------+-----------------+
     * |        2        |        r        |        3        |
     * +-----------------+-----------------+-----------------+
     * |        3        |        d        |        0        |
     * +-----------------+-----------------+-----------------+
     * |  All other configurations will set the State to 0   |
     * +-----------------+-----------------+-----------------+
     */
    action state_zero()    { /* empty by design */ }
    action state_one()     { /* empty by design */ }
    action state_two()     { /* empty by design */ }
    action state_three()   { /* empty by design */ }
    action state_default() { /* empty by design */ }

    table state_change {
        key = {
            hdr.loop.state : exact;
        }
        actions = {
            state_zero;
            state_one;
            state_two;
            state_three;
            state_default;
        }
        const entries = {
            0 : state_zero;
            1 : state_one;
            2 : state_two;
            3 : state_three;
        }
        const default_action = state_default;
    }

    /*
     * Method to swap the source and destination Mac Addresses.
     */
    action swapMac() {
        macAddr_t tmp = hdr.ethernet.srcAddr;
        hdr.ethernet.srcAddr = hdr.ethernet.dstAddr;
        hdr.ethernet.dstAddr = tmp;
    }

    /*
     * Method that is executed once before the loop's first cycle.
     */
    action loop_initialize() {
        /* swap mac addresses */
        swapMac();

        hdr.loop.setValid();
        hdr.loop.current_pos = 0;
        hdr.loop.state = 0;
        hdr.loop.origin_port = standard_metadata.ingress_port;
    }

    /*
     * Method that is executed before each of the loop's cycles, except the first one.
     */
    action loop_increment() {
        hdr.loop.current_pos = hdr.loop.current_pos + 1;
        hdr.fss.sentence = hdr.fss.sentence << 8;
    }

    /*
     * Method that is executed once during the loop's last cycle.
     */
    action loop_end() {
        standard_metadata.egress_spec = hdr.loop.origin_port;
    }

    /*
     * The main body of the Ingress Processing
     */
    apply {
        if (hdr.loop.isValid()) {
            loop_increment();
        } else {
            loop_initialize();
        }

        if (hdr.loop.current_pos < hdr.fss.length) {

            /*
             * This is the code of the main cycle of the loop.
             *     This part is kept this ugly, because the logging
             *     does not work properly, if these are separated into their own actions
             */
            switch (state_change.apply().action_run) {
                state_zero: {
                    if (hdr.fss.sentence[2047:2040] == char_w) {
                        hdr.loop.state = 1;
                    } else {
                        hdr.loop.state = 0;
                    }
                }
                state_one: {
                    if (hdr.fss.sentence[2047:2040] == char_o) {
                        hdr.loop.state = 2;
                    } else {
                        hdr.loop.state = 0;
                    }
                }
                state_two: {
                    if (hdr.fss.sentence[2047:2040] == char_r) {
                        hdr.loop.state = 3;
                    } else {
                        hdr.loop.state = 0;
                    }
                }
                state_three: {
                    if (hdr.fss.sentence[2047:2040] == char_d) {
                        hdr.loop.state = 0;
                        hdr.fss.find_count = hdr.fss.find_count + 1;

                        if (hdr.fss.first_find_pos == 0) {
                            hdr.fss.first_find_pos = hdr.loop.current_pos - 3;
                        }

                    } else {
                        hdr.loop.state = 0;
                    }
                }
                state_default: { 
                    hdr.loop.state = 0;
                }
            }

        } else {
            loop_end();
        }
    }
}

/*************************************************************************
 ****************  E G R E S S   P R O C E S S I N G   *******************
 *************************************************************************/
control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    apply {
        // If the loop is still going, then recirculate the packet
        if (hdr.loop.current_pos < hdr.fss.length) {
            recirculate_preserving_field_list(0);
        }
    }
}

/*************************************************************************
 *************   C H E C K S U M    C O M P U T A T I O N   **************
 *************************************************************************/

control MyComputeChecksum(inout headers hdr, inout metadata meta) {
    apply { }
}

/*************************************************************************
 ***********************  D E P A R S E R  *******************************
 *************************************************************************/
control MyDeparser(packet_out packet, in headers hdr) {
    apply {
        /* deparse ethernet header */
        // Here emit will emit the struct fields IN ORDER
        // struct is unordered originally
        // packet.emit(hdr);
        packet.emit(hdr.ethernet);
        packet.emit(hdr.fss);
        packet.emit(hdr.loop);
    }
}

/*************************************************************************
 ***********************  S W I T T C H **********************************
 *************************************************************************/

V1Switch(
MyParser(),
MyVerifyChecksum(),
MyIngress(),
MyEgress(),
MyComputeChecksum(),
MyDeparser()
) main;
