---
title: "Eduroam and wpa_supplicant"
date: 2020-02-24T11:32:46+01:00
---

So, I simply use `wpa_supplicant` for WiFi and `wpa_cli` for configuration, and
none of that bloated NetworkManager. It works great, but can be hard to get the
configuration right for corporate and university networks.

Here's a simple configuration for the Eduroam network, that has been verified to
work for LTU (Luleå University of Technology), and several airports in Sweden.
Hopefully it also works at the other universities.

```
network={
        ssid="eduroam"
        scan_ssid=1
        key_mgmt=WPA-EAP
        auth_alg=OPEN
        eap=PEAP
        identity="abcdef-1@LTU.SE"
        anonymous_identity="abcdef-1@LTU.SE"
        password="W1ll14m5Ultim4t3L0ngP4ssw0rd123!"
        phase1="peaplabel=0"
        phase2="auth=MSCHAPV2"
}
```

Just copy and paste this into `/etc/wpa_supplicant/wpa_supplicant.conf` and edit
the fields `identity`, `anonymous_identity` and `password`.

 * `identity`: Should be your username _with_ the organization domain added. For
   LTU you should _not_ use `student.ltu.se`, you **must** use uppercase `LTU.SE`.
 * `anonymous_identity`: Is allegedly optional, and can be whatever. I simply
   went with the same value as `identity`.
 * `password`: The password you have picked. For LTU, this can be configured
   using their student portal,
   `Mitt LTU > Mina uppgifter > Byt Lösenord > Byt ditt eduroam lösenord`

Restart `wpa_supplicant` with whatever method you use, for Gentoo it's:
```
rc-service wpa_supplicant restart
```

If you have decided to go rouge and start `wpa_supplicant` without any
service manager (change `interface` to your WiFi card):
```
wpa_supplicant -B -i interface -c /etc/wpa_supplicant/wpa_supplicant.conf
```

And lastly, you can check the status of your connections with:
```
wpa_cli status
```
