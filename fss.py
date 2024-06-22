#!/usr/bin/env python3

from scapy.all import (
    Ether,
    IntField,
    Packet,
    StrFixedLenField,
    bind_layers,
    srp1
)


"""
The custom header that was defined specifically for this task.

first_find_pos is the position of the first occurrence of the phrase 'word'
find_count is how many times the phrase 'word' was found in the sentence.
length is how many characters (bytes) long the sentence is, max 256!
sentence is the characters of the sentence, max 256!
"""
class FSS(Packet):
    name = "FSS"
    fields_desc = [ IntField("first_find_pos", 0),
                    IntField("find_count", 0),
                    IntField("length", 0),
                    StrFixedLenField("sentence", "s", length=256)
                ]

# Binding the Ethernet and FSS layers together
bind_layers(Ether, FSS, type=0x1234)


def main():

    s = ""

    # What the name of the interface is in the simulated network.
    iface = "h1-eth0"

    while True:

        # Handling user input.
        s = input("> ")
        if s == "exit":
            break

        # Handling if the typed sentence was too long.
        s_l = len(s)
        if s_l > 256:
            print("Sentence too long! Cutting it back to 256 characters long.")
            s_l = 256
            s = s[0:256]
        
        try:
            # Assembling packet to send to server1.
            pkt = Ether(dst="00:04:00:00:00:00", type=0x1234) / FSS(
                                              first_find_pos=0,
                                              find_count=0,
                                              length=s_l,
                                              sentence=s
                                            )
            pkt = pkt/" "

            # Uncomment to see the debug message about the sent packet
            # pkt.show()

            # Sending the assembled packet and receiving one answer packet
            resp = srp1(pkt, iface=iface, timeout=3, verbose=True)

            # Uncomment to see the debug message about the received packet
            # resp.show()

            # Check if there is a response at all
            if resp:

                # Check if the response's FSS header is valid
                fssres=resp[FSS]
                if fssres:
                    print(f"\nHow many times the phrase 'word' has been found: {fssres.find_count}")

                    # If the first_find_pos is set to 2048, then there were no occurrences
                    #     of the phrase 'word' in the sentence
                    if (fssres.first_find_pos != 2048):
                        print(f"Where the first occurrence was: {fssres.first_find_pos}")
                        print(f"The first occurrence: {s[fssres.first_find_pos:fssres.first_find_pos + 4]}")
                else:
                    print("Can't find FSS header!")
            else:
                print("No response!")

        except Exception as error:
            print(error)


if __name__ == "__main__":
    main()
