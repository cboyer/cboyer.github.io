---
title: "Partage Samba sur RedHat 9 avec authentification Active Directory"
date: "2024-04-06T16:29:41-04:00"
updated: "2024-04-06T16:29:41-04:00"
author: "C. Boyer"
license: "Creative Commons BY-SA-NC 4.0"
website: "https://cboyer.github.io"
category: "Linux"
keywords: [samba, redhat, winbind, sssd, active directory]
abstract: "Partage de fichier Samba avec authentification Active Directory sous RedHat 9"
---

Avec RedHat 9.3 la version de Samba utilisée est la 4.17.X. Or à partir de la version 4.8 de Samba, l'utilisation de Winbind (winbindd) est obligatoire car le démon Samba (smbd) délègue l'authentification de ses partages à Winbind: [Source](https://www.suse.com/fr-fr/support/kb/doc/?id=000020593).

L'absence de configuration adéquate de Winbind causera la présence des erreurs suivantes dans les journaux de Samba:
```
auth3_generate_session_info_pac: winbindd not running - but required as domain member: NT_STATUS_NO_LOGON_SERVERS
```

Deux possibilités s'offrent à nous:

- Combiner l'utilisation de SSSD et Winbind (recommandé)
- Utiliser exclusivement Winbind


## Combiner l'utilisation de SSSD et Winbind

Cette procédure permet d’associer une machine Linux à Active Directory et partager des dossiers/fichiers via Samba en gérant les accès avec Active Directory.

Installer les paquets suivants:

- samba-common-tools
- realmd
- oddjob
- oddjob-mkhomedir
- samba-winbind-clients
- samba-winbind
- samba-winbind-krb5-locator
- samba


Joindre la machine au domaine avec SSSD
```
echo Mot_de_passe | realm join -v --client-software=sssd -U Admin_du_domaine MONDOMAINE.COM
```

Modifier la configuration de SSSD via `/etc/sssd/sssd.conf` dans le bloc `[domain/mondomaine.com]`
```
# Modifier les valeurs suivantes
enumerate = False
cache_credentials = False

# Ajouter les directives suivantes
auth_provider = ad
chpass_provider = ad
ldap_schema = ad
ad_gpo_access_control = disabled
```

La directive `ad_gpo_access_control = disabled` permet d'ignorer les GPO car elles peuvent empêcher les utilisateurs du domaine de se connecter en SSH (cause des erreurs de lecture de SSSD dans l'AD).
Si elle est omise on observera les erreurs suivantes dans `/var/log/secure`:
```
pam_sss(sshd:auth): authentication success; logname= uid=0 euid=0 tty=ssh ruser= rhost=10.2.196.73 user=utilisateur@mondomaine.com
pam_sss(sshd:account): Access denied for user utilisateur@mondomaine.com: 4 (System error)
Failed password for utilisateur@mondomaine.com from 10.2.196.73 port 40246 ssh2
Access denied for user utilisateur@mondomaine.com by PAM account configuration [preauth]
```

Redémarrer SSSD
```
systemctl restart sssd
```


Vérifier l'association au domaine
```
realm list
mondomaine.com
  type: kerberos
  realm-name: MONDOMAINE.COM
  domain-name: mondomaine.com
  configured: kerberos-member
  server-software: active-directory
  client-software: sssd
  required-package: oddjob
  required-package: oddjob-mkhomedir
  required-package: sssd
  required-package: adcli
  required-package: samba-common-tools
  login-formats: %U@mondomaine.com
  login-policy: allow-realm-logins

getent passwd MONDOMAINE.COM\\Admin_du_domaine
MONDOMAINE\\Admin_du_domaine:*:22005:20513:Monsieur Admin:/home/MONDOMAINE/Admin_du_domaine:/bin/bash
```

Configurer Samba via `/etc/samba/smb.conf`
```
[global]
    workgroup = MONDOMAINE
    realm = mondomaine.com
    security = ads
    server string =
    kerberos method = secrets and keytab
    log file = /var/log/samba/samba.log
    max log size = 200
    idmap config * : backend = tdb
    idmap config * : range = 10000-19999
    idmap config MONDOMAINE : backend = nss
    idmap config MONDOMAINE : range = 20000-29999
    machine password timeout = 0
    load printers = no
    store dos attributes = Yes
    vfs objects = acl_xattr

[test]
    comment = Partage test
    path = /test
    read only = No
    valid users = "@MONDOMAINE\utilisateurs du domaine","@MONDOMAINE\admins du domaine"
    admin users = "@MONDOMAINE\admins du domaine"
```

