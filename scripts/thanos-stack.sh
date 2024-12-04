#!/usr/bin/env bash

# This script is used to generate the thanos-stack-values.yaml

echo -e "* indicates a required input. Please enter the values.\n"

# Check required environment variables
reqenv() {
    local var_name=$1
    while true; do
        if [ -z "${!var_name}" ]; then
            read -p "* $var_name : " input
            if [ -z "$input" ]; then
                echo "Error! $var_name is required."
            else
                export $var_name="$input"
                break
            fi
        else
            break
        fi
    done
}

# Check optional environment variables
optenv() {
    local var_name=$1
    local default_value=$2
    read -p "$var_name (default: $default_value): " input
    if [ -z "$input" ]; then
        export $var_name="$default_value"
        echo "$var_name is not set. Using default value: $default_value"
    else
        export $var_name="$input"
    fi
}

# Required environment variables
reqenv_vars=(
    "stack_infra_name"
    "stack_infra_region"
    "stack_l1_rpc_url"
    "stack_l1_rpc_kind"
    "stack_op_geth_hostname"
    "stack_chain_id"
    "stack_l1_beacon_url"
    "stack_graph_node_hostname"
    "stack_ipfs_hostname"
    "stack_coinmarketcap_api_key"
    "stack_coinmarketcap_coin_id"
    "stack_blockscout_hostname"
    "stack_blockscout_stats_hostname"
    "stack_network_name"
    "wallet_connect_project_id"
)

# Optional environment variables
optenv_vars=(
    "stack_nativetoken_name:Tokamak Network Token"
    "stack_nativetoken_symbol:TON"
    "stack_nativetoken_decimals:18"
)

# Prompt for required environment variables
for var in "${reqenv_vars[@]}"; do
    reqenv "$var"
done

# Prompt for optional environment variables
for var in "${optenv_vars[@]}"; do
    IFS=":" read -r var_name default_value <<< "$var"
    optenv "$var_name" "$default_value"
done

# Extract values from Terraform output
extract_from_terraform() {
    local key=$1
    local dir=$2
    local current_dir=$(pwd)

    cd "$dir" || exit
    # Get the value from terraform output
    local value=$(terraform output | awk -v key="$key" '$1 == key {print $3}' | tr -d '"')
    cd "$current_dir" || exit

    if [ -z "$value" ]; then
        echo "Error: Failed to retrieve $key from terraform output in $dir."
        exit 1
    fi
    echo "$value"
}

# Extract values from Terraform outputs
thanos_stack_dir="../terraform/thanos-stack"
efs_id=$(extract_from_terraform "efs_id" "$thanos_stack_dir")
rds_endpoint=$(extract_from_terraform "rds_endpoint" "$thanos_stack_dir")

chain_config_dir="../terraform/chain-config"
genesis_file_url=$(extract_from_terraform "genesis_file_url" "$chain_config_dir")
prestate_file_url=$(extract_from_terraform "prestate_file_url" "$chain_config_dir")
rollup_file_url=$(extract_from_terraform "rollup_file_url" "$chain_config_dir")

# Extracted values
echo "======================================="
echo "efs_id: $efs_id"
echo "rds_endpoint: $rds_endpoint"
echo "genesis_file_url: $genesis_file_url"
echo "prestate_file_url: $prestate_file_url"
echo "rollup_file_url: $rollup_file_url"

# Download chain-config files
curl -o genesis.json "$genesis_file_url"
curl -o prestate.json "$prestate_file_url"
curl -o rollup.json "$rollup_file_url"

# Extract values from the chain-config file
l1_batch_start_block=$(jq '.genesis.l1.number' rollup.json)
batch_inbox_address=$(jq '.batch_inbox_address' rollup.json)
l1_batch_submitter=$(jq '.genesis.system_config.batcherAddr' rollup.json)
l2_batch_genesis_block_number=$(jq '.genesis.l2.number' rollup.json)
l1_output_oracle_contract="a"
l1_portal_contract=$(jq '.deposit_contract_address' rollup.json)
l2_withdrawals_start_block=$((l2_batch_genesis_block_number + 1))
block_duration=$(jq '.block_time' rollup.json)

