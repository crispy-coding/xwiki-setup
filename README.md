# XWiki Setup

The reason I started this project is that I like XWiki as a personal knowledge database that can be shared with the public. I wanted to have my own self-hosted XWiki server, but the deployment with Nginx and Let's Encrypt via Docker is a little tricky. Since XWiki is pretty cool software, it would be a pity if the deployment was an obstacle that drives people away from it. So I decided to automate the deployment process and keep the effort required to a minimum. There are two deployment options: 1) a test instance and 2) a production instance with automatically generated certificate.



## 1) Test Instance

The test instance is used to take a first look at XWiki's graphical user interface to get to know the basic design and features. The test instance does not store data in persistent Docker volumes, does not generate a certificate, and does not generate secure passwords for database access. It is not intended for production use. It is recommended to deploy the test instance on your working PC or on a host in your LAN.



### Software Requirements for the Host Device

* Ubuntu 20.04 (I have not tried other systems, yet. Probably other operating systems will work as well.)
* docker (version 20.10.12+, API version 1.41+)
* docker-compose (version 1.29+): If Ubuntu does not provide such package version in its repositories, then you can use the binary of, e.g., version 1.29 from the [docker-compose release page](https://github.com/docker/compose/releases).



### Deployment

```sh
git clone https://github.com/crispy-coding/xwiki-setup.git
cd xwiki-setup/xwiki-test
docker-compose up -d
```

In your browser, visit `http://<host>:8080` where `<host>` is either `localhost` or the LAN IP address of the host you deployed it on (such as `192.168.x.x`).



## 2) Production Instance

If you like XWiki, you can easily set it up for production with persistent data, secure database passwords and automatically generated certificate.



### Software Requirements for the Host Device

* All software requirements mentioned above in the requirements of the "Test Instance" documentation are needed here as well.
* `envsubst` command. Contained in the `gettext-base` package.
* A registered domain which directs requests to the IP address of the host device, e.g. `my-company.com`.



### Deployment 

```sh
cd xwiki-setup/xwiki-prod
bash install-xwiki-production-instance.sh
```

Enter the required inputs and that's it. When the script is finished, you can access your XWiki instance via browser at `https://<your-domain>`. The database passwords are stored in the `.env` file and all other persistent data are stored in the `data` folder. If you intend to backup or move the XWiki server to another machine, you should copy/move the entire `xwiki-prod` folder.

Note that Let's Encrypt limits the number of free certificates to 5 per week. If you run this script too often, it may not work until the limit time has expired.

Once the setup has been initialized by the installation script, then these simple commands are sufficient to shut down or re-deploy the docker containers:

```sh
docker-compose down
docker-compose up -d 
```

If you intent to reset the deployment, which includes deleting all data (including passwords and certificates), then execute:

```sh
docker-compose down; rm -rf data .env
```



## For Developers

If you are developing the production installation script, you will want to test it frequently. In this case, you can run the script in `test` mode:

```sh
cd xwiki-setup/xwiki-prod
bash install-xwiki-production-instance.sh test
```

Compared to the regular execution from the section above, this has following advantages for the testing:

* Inputs such as the email address and the domain have to be entered once on the first execution. The data is stored in `config/test-inputs.txt` and read on all subsequent executions.
* At the end of the script, all components are shut down and all persistent data is deleted, resulting in a clean setup. **WARNING**: If there is a `data` folder with production data, it will be deleted.
* The certbot does not request a real certificate. Therefore the Let's Encrypts restriction of 5 certificates per week does not apply here and you can test it as often as you like. The disadvantage is that access via browser does not work because there is no real certificate.



## Technical Problems and Acknowledgements

Thanks to [this article](https://pentacent.medium.com/nginx-and-lets-encrypt-with-docker-in-less-than-5-minutes-b4b8a60d3a71) by Philipp Schmieder, it was quite easy to set up an Nginx service and a Let's Encrypt certificate. After that, I simply deployed XWiki behind Nginx. I was able to access XWiki via browser, but trying to install a flavor or extensions resulted in a [mixed content bug](https://forum.xwiki.org/t/xwiki-https-mixed-content-10-11-docker-container-behind-nginx-proxy-rest-nightmare/4311). When I clicked a button to run an installation, the browser gave an error message about mixed content, but nothing else happened. As far as I know, the Tomcat service tries to send HTTP content and the browser refuses to accept it due to the lack of encryption. The solution was to configure Tomcat to use HTTPS, which was pointed out by the [documentation](https://www.xwiki.org/xwiki/bin/view/Documentation/AdminGuide/Installation/InstallationWAR/InstallationTomcat/#Hhttps28secure29) and the issue reporter "unadequate", who shared the necessary adjustments [in the above bug report](https://forum.xwiki.org/t/xwiki-https-mixed-content-10-11-docker-container-behind-nginx-proxy-rest-nightmare/4311/2). Thanks to them, I was able to automate this configuration and simplify the deployment process: Tomcat needs to know the IP address from which the network traffic originates. If Nginx is installed directly on the host, this IP address would be `127.0.0.1` as pointed out in the docs, but since this setup uses Docker containers, I had to assign static IP addresses to the containers instead and apply that static IP address to the `server.xml` Tomcat configuration.