> La directive `idmap config MONDOMAINE : backend = nss` permet à Winbind d'utiliser SSSD comme backend au lieu du contrôleur de domaine.
> La directive `machine password timeout = 0` empêche la mise à jour du mot de passe du compte machine AD pour laisser SSSD s'en occuper et éviter les conflits.


Joindre de nouveau la machine au domaine avec Winbind pour créer le fichier secrets.tdb utilisé par Samba
```
net ads join -U MONDOMAINE\\Admin_du_domaine%Mot_de_passe
```

Activer Winbind et Samba au démarrage puis les redémarrer
```
systemctl enable winbind smb
systemctl restart winbind smb
```


Vérifier le fonctionnement de Winbind au travers d'SSSD
```
wbinfo --ping-dc
checking the NETLOGON for domain[MONDOMAINE] dc connection to "winad01.mondomaine.com" succeeded

wbinfo -u
MONDOMAINE\invité
MONDOMAINE\administrateur
MONDOMAINE\test01
...
```

Créer le dossier partagé test
```
mkdir /test
echo "Bonjour!" > /test/test.txt
chcon -t samba_share_t /test
chmod -R 770 /test
chgrp -R "MONDOMAINE\utilisateurs du domaine" /test
```

Tester l'accès au partage avec un utilisateur membre du groupe `MONDOMAINE\utilisateurs du domaine`
```
smbclient -L //`hostname`/test --user=Admin_du_domaine%Mot_de_passe
Sharename       Type      Comment
---------       ----      -------
test            Disk      Partage test
IPC$            IPC       IPC Service ()
SMB1 disabled -- no workgroup available

smbclient //`hostname`/test -c 'ls' --user=Admin_du_domaine%Mot_de_passe
.                                   D        0  Wed Mar 20 14:23:57 2024
..                                  D        0  Wed Mar 20 14:23:57 2024
test.txt                            N       20  Wed Mar 20 14:23:57 2024

21915184 blocks of size 1024. 19730188 blocks available
```

Répéter le même test avec un utilisateur qui n'est pas membre du groupe `MONDOMAINE\utilisateurs du domaine` pour s'assurer de l'application des directives de sécurité. Ce test doit retourner l'erreur `NT_STATUS_LOGON_FAILURE`.




## Utiliser exclusivement Winbind

Cette procédure permet d’associer une machine Linux à Active Directory avec Winbind en se passant de SSSD et partager des dossiers/fichiers via Samba en gérant les accès avec Active Directory.

Installer les paquets suivants:

- samba-common-tools
- realmd
- oddjob
- oddjob-mkhomedir
- samba-winbind-clients
- samba-winbind
- samba-winbind-krb5-locator
- samba
- krb5-workstation

Configurer Samba via `/etc/samba/smb.conf`
```
[global]
    workgroup = MONDOMAINE
    realm = mondomaine.com
    security = ads
    server string =
    kerberos method = secrets and keytab
    log file = /var/log/samba/samba.log
    max log size = 200
    idmap config * : backend = tdb
    idmap config * : range = 10000-19999
    idmap config MONDOMAINE : backend = rid
    idmap config MONDOMAINE : range = 20000-29999
    template shell = /bin/bash
    template homedir  = /home/%U@%D
    load printers = no
    store dos attributes = Yes
    vfs objects = acl_xattr

[test]
    comment = Partage test
    path = /test
    read only = No
    valid users = "@MONDOMAINE\utilisateurs du domaine","@MONDOMAINE\admins du domaine"
    admin users = "@MONDOMAINE\admins du domaine"
```

> La directive `template shell = /bin/bash` est très importante car elle spécifie le shell à utiliser lors d'une connexion SSH. Sa valeur par défaut `/bin/false` (observable avec la commande `getent passwd MONDOMAINE.COM\\Utilisateur`) empêche toute connexion SSH en affichant `debug1: client_input_channel_req: channel 0 rtype exit-status reply 0` dans le debug SSH.
> La directive `template homedir  = /home/%U@%D` permet dans le cas d'une connexion SSH d'affecter un dossier home à l'utilisateur. Par défaut Samba affecte le dossier /home/domaine/utilisateur

Joindre la machine au domaine
```
net ads join -U MONDOMAINE\\Admin_du_domaine%Mot_de_passe
```

