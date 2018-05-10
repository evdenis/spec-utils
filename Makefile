default:

test:
	prove --jobs 1 --shuffle --lib --recurse t/

.PHONY: default test
