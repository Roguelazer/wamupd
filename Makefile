doc::
	rdoc -U -x test/ --main src/main.rb
	rdoc -Ur -x test/ --main src/main.rb

dist::
	git archive master --prefix=wamupd/ -o wamupd-latest.tar
	bzip2 wamupd-latest.tar
