build:
	@echo "Please enter your API key:"
	@read -p "API Key: " api_key; \
	chmod +x create_fullvm_ubuntu_xrdp_flist.sh; \
	sudo ./create_fullvm_ubuntu_xrdp_flist.sh "$$api_key"

delete:
	sudo rm -rf ubuntu-noble
	sudo rm -rf logs
	sudo rm ubuntu-24.04_fullvm_xrdp.tar.gz