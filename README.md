# Fast String Searching on PISA #

**DISCLAIMER:** this program was made as part of my Programmable Networks course on ELTE (Eötvös Loránd University) IK (Faculty of Informatics).

For further information, please visit the course's Github page: [https://github.com/slaki/prognets2024/tree/main](https://github.com/slaki/prognets2024/tree/main)

## Goal ##

The goal for this assignment was to implement a basic solution for the Fast String Searching on PISA. For more information on the problem, please read the research paper on the matter: [https://www.cs.yale.edu/homes/soule/pubs/sosr2019.pdf](https://www.cs.yale.edu/homes/soule/pubs/sosr2019.pdf)

## How to start the program ##

What is needed in order to run this program:
- Python3 virtual environment with scapy
- P4 installed on the computer

After downloading this repository, navigate inside the `ELTE_ProgNets_String_Search` folder and type `sudo p4run`. This will set up the virtual network.

Once the `mininet>` prompt appears, type `h1 python3 fss.py` to start the communication from host1 to server1.

When the `>` prompt appears, type whatever sentence you would like and hit Enter. Host1 will assemble and send the packet with your typed sentence for processing to server1. Server1 will send back exactly how many times your sentence contained `word` and where the first appearance was, if there was any.

If you type `exit` then the communication stops between host1 and server1.

Type `exit` again and you will stop the simulated network and get back your Terminal.

There are two solutions contained in this program. Their results are the same, but while `fss_one.p4` processes your sentence one character at a time, `fss_two.p4` processes it two characters at a time.

To change between `fss_one.p4` and `fss_two.p4`, make the following changes:
- `network.py line 10:` `fss_one.p4` to `fss_two.p4` or back
- `p4app.json line 2:` `fss_one.p4` to `fss_two.p4` or back

## How it works ##

For further insight into how the code works exactly, please open:
- `fss.py` for more information on how the packet construction works
- `fss_one.p4` for more information about how the one character at a time approach works
- `fss_two.p4` for more information on how the two character at a time approach works

All three of these files contain extensive comments that explain everything in excruciating detail.
