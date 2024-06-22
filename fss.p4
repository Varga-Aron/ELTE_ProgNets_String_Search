/* -*- P4_16 -*- */

#include <core.p4>
#include <v1model.p4>

/*
 * Define the types the program will recognize
 */

 // Mac address type
 typedef bit<48> macAddr_t;

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
    bit<32> first_find_pos;
    bit<32> find_count;
    bit<32> length;
    bit<2048> sentence;
}

// Header for the looping
header loop_t {
    bit<32> current_pos;
    bit<32> state;
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

    action swapMac() {
        macAddr_t tmp = hdr.ethernet.srcAddr;
        hdr.ethernet.srcAddr = hdr.ethernet.dstAddr;
        hdr.ethernet.dstAddr = tmp;
    }

    apply {

        if (hdr.loop.isValid()) {
            hdr.loop.current_pos = hdr.loop.current_pos + 1;
            hdr.loop.state = 1;
        } else {
            /* swap mac addresses */
            swapMac();

            hdr.loop.setValid();
            hdr.loop.current_pos = 0;
            hdr.loop.state = 0;
            hdr.loop.origin_port = standard_metadata.ingress_port;
        }

        if (hdr.loop.current_pos < hdr.fss.length) {
            
        } else {
            standard_metadata.egress_spec = hdr.loop.origin_port;
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
