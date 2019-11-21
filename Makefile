lint:
	bash ./scripts/veri_lint.sh
strict_lint:
	bash ./scripts/veri_lint_strict.sh
local_spyglass:
	bash ./scripts/local_spy.sh
remote_spyglass:
	bash ./scripts/spyglass_ci.sh
init:
	git config core.hooksPath .githooks

