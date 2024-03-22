『P』『A』『M』『P』 『D』『A』 『S』『H』『*』『T』 『C』『O』『I』『N』

INSTALLATION

$ forge install


COMPILATION

$ forge fmt
$ forge clean
$ forge build


TESTING

$ forge test


DEPLOYMENT

$ source .env
$ forge script script/Sicbo.s.sol \
        -f fuji \
        --etherscan-api-key $SNOWTRACE_KEY \
        --private-key $DEPLOYER_KEY \
        --with-gas-price $(cast gas-price $RPC_URL_FUJI)
        --broadcast --verify --legacy -vv

VERIFY

$ source .env
$ forge verify-contract \
        --chain-id 43113 \
        --num-of-optimizations 200000 \
        --watch \
        --constructor-args $(cast abi-encode "constructor(address,bytes)" 0x4e6bc3964dDe538ee0b04bD14f5360d993666cC3 $(cast calldata "initialize(address)" 0x7a2a5e973B944a66eCF29CcCAfC6184f179ee1A3)) \
        --etherscan-api-key $SNOWTRACE_KEY \
        --compiler-version 0.8.23+commit.f704f362 \
        0xE406c1E238e17C4c854571EC48dBAD169579b381 \
        ./src/v0/Sicbo.sol:Sicbo 

        
SIMULATION

$ source .env
$ forge script script/Sicbo.s.sol \
        -f fuji \
        --etherscan-api-key $SNOWTRACE_KEY \
        --private-key $DEPLOYER_KEY \
        -vv

DEBUG

$ source .env
$ forge script script/Debug.s.sol \
        --sig 'debug(uint256, address, address, uint256, bytes)' \
        $BLOCK $FROM $TO $VALUE $CALLDATA
        -f fuji \
        -vv

-cgccld