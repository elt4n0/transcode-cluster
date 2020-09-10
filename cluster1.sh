#!/bin/bash

#set -e
set -x

# Variables
indir="/media/BACUA_CACHE/A_MP4_5M_1080"
outdir="/media/BACUA_FINALES"
numnodes="$(wc -l < '/etc/transcodenode_list')"
currentnode="$(cat /etc/transcodenode)"
lockfile="/tmp/transcode_cluster.lockfile"
logfile="/media/BACUA_FINALES/logs/$(date +'%Y-%m-%d')_node$currentnode.log"

# Funciones
function loguear {
	echo "$(date +'%H:%M:%S'): $1" >> $logfile
}

# --- Inicio de tareas ---

if [ -f $lockfile ]; then 
	# Verificación de ejecucion del servicio.
	echo "El servicio ya se está ejecutando"
	exit 1
fi

touch $lockfile 														# Creacion de lockfile para marcar el servicio "en ejecución".
touch $logfile															# Loguear inicio
loguear "---- Inicio de ejecución en NODO $currentnode ----" 			
loguear "[Cantidad de nodos = $numnodes]"

if [ "$currentnode" = "0" ]; then
	# Ejecución de nodo MASTER
	while :; do
		loguear "[Inicio de proceso MASTER]"
		#1. Encontrar archivos
		for i in "$indir"/*.mxf; do
			archivo=$(basename $i .mxf)
			loguear "[Archivo encontrado] $archivo"
			#2. Encontrar duración de archivo
			duracion_total="$(/usr/bin/printf '%.0f' $(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $i))"
			loguear "[$archivo] Duración en segundos (redondeada): $duracion_total"
			segmento=$((duracion_total/numnodes))
			loguear "[$archivo] Inicio de splitting"
			for ((n=1; n<=numnodes; n++)); do
				mkdir -v $indir/node$n
				#3. Generación de cada segmento
				loguear "[$archivo][Ejecución] ffmpeg -hwaccel auto -threads 8 -ss $(((n - 1) * segmento)) -t $segmento -i $i -codec copy $indir/node$n/$archivo.mxf"
				ffmpeg -hwaccel auto -threads 8 -y -ss $(((n - 1) * segmento)) -t $segmento -i $i -codec copy $indir/node$n/$archivo.mxf
				loguear "[$archivo][Ejecución] Completado."
			done
			loguear "[Mover] $(mv -v $i $indir/../SPLITED)"
		done		
	done
fi

rm $lockfile
exit 0