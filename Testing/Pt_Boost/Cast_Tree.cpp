#include <boost/property_tree/ptree.hpp>
#include <boost/property_tree/json_parser.hpp>
#include <iostream>

namespace pt = boost::property_tree;

// // Create a root
pt::ptree root;

int main(){
	int num_records;
	std::cin >> num_records;

	root.put("Total_Records", num_records);
	for(int i = 1; i <= num_records; i++){
		pt::ptree record;
		record.put("node_name", "c650f03p41_" + std::to_string(i));
		record.put("collection_time", "2018-07-10 09:53:18.018348" + std::to_string(i));
		record.put("update_time", "2018-07-10 09:53:18.018822" + std::to_string(i));
		record.put("comment", "");
		record.put("discovered_cores", 20);
		record.put("disovered_dimms", 0);
		record.put("discovered_gpus", 0);
		record.put("discovered_hcas",1);
		record.put("discovered_sockets",2);
		record.put("discovered_ssds", 0);
		record.put("feature_1","");
		record.put("feature_2","");
		record.put("feature_3","");
		record.put("feature_4","");
		record.put("hard_power_cap", -1);
		record.put("installed_memory", 268435456);
		record.put("installed_swap", 4194240);
		record.put("kernel_release","3.10.0-514.e17.ppc641e");
		record.put("kernel_version", "#1 SMP Wed Oct 19 11:27:06 EDT 2016");
		record.put("machine_model", "8335-GTA");
		record.put("os_image_name", "");
		record.put("os_image_uuid", "");
		record.put("physical_frame_location", "");
		record.put("physical_u_location", "");
		record.put("primary_agg", "");
		record.put("secondary_agg", "");
		record.put("serial_number", "0000000000000000");
		record.put("state", "DISCOVERED");
		record.put("nodetype", "utility");

		std::string x = "Record_" + std::to_string(i);
		root.add_child(x, record);
	}
	pt::write_json(std::cout, root);
}