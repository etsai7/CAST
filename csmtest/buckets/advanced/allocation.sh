#================================================================================
#   
#    buckets/advanced/allocation.sh
# 
#  © Copyright IBM Corporation 2015-2018. All Rights Reserved
#
#    This program is licensed under the terms of the Eclipse Public License
#    v1.0 as published by the Eclipse Foundation and available at
#    http://www.eclipse.org/legal/epl-v10.html
#
#    U.S. Government Users Restricted Rights:  Use, duplication or disclosure
#    restricted by GSA ADP Schedule Contract with IBM Corp.
# 
#================================================================================

# Advanced Bucket for allocation testing
# Allocation create, update, query, delete with cgroups, staging-in
# DEBUG: set -x

if [ -f "${BASH_SOURCE%/*}/../../csm_test.cfg" ]
then
        . "${BASH_SOURCE%/*}/../../csm_test.cfg"
else
        echo "Could not find csm_test.cfg file expected at "${BASH_SOURCE%/*}/../csm_test.cfg", exitting."
        exit 1
fi

LOG=${LOG_PATH}/buckets/advanced/allocation.log
TEMP_LOG=${LOG_PATH}/buckets/advanced/allocation_tmp.log
FLAG_LOG=${LOG_PATH}/buckets/advanced/allocation_flags.log

if [ -f "${BASH_SOURCE%/*}/../../include/functions.sh" ]
then
        . "${BASH_SOURCE%/*}/../../include/functions.sh"
else
        echo "Could not find functions file expected at /../../include/functions.sh, exitting."
fi

echo "------------------------------------------------------------" >> ${LOG}
echo "            Starting Advanced Allocation Bucket" >> ${LOG}
echo "------------------------------------------------------------" >> ${LOG}
date >> ${LOG}
echo "------------------------------------------------------------" >> ${LOG}

# Section A - create staging-in, no cgroup
echo "Section A BEGIN" >> ${LOG}
# Test Case 1: Calling csm_allocation_create at staging-in, no cgroup
${CSM_PATH}/csm_allocation_create -j 1 -n ${COMPUTE_NODES} -s "staging-in" 2>&1 > ${TEMP_LOG}
check_return_exit $? 0 "Test Case 1: Calling csm_allocation_create at staging-in, no cgroup"

# Grab & Store Allocation ID from temp log
allocation_id=`grep allocation_id ${TEMP_LOG} | awk -F': ' '{print $2}'`

# Test Case 2: Validating allocation state staging-in
${CSM_PATH}/csm_allocation_query -a ${allocation_id} > ${TEMP_LOG} 2>&1
check_all_output "staging-in"
check_return_flag $? "Test Case 2: Validating allocation state staging-in"

# Test Case 3: Calling csm_allocation_query_active_all
${CSM_PATH}/csm_allocation_query_active_all > ${TEMP_LOG} 2>&1
check_return_exit $? 0 "Test Case 3: Calling csm_allocation_query_active_all"

# Test Case 4: Calling csm_allocation_update_state -s running on Allocation ID = ${allocation_id}
${CSM_PATH}/csm_allocation_update_state -a ${allocation_id} -s "running" > ${TEMP_LOG} 2>&1
check_return_exit $? 0 "Test Case 4: Calling csm_allocation_update_state -s running on Allocation ID = ${allocation_id}"

# Test Case 5: Validating allocation state running
${CSM_PATH}/csm_allocation_query -a ${allocation_id} > ${TEMP_LOG} 2>&1
check_all_output "running"
check_return_flag $? "Test Case 5: Validating allocation state running"

# Test Case 6: Calling csm_allocation_query
${CSM_PATH}/csm_allocation_query -a ${allocation_id} > ${TEMP_LOG} 2>&1
check_return_exit $? 0 "Test Case 6: Calling csm_allocation_query"

# Test Case 7: Calling csm_allocation_update_state -s staging-out on Allocation ID = ${allocation_id}
${CSM_PATH}/csm_allocation_update_state -a ${allocation_id} -s "staging-out" > ${TEMP_LOG} 2>&1
check_return_exit $? 0 "Test Case 7: Calling csm_allocation_update_state -s staging-out on Allocation ID = ${allocation_id}"

# Test Case 8: Checking allocation state staging-out
${CSM_PATH}/csm_allocation_query -a ${allocation_id} > ${TEMP_LOG} 2>&1
check_all_output "staging-out"
check_return_flag $? "Test Case 8: Checking allocation state staging-out"

# Test Case 9: Calling csm_allocation_delete on Allocation ID = ${allocation_id}
${CSM_PATH}/csm_allocation_delete -a ${allocation_id} > ${TEMP_LOG} 2>&1
check_return_exit $? 0 "Test Case 9: Calling csm_allocation_delete on Allocation ID = ${allocation_id}"

# Test Case 10: Calling csm_allocation_query_active_all
${CSM_PATH}/csm_allocation_query_active_all > ${TEMP_LOG} 2>&1
check_return_exit $? 4 "Test Case 10: Calling csm_allocation_query_active_all"

# Test Case 11: Checking allocation state complete
${CSM_PATH}/csm_allocation_query -a ${allocation_id} > ${TEMP_LOG} 2>&1
check_all_output "complete"
check_return_flag $? "Test Case 11: Checking allocation state complete"

echo "Section A COMPLETED!" >> ${LOG}
echo "------------------------------------------------------------" >> ${LOG}

# Section B - create running with cgroup
echo "Section B BEGIN" >> ${LOG}

# Test Case 1: Calling csm_allocation_create
${CSM_PATH}/csm_allocation_create -j 1 -n ${SINGLE_COMPUTE} --isolated_cores 2 2>&1 > ${TEMP_LOG}
check_return_exit $? 0 "Test Case 1: Calling csm_allocation_create"

# Grab & Store Allocation ID from csm_allocation_create.log
allocation_id=`grep allocation_id ${TEMP_LOG} | awk -F': ' '{print $2}'`

# Test Case 2: Calling csm_allocation_query_active_all
${CSM_PATH}/csm_allocation_query_active_all > ${TEMP_LOG} 2>&1
check_return_exit $? 0 "Test Case 2: Calling csm_allocation_query_active_all"

# Test Case 3: Validating allocation state running
${CSM_PATH}/csm_allocation_query -a ${allocation_id} > ${TEMP_LOG} 2>&1
check_all_output "running"
check_return_flag $? "Test Case 3: Validating allocation state running"

# Test Case 4: Validating cgroup creation
xdsh ${SINGLE_COMPUTE} "ls /sys/fs/cgroup/cpuset/allocation_${allocation_id}" > ${TEMP_LOG} 2>&1
check_return_flag $? "Test Case 4: Validating cgroup creation"

# Test Case 5: Validating cgroup assigned cpus correctly
xdsh ${SINGLE_COMPUTE} "cat /sys/fs/cgroup/cpuset/allocation_${allocation_id}/cpuset.cpus" > ${TEMP_LOG} 2>&1
check_all_output "0-79,88-167"
check_return_flag $? "Test Case 5: Validating cgroup assigned cpus correctly"

# Test Case 6: Calling csm_allocation_update_state -s staging-out on Allocation ID = ${allocation_id}
${CSM_PATH}/csm_allocation_update_state -a ${allocation_id} -s "staging-out" > ${TEMP_LOG} 2>&1
check_return_exit $? 0 "Test Case 6: Calling csm_allocation_update_state -s staging-out on Allocation ID = ${allocation_id}"

# Test Case 7: Validating allocation state staging-out
${CSM_PATH}/csm_allocation_query -a ${allocation_id} > ${TEMP_LOG} 2>&1
check_all_output "staging-out"
check_return_flag $? "Test Case 7: Validating allocation state staging-out"

# Test Case 8: Calling csm_allocation_delete on Allocation ID = ${allocation_id}
${CSM_PATH}/csm_allocation_delete -a ${allocation_id} > ${TEMP_LOG} 2>&1
check_return_exit $? 0 "Test Case 8: Calling csm_allocation_delete on Allocation ID = ${allocation_id}"

# Test Case 9: Checking allocation state complete
${CSM_PATH}/csm_allocation_query -a ${allocation_id} > ${TEMP_LOG} 2>&1
check_all_output "complete"
check_return_flag $? "Test Case 9: Checking allocation state complete"

# Test Case 10: Calling csm_allocation_query_active_all
${CSM_PATH}/csm_allocation_query_active_all > ${TEMP_LOG} 2>&1
check_return_exit $? 4 "Test Case 10: Calling csm_allocation_query_active_all"

# Test Case 11: Checking cgroup deletion
xdsh ${SINGLE_COMPUTE} "ls /sys/fs/cgroup/cpuset/allocation_${allocation_id}" > ${TEMP_LOG} 2>&1
check_all_output "No such file or directory"
check_return_flag $? "Test Case 11: Checking cgroup deletion"

echo "Section B COMPLETED!" >> ${LOG}
echo "------------------------------------------------------------" >> ${LOG}

# Section C - create staging-in, with cgroup
echo "Section C BEGIN" >> ${LOG}

# Test Case 1: Calling csm_allocation_create at staging-in, with cgroup
${CSM_PATH}/csm_allocation_create -j 1 -n ${SINGLE_COMPUTE} -s "staging-in" --isolated_cores 2 2>&1 > ${TEMP_LOG}
check_return_exit $? 0 "Test Case 1: Calling csm_allocation_create at staging-in, with cgroup"

# Grab & Store Allocation ID from csm_allocation_create.log
allocation_id=`grep allocation_id ${TEMP_LOG} | awk -F': ' '{print $2}'`

# Test Case 2: Checking allocation state staging-in
${CSM_PATH}/csm_allocation_query -a ${allocation_id} > ${TEMP_LOG} 2>&1
check_all_output "staging-in"
check_return_flag $? "Test Case 2: Checking allocation state staging-in"

# Test Case 3: Calling csm_allocation_query_active_all
${CSM_PATH}/csm_allocation_query_active_all > ${TEMP_LOG} 2>&1
check_return_exit $? 0 "Test Case 3: Calling csm_allocation_query_active_all"

# Test Case 4: Validating cgroup not created yet
xdsh ${SINGLE_COMPUTE} "ls /sys/fs/cgroup/cpuset/allocation_${allocation_id}" > ${TEMP_LOG} 2>&1
check_all_output "No such file or directory"
check_return_flag $? "Test Case 4: Validating cgroup not created yet"

# Test Case 5: Calling csm_allocation_update_state -s running on Allocation ID = ${allocation_id}
${CSM_PATH}/csm_allocation_update_state -a ${allocation_id} -s running > ${TEMP_LOG} 2>&1
check_return_exit $? 0 "Test Case 5: Calling csm_allocation_update_state -s running on Allocation ID = ${allocation_id}"

# Test Case 6: Validating allocation state running
${CSM_PATH}/csm_allocation_query -a ${allocation_id} > ${TEMP_LOG} 2>&1
check_all_output "running"
check_return_flag $? "Test Case 6: Validating allocation state running"

# Test Case 7: Validating cgroup creation
xdsh ${SINGLE_COMPUTE} "ls /sys/fs/cgroup/cpuset/allocation_${allocation_id}" > ${TEMP_LOG} 2>&1
check_return_flag $? "Test Case 7: Validating cgroup creation"

# Test Case 8: Validating cgroup assigned cpus correctly
xdsh ${SINGLE_COMPUTE} "cat /sys/fs/cgroup/cpuset/allocation_${allocation_id}/cpuset.cpus" > ${TEMP_LOG} 2>&1
check_all_output "0-79,88-167"
check_return_flag $? "Test Case 8: Validating cgroup assigned cpus correctly"

# Test Case 9: Calling csm_allocation_update_state -s staging-out on Allocation ID = ${allocation_id}
${CSM_PATH}/csm_allocation_update_state -a ${allocation_id} -s "staging-out" > ${TEMP_LOG} 2>&1
check_return_exit $? 0 "Test Case 9: Calling csm_allocation_update_state -s staging-out on Allocation ID = ${allocation_id}"

# Test Case 10: Validating allocation state staging-out
${CSM_PATH}/csm_allocation_query -a ${allocation_id} > ${TEMP_LOG} 2>&1
check_all_output "staging-out"
check_return_flag $? "Test Case 10: Validating allocation state staging-out"

# Test Case 11: Calling csm_allocation_delete on Allocation ID = ${allocation_id}
${CSM_PATH}/csm_allocation_delete -a ${allocation_id} > ${TEMP_LOG} 2>&1
check_return_exit $? 0 "Test Case 11: Calling csm_allocation_delete on Allocation ID = ${allocation_id}"

# Test Case 12: Checking cgroup deletion
xdsh ${SINGLE_COMPUTE} "ls /sys/fs/cgroup/cpuset/allocation_${allocation_id}" > ${TEMP_LOG} 2>&1
check_all_output "No such file or directory"
check_return_flag $? "Test Case 12: Checking cgroup deletion"

# Test Case 13: Calling csm_allocation_query_active_all
${CSM_PATH}/csm_allocation_query_active_all > ${TEMP_LOG} 2>&1
check_return_exit $? 4 "Test Case 13: Calling csm_allocation_query_active_all"

# Test Case 14: Validating allocation state complete
${CSM_PATH}/csm_allocation_query -a ${allocation_id} > ${TEMP_LOG} 2>&1
check_all_output "complete"
check_return_flag $? "Test Case 14: Validating allocation state complete"

echo "Section C COMPLETED!" >> ${LOG}

echo "------------------------------------------------------------" >> ${LOG}
# Section D - Permissions checks for non-root users
echo "Section D BEGIN" >> ${LOG}

# Test Case 1: Calling csm_allocation_create for user ${USER} at staging-in
${CSM_PATH}/csm_allocation_create -j 1 -n ${SINGLE_COMPUTE} -s "staging-in" -u ${USER} > ${TEMP_LOG} 2>&1
check_return_exit $? 0 "Test Case 1: Calling csm_allocation_create for user ${USER} at staging-in"

# Grab & Store Allocation ID from csm_allocation_create.log
allocation_id=`grep allocation_id ${TEMP_LOG} | awk -F': ' '{print $2}'`

# Test Case 2: Checking Allocation ${allocation_id} created for user ${USER}
check_all_output "${USER}"
check_return_exit $? 0 "Test Case 2: Checking Allocation ${allocation_id} created for user ${USER}"

# Test Case 3: Attempt csm_allocation_update_state as secondary non-root user (error expected)
su -c "${CSM_PATH}/csm_allocation_update_state -a ${allocation_id} -s running" ${SECOND_USER} > ${TEMP_LOG} 2>&1
check_return_exit $? 16 "Test Case 3: Attempt csm_allocation_update_state as secondary non-root user (error expected)"

# Test Case 3: Attempt csm_allocation_update_state as owner
su -c "${CSM_PATH}/csm_allocation_update_state -a ${allocation_id} -s running" ${USER} > ${TEMP_LOG} 2>&1
check_return_exit $? 0 "Test Case 3: Attempt csm_allocation_update_state as owner"

# Test Case 3: Validate state transitions in csm_allocation_query_details
${CSM_PATH}/csm_allocation_query_details -a ${allocation_id} > ${TEMP_LOG} 2>&1
check_all_output "staging-in" "to-running" "running" "${USER}"
check_return_flag $? "Test Case 3: Validate state transitions in csm_allocation_query_details"

# Test Case 4: Attempt csm_allocation_update_state as secondary non-root user (error expected)
su -c "${CSM_PATH}/csm_allocation_update_state -a ${allocation_id} -s staging-out" ${SECOND_USER} > ${TEMP_LOG} 2>&1
check_return_exit $? 16 "Test Case 4: Attempt csm_allocation_update_state as secondary non-root user (error expected)"

# Test Case 4: Attempt csm_allocation_update_state as owner
su -c "${CSM_PATH}/csm_allocation_update_state -a ${allocation_id} -s staging-out" ${USER} > ${TEMP_LOG} 2>&1
check_return_exit $? 0 "Test Case 4: Attempt csm_allocation_update_state as owner"

# Test Case 4: Validate state transitions in csm_allocation_query_details
${CSM_PATH}/csm_allocation_query_details -a ${allocation_id} > ${TEMP_LOG} 2>&1
check_all_output "staging-in" "to-running" "running" "to-staging-out" "staging-out" "${USER}"
check_return_flag $? "Test Case 4: Validate state transitions in csm_allocation_query_details"

# Test Case 5: Calling csm_allocation_delete as user ${USER}
su -c "${CSM_PATH}/csm_allocation_delete -a ${allocation_id}" ${USER} > ${TEMP_LOG} 2>&1
check_return_exit $? 0 "Test Case 5: Calling csm_allocation_delete as user ${USER}"

# Test Case 5: Checking allocation deleted
${CSM_PATH}/csm_allocation_query_active_all > ${TEMP_LOG} 2>&1
check_return_exit $? 4 "Test Case 5: Checking allocation deleted"

echo "Section D COMPLETED!" >> ${LOG}
rm -f ${TEMP_LOG}

echo "------------------------------------------------------------" >> ${LOG}
echo "         Advanced Allocation Bucket COMPLETED" >> ${LOG}
echo "------------------------------------------------------------" >> ${LOG}
echo "Additional Flags:" >> ${LOG}
echo -e "${FLAGS}" >> ${LOG}
echo "------------------------------------------------------------" >> ${LOG}
exit 0