# Generate the YAML file
yaml=$(cat <<EOL
thanos_stack_infra:
  name: "$stack_infra_name"
  region: "$stack_infra_region"

l1_rpc:
  url: $stack_l1_rpc_url
  kind: $stack_l1_rpc_kind

op_geth:
  volume:
    csi:
      volumeHandle: "$efs_id"
  ingress:
    hostname: "$stack_op_geth_hostname"
  env:
    chain_id: "$stack_chain_id"
    genesis_file_url: $genesis_file_url
    geth_override_fjord: "1733110200"

op_node:
  volume:
    csi:
      volumeHandle: "$efs_id"
  env:
    rollup_config_url: $rollup_file_url
    l1_beacon: $stack_l1_beacon_url

op_batcher:
  env:
    max_channel_duration: 60

op-proposer:
  enabled: true
  env:
    game_factory_address: "addresses.json"
    proposal_interval: 1440s

op-challenger:
  enabled: true
  volume:
    csi:
      volumeHandle: "$efs_id"
  env:
    l1_beacon: $stack_l1_beacon_url
    game_factory_address: "addresses.json"
    cannon_rollup_config_url: $rollup_file_url
    cannon_l2_genesis_url: $genesis_file_url
    cannon_prestates_url: $prestate_file_url

graph_node:
  enabled: true
  ingress:
    hostname: "$stack_graph_node_hostname"
  env:
    postgres_host: $rds_endpoint
    secret:
      postgres_pass: postgres
    PGPASSWORD: postgres

ipfs:
  ingress:
    hostname: "$stack_ipfs_hostname"
  volume:
    csi:
      volumeHandle: "$efs_id"

blockscout-stack:
  blockscout:
    image:
      repository: blockscout/blockscout-optimism
      tag: 6.9.2
    env:
      CHAIN_TYPE: "optimism"
      DATABASE_URL: "postgresql://postgres:postgres@$rds_endpoint/blockscout"
      ETHEREUM_JSONRPC_VARIANT: geth
      ETHEREUM_JSONRPC_HTTP_URL: "http://sepolia-thanos-stack-op-geth:8545"
      ETHEREUM_JSONRPC_TRACE_URL: "http://sepolia-thanos-stack-op-geth:8545"
      ETHEREUM_JSONRPC_WS_URL: "ws://sepolia-thanos-stack-op-geth:8546"
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
      INDEXER_OPTIMISM_L1_BATCH_START_BLOCK: "$l1_batch_start_block"
      INDEXER_OPTIMISM_L1_BATCH_INBOX: $batch_inbox_address
      INDEXER_OPTIMISM_L1_BATCH_SUBMITTER: $l1_batch_submitter
      INDEXER_OPTIMISM_L1_BATCH_BLOCKSCOUT_BLOBS_API_URL: "https://eth.blockscout.com/api/v2/blobs"
      INDEXER_OPTIMISM_L2_BATCH_GENESIS_BLOCK_NUMBER: "$l2_batch_genesis_block_number"
      INDEXER_OPTIMISM_L1_OUTPUT_ROOTS_START_BLOCK: "$l1_batch_start_block"
      INDEXER_OPTIMISM_L1_OUTPUT_ORACLE_CONTRACT: $l1_output_oracle_contract
      INDEXER_OPTIMISM_L1_PORTAL_CONTRACT: $l1_portal_contract
      INDEXER_OPTIMISM_L1_DEPOSITS_START_BLOCK: "$l1_batch_start_block"
      INDEXER_OPTIMISM_L1_WITHDRAWALS_START_BLOCK: "$l1_batch_start_block"
      INDEXER_OPTIMISM_L2_WITHDRAWALS_START_BLOCK: "$l2_withdrawals_start_block"
      INDEXER_OPTIMISM_L2_MESSAGE_PASSER_CONTRACT: "0x4200000000000000000000000000000000000016"
      INDEXER_OPTIMISM_BLOCK_DURATION: "$block_duration"
  ingress:
    enabled: true
    className: alb
    annotations:
      alb.ingress.kubernetes.io/target-type: ip
      alb.ingress.kubernetes.io/scheme: internet-facing
      alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS":443}]'
      alb.ingress.kubernetes.io/ssl-redirect: "443"
      alb.ingress.kubernetes.io/group.name: thanos-stack
    tls:
      enabled: true
    hostname: "$stack_blockscout_hostname"

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
    image:
      tag: v1.36.4
    replicaCount: 1
    env:
      NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID: "$stack_wallet_connect_project_id"
      NEXT_PUBLIC_NETWORK_RPC_URL: https://$stack_op_geth_hostname
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
  ingress:
    enabled: true
    className: alb
    annotations:
      alb.ingress.kubernetes.io/target-type: ip
      alb.ingress.kubernetes.io/scheme: internet-facing
      alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS":443}]'
      alb.ingress.kubernetes.io/ssl-redirect: "443"
      alb.ingress.kubernetes.io/group.name: thanos-stack
    tls:
      enabled: true
    hostname: $stack_blockscout_hostname

  stats:
    enabled: true
    image:
      tag: v2.2.3
    env:
      STATS__DB_URL: "postgresql://postgres:postgres@$rds_endpoint/stats"
      STATS__BLOCKSCOUT_DB_URL: "postgresql://postgres:postgres@$rds_endpoint/blockscout"
      STATS__CREATE_DATABASE: true
      STATS__RUN_MIGRATIONS: true
      STATS__FORCE_UPDATE_ON_START: true
      STATS__SERVER__HTTP__CORS__ENABLED: true
      STATS__SERVER__HTTP__CORS__ALLOWED_ORIGIN: "https://$stack_blockscout_hostname"
  ingress:
    enabled: true
    className: alb
    annotations:
      alb.ingress.kubernetes.io/target-type: ip
      alb.ingress.kubernetes.io/scheme: internet-facing
      alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS":443}]'
      alb.ingress.kubernetes.io/ssl-redirect: "443"
      alb.ingress.kubernetes.io/group.name: thanos-stack
    tls:
      enabled: true
    hostname: $stack_blockscout_stats_hostname
EOL
)

echo "$yaml" > ./stack-values_3.yaml
echo "Generated YAML configuration in scripts/stack-values.yaml"
