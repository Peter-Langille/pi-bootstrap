RASPBERRY PI — ADD TO PROMETHEUS / GRAFANA MONITORING
======================================================

MONITORING HOST:
  Hostname: pi5-dev-1
  LAN IP:   192.168.68.84

SERVICES ON pi5-dev-1:
  Homepage:   http://192.168.68.84:3000
  Grafana:    http://192.168.68.84:3001
  Prometheus: http://192.168.68.84:9090
  Targets:    http://192.168.68.84:9090/targets


STEP 1 — INSTALL NODE EXPORTER ON THE PI TO BE MONITORED
---------------------------------------------------------

sudo apt install -y prometheus-node-exporter


STEP 2 — VERIFY NODE EXPORTER IS ENABLED AND RUNNING
------------------------------------------------------

systemctl status prometheus-node-exporter --no-pager

Expected:

  Loaded: ... enabled
  Active: active (running)


STEP 3 — VERIFY METRICS ARE BEING EXPOSED LOCALLY
---------------------------------------------------

curl -s http://localhost:9100/metrics | head

Expected output contains Prometheus metrics such as:

  # HELP ...
  # TYPE ...
  node_...

Node Exporter serves the Pi's hardware/OS metrics on TCP port 9100.


STEP 4 — GET THE PI'S TAILSCALE IP
-----------------------------------

tailscale ip -4

Record this IP.

Example from pi4-dev-1:

  100.74.240.9


STEP 5 — MOVE TO THE MONITORING HOST
-------------------------------------

SSH into:

  pi5-dev-1

Prometheus, Grafana and Homepage run here in Docker.


STEP 6 — ADD THE NEW PI TO PROMETHEUS
--------------------------------------

Open:

vim /home/peter/docker/monitoring/prometheus/prometheus.yml

Prometheus currently uses a "nodes" scrape job with a 15-second interval.

Structure:

global:
  scrape_interval: 15s

scrape_configs:
  - job_name: "nodes"
    static_configs:
      - targets:
          - "TAILSCALE_IP:9100"    # hostname

Add the new Pi, for example:

          - "100.x.x.x:9100"       # pi5-dev-4

Save and exit:

:wq


STEP 7 — RESTART PROMETHEUS
----------------------------

docker restart prometheus

Expected output:

prometheus

This causes Prometheus to reread prometheus.yml.


STEP 8 — VERIFY THE MONITORING HOST CAN REACH NODE EXPORTER
------------------------------------------------------------

From pi5-dev-1:

curl -s http://TAILSCALE_IP:9100/metrics | head

Example:

curl -s http://100.74.240.9:9100/metrics | head

Expected:

  # HELP ...
  # TYPE ...
  node_...

This proves:

  pi5-dev-1
       |
       v
    Tailscale
       |
       v
  monitored Pi:9100
       |
       v
  Node Exporter


STEP 9 — VERIFY PROMETHEUS IS SCRAPING THE NEW PI
--------------------------------------------------

Open:

http://192.168.68.84:9090/targets

Under the "nodes" job, verify the new:

  TAILSCALE_IP:9100

shows:

  UP

All targets should be UP.


STEP 10 — ADD THE PI TO HOMEPAGE
---------------------------------

On pi5-dev-1 open:

vim /home/peter/docker/monitoring/homepage-config/services.yaml

Add:

- pi5-dev-4:
    href: http://TAILSCALE_IP:9100/metrics
    description: node_exporter metrics

Use the actual hostname and Tailscale IP for each machine.

Save:

:wq


STEP 11 — VERIFY HOMEPAGE
--------------------------

Open/refresh:

http://192.168.68.84:3000

Verify the new Pi appears.

During the pi4-dev-1 setup, Homepage detected the YAML change automatically.
No Homepage container restart was required.


STEP 12 — VERIFY GRAFANA
-------------------------

Open:

http://192.168.68.84:3001

Open the existing node monitoring dashboard.

Verify the new hostname appears in the node-selection dropdown.

If it appears and displays metrics, the entire monitoring path is working.


ARCHITECTURE
============

Each monitored Raspberry Pi
        |
        | prometheus-node-exporter
        | TCP :9100
        v
     Tailscale
        |
        v
pi5-dev-1
        |
        +-- Prometheus
        |      Scrapes :9100 every 15 seconds
        |      Stores time-series metrics
        |
        +-- Grafana
        |      Queries Prometheus
        |      Displays dashboards
        |
        +-- Homepage
               Provides convenient links/status entry points


PI4-DEV-1 — PROVEN SETUP
=========================

Hostname:
  pi4-dev-1

LAN IP at setup:
  192.168.68.66

Tailscale IP:
  100.74.240.9

Node Exporter:
  installed
  enabled
  active/running

Local metrics:
  http://localhost:9100/metrics
  PASS

Remote metrics from pi5-dev-1:
  http://100.74.240.9:9100/metrics
  PASS

Prometheus:
  100.74.240.9:9100
  UP

Homepage:
  pi4-dev-1 visible
  PASS

Grafana:
  pi4-dev-1 appears in node dropdown
  PASS


TO ADD NEXT
===========

Repeat this procedure for:

  pi5-dev-4

  Pironman 5 Max
  NOTE: Verify its actual hostname before editing Prometheus/Homepage.
  Do not assume the hostname.


SUCCESS CRITERIA
================

For each new Pi:

  [ ] prometheus-node-exporter installed
  [ ] service enabled
  [ ] service active/running
  [ ] localhost:9100/metrics works
  [ ] Tailscale IP recorded
  [ ] Prometheus target added
  [ ] Prometheus restarted
  [ ] pi5-dev-1 can curl target over Tailscale
  [ ] Prometheus /targets shows UP
  [ ] Homepage entry added
  [ ] Homepage displays new Pi
  [ ] Grafana dropdown displays new Pi
  [ ] Grafana receives metrics
