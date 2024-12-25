#include "../shared/header.p4"

control MultiIngress(inout ingress_headers_t hdr,
                        inout Basic_ingress_metadata_t basic_md,
                        in    ingress_intrinsic_metadata_t ig_intr_md,
                        inout ingress_intrinsic_metadata_for_tm_t ig_tm_md,
                        inout ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md) {
     // Create direct counters
    DirectCounter<bit<32>>(CounterType_t.PACKETS_AND_BYTES) l2_counter;
    DirectCounter<bit<32>>(CounterType_t.PACKETS_AND_BYTES) ipv4_counter;
    DirectCounter<bit<32>>(CounterType_t.PACKETS_AND_BYTES) ipv6_counter;
    DirectCounter<bit<32>>(CounterType_t.PACKETS_AND_BYTES) id_counter;
    DirectCounter<bit<32>>(CounterType_t.PACKETS_AND_BYTES) geo_counter;
    DirectCounter<bit<32>>(CounterType_t.PACKETS_AND_BYTES) mf_counter;
    DirectCounter<bit<32>>(CounterType_t.PACKETS_AND_BYTES) ndn_counter;
    DirectCounter<bit<32>>(CounterType_t.PACKETS_AND_BYTES) flexip_counter;
    // Create indirect counter
    // Counter<bit<32>, ether_type_t>(
    //     8, CounterType_t.PACKETS_AND_BYTES) indirect_counter;

    action drop() {
        ig_dprsr_md.drop_ctl = 0x1; // Drop packet.
    }

    action to_cpu() {
        ig_tm_md.ucast_egress_port = CPU_PORT;
        hdr.packet_in.setValid();
        hdr.packet_in.ingress_port = (BasicPortId_t)ig_intr_md.ingress_port;
    }

    action icmp_switch(PortId_t port) {
        l2_counter.count();
        ig_tm_md.ucast_egress_port = port;
    }

    action icmp6_switch(PortId_t port) {
        l2_counter.count();
        ig_tm_md.ucast_egress_port = port;
    }


    action route_l3() {
        l2_counter.count();
        basic_md.l3 = 1;
    }



    table ing_dmac {
        key = {
            hdr.ethernet.src_addr : ternary;
            hdr.ethernet.dst_addr : ternary;
            hdr.ethernet.ether_type : exact;
        }

        actions = {
            icmp_switch;
            icmp6_switch;
            route_l3;
        }
        size = 24;
        const default_action = route_l3;
        // Associate this table with a direct counter
        counters = l2_counter;
    }


    action set_next_v4_hop(PortId_t dst_port) {
        ig_tm_md.ucast_egress_port = dst_port;
        ipv4_counter.count();
    }
    action v4_to_cpu(){
        ig_tm_md.ucast_egress_port = CPU_PORT;
        hdr.packet_in.setValid();
        hdr.packet_in.ingress_port = (BasicPortId_t)ig_intr_md.ingress_port;
        ipv4_counter.count();
    }
    table routing_v4_table {
        key = {
            hdr.ethernet.ether_type: exact;
            hdr.ipv4.srcAddr: exact;
            hdr.ipv4.dstAddr: exact;
        }

        actions = {
            set_next_v4_hop;
            v4_to_cpu;
        }
        default_action  = v4_to_cpu;
        counters = ipv4_counter;
        size = 1024;
    }



    action set_next_v6_hop(PortId_t dst_port) {
        ig_tm_md.ucast_egress_port = dst_port;
        ipv6_counter.count();
    }
    action v6_to_cpu(){
        ig_tm_md.ucast_egress_port = CPU_PORT;
        hdr.packet_in.setValid();
        hdr.packet_in.ingress_port = (BasicPortId_t)ig_intr_md.ingress_port;
        ipv6_counter.count();
    }
    table routing_v6_table {
        key = {
            hdr.ethernet.ether_type: exact;
            hdr.ipv6.src_addr: exact;
            hdr.ipv6.dst_addr: exact;
        }

        actions = {
            set_next_v6_hop;
            v6_to_cpu;
        }
        default_action = v6_to_cpu;
        counters = ipv6_counter;
        size = 1024;
    }

    // --- routing_id_table ----------------------------------------------------
    //  身份模态
    action set_next_id_hop(PortId_t dst_port){
        ig_tm_md.ucast_egress_port = dst_port;
        id_counter.count();
    }
    action id_to_cpu(){
        ig_tm_md.ucast_egress_port = CPU_PORT;
        hdr.packet_in.setValid();
        hdr.packet_in.ingress_port = (BasicPortId_t)ig_intr_md.ingress_port;
        id_counter.count();
    }
    table routing_id_table {
        key = {
            hdr.ethernet.ether_type: exact;
            hdr.id.srcIdentity: exact;
            hdr.id.dstIdentity: exact;
        }
        actions = {
            set_next_id_hop;
            id_to_cpu;
        }
        default_action = id_to_cpu;
        counters = id_counter;
        size = 1024;
    }

    // --- routing_geo_table -----------------------------------------------------
    // 地理模态
    action geo_ucast_route(PortId_t dst_port) {
        ig_tm_md.ucast_egress_port = dst_port;
        geo_counter.count();
    }
    action geo_mcast_route(MulticastGroupId_t mgid1) {
        ig_tm_md.mcast_grp_a = mgid1;
        geo_counter.count();
    }
    action geo_to_cpu(){
        ig_tm_md.ucast_egress_port = CPU_PORT;
        hdr.packet_in.setValid();
        hdr.packet_in.ingress_port = (BasicPortId_t)ig_intr_md.ingress_port;
        geo_counter.count();
    }
    table routing_geo_table {
        key = {
            hdr.ethernet.ether_type: exact;
            hdr.gbc.geoAreaPosLat: exact;
            hdr.gbc.geoAreaPosLon: exact;
            hdr.gbc.disa: exact;
            hdr.gbc.disb: exact;
        }

        actions = {
            geo_ucast_route;
            geo_mcast_route;
            geo_to_cpu;
        }
        default_action = geo_to_cpu;
        counters = geo_counter;
        size = 1024;
    }

    // --- routing_mf_table -----------------------------------------------------
    // mf模态
    action set_next_mf_hop(PortId_t dst_port) {
        ig_tm_md.ucast_egress_port = dst_port;
        mf_counter.count();
    }
    action mf_to_cpu(){
        ig_tm_md.ucast_egress_port = CPU_PORT;
        hdr.packet_in.setValid();
        hdr.packet_in.ingress_port = (BasicPortId_t)ig_intr_md.ingress_port;
        mf_counter.count();
    }
    table routing_mf_table {
        key = {
            hdr.ethernet.ether_type: exact;
            hdr.mf.src_guid: exact;
            hdr.mf.dest_guid : exact;
        }

        actions = {
            set_next_mf_hop;
            mf_to_cpu;
        }
        default_action = mf_to_cpu;
        counters = mf_counter;
        size = 1024;
    }

    // --- routing_ndn_table ------------------------------------------------------
    // ndn模态
    action set_next_ndn_hop(PortId_t dst_port) {
        ig_tm_md.ucast_egress_port = dst_port;
        ndn_counter.count();
    }
    action ndn_to_cpu(){
        ig_tm_md.ucast_egress_port = CPU_PORT;
        hdr.packet_in.setValid();
        hdr.packet_in.ingress_port = (BasicPortId_t)ig_intr_md.ingress_port;
        ndn_counter.count();
    }
    table routing_ndn_table {
        key = {
            hdr.ethernet.ether_type: exact;
            hdr.ndn.ndn_prefix.code: exact;
            hdr.ndn.name_tlv.components[0].value: exact;
            hdr.ndn.name_tlv.components[1].value: exact;
            hdr.ndn.content_tlv.value: exact;
        }

        actions = {
            set_next_ndn_hop;
            ndn_to_cpu;
        }
        default_action = ndn_to_cpu;
        counters = ndn_counter;
        size = 1024;
    }

    // --- routing_flexip_table -----------------------------------------------------
    // FlexIP模态
    action set_next_flexip_hop(PortId_t dst_port) {
        ig_tm_md.ucast_egress_port = dst_port;
    }
    action flexip_to_cpu(){
        ig_tm_md.ucast_egress_port = CPU_PORT;
        hdr.packet_in.setValid();
        hdr.packet_in.ingress_port = (BasicPortId_t)ig_intr_md.ingress_port;
        flexip_counter.count();
    }
    table routing_flexip_table {
        key = {
            hdr.ethernet.ether_type: exact;
            hdr.flexip.srcFormat: exact;
            hdr.flexip.dstFormat: exact;
            hdr.flexip.srcAddr: exact;
            hdr.flexip.dstAddr: exact;
        }
        actions = {
            set_next_flexip_hop;
            flexip_to_cpu;
        }
        default_action = flexip_to_cpu;
        counters = flexip_counter;
        size = 1024;
    }

    apply {
        ing_dmac.apply();
            if (basic_md.l3 == 1) //todo
            {
                if(hdr.ethernet.ether_type == ETHERTYPE_IPV4){
                    routing_v4_table.apply();
                }
                if(hdr.ethernet.ether_type == ETHERTYPE_IPV6){
                    routing_v6_table.apply();
                }
                if(hdr.ethernet.ether_type == ETHERTYPE_ID) {
                    routing_id_table.apply();
                }
                if(hdr.ethernet.ether_type == ETHERTYPE_GEO) {
                    routing_geo_table.apply();
                }
                if(hdr.ethernet.ether_type == ETHERTYPE_MF) {
                    routing_mf_table.apply();
                }
                if(hdr.ethernet.ether_type == ETHERTYPE_NDN) {
                    routing_ndn_table.apply();
                }
            }
    }
}