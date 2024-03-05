My minimal foundry template.

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
$ forge script script/SampleDeploy.s.sol \
        -f goerli \
        --etherscan-api-key $API_KEY_ETHERSCAN \
        --private-key $DEPLOYER_KEY \
        --broadcast --verify -vv

VERIFY

$ source .env
$ forge verify-contract \
        0x4259557F6665eCF5907c9019a30f3Cb009c20Ae7 \
        ./src/Sample.sol:Sample \
        --chain goerli \
        --etherscan-api-key $API_KEY_ETHERSCAN \
        --watch \


SIMULATION

$ source .env
$ forge script script/SampleDeploy.s.sol -f goerli --private-key $DEPLOYER_KEY -vv


DEBUG

$ source .env
$ forge script script/Debug.s.sol \
        --sig 'debug(uint256, address, address, uint256, bytes)' \
        $BLOCK $FROM $TO $VALUE $CALLDATA
        -f goerli \
        -vv

-tasibii