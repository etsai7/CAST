/*================================================================================

    csmd/src/daemon/src/csmi_request_handler/csmi_mcast/CSMIMcastAllocation.cc

  © Copyright IBM Corporation 2015-2017. All Rights Reserved

    This program is licensed under the terms of the Eclipse Public License
    v1.0 as published by the Eclipse Foundation and available at
    http://www.eclipse.org/legal/epl-v10.html

    U.S. Government Users Restricted Rights:  Use, duplication or disclosure
    restricted by GSA ADP Schedule Contract with IBM Corp.
 
================================================================================*/
#include "CSMIMcastAllocation.h"
#define STRUCT_TYPE csmi_allocation_mcast_context_t

template<>
CSMIMcast<STRUCT_TYPE>::~CSMIMcast()
{
    if(_Data)
    {
        csm_free_struct_ptr( STRUCT_TYPE, _Data );
        _Data = nullptr;
    }
}

template<>
void CSMIMcast<STRUCT_TYPE>::BuildMcastPayload(char** buffer, uint32_t* bufferLength)
{
    // Generate the leaner allocation payload.
    csmi_allocation_mcast_payload_request_t *allocPayload = nullptr;
    csm_init_struct_ptr(csmi_allocation_mcast_payload_request_t, allocPayload);

    allocPayload->allocation_id    = _Data->allocation_id;
    allocPayload->primary_job_id   = _Data->primary_job_id;
    allocPayload->secondary_job_id = _Data->secondary_job_id;
    allocPayload->user_flags       = _Data->user_flags ? strdup(_Data->user_flags) : nullptr;
    allocPayload->system_flags     = _Data->system_flags ? strdup(_Data->system_flags) : nullptr;
    allocPayload->user_name        = _Data->user_name ? strdup(_Data->user_name) : nullptr;
    allocPayload->create           = _Create;
    
    // Create only 
    allocPayload->isolated_cores   = _Data->isolated_cores;
    allocPayload->num_gpus         = _Data->num_gpus; 
    allocPayload->num_processors   = _Data->num_processors;  
    allocPayload->projected_memory = _Data->projected_memory;
    allocPayload->shared           = _Data->shared;

    csm_serialize_struct( csmi_allocation_mcast_payload_request_t, allocPayload,
                        buffer, bufferLength );

    csm_free_struct_ptr(csmi_allocation_mcast_payload_request_t, allocPayload);

    // Check if the number of nodes is greater than zero and that the arrays haven't been initialized.
    if ( _Data->num_nodes > 0 && _Data->ib_rx == nullptr )
    {
        _Data->ib_rx      = (int64_t*) calloc( _Data->num_nodes, sizeof(int64_t)); 
        _Data->ib_tx      = (int64_t*) calloc( _Data->num_nodes, sizeof(int64_t)); 
        _Data->gpfs_read  = (int64_t*) calloc( _Data->num_nodes, sizeof(int64_t)); 
        _Data->gpfs_write = (int64_t*) calloc( _Data->num_nodes, sizeof(int64_t)); 
        _Data->energy     = (int64_t*) calloc( _Data->num_nodes, sizeof(int64_t));
        _Data->power_cap_hit = (int64_t*) calloc( _Data->num_nodes, sizeof(int64_t));
        _Data->gpu_energy  = (int64_t*) calloc( _Data->num_nodes, sizeof(int64_t));
        
        // If this is a create operation ps_ratio and power_cap will be populated.
        if(_Create)
        {
            _Data->ps_ratio  = (int32_t*) calloc( _Data->num_nodes, sizeof(int32_t));
            _Data->power_cap = (int32_t*) calloc( _Data->num_nodes, sizeof(int32_t));
        }
        else
        {
            // Only populate when not creating.
            _Data->cpu_usage   = (int64_t*) calloc( _Data->num_nodes, sizeof(int64_t));
            _Data->memory_max  = (int64_t*) calloc( _Data->num_nodes, sizeof(int64_t));
        }
    }
}

template<>
std::string CSMIMcast<STRUCT_TYPE>::GenerateIdentifierString()
{
    std::string idString = "Allocation ID: ";
    if ( _Data )
        idString.append(std::to_string(_Data->allocation_id)).append( "; Primary Job Id: ")
            .append(std::to_string(_Data->primary_job_id)).append("; Secondary Job Id: ")
            .append(std::to_string(_Data->secondary_job_id));
    else 
        idString.append("NOT FOUND");

    return idString;
}

