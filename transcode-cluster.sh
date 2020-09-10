#!/bin/bash
#
# Arrancador de servicios de Transcode-Cluster
#
#set -e
#set -x

# Verificación de ejecucion del servicio.
lockfile="/tmp/transcode_cluster.lockfile"
if [ -f $lockfile ]; then 
	echo "El servicio ya se está ejecutando"
	exit 1
fi

# Importar y verificar variables de configuracion
if [ -f "/etc/transcode-cluster.cfg" ]; then
	source /etc/transcode-cluster.cfg
else
	echo "No se encuentra el script de configuracion de transcode-cluster"
	exit 1
fi

if [ "$currentnode" = "" ] || [ "$transcode_cache" = "" ] || [ "$transcode_final" = "" ] || [ "$script_dir" = "" ]; then
	echo "Error en archivo de configuración."
	exit 1
fi

# Variables
cantserv=0
logfile="$transcode_final/logs/$(date +'%Y-%m-%d')_node$currentnode.log"
mkdir "$transcode_final/logs"

# Funciones
function loguear {
	echo "$(date +'%H:%M:%S')(TRANSCODE-CLUSTER): $1" >> "$logfile"
}

# Buscar servicios:
for D in "$transcode_cache"/*; do
	if [ -d "${D}" ]; then
		cantserv++
		servicio[$cantserv]=$D
		if [ ! -f "$script_dir/${D}.sh" ]; then
			echo "No se puede iniciar: servicio correspondiente a ${D} no cuenta con el script en $script_dir"
			exit 1
		fi
	fi
done

if [ "$cantserv" = "0" ]; then
	echo "No hay servicios configurados."
	exit 1
fi

# Inicio de servicios
touch $lockfile
loguear "---- Inicio de ejecución en NODO $currentnode ----"

if [ "$currentnode" = "0" ]; then
	# Opcion Master (Splitters y Joiners)
	for i in "${servicio[@]}"; do
		echo "Iniciando Splitter para servicio ${servicio[$i]}"
		nohup "$script_dir"/splitter.sh "${servicio[$i]}" &
		echo "Iniciando Joiner para servicio ${servicio[$i]}"
		nohup "$script_dir"/joiner.sh "${servicio[$i]}" &
	done
else
	# Opcion Slave (transcode)
	for i in "${servicio[@]}"; do
		echo "Iniciando Transcoder para servicio ${servicio[$i]}"
		nohup "$script_dir"/"${servicio[$i]}".sh &
	done
fi

exit 0