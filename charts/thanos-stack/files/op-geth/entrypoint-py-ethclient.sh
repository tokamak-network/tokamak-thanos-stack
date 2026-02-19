#!/bin/sh
set -exu

wget \
	"${GENESIS_FILE_URL}" \
	-q \
	-O genesis.json

DATA_DIR="${GETH_DATA_DIR:-/db}"
CHAIN_ID="${CHAIN_ID:-42069}"
RPC_PORT="${RPC_PORT:-8545}"
WS_PORT="${WS_PORT:-8546}"
LOG_LEVEL="${LOG_LEVEL:-INFO}"

exec python3 -m ethclient.main \
	--genesis genesis.json \
	--data-dir "$DATA_DIR" \
	--rpc-port "$RPC_PORT" \
	--port 30303 \
	--engine-port 8551 \
	--jwt-secret /op-geth-auth/jwt.txt \
	--log-level "$LOG_LEVEL" \
	--sync-mode full \
	"$@"
