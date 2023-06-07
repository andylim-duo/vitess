#!/bin/bash

# Copyright 2019 The Vitess Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# this script brings up zookeeper and all the vitess components
# required for a single shard deployment.

source ../common/env.sh

# start topo server
if [ "${TOPO}" = "zk2" ]; then
	CELL=zone1 ../common/scripts/zk-up.sh
elif [ "${TOPO}" = "k8s" ]; then
	CELL=zone1 ../common/scripts/k3s-up.sh
elif [ "${TOPO}" = "consul" ]; then
	CELL=zone1 ../common/scripts/consul-up.sh
else
	CELL=zone1 ../common/scripts/etcd-up.sh
fi

# start vtctld
CELL=zone1 ../common/scripts/vtctld-up.sh

# Setup 3 clusters (3 instances each). Two for sharded storage of User flavor
# data and one cluster that is unsharded for auto-increment tables
# ==============================================================================

# start vttablets for keyspace duo which will be sharded
echo "--- Setting up keyspace and instances for shareded cluster: duo"
for i in 100 101 102; do
	CELL=zone1 TABLET_UID=$i ../common/scripts/mysqlctl-up.sh
	SHARD=-80 CELL=zone1 KEYSPACE=duo TABLET_UID=$i ../common/scripts/vttablet-up.sh
done

echo "--- Setting up keyspace and instances for 2nd shareded cluster: duo"
for i in 200 201 202; do
	CELL=zone1 TABLET_UID=$i ../common/scripts/mysqlctl-up.sh
	SHARD=80- CELL=zone1 KEYSPACE=duo TABLET_UID=$i ../common/scripts/vttablet-up.sh
done

# set the correct durability policy for the keyspace
echo "--- Setting up durability policy..."
vtctldclient --server localhost:15999 SetKeyspaceDurabilityPolicy --durability-policy=semi_sync duo || fail "Failed to set keyspace durability policy on the duo keyspace"

# start vtorc
echo "--- Starting VTorc ..."
../common/scripts/vtorc-up.sh

# Wait for all the tablets to be up and registered in the topology server
# and for a primary tablet to be elected in the shard and become healthy/serving.
echo "--- Waithing for healthy instances on duo keyspace with 2 shards"
for shard in "-80" "80-"; do
	# Wait for all the tablets to be up and registered in the topology server
	# and for a primary tablet to be elected in the shard and become healthy/serving.
	wait_for_healthy_shard duo "${shard}" || exit 1
done;

# start vttablets for non-sharded keyspace to store sequence tables that will
# support cross-shard auto-increment capabilities
echo "--- Setting up keyspace for non-sharded sequence tables to support auto-increment fields"
for i in 300 301 302; do
	CELL=zone1 TABLET_UID=$i ../common/scripts/mysqlctl-up.sh
	CELL=zone1 KEYSPACE=duo_unsharded TABLET_UID=$i ../common/scripts/vttablet-up.sh
done

# set the correct durability policy for the keyspace
echo "--- Setting up durability policy for duo_unshared ..."
vtctldclient --server localhost:15999 SetKeyspaceDurabilityPolicy --durability-policy=semi_sync duo_unsharded || fail "Failed to set keyspace durability policy on the duo_unsharded keyspace"

echo "--- Waithing for healthy instances on duo_unsharded keyspace"
wait_for_healthy_shard duo_unsharded 0 || exit 1

# Setup unsharded keyspace tables for auto-increment sequence table ============

# create schema for unsharded tables to support cross-shard auto-increment columns
echo "-- Running: vtctldclient ApplySchema --sql-file duo_subsharded_unsharded_schema_update.sql duo_unsharded\n"
vtctldclient ApplySchema --sql-file duo_subsharded_unsharded_schema_update.sql duo_unsharded || fail "Failed to apply schema SQL for the duo_unsharded keyspace"

# create the vschema for the duo_unshared keyspace
echo "--- Running: vtctldclient ApplyVSchema --vschema-file vschema_duo_subsharded_unsharded.json duo"
vtctldclient ApplyVSchema --vschema-file vschema_duo_unsharded.json duo_unsharded || fail "Failed to apply vschema JSON for the duo_unsharded keyspace"

# Setup sharded keyspace tables for sharded User flavor database ===============

# create the schema
# vtctldclient ApplySchema --sql-file create_commerce_schema.sql commerce || fail "Failed to apply schema for the commerce keyspace"
echo "--- Running: vtctldclient ApplySchema --sql-file duo_subshard_schema_update.sql duo\n"
vtctldclient ApplySchema --sql-file duo_subshard_schema_update.sql duo || fail "Failed to apply schema for the duo keyspace"

# create the vschema
# vtctldclient ApplyVSchema --vschema-file vschema_commerce_initial.json commerce || fail "Failed to apply vschema for the commerce keyspace"
echo "--- Running: vtctldclient ApplyVSchema --vschema-file vschema_duo_subsharded.json duo"
vtctldclient ApplyVSchema --vschema-file vschema_duo_subsharded.json duo || fail "Failed to apply vschema JSON for the duo keyspace"

# start vtgate
echo "--- Starting vtgate ..."
CELL=zone1 ../common/scripts/vtgate-up.sh

# Start table replication of customer table from duo_unsharded to duo keyspaces.
# This sets up a customer reference table in each shard.
echo "--- Starting Materialize workflow to replicate the customer reference table to each shard."
vtctlclient Materialize -- --tablet_types=PRIMARY '{
    "workflow": "customer_reference_replication",
    "source_keyspace": "duo_unsharded",
    "target_keyspace": "duo",
    "table_settings": [{
        "target_table": "customers",
        "source_expression": "SELECT * FROM customers",
        "create_ddl": "copy"
    }],
    "cell": "zone1"
}'
vtctlclient Workflow -- duo listall

# start vtadmin
if [[ -n ${SKIP_VTADMIN} ]]; then
	echo -e "\nSkipping VTAdmin! If this is not what you want then please unset the SKIP_VTADMIN env variable in your shell."
else
	echo "--- Starting vtadmin ..."
	../common/scripts/vtadmin-up.sh
fi
