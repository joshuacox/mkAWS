# mkAWS

Make an AWS cluster PDQ

[video](https://youtu.be/kp2F6SB-3bI):
<iframe width="560" height="315" src="https://www.youtube.com/embed/kp2F6SB-3bI" frameborder="0" allowfullscreen></iframe>

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

you now have a small cluster of [Rancher](http://rancher.com/rancher/)

### GNU Parallel

  O. Tange (2011): GNU Parallel - The Command-Line Power Tool,
      ;login: The USENIX Magazine, February 2011:42-47.
