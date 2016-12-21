all: help

help:
	-@echo "read the README.md for more"

rancher: AMI_ID SG_ID WORKER_COUNT SSH_KEY rancherServer rancherAgent

rancherAgent:
	$(eval AMI_ID := $(shell cat AMI_ID))
	$(eval SG_ID := $(shell cat SG_ID))
	$(eval SSH_KEY := $(shell cat SSH_KEY))
	$(eval WORKER_COUNT := $(shell cat WORKER_COUNT))
	aws ec2 run-instances --image-id $(AMI_ID) --count $(WORKER_COUNT) --instance-type t2.micro --key-name $(SSH_KEY) --security-groups $(SG_ID)

rancherServer:
	$(eval AMI_ID := $(shell cat AMI_ID))
	$(eval SG_ID := $(shell cat SG_ID))
	$(eval SSH_KEY := $(shell cat SSH_KEY))
	aws ec2 run-instances --image-id $(AMI_ID) --count 1 --instance-type t2.small --key-name $(SSH_KEY) --security-groups $(SG_ID)

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

SSH_PORT:
	@while [ -z "$$SSH_PORT" ]; do \
		read -r -p "Enter the the SSH_PORT you wish to associate with this cluster [SSH_PORT]: " SSH_PORT; echo "$$SSH_PORT">>SSH_PORT; cat SSH_PORT; \
	done ;

AGENT_CMD:
	@while [ -z "$$AGENT_CMD" ]; do \
		read -r -p "Enter the AGENT_CMD you wish to associate with this cluster [AGENT_CMD]: " AGENT_CMD; echo "$$AGENT_CMD">>AGENT_CMD; cat AGENT_CMD; \
	done ;

WORKER_COUNT:
	@while [ -z "$$WORKER_COUNT" ]; do \
		read -r -p "Enter the WORKER_COUNT you wish to associate with this cluster [WORKER_COUNT]: " WORKER_COUNT; echo "$$WORKER_COUNT">>WORKER_COUNT; cat WORKER_COUNT; \
	done ;

listinstances:
	aws ec2 describe-instances > listinstances

workingList: listinstances
	jq -r '.Reservations[] | .Instances[] | " \(.InstanceId) \(.ImageId) \(.PrivateIpAddress) \(.PublicIpAddress) \(.PublicDnsName) \(.InstanceType) \(.KeyName) " ' listinstances > workingList

testrancher: listinstances workingList
	$(eval TMP := $(shell mktemp -d --suffix=DOCKERTMP))
	$(eval SSH_PORT := $(shell cat SSH_PORT))
	while read INSTANCE_ID IMAGE_ID PRIVATE_IP PUBLIC_IP HOSTNAME INSTANCE_TYPE KEY_NAME ; \
		do \
		echo "ssh -i ./$$KEY_NAME.pem -p$(SSH_PORT) rancher@$$PUBLIC_IP 'uname -a ;docker ps'"; \
		done < workingList > $(TMP)/tester 
	-@cat $(TMP)/tester
	-/usr/bin/time parallel  --jobs 25 -- < $(TMP)/tester
	-@rm -Rf $(TMP)

keyscan: listinstances workingList
	$(eval TMP := $(shell mktemp -d --suffix=DOCKERTMP))
	$(eval SSH_PORT := $(shell cat SSH_PORT))
	while read INSTANCE_ID IMAGE_ID PRIVATE_IP PUBLIC_IP HOSTNAME INSTANCE_TYPE KEY_NAME ; \
		do \
		echo "ssh-keyscan -p$(SSH_PORT) $$PUBLIC_IP >>~/.ssh/known_hosts"; \
		done < workingList > $(TMP)/keyscan
	-bash $(TMP)/keyscan
	-@rm -Rf $(TMP)

agents:
	$(eval TMP := $(shell mktemp -d --suffix=DOCKERTMP))
	$(eval SSH_PORT := $(shell cat SSH_PORT))
	$(eval AGENT_CMD := $(shell cat AGENT_CMD))
	while read INSTANCE_ID IMAGE_ID PRIVATE_IP PUBLIC_IP HOSTNAME INSTANCE_TYPE KEY_NAME ; \
		do \
		echo "ssh -i ./$$KEY_NAME.pem -p$(SSH_PORT) rancher@$$PUBLIC_IP \"$(AGENT_CMD)\""; \
		done < workingList > $(TMP)/agentbootstrap 
	-@cat $(TMP)/agentbootstrap
	-/usr/bin/time parallel  --jobs 25 -- < $(TMP)/agentbootstrap
	-@rm -Rf $(TMP)