Configurer l'utilisation du profil Winbind
```
authselect select winbind --force
```
> Cette commande permet de modifier une série de fichier comme /etc/nsswitch.conf où les directives `group` et `passwd` se voient ajouter la valeur `winbind` dans notre cas.

Configurer Kerberos via `/etc/krb5.conf`
```
includedir /etc/krb5.conf.d/

[logging]
    default = FILE:/var/log/krb5libs.log
    kdc = FILE:/var/log/krb5kdc.log
    admin_server = FILE:/var/log/kadmind.log

[libdefaults]
    dns_lookup_realm = false
    ticket_lifetime = 24h
    renew_lifetime = 7d
    forwardable = true
    rdns = false
    pkinit_anchors = FILE:/etc/pki/tls/certs/ca-bundle.crt
    spake_preauth_groups = edwards25519
    dns_canonicalize_hostname = fallback
    qualify_shortname = ""
    default_realm = mondomaine.com
    default_ccache_name = KEYRING:persistent:%{uid}

[realms]
    mondomaine.com = {
        kdc = WINAD01.mondomaine.com
    }

[domain_realm]
    mondomaine.com = MONDOMAINE.COM
```

> Il est important de respecter la casse comme présenté ci-dessus pour le nom de domaine.

Tester Kerberos
```
kinit Admin_du_domaine@MONDOMAINE.COM
Ticket cache: KCM:0
    Default principal: Admin_du_domaine@MONDOMAINE.COM

klist
Valid starting       Expires              Service principal
2024-03-20 14:23:42  2024-03-21 00:23:42  krbtgt/MONDOMAINE.COM@MONDOMAINE.COM
renew until 2024-03-27 14:23:42
```

Activer Winbind et Samba au démarrage
```
systemctl enable winbind smb
systemctl restart winbind smb
```

Tester l'association au domaine
```
wbinfo --ping-dc
checking the NETLOGON for domain[MONDOMAINE] dc connection to "WINAD01.mondomaine.com" succeeded

getent passwd MONDOMAINE.COM\\Admin_du_domaine
MONDOMAINE\\Admin_du_domaine:*:22005:20513:Monsieur Admin:/home/MONDOMAINE/Admin_du_domaine:/bin/bash
```

Configurer la création automatique du home si absent à la première connexion SSH en ajoutant la ligne en première position dans la section "session" de `/etc/pam.d/sshd`
```
session    required     pam_mkhomedir.so skel=/etc/skel/ umask=0022
```
> Sans cette ligne le dossier home de l'utilisateur n'est pas créé lors de sa première connexion.

Créer le dossier partagé test
```
mkdir /test
echo "Bonjour!" > /test/test.txt
chcon -t samba_share_t /test
chmod -R 770 /test
chgrp -R "MONDOMAINE\utilisateurs du domaine" /test
```

Tester l'accès au partage avec un utilisateur membre du groupe `MONDOMAINE\utilisateurs du domaine`
```
smbclient -L //`hostname`/test --user=Admin_du_domaine%Mot_de_passe
Sharename       Type      Comment
---------       ----      -------
test            Disk      Partage test
IPC$            IPC       IPC Service ()
SMB1 disabled -- no workgroup available

smbclient //`hostname`/test -c 'ls' --user=Admin_du_domaine%Mot_de_passe
.                                   D        0  Wed Mar 20 14:23:57 2024
..                                  D        0  Wed Mar 20 14:23:57 2024
test.txt                            N       20  Wed Mar 20 14:23:57 2024

21915184 blocks of size 1024. 19730188 blocks available
```

Répéter le même test avec un utilisateur qui n'est pas membre du groupe `MONDOMAINE\utilisateurs du domaine` pour s'assurer de l'application des directives de sécurité. Ce test doit retourner l'erreur `NT_STATUS_LOGON_FAILURE`.


Documentation complémentaire:

- [https://wiki.samba.org/index.php/Setting_up_Samba_as_a_Domain_Member#Configuring_Samba](https://wiki.samba.org/index.php/Setting_up_Samba_as_a_Domain_Member#Configuring_Samba)
- [https://www.samba.org/samba/docs/current/man-html/smb.conf.5.html](https://www.samba.org/samba/docs/current/man-html/smb.conf.5.html)
- [https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html-single/configuring_authentication_and_authorization_in_rhel/index](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html-single/configuring_authentication_and_authorization_in_rhel/index)
