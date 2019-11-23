# axpert
communtication with Voltronic Power compatible inverters (axpert compatible) via bash

For now this project contains two bash scripts.

`axpert.sh` sends commands to an axpert compatible inverter and prints the answer to `stdout`.

`log_axpert.sh` sends the **`QPIGS`** command to the inverter and stores the answer into a logfile.  
> I use this for backup and later graphical visualization (import into an influxDB and visualize with grafana).

#### compatible inverters (tested so far):
* *EA Sun Power*: ISolar SM 5KW
