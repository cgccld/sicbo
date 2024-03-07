Sicbo deployment

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
        --etherscan-api-key $SNOWTRACE_SCAN \
        --private-key $DEPLOYER_KEY \
        --broadcast --verify -vv

VERIFY

$ source .env
$ forge verify-contract \
        0xE406c1E238e17C4c854571EC48dBAD169579b381 \
        ./src/v0/Sicbo.sol:Sicbo \
        --chain fuji \
        --etherscan-api-key $SNOWTRACE_SCAN \
        --watch \


SIMULATION

$ source .env
$ forge script script/Sicbo.s.sol \
        -f fuji \
        --etherscan-api-key $SNOWTRACE_SCAN \
        --private-key $DEPLOYER_KEY \
        -vv

DEBUG

$ source .env
$ forge script script/Debug.s.sol \
        --sig 'debug(uint256, address, address, uint256, bytes)' \
        $BLOCK $FROM $TO $VALUE $CALLDATA
        -f fuji \
        -vv

-tasibii