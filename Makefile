all: help

help:
	-@echo "read the README.md for more"

rancher: AMI_ID SG_ID SERVER_COUNT AGENT_COUNT SSH_KEY SSH_PORT SERVER_SIZE AGENT_SIZE rancherServer rancherAgent askWaitForInitFinish dockers
	
dockers: keyscan servers agents

servers: serverDocker

agents: agentcmdHelp AGENT_CMD agentsDocker

rancherAgent:
	$(eval AMI_ID := $(shell cat AMI_ID))
	$(eval SG_ID := $(shell cat SG_ID))
	$(eval SSH_KEY := $(shell cat SSH_KEY))
	$(eval AGENT_COUNT := $(shell cat AGENT_COUNT))
	$(eval AGENT_SIZE := $(shell cat AGENT_SIZE))
	aws ec2 run-instances --image-id $(AMI_ID) --count $(AGENT_COUNT) --instance-type $(AGENT_SIZE) --key-name $(SSH_KEY) --security-groups $(SG_ID)

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

AGENT_COUNT:
	@while [ -z "$$AGENT_COUNT" ]; do \
		read -r -p "Enter the AGENT_COUNT you wish to associate with this cluster [AGENT_COUNT]: " AGENT_COUNT; echo "$$AGENT_COUNT">>AGENT_COUNT; cat AGENT_COUNT; \
	done ;

SERVER_COUNT:
	@while [ -z "$$SERVER_COUNT" ]; do \
		read -r -p "Enter the SERVER_COUNT you wish to associate with this cluster [SERVER_COUNT]: " SERVER_COUNT; echo "$$SERVER_COUNT">>SERVER_COUNT; cat SERVER_COUNT; \
	done ;

SERVER_SIZE:
	@echo 't2.small' > SERVER_SIZE
	@echo 'edit SERVER_SIZE to the size of the rancher server you require (min 2G of ram [t2.small])'

AGENT_SIZE:
	@echo 't2.micro' > AGENT_SIZE
	@echo 'edit AGENT_SIZE to the size of the rancher agent you require (min 512M of ram [t2.nano])'

listinstances:
	aws ec2 describe-instances > listinstances

workingList: listinstances
	jq -r '.Reservations[] | .Instances[] | " \(.InstanceId) \(.ImageId) \(.PrivateIpAddress) \(.PublicIpAddress) \(.PublicDnsName) \(.InstanceType) \(.KeyName) " ' listinstances | grep -v null > workingList

test: testrancher

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
		echo "ssh-keyscan -p$(SSH_PORT) $$PUBLIC_IP >> $(TMP)/known_hosts"; \
		done < workingList > $(TMP)/keyscan
	-bash $(TMP)/keyscan
	cat ~/.ssh/known_hosts >> $(TMP)/known_hosts
	cat $(TMP)/known_hosts | sort | uniq > ~/.ssh/known_hosts
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
	-@rm workingList 2>/dev/null ;true
	-@rm agentList 2>/dev/null ;true
	-@rm serverList 2>/dev/null ;true
	-@rm listinstances 2>/dev/null ;true
	-@rm AGENT_CMD 2>/dev/null ;true
	-@rm AGENT_COUNT 2>/dev/null ;true
	-@rm AGENT_SIZE 2>/dev/null ;true
	-@rm SERVER_COUNT 2>/dev/null ;true
	-@rm SERVER_SIZE 2>/dev/null ;true
	-@rm SSH_KEY 2>/dev/null ;true

agentList: workingList
	$(eval AMI_ID := $(shell cat AMI_ID))
	$(eval AGENT_SIZE := $(shell cat AGENT_SIZE))
	cat workingList | grep -v null | grep $(AMI_ID) | grep $(AGENT_SIZE) > agentList

serverList: workingList
	$(eval AMI_ID := $(shell cat AMI_ID))
	$(eval SERVER_SIZE := $(shell cat SERVER_SIZE))
	cat workingList | grep -v null | grep $(AMI_ID) | grep $(SERVER_SIZE) > serverList

agentcmdHelp:
	@echo 'Now visit your rancher server (choose your environment if other than default Cattle) and click on addhost, where you will get the AGENT_CMD'

askWaitForInitFinish: SHELL:=/bin/bash
askWaitForInitFinish:
	read -p "Please wait for the VMs to initialize in AWS and then hit any key to continue, or make dockers to continue from this point to retry " -n 1 -r

regionsList:
	aws ec2 describe-regions>regionsList

listRegions:
	jq -r '.Regions[] | " \(.RegionName)\t http://\(.Endpoint) " ' regionsList
