# Copyright 2019-present Open Networking Foundation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# ------------------------------------------------------------------------------
# IPV6 ROUTING TESTS
#
# To run all tests:
#     make routing
#
# To run a specific test case:
#     make routing.<TEST CLASS NAME>
#
# For example:
#     make routing.IPv6RoutingTest
# ------------------------------------------------------------------------------

from ptf.testutils import group

from base_test import *


@group("routing")
class IPv6RoutingTest(P4RuntimeTest):
    """Tests basic IPv6 routing"""

    def runTest(self):
        # Test with different type of packets.
        for pkt_type in ["tcpv6", "udpv6", "icmpv6"]:
            print_inline("%s ... " % pkt_type)
            pkt = getattr(testutils, "simple_%s_packet" % pkt_type)()
            self.testPacket(pkt)

    @autocleanup
    def testPacket(self, pkt):
        next_hop_mac = SWITCH2_MAC

        # Add entry to "My Station" table. Consider the given pkt's eth dst addr
        # as myStationMac address.
        self.insert(self.helper.build_table_entry(
            table_name="IngressPipeImpl.my_station_table",
            match_fields={
                # Exact match.
                "hdr.ethernet.dst_addr": pkt[Ether].dst
            },
            action_name="NoAction"
        ))

        # Insert ECMP group with only one member (next_hop_mac)
        self.insert(self.helper.build_act_prof_group(
            act_prof_name="IngressPipeImpl.ecmp_selector",
            group_id=1,
            actions=[
                # List of tuples (action name, action param dict)
                ("IngressPipeImpl.set_next_hop", {"dmac": next_hop_mac}),
            ]
        ))

        # Insert L3 entry to app pkt's IPv6 dst addr to group
        self.insert(self.helper.build_table_entry(
            table_name="IngressPipeImpl.routing_v6_table",
            match_fields={
                # LPM match (value, prefix)
                "hdr.ipv6.dst_addr": (pkt[IPv6].dst, 128)
            },
            group_id=1
        ))

        # Insert L3 entry to map next_hop_mac to output port 2.
        self.insert(self.helper.build_table_entry(
            table_name="IngressPipeImpl.l2_exact_table",
            match_fields={
                # Exact match
                "hdr.ethernet.dst_addr": next_hop_mac
            },
            action_name="IngressPipeImpl.set_egress_port",
            action_params={
                "port_num": self.port2
            }
        ))

        # Expected pkt should have routed MAC addresses and decremented hop
        # limit (TTL).
        exp_pkt = pkt.copy()
        pkt_route(exp_pkt, next_hop_mac)
        pkt_decrement_ttl(exp_pkt)

        testutils.send_packet(self, self.port1, str(pkt))
        testutils.verify_packet(self, exp_pkt, self.port2)
