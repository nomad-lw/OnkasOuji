-include .env

.PHONY: deploy-testnet deploy setup setup-testnet snapshot-testnet snapshot test-testnet build test


build:
	@echo "Building All Contracts..."
	@forge build --no-cache

build-essential: src/Wyrd.sol src/OnkasOujiGame.sol
	@forge build src/Wyrd.sol src/OnkasOujiGame.sol \
	    --force -vvv

test:
	@forge test -v

deploy-testnet: script/Deploy.s.sol
	@forge script script/Deploy.s.sol:DeployScript \
		--rpc-url ${TESTNET_RPC_URL} \
		--verifier blockscout \
        --verifier-url 'https://sanko-arb-sepolia.explorer.caldera.xyz/api/' \
		--broadcast \
		--verify \
		-vvvv\
		--no-cache

deploy: script/Deploy.s.sol
	@forge script script/Deploy.s.sol:DeployScript \
		--rpc-url ${MAINNET_RPC_URL} \
		--broadcast \
		-vvvv\
		--no-cache

setup-testnet: script/Setup.s.sol
	@forge script script/Setup.s.sol:SetupScript \
		--rpc-url ${TESTNET_RPC_URL} \
		--broadcast \
		-vvvv\
		--no-cache

setup: script/Setup.s.sol
	@forge script script/Setup.s.sol:SetupScript \
		--rpc-url ${MAINNET_RPC_URL} \
		--broadcast \
		-vvvv\
		--no-cache

snapshot-testnet: script/Setup.s.sol
	@forge script script/Setup.s.sol:SetupScript \
		--sig 'state_snapshot()' \
		--rpc-url ${TESTNET_RPC_URL} \
		-vvvv

snapshot: script/Setup.s.sol
	@forge script script/Setup.s.sol:SetupScript \
		--sig 'state_snapshot()' \
		--rpc-url ${MAINNET_RPC_URL} \
		--broadcast \
		-vvvv

test-testnet: script/Integration.s.sol
	@forge script script/Integration.s.sol:IntegrationScript \
		--rpc-url ${TESTNET_RPC_URL} \
		--broadcast \
		-vvvv\
		--no-cache
