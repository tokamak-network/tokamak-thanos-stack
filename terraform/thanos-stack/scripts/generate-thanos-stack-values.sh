#!/usr/bin/env bash

# This script generates the thanos-stack-values.yaml based on environment variables.

echo -e "[INFO] Starting environment variable validation"

# Check and validate required environment variables
reqenv() {
    if [ -z "${!1}" ]; then
        echo "Error: Required environment variable '$1' is undefined"
        exit 1
    fi
}

for i in {1..3}; do
    echo "."
    sleep 0.7
done

echo -e "[INFO] All required environment variables are present"

# Required environment variables
reqenv "stack_deployments_path"
reqenv "stack_infra_name"
reqenv "stack_infra_region"
reqenv "stack_l1_rpc_url"
reqenv "stack_l1_rpc_provider"
reqenv "stack_l1_beacon_url"
reqenv "stack_efs_id"
reqenv "stack_genesis_file_url"
reqenv "stack_prestate_file_url"
reqenv "stack_rollup_file_url"
reqenv "stack_op_geth_image_tag"
reqenv "stack_thanos_stack_image_tag"
reqenv "stack_max_channel_duration"
reqenv "txmgr_cell_proof_time"

# Customizable variables with defaults
: "${stack_nativetoken_name:=Tokamak Network Token}"
: "${stack_nativetoken_symbol:=TON}"
: "${stack_nativetoken_decimals:=18}"

# Check if the deployments file exists
if [ ! -f "$stack_deployments_path" ]; then
    echo "Error: Deployments file not found at $stack_deployments_path"
    exit 1
fi

# Parse and store values
DisputeGameFactoryProxy=$(jq -r '.DisputeGameFactoryProxy // empty' "$stack_deployments_path")
L2OutputOracleProxy=$(jq -r '.L2OutputOracleProxy // empty' "$stack_deployments_path")

# Validate parsed values
if [ -z "$DisputeGameFactoryProxy" ]; then
    echo "Error: 'DisputeGameFactoryProxy' value not found in $stack_deployments_path"
    exit 1
fi

if [ -z "$L2OutputOracleProxy" ]; then
    echo "Error: 'L2OutputOracleProxy' value not found in $stack_deployments_path"
    exit 1
fi

# Extract values from terraform output
extract_from_tf() {
    local key=$1
    local dir=$2
    local current_dir=$(pwd)

    cd "$dir" || exit
    # Get the value from terraform output
    local value=$(terraform output | awk -v key="$key" '$1 == key {print $3}' | tr -d '"')
    cd "$current_dir" || exit

    if [ -z "$value" ]; then
        echo "Error: Failed to retrieve $key from terraform output in $dir"
        exit 1
    fi
    
    echo "$value"
}

efs_id="$stack_efs_id"
genesis_file_url="$stack_genesis_file_url"
prestate_file_url="$stack_prestate_file_url"
rollup_file_url="$stack_rollup_file_url"
op_geth_image_tag="$stack_op_geth_image_tag"
thanos_stack_image_tag="$stack_thanos_stack_image_tag"
max_channel_duration="$stack_max_channel_duration"

# Download rollup.json file
echo ""
echo -e "[INFO] Downloading rollup.json file....."
curl -o rollup.json "$rollup_file_url"

# Extract values from the rollup.json file
l1_system_config_address=$(jq '.l1_system_config_address' rollup.json)
l1_batch_start_block=$(jq '.genesis.l1.number' rollup.json)
batch_inbox_address=$(jq '.batch_inbox_address' rollup.json)
l1_batch_submitter=$(jq '.genesis.system_config.batcherAddr' rollup.json)
l2_batch_genesis_block_number=$(jq '.genesis.l2.number' rollup.json)
l1_portal_contract=$(jq '.deposit_contract_address' rollup.json)
l2_withdrawals_start_block=$((l2_batch_genesis_block_number + 1))
block_duration=$(jq '.block_time' rollup.json)
l2_chain_id=$(jq '.l2_chain_id' rollup.json)

# Delete rollup.json file
echo ""
rm rollup.json
echo -e "[INFO] rollup.json file deleted successfully"

# Generate the YAML file
yaml=$(cat <<EOL
thanos_stack_infra:
  name: "$stack_infra_name"
  region: "$stack_infra_region"

enable_vpc: false
enable_deployment: false

l1_rpc:
  url: $stack_l1_rpc_url
  kind: $stack_l1_rpc_provider

op_geth:
  image: "tokamaknetwork/thanos-op-geth:nightly-$op_geth_image_tag"
  volume:
    csi:
      volumeHandle: "$efs_id"
  ingress:
    enabled: true
    className: alb
    annotations:
      alb.ingress.kubernetes.io/target-type: ip
      alb.ingress.kubernetes.io/scheme: internet-facing
      alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
      alb.ingress.kubernetes.io/group.name: op-geth
  env:
    chain_id: "$l2_chain_id"
    genesis_file_url: $genesis_file_url

op_node:
  image: "tokamaknetwork/thanos-op-node:nightly-$thanos_stack_image_tag"
  volume:
    csi:
      volumeHandle: "$efs_id"
  env:
    rollup_config_url: $rollup_file_url
    l1_beacon: $stack_l1_beacon_url   
    # Op-node flags for rate limiting and optimization
    l1_max_concurrency: 2
    l1_rpc_rate_limit: 10

op_batcher:
  image: "tokamaknetwork/thanos-op-batcher:nightly-$thanos_stack_image_tag"
  env:
    max_channel_duration: $max_channel_duration
    txmgr_cell_proof_time: "$txmgr_cell_proof_time"

op_proposer:
  image: "tokamaknetwork/thanos-op-proposer:nightly-$thanos_stack_image_tag"
  enabled: true
  env:
    l2oo_address: $L2OutputOracleProxy
EOL
)

echo "$yaml" > ./thanos-stack-values.yaml
echo ""
echo "[INFO] The thanos-stack-values.yaml file has been successfully created!"
