# XWiki Setup

The reason I started this project is that I like XWiki as a personal knowledge database that can be shared with the public. I wanted to have my own self-hosted XWiki server, but the deployment was quite tricky. Since XWiki is pretty cool software, it would be a shame if the deployment was an obstacle that drives people away from it. So I decided to automate the entire process and keep the deployment effort required to an absolute minimum. There are two deployment options: 1) a test instance and 2) a production instance with automatically generated certificate.



## 1) Test Instance

* For testing XWiki:
  * envsubst
  * docker
  * docker-compose
  * Linux VM, Ubuntu 20.04
  * I should test their presence in the installation script.



Visit `<host>:8080` where `<host>` is either local host or the IP of the device you deployed it on.



## 2) Production Instance

For setting up with certificate:

* a registered domain which directs to the IP address of the VM



There are two deployment options: 

* For newcomers to XWiki I suggest to deploy a test-instance locally to get familiar with the software and based on that, decide if you want to use it in a production environment. The data generated in this setup should not be important as there is no serious persistence.
* If you like XWiki you can easily set it up for production with persistent data and automatically generated certificate.



Just go to the script folder

```sh
bash install-xwiki-production-instance.sh test
```

asd

```
bash run-xwiki-test-instance.sh
```

asd

```
bash wipe-setup.sh
```

Of special interest for development or testing if the DNS is configured properly

```sh
bash install-xwiki-production-instance.sh test
```





## Technical Details

* a



## Acknowledgements and references

* a