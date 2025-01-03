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
reqenv "stack_op_geth_hostname"
reqenv "stack_chain_id"
reqenv "stack_l1_beacon_url"
reqenv "stack_graph_node_network_name"
reqenv "stack_graph_node_hostname"
reqenv "stack_ipfs_hostname"
reqenv "stack_coinmarketcap_api_key"
reqenv "stack_coinmarketcap_coin_id"
reqenv "stack_blockscout_hostname"
reqenv "stack_blockscout_stats_hostname"
reqenv "stack_helm_release_name"
reqenv "stack_network_name"
reqenv "stack_wallet_connect_project_id"

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

# Extract values from terraform outputs
thanos_stack_dir="../terraform/thanos-stack"
efs_id=$(extract_from_tf "efs_id" "$thanos_stack_dir")
rds_address=$(extract_from_tf "rds_address" "$thanos_stack_dir")
rds_endpoint=$(extract_from_tf "rds_endpoint" "$thanos_stack_dir")
rds_port=$(extract_from_tf "rds_port" "$thanos_stack_dir")

chain_config_dir="../terraform/chain-config"
genesis_file_url=$(extract_from_tf "genesis_file_url" "$chain_config_dir")
prestate_file_url=$(extract_from_tf "prestate_file_url" "$chain_config_dir")
prestate_file=${prestate_file_url%/*}
rollup_file_url=$(extract_from_tf "rollup_file_url" "$chain_config_dir")

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

# Delete rollup.json file
echo ""
rm rollup.json
echo -e "[INFO] rollup.json file deleted successfully"

# Generate the YAML file
yaml=$(cat <<EOL
thanos_stack_infra:
  name: "$stack_infra_name"
  region: "$stack_infra_region"

l1_rpc:
  url: $stack_l1_rpc_url
  kind: $stack_l1_rpc_provider

op_geth:
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
    chain_id: "$stack_chain_id"
    genesis_file_url: $genesis_file_url

op_node:
  volume:
    csi:
      volumeHandle: "$efs_id"
  env:
    rollup_config_url: $rollup_file_url
    l1_beacon: $stack_l1_beacon_url

op_batcher:
  env:
    max_channel_duration: 1500

op_proposer:
  enabled: false
  env:
    l2oo_address: $L2OutputOracleProxy
    game_factory_address: $DisputeGameFactoryProxy
    proposal_interval: 21600s

op_challenger:
  enabled: false
  volume:
    csi:
      volumeHandle: "$efs_id"
  env:
    l1_beacon: $stack_l1_beacon_url
    game_factory_address: $DisputeGameFactoryProxy
    cannon_rollup_config_url: $rollup_file_url
    cannon_l2_genesis_url: $genesis_file_url
    cannon_prestates_url: $prestate_file

graph_node:
  enabled: false
  network_name: "$stack_graph_node_network_name"
  ingress:
    enabled: true
  env:
    postgres_host: $rds_address
  secret:
    postgres_pass: postgres
    PGPASSWORD: postgres
ipfs:
  ingress:
    enabled: true
  volume:
    csi:
      volumeHandle: "$efs_id"

blockscout-stack:
  blockscout:
    enabled: false
    image:
      repository: blockscout/blockscout-optimism
      tag: 6.9.2
    env:
      CHAIN_TYPE: "optimism"
      DATABASE_URL: "postgresql://postgres:postgres@$rds_endpoint/blockscout"

      ETHEREUM_JSONRPC_VARIANT: geth
      ETHEREUM_JSONRPC_HTTP_URL: "http://$stack_helm_release_name-thanos-stack-op-geth:8545"
      ETHEREUM_JSONRPC_TRACE_URL: "http://$stack_helm_release_name-thanos-stack-op-geth:8545"
      ETHEREUM_JSONRPC_WS_URL: "ws://$stack_helm_release_name-thanos-stack-op-geth:8546"
      CONTRACT_DISABLE_INTERACTION: false
      CHAIN_SPEC_PATH: $genesis_file_url
      SECRET_KEY_BASE: 56NtB48ear7+wMSf0IQuWDAAazhpb31qyc7GiyspBP2vh7t5zlCsF5QDv76chXeN
      EXCHANGE_RATES_MARKET_CAP_SOURCE: coin_market_cap
      EXCHANGE_RATES_COINMARKETCAP_API_KEY: $stack_coinmarketcap_api_key
      EXCHANGE_RATES_COINMARKETCAP_COIN_ID: "$stack_coinmarketcap_coin_id"
      # MICROSERVICES
      MICROSERVICE_SC_VERIFIER_ENABLED: true
      MICROSERVICE_SC_VERIFIER_URL: "https://eth-bytecode-db.services.blockscout.com"
      MICROSERVICE_SC_VERIFIER_TYPE: eth_bytecode_db
      # Optimism
      INDEXER_OPTIMISM_L1_RPC: "$stack_l1_rpc_url"
      INDEXER_OPTIMISM_L1_SYSTEM_CONFIG_CONTRACT: $l1_system_config_address
      INDEXER_OPTIMISM_L1_BATCH_START_BLOCK: "$l1_batch_start_block"
      INDEXER_OPTIMISM_L1_BATCH_INBOX: $batch_inbox_address
      INDEXER_OPTIMISM_L1_BATCH_SUBMITTER: $l1_batch_submitter
      INDEXER_OPTIMISM_L1_BATCH_BLOCKSCOUT_BLOBS_API_URL: "https://eth.blockscout.com/api/v2/blobs"
      INDEXER_OPTIMISM_L2_BATCH_GENESIS_BLOCK_NUMBER: "$l2_batch_genesis_block_number"
      INDEXER_OPTIMISM_L1_OUTPUT_ROOTS_START_BLOCK: "$l1_batch_start_block"
      INDEXER_OPTIMISM_L1_OUTPUT_ORACLE_CONTRACT: "$L2OutputOracleProxy"
      INDEXER_OPTIMISM_L1_PORTAL_CONTRACT: $l1_portal_contract
      INDEXER_OPTIMISM_L1_DEPOSITS_START_BLOCK: "$l1_batch_start_block"
      INDEXER_OPTIMISM_L1_WITHDRAWALS_START_BLOCK: "$l1_batch_start_block"
      INDEXER_OPTIMISM_L2_WITHDRAWALS_START_BLOCK: "$l2_withdrawals_start_block"
      INDEXER_OPTIMISM_L2_MESSAGE_PASSER_CONTRACT: "0x4200000000000000000000000000000000000016"
      INDEXER_OPTIMISM_BLOCK_DURATION: $block_duration

    ingress:
      enabled: true
      className: alb
      annotations:
        alb.ingress.kubernetes.io/target-type: ip
        alb.ingress.kubernetes.io/scheme: internet-facing
        alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
        alb.ingress.kubernetes.io/group.name: blockscout
      tls:
        enabled: false
      hostname: ""
  config:
    network:
      id: "$stack_chain_id"
      name: $stack_network_name
      shortname: $stack_network_name
      currency:
        name: $stack_nativetoken_name
        symbol: $stack_nativetoken_symbol
        decimals: $stack_nativetoken_decimals

    prometheus:
      enabled: false

  frontend:
    enabled: false
    image:
      tag: v1.36.4
    replicaCount: 1

    env:
      NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID: "$stack_wallet_connect_project_id"
      NEXT_PUBLIC_NETWORK_RPC_URL: http://$stack_helm_release_name-thanos-stack-op-geth:8545
      NEXT_PUBLIC_HOMEPAGE_CHARTS: "['daily_txs','coin_price','market_cap']"
      NEXT_PUBLIC_API_SPEC_URL: "https://raw.githubusercontent.com/blockscout/blockscout-api-v2-swagger/main/swagger.yaml"
      NEXT_PUBLIC_WEB3_DISABLE_ADD_TOKEN_TO_WALLET: false
      NEXT_PUBLIC_AD_BANNER_PROVIDER: none
      NEXT_PUBLIC_AD_TEXT_PROVIDER: none
      # NEXT_PUBLIC_VIEWS_NFT_MARKETPLACES: --> https://github.com/blockscout/frontend/blob/main/docs/ENVS.md#nft-views
      NEXT_PUBLIC_NETWORK_LOGO: "https://thanos-assets.s3.ap-northeast-2.amazonaws.com/thanos_B.png"
      NEXT_PUBLIC_NETWORK_LOGO_DARK: "https://thanos-assets.s3.ap-northeast-2.amazonaws.com/thanos_W.png"
      NEXT_PUBLIC_NETWORK_ICON: "https://thanos-assets.s3.ap-northeast-2.amazonaws.com/thanos_network-icon.png"
      NEXT_PUBLIC_NETWORK_ICON_DARK: "https://thanos-assets.s3.ap-northeast-2.amazonaws.com/thanos_network-icon.png"
      FAVICON_GENERATOR_API_KEY: 9cbebba57891c43c345be98d6e22a3efc1b9ca79
      FAVICON_MASTER_URL: "https://tokamak-thanos.s3.ap-northeast-2.amazonaws.com/thanos_favicon.png"
      # Optimistic rollup (L2) chain
      NEXT_PUBLIC_ROLLUP_TYPE: "optimistic"
      NEXT_PUBLIC_ROLLUP_L1_BASE_URL: "https://eth.blockscout.com"
      NEXT_PUBLIC_ROLLUP_L2_WITHDRAWAL_URL: "https://app.optimism.io/bridge/withdraw"
      NEXT_PUBLIC_FAULT_PROOF_ENABLED: true
      NEXT_PUBLIC_API_PROTOCOL: http
      NEXT_PUBLIC_APP_PROTOCOL: http
      NEXT_PUBLIC_API_WEBSOCKET_PROTOCOL: ws
      NEXT_PUBLIC_API_HOST: 
      NEXT_PUBLIC_APP_HOST: 

    ingress:
      enabled: true
      className: alb
      annotations:
        alb.ingress.kubernetes.io/target-type: ip
        alb.ingress.kubernetes.io/scheme: internet-facing
        alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
        alb.ingress.kubernetes.io/group.name: blockscout
      tls:
        enabled: false
      hostname: ""
EOL
)

echo "$yaml" > ./thanos-stack-values.yaml
echo ""
echo "[INFO] The thanos-stack-values.yaml file has been successfully created!"
