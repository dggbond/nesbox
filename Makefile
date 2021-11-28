local_test:
	@ dart test --no-chain-stack-traces --timeout none

ci_test:
	@ CI=true dart test --no-chain-stack-traces
