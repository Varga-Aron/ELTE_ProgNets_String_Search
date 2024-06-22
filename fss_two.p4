/* -*- P4_16 -*- */

/*
 * This file contains the two character at a time approach to the Fast String Search (FSS) problem.
 * 
 * The program will look for any occurrence of 'word' in a given sentence and return the count of it and the byte (1 byte = 8 bits)
 *     position of the first found occurrence.
 *
 * This is done by imitating a loop that goes over the whole sentence. Each cycle of the loop is one table search
 *     in this program, and a new cycle is started by recirculating the packet.
 *
 * Scroll down for more detailed explanations.
 */

// Some basic imports
#include <core.p4>
#include <v1model.p4>


/*
 * Define the types the program will recognize.
 */

 // Mac address type
 typedef bit<48> macAddr_t;

 // 32 bit long integer
 typedef bit<32> int_32;


/*
 * Define the constants the program will use.
 */
const bit<8> char_w = 0x77;   // 'w' (ASCII | UTF-8)
const bit<8> char_o = 0x6f;   // 'o' (ASCII | UTF-8)
const bit<8> char_r = 0x72;   // 'r' (ASCII | UTF-8)
const bit<8> char_d = 0x64;   // 'd' (ASCII | UTF-8)


/*
 * Define the headers the program will recognize.
 */

/*
 * Standard Ethernet header.
 *
 * Includes the destination address, the source address, and the ethernet type.
 */
header ethernet_t {
    bit<48> dstAddr;
    bit<48> srcAddr;
    bit<16> etherType;
}

/*
 * FSS header
 *
 * This is a custom header that was defined explicitly for this program.
 * 
 * The first 32 bits are an integer indicating where the first found instance of 'word' starts in the sentence.
 *     The position is given in how many bytes (1 byte is 8 bits)
 *     to skip for the beginning of the first found 'word' instance!
 * The second 32 bits are an integer indicating how many instances of 'word' was found in the sentence.
 * The third 32 bits are an integer indicating how many characters are in the sentence
 *     (One character is 1 byte, which is 8 bits).
 * And the remaining 2048 bits contain the maximum 256 (2048 / 8 = 256) characters of the sentence.
 *
 * The first and second set of 32 bits are only used to return information to the sender,
 *     so it does not matter what content the sender set these to.
 */
header fss_t {
    int_32 first_find_pos;
    int_32 find_count;
    int_32 length;
    bit<2048> sentence;
}

