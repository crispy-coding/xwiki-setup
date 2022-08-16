# XWiki Setup

The reason I started this project is that I like XWiki as a personal knowledge database that can be shared with the public. I wanted to have my own self-hosted XWiki server, but the deployment with with Nginx and Let's Encrypt was quite tricky. Since XWiki is pretty cool software, it would be a shame if the deployment was an obstacle that drives people away from it. So I decided to automate the deployment process and keep the effort required to a minimum. There are two deployment options: 1) a test instance and 2) a production instance with automatically generated certificate.



## 1) Test Instance

The test instances purpose is to get a first glance at the XWiki UI to learn about the basic design and features of it. The test instance does not store data in persistent docker volumes, does not generate a certificate and does not generate secure passwords for the database access. It is not meant for production use. It is recommended to deploy the test instance on your regular work PC.



### Software Requirements for the Host Device

* Ubuntu 20.04 (I have not tried other systems, yet. Probably, other OS's will work as well.)
* docker
* docker-compose (version 1.29+): If Ubuntu does not provide such package version in its repositories, then you can use the binary of, e.g., version 1.29 from the [docker-compose release page](https://github.com/docker/compose/releases).



### Deployment

```sh
git clone https://github.com/crispy-coding/xwiki-setup.git
cd xwiki-setup/xwiki-test
docker-compose up -d
```

In your browser, visit `http://<host>:8080` where `<host>` is either `localhost` or the LAN IP address of the device you deployed it on (something like `192.168.x.x`).



## 2) Production Instance

If you like XWiki you can easily set it up for production with persistent data, secure database passwords and automatically generated certificate.



### Software Requirements for the Host Device

* All software requirements mentioned above in the requirement of the "Test Instance" documentation.
* `envsubst`command. Contained in the `gettext-base`package.
* A registered domain which directs requests to the IP address of the host device, e.g. `my-company.com`.



### Deployment 

```sh
cd xwiki-setup/xwiki-prod
bash install-xwiki-production-instance.sh
```

Enter the prompted inputs and that's it. When the script has finished, then you can access your XWiki instance with your browser at `https://<your-domain>`. The database passwords are stored in the `.env` file.

Notice that Let's Encrypt limits the amount of free certificates to 5 per week. If you run this script too frequently, it might not work until the limitation time has passed.

When the setup was initialized through the installation script once, then simple `docker-compose down` and `docker-compose up -d` are sufficient for future container management.



## For Developers

If you develop the production installation script, you would want to frequently test them. For this case, you can execute the script in `test`mode:

```sh
cd xwiki-setup/xwiki-prod
bash install-xwiki-production-instance.sh test
```

Compared to the regular execution from the section above, this has following advantages for testing:

* Inputs like email address and domain have to be entered only once at the first execution. The data are stored in `config/test-inputs.txt` and they are read at all subsequent executions.
* At the end of the script, all components are shut down and all persistent data are deleted, so that there is a clean setup.
* The certbot does not request a real certificate. Therefore the Let's Encrypts limitation of 5 certificates per week does not apply here and you can test it as often as you like. The disadvantage is that, since there is no real certificate, access via browser does not work.



## Technical Problems and Acknowledgements

* Thanks to [this article](https://pentacent.medium.com/nginx-and-lets-encrypt-with-docker-in-less-than-5-minutes-b4b8a60d3a71) of Philipp Schmieder, it was quite easy to deploy a Nginx service and Let's Encrypt certificate. So I set this up and simply deployed XWiki behind Nginx. I could access XWiki normally but trying to install a flavor or extension lead to a [mixed content bug](https://forum.xwiki.org/t/xwiki-https-mixed-content-10-11-docker-container-behind-nginx-proxy-rest-nightmare/4311). As far as I understand, using that simple setup, the tomcat service tries to send HTTP content and the browser denies it due to missing encryption. The solution was to configure the tomcat to use HTTPS which pointed out by the [documentation](https://www.xwiki.org/xwiki/bin/view/Documentation/AdminGuide/Installation/InstallationWAR/InstallationTomcat/#Hhttps28secure29) and the issue reporter "unadequate", who kindly shared the adjustments required [within above mentioned bug report](https://forum.xwiki.org/t/xwiki-https-mixed-content-10-11-docker-container-behind-nginx-proxy-rest-nightmare/4311/2). Thanks to them I was able to automate this configuration and ease the deployment process.

