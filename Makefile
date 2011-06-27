pkg_dir = pkg

etc_files = wamupd.yaml.dist
rc_files = rc.d/wamupd
sbin_files = src/wamupd.rb
lib_files = src/action.rb src/avahi_model.rb src/avahi_service.rb \
	src/avahi_service_file.rb src/dns_avahi_controller.rb \
	src/dns_ip_controller.rb src/dns_update.rb src/lease_update.rb \
	src/main_settings.rb src/signals.rb
pkg_files = pkg_src/comment pkg_src/desc pkg_src/packing_list

.PHONY : all clean

all: pkg

clean:
	rm -rf $(pkg_dir)
	rm -f wamupd.tbz

pkg_setup: $(etc_files) $(rc_files) $(sbin_files) $(lib_files) \
           $(pkg_files)
	mkdir -p $(pkg_dir)/etc/rc.d $(pkg_dir)/sbin \
		$(pkg_dir)/lib/ruby/1.9/wamupd
	cp -f $(etc_files) $(pkg_dir)/etc/
	cp -f $(rc_files) $(pkg_dir)/etc/rc.d/
	cp -f $(sbin_files) $(pkg_dir)/sbin
	cp -f $(lib_files) $(pkg_dir)/lib/ruby/1.9/wamupd/
	cp -f $(pkg_files) $(pkg_dir)/
	mv $(pkg_dir)/sbin/wamupd.rb $(pkg_dir)/sbin/wamupd

pkg: pkg_setup
	cd $(pkg_dir) && pkg_create -c comment -d desc -f packing_list \
	-v wamupd && mv wamupd.tbz ../

doc::
	rdoc -U -x test/ --main src/main.rb
	rdoc -Ur -x test/ --main src/main.rb

dist::
	git archive master --prefix=wamupd/ -o wamupd-latest.tar
	bzip2 wamupd-latest.tar
