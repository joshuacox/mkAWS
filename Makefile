all: help

help:
	-@echo "read the README.md for more"

rancher: AMI_ID rancher-make

rancher-make:
	$(eval AMI_ID := $(shell cat AMI_ID))
	$(eval SG_ID := $(shell cat SG_ID))
	$(eval SSH_KEY := $(shell cat SSH_KEY))
	aws ec2 run-instances --image-id $(AMI_ID) --count 1 --instance-type t2.micro --key-name $(SSH_KEY) --security-groups $(SG_ID)

AMI_ID:
	@while [ -z "$$AMI_ID" ]; do \
		read -r -p "Enter the AMI_ID you wish to associate with this cluster [AMI_ID]: " AMI_ID; echo "$$AMI_ID">>AMI_ID; cat AMI_ID; \
	done ;

SG_ID:
	@while [ -z "$$SG_ID" ]; do \
		read -r -p "Enter the SG_ID you wish to associate with this cluster [SG_ID]: " SG_ID; echo "$$SG_ID">>SG_ID; cat SG_ID; \
	done ;

SSH_KEY:
	@while [ -z "$$SSH_KEY" ]; do \
		read -r -p "Enter the path to the SSH_KEY you wish to associate with this cluster [SSH_KEY]: " SSH_KEY; echo "$$SSH_KEY">>SSH_KEY; cat SSH_KEY; \
	done ;
