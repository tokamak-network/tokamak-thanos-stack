#!/bin/sh
set -exu

wget \
    "${OP_NODE_ROLLUP_CONFIG_URL}" \
    -q \
    -O rollup.json.raw

# Strip fields not recognized by newer op-node versions (deprecated Plasma/Tokamak-specific).
# Removing da_challenge_contract_address and IsForkPublicNetwork leaves a trailing comma
# on protocol_versions_address, which we also strip directly.
sed -e '/da_challenge_contract_address/d' \
    -e '/IsForkPublicNetwork/d' \
    -e 's/\("protocol_versions_address":[^,]*\),/\1/' \
    rollup.json.raw > rollup.json

# Inject chain_op_config required by op-node v1.11.0+ (EIP-1559 params for Thanos).
sed 's/^}$/,"chain_op_config":{"eip1559Elasticity":6,"eip1559Denominator":50,"eip1559DenominatorCanyon":250}}/' \
    rollup.json > rollup.json.tmp && mv rollup.json.tmp rollup.json

exec op-node \
    --rollup.config=./rollup.json \
    --safedb.path=/safedb \
    --l1.trustrpc \
    "$@"
