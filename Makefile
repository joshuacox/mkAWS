all: help

help:
	-@echo "read the README.md for more"

rancher: AMI_ID SG_ID SERVER_COUNT WORKER_COUNT SSH_KEY SSH_PORT SERVER_SIZE WORKER_SIZE rancherServer rancherAgent askWaitForInitFinish dockers
	
dockers: keyscan servers agents

servers: serverDocker

agents: agentcmdHelp AGENT_CMD agentsDocker

rancherAgent:
	$(eval AMI_ID := $(shell cat AMI_ID))
	$(eval SG_ID := $(shell cat SG_ID))
	$(eval SSH_KEY := $(shell cat SSH_KEY))
	$(eval WORKER_COUNT := $(shell cat WORKER_COUNT))
	$(eval WORKER_SIZE := $(shell cat WORKER_SIZE))
	aws ec2 run-instances --image-id $(AMI_ID) --count $(WORKER_COUNT) --instance-type $(WORKER_SIZE) --key-name $(SSH_KEY) --security-groups $(SG_ID)

rancherServer:
	$(eval AMI_ID := $(shell cat AMI_ID))
	$(eval SG_ID := $(shell cat SG_ID))
	$(eval SSH_KEY := $(shell cat SSH_KEY))
	$(eval SERVER_COUNT := $(shell cat SERVER_COUNT))
	$(eval SERVER_SIZE := $(shell cat SERVER_SIZE))
	aws ec2 run-instances --image-id $(AMI_ID) --count $(SERVER_COUNT) --instance-type $(SERVER_SIZE) --key-name $(SSH_KEY) --security-groups $(SG_ID)

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

SERVER_COUNT:
	@while [ -z "$$SERVER_COUNT" ]; do \
		read -r -p "Enter the SERVER_COUNT you wish to associate with this cluster [SERVER_COUNT]: " SERVER_COUNT; echo "$$SERVER_COUNT">>SERVER_COUNT; cat SERVER_COUNT; \
	done ;

SERVER_SIZE:
	@echo 't2.small' > SERVER_SIZE
	@echo 'edit SERVER_SIZE to the size of the rancher server you require (min 2G of ram [t2.small])'

WORKER_SIZE:
	@echo 't2.micro' > WORKER_SIZE
	@echo 'edit WORKER_SIZE to the size of the rancher agent you require (min 512M of ram [t2.nano])'

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

serverDocker: serverList
	$(eval TMP := $(shell mktemp -d --suffix=DOCKERTMP))
	$(eval SSH_PORT := $(shell cat SSH_PORT))
	$(eval AGENT_CMD := $(shell cat AGENT_CMD))
	while read INSTANCE_ID IMAGE_ID PRIVATE_IP PUBLIC_IP HOSTNAME INSTANCE_TYPE KEY_NAME ; \
		do \
		echo "ssh -i ./$$KEY_NAME.pem -p$(SSH_PORT) rancher@$$PUBLIC_IP \"sudo docker run -d --restart=unless-stopped -p 8080:8080 rancher/server\""; \
		done < serverList > $(TMP)/serverbootstrap
	-@cat $(TMP)/serverbootstrap
	-/usr/bin/time parallel  --jobs 25 -- < $(TMP)/serverbootstrap
	-@rm -Rf $(TMP)
	@echo 'If you have multple servers be sure and configure them using the "High Availability" menu under admin in the rancher servers'
	@echo 'Now is also the time to configure your environments if you would like to use kubernetes, Mesos, or Swarm instead of Cattle'

agentsDocker: agentList
	$(eval TMP := $(shell mktemp -d --suffix=DOCKERTMP))
	$(eval SSH_PORT := $(shell cat SSH_PORT))
	$(eval AGENT_CMD := $(shell cat AGENT_CMD))
	while read INSTANCE_ID IMAGE_ID PRIVATE_IP PUBLIC_IP HOSTNAME INSTANCE_TYPE KEY_NAME ; \
		do \
		echo "ssh -i ./$$KEY_NAME.pem -p$(SSH_PORT) rancher@$$PUBLIC_IP \"$(AGENT_CMD)\""; \
		done < agentList > $(TMP)/agentbootstrap 
	-@cat $(TMP)/agentbootstrap
	-/usr/bin/time parallel  --jobs 25 -- < $(TMP)/agentbootstrap
	-@rm -Rf $(TMP)

install:
	sudo pip install awscli
	echo 'http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html'
	aws configure

clean:
	-rm workingList
	-rm agentList
	-rm serverList
	-rm listinstances

agentList: workingList
	$(eval AMI_ID := $(shell cat AMI_ID))
	$(eval WORKER_SIZE := $(shell cat WORKER_SIZE))
	cat workingList | grep $(AMI_ID) | grep $(WORKER_SIZE) > agentList

serverList: workingList
	$(eval AMI_ID := $(shell cat AMI_ID))
	$(eval SERVER_SIZE := $(shell cat SERVER_SIZE))
	cat workingList | grep $(AMI_ID) | grep $(SERVER_SIZE) > serverList

agentcmdHelp:
	@echo 'Now visit your rancher server (choose your environment if other than default Cattle) and click on addhost, where you will get the AGENT_CMD'

askWaitForInitFinish: SHELL:=/bin/bash
askWaitForInitFinish:
	read -p "Please wait for the VMs to initialize in AWS and then hit any key to continue, or make dockers to continue from this point to retry " -n 1 -r