/*
 * Header for the looping
 *
 * This is a custom header that was defined explicitly for this program.
 *
 * The first 32 bits are an integer indicating the current position of the sentence processing.
 * The second 32 bits are an integer indicating the inner state of the program.
 *     This is used to save the status of the search between each cycle.
 * The third 9 bits are used to save the sender's original port number,
 *     as that would be lost during the very first recirculation.
 * The last 7 bits are padding and are not used for anything
 *     (P4 requires that each header's length should be divisible by 8).
 *
 * This program relies on the sender not sending this loop header with their initial packet,
 *     as the failed extraction of this header is what tells te program to begin a new loop
 *     (see the Ingress Processing for more info).
 */
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
          // When the packet is first received from the sender, the loop
          //     header should not be part of it, so that the loop header
          //     is set to invalid (this will be important in the Ingress processing). 
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
     *     a predefined word two character at a time.
     *
     * This table implements the action choosing for the main cycle of the loop.
     *
     * The phrase that the P4 program will search for is 'word'
     *
     *        State             Chars         To What State
     * +-----------------+-----------------+-----------------+
     * |        0        |        wo       |        1        |
     * +-----------------+-----------------+-----------------+
     * |        1        |        rd       |        0        |
     * +-----------------+-----------------+-----------------+
     * |        0        |        *w       |        2        |
     * +-----------------+-----------------+-----------------+
     * |        2        |        or       |        3        |
     * +-----------------+-----------------+-----------------+
     * |        3        |        d*       |        0        |
     * +-----------------+-----------------+-----------------+
     * |  All other configurations will set the State to 0   |
     * +-----------------+-----------------+-----------------+
     */
    action state_zero()    { /* empty by design */ }
    action state_one()     { /* empty by design */ }
    action state_two()     { /* empty by design */ }
    action state_three()   { /* empty by design */ }
    action state_default() { /* empty by design */ }

    // Table that uses the state of the packet to find what action to take.
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
     * Method that is executed once before the loop's first cycle.
     */
    action loop_initialize() {
        // Swap the source and destination Mac Addresses
        macAddr_t tmp = hdr.ethernet.srcAddr;
        hdr.ethernet.srcAddr = hdr.ethernet.dstAddr;
        hdr.ethernet.dstAddr = tmp;

        // Initialize the first position and count
        hdr.fss.first_find_pos = 2048;
        hdr.fss.find_count = 0;

        // Set the loop header to valid and initialize all the elements in it
        hdr.loop.setValid();
        hdr.loop.current_pos = 0;
        hdr.loop.state = 0;
        hdr.loop.origin_port = standard_metadata.ingress_port;
    }

    /*
     * Method that is executed before each of the loop's cycles, except the first one.
     */
    action loop_increment() {
        // Increasing the current position by two
        hdr.loop.current_pos = hdr.loop.current_pos + 2;

        /* Shifting the sentence to the left by two bytes.
         *
         * This is unfortunately needed, because there is no other way
         *     to access different bytes dynamically during runtime.
         *
         * Sentence before shifting: 0001 0010 0011 0100 0101 0000 (0 repeating until 2048 bit limit).
         * Sentence after shifting:  0101 0000 0000 0000 0000 0000 (0 repeating until 2048 bit limit).
         */
        hdr.fss.sentence = hdr.fss.sentence << 16;
    }

    /*
     * Method that is executed once as the loop's last cycle.
     */
    action loop_end() {
        // Restoring the saved port number of the sender in order to successfully
        //     send the processed packet back to the sender
        standard_metadata.egress_spec = hdr.loop.origin_port;
    }

    /*
     * The main body of the Ingress Processing
     */
    apply {
        if (hdr.loop.isValid()) {
            // If there was a loop header in the packet, then that means the loop
            //     has already been initialized before and a new cycle needs to begin
            loop_increment();
        } else {
            // If there was no loop header in the packet, then that means the loop
            //     hasn't yet started, so it needs to be initialized
            loop_initialize();
        }

        // Checking if the loop is still going
        //     (meaning that there are still more characters to process)
        if (hdr.loop.current_pos < hdr.fss.length) {

            /*
             * This is the code of the main cycle of the loop.
             *     This part is kept this ugly, because the logging (log/p4s.s1.log)
             *     does not work properly, if these are separated into their own actions.
             *
             * The state_change table will check which state it is currently, and execute
             *     an empty action according to what was defined in its entries.
             * 
             * The switch below will read what empty action was taken, and
             *     that will indicate what state the program is in currently
             *     (this is essentially an overly complicated switch case).
             *
             * Each state does what has already been shown in the state_change table's comment.
             */
            switch (state_change.apply().action_run) {
                state_zero: {
                    /* The indexing of the sentence works weirdly.
                     *
                     * The first character of the sentence is actually the last 8 bits of the sentence,
                     *     and the indexes must be given in this way: [end:begin]
                     *     not to mention that both end and begin are inclusive.
                     *
                     * And the last great thing about this is that the end and begin indexes
                     *     must be constants, so no dynamic accessing for you.
                     *
                     * This is the reason why instead of shifting the end and begin indexes
                     *     by 8 in each cycle, the program shifts the sentence's bits to
                     *     the left by 8.
                     *
                     * In this solution, two bytes (characters) are checked at the same time.
                     */     
                    if (hdr.fss.sentence[2047:2040] == char_w &&
                    hdr.fss.sentence[2039:2032] == char_o) {
                        hdr.loop.state = 1;
                    } else if (hdr.fss.sentence[2039:2032] == char_w) {
                        hdr.loop.state = 2;
                    } else {
                        hdr.loop.state = 0;
                    }
                }
                state_one: {
                    if (hdr.fss.sentence[2047:2040] == char_r &&
                    hdr.fss.sentence[2039:2032] == char_d) {
                        hdr.loop.state = 0;
                        
                        // Found a complete match, incrementing the count by one
                        hdr.fss.find_count = hdr.fss.find_count + 1;

                        // If the very first match, then save the beginning position of it
                        if (hdr.fss.first_find_pos == 2048) {
                            hdr.fss.first_find_pos = hdr.loop.current_pos - 2;
                        }

                    } else {
                        hdr.loop.state = 0;
                    }
                }
                state_two: {
                    if (hdr.fss.sentence[2047:2040] == char_o &&
                    hdr.fss.sentence[2039:2032] == char_r) {
                        hdr.loop.state = 3;
                    } else {
                        hdr.loop.state = 0;
                    }
                }
                state_three: {
                    if (hdr.fss.sentence[2047:2040] == char_d) {
                        hdr.loop.state = 0;
                        
                        // Found a complete match, incrementing the count by one
                        hdr.fss.find_count = hdr.fss.find_count + 1;

                        // If the very first match, then save the beginning position of it
                        if (hdr.fss.first_find_pos == 2048) {
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
            // If there are no more characters to process, then the loop should end
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
        /*
         * If the loop is still going (there are still more characters to process),
         *     then recirculate the packet.
         * Note that because of the recirculation, the sender's original port number
         *     will be lost from the metadata, that is why it had to be saved in the 
         *     loop header.
         */
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
        // Here emit will emit the struct fields IN ORDER
        //     struct is unordered originally
        packet.emit(hdr.ethernet);
        packet.emit(hdr.fss);
        packet.emit(hdr.loop);
    }
}

/*************************************************************************
 ***********************  S W I T C H ************************************
 *************************************************************************/

V1Switch(
MyParser(),
MyVerifyChecksum(),
MyIngress(),
MyEgress(),
MyComputeChecksum(),
MyDeparser()
) main;