namespace csm{
namespace mcast{
namespace allocation{

bool ParseResponseCreate( 
    CSMIMcastAllocation* mcastProps,
    const csm::network::MessageAndAddress content )
{
    LOG(csmapi,trace) << "Parsing Mcast Response Create";
    
    // Track whether or not the received payload is valid.
    bool success = false;
    
    // If this is not in recovery and the message length is greater than zero parse the content.
    if( mcastProps && content._Msg.GetDataLen() > 0 )
    {
        csmi_allocation_mcast_payload_response_t *allocPayload = nullptr;

        // Attempt to deserialize the struct, if it deserializes process.
        if ( csm_deserialize_struct( csmi_allocation_mcast_payload_response_t, &allocPayload,
                content._Msg.GetData().c_str(), content._Msg.GetDataLen()) == 0 )
        {
            STRUCT_TYPE* allocation = mcastProps->GetData();

            if( allocation && allocPayload->hostname && 
                    allocPayload->create == mcastProps->IsCreate() )
            {
                success = true;
                std::string hostname(allocPayload->hostname);
                uint32_t hostIdx = mcastProps->SetHostError(hostname);
                
                if (  hostIdx < allocation->num_nodes )
                {
                    allocation->ib_rx[hostIdx]          = allocPayload->ib_rx;
                    allocation->ib_tx[hostIdx]          = allocPayload->ib_tx;
                    allocation->gpfs_read[hostIdx]      = allocPayload->gpfs_read;
                    allocation->gpfs_write[hostIdx]     = allocPayload->gpfs_write;
                    allocation->power_cap[hostIdx]      = allocPayload->power_cap;
                    allocation->ps_ratio[hostIdx]       = allocPayload->ps_ratio;
                    allocation->energy[hostIdx]         = allocPayload->energy;
                    allocation->power_cap_hit[hostIdx]  = allocPayload->pc_hit;
                    allocation->gpu_energy[hostIdx]     = allocPayload->gpu_energy;
                }
            }
            
            csm_free_struct_ptr(csmi_allocation_mcast_payload_response_t, allocPayload);
        }
    }

    return success;
}

bool ParseResponseDelete( 
    CSMIMcastAllocation* mcastProps,
    const csm::network::MessageAndAddress content )
{
    LOG(csmapi,trace) << "Parsing Mcast Response Delete";

    // Track whether or not the received payload is valid.
    bool success = false;

    // If this is not in recovery and the message length is greater than zero parse the content.
    if( mcastProps && content._Msg.GetDataLen() > 0 )
    {
        csmi_allocation_mcast_payload_response_t *allocPayload = nullptr;

        // Attempt to deserialize the struct, if it deserializes process.
        if ( csm_deserialize_struct( csmi_allocation_mcast_payload_response_t, &allocPayload,
                content._Msg.GetData().c_str(), content._Msg.GetDataLen()) == 0 )
        {
            STRUCT_TYPE* allocation = mcastProps->GetData();

            if( allocation && allocPayload->hostname && 
                    allocPayload->create == mcastProps->IsCreate() )
            {
                success = true;
                std::string hostname(allocPayload->hostname);
                uint32_t hostIdx = mcastProps->SetHostError(hostname, 
                    allocPayload->error_code, 
                    allocPayload->error_message);

                if ( hostIdx < allocation->num_nodes )
                {
                    allocation->ib_rx[hostIdx]      = allocPayload->ib_rx;
                    allocation->ib_tx[hostIdx]      = allocPayload->ib_tx;
                    allocation->gpfs_read[hostIdx]  = allocPayload->gpfs_read;
                    allocation->gpfs_write[hostIdx] = allocPayload->gpfs_write;
                    allocation->energy[hostIdx]     = allocPayload->energy;
                    allocation->cpu_usage[hostIdx]  = allocPayload->cpu_usage;
                    allocation->memory_max[hostIdx] = allocPayload->memory_max;
                }
            }

            csm_free_struct_ptr(csmi_allocation_mcast_payload_response_t, allocPayload);
        }
    }

    return success;
}

bool ParseResponseRecover( 
    CSMIMcastAllocation* mcastProps,
    const csm::network::MessageAndAddress content )
{

    LOG(csmapi,trace) << "Parsing Mcast Response Recover";

    // Track whether or not the received payload is valid.
    bool success = false;
    
    // If this is not in recovery and the message length is greater than zero parse the content.
    if( mcastProps && content._Msg.GetDataLen() > 0 )
    {
        csmi_allocation_mcast_payload_response_t *allocPayload = nullptr;

        // Attempt to deserialize the struct, if it deserializes process.
        if ( csm_deserialize_struct( csmi_allocation_mcast_payload_response_t, &allocPayload,
                content._Msg.GetData().c_str(), content._Msg.GetDataLen()) == 0 )
        {
            // Always update for error recovery.
            if( allocPayload->hostname && 
                    allocPayload->create == mcastProps->IsCreate() )
            {
                success = true;
                std::string hostname(allocPayload->hostname);
                mcastProps->SetHostError(hostname);
            }

            csm_free_struct_ptr(csmi_allocation_mcast_payload_response_t, allocPayload);
        }
    }

    return success;
}

}
}
}
