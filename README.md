# mkAWS

Make an AWS cluster PDQ

### Install

```
make install
```

will use pip to install awscli and then incant `aws configure` which will prompt you for your AWS creds

### Usage

```
make rancher
```

You will be prompted for your AWS key and a few other questions, at the end you will have one master rancher server and a number of worker machines
