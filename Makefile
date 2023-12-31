# *** CI rules ***
lint:
	bash ./scripts/veri_lint.sh
	exit $?	
strict_lint:
	bash ./scripts/veri_lint_strict.sh
	exit $?	
local_spyglass:
	bash ./scripts/local_spy.sh
	exit $?	
remote_spyglass:
	bash ./scripts/spyglass_ci.sh
	exit $?	
init:
	git config core.hooksPath .githooks
	exit $?	
questa:
	rm -f /tmp/artifact_questa.log
	bash ./scripts/questa_ci.sh
	exit $?	
