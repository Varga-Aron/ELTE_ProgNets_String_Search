#!/usr/bin/env python3

import re

from scapy.all import (
    Ether,
    IntField,
    Packet,
    StrFixedLenField,
    StrField,
    XByteField,
    bind_layers,
    srp1
)


class FSS(Packet):
    name = "FSS"
    fields_desc = [ IntField("first_find_pos", 0),
                    IntField("find_count", 0),
                    IntField("length", 0),
                    StrFixedLenField("sentence", "s", length=256)
                ]

bind_layers(Ether, FSS, type=0x1234)

def main():

    s = ""
    iface = "h1-eth0"

    while True:
        s = input("> ")
        if s == "exit":
            break

        s_l = len(s)
        if s_l > 256:
            print("Sentence too long! Cutting it back to 256 characters long.")
            s_l = 256
            s = s[0:256]
        
        try:
            pkt = Ether(dst="00:04:00:00:00:00", type=0x1234) / FSS(
                                              first_find_pos=0,
                                              find_count=0,
                                              length=s_l,
                                              sentence=s
                                            )
            pkt = pkt/" "

            pkt.show()
            resp = srp1(pkt, iface=iface, timeout=10, verbose=True)
            resp.show()

            if resp:
                fssres=resp[FSS]
                if fssres:
                    print(str(fssres.sentence))
                else:
                    print("Can't find FSS header!")
            else:
                print("No response!")

        except Exception as error:
            print(error)


if __name__ == "__main__":
    main()
