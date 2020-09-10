#!/bin/bash

#set -x
#set -e

# Variables
indir="/media/BACUA_CACHE/A_MP4_5M_1080"
outdir="/media/BACUA_FINALES/MP4_5M_1080"
numnodes="$(wc -l < '/etc/transcodenode_list')"
currentnode="$(cat /etc/transcodenode)"
lockfile="/tmp/transcode_joiner.lockfile"
logfile="/media/BACUA_FINALES/logs/$(date +'%Y-%m-%d')_node$currentnode.log"

# Funciones
function loguear { # Param 1: STRING - Lo que se loguea
	echo "$(date +'%H:%M:%S')(JOINER): $1" >> "$logfile"
}

function estalisto { # Param 1: INT - Nodo      Param 2: STRING - Archivo
	busq=$(find "$indir/node$1/done" -maxdepth 1 -name "*$2*" | wc -l)
	if [ "$busq" != "0" ]; then
		return 0
	else
		return 1
	fi
}


# --- Inicio de tareas ---

if [ -f $lockfile ]; then 
	# Verificación de ejecucion del servicio.
	echo "El servicio ya se está ejecutando"
	exit 1
fi

touch "$lockfile"														# Creacion de lockfile para marcar el servicio "en ejecución".

if [ "$currentnode" = "0" ]; then
loguear "[Inicio de proceso JOINER]"
	# Ejecución de nodo MASTER
	while :; do
		cnt=$(find "$indir" -maxdepth 1 -name '.*_v' | wc -l)
		if [ "$cnt" != "0" ]; then
			for a in "$indir"/.*_v; do
				nombre=$(basename "$a" _v)
				nombre=${nombre:1}
				nodolisto=0
				for ((n=1;n<=numnodes;n++)); do
					if ! estalisto "$n" "$nombre"; then nodolisto=1; fi
				done
				if $nodolisto; then
					loguear "[Archivo listo para unir] $nombre"
					# Crear string de concatenacion.
					concat=""
					for ((n=1;n<=numnodes;n++)); do
						arch_enc=$(find "$indir/node$n/done" -maxdepth 1 -name "*$nombre*")
						concat="$concat$indir/node$1/done/$arch_enc"
						if [ "$n" != "$numnodes" ]; then concat="$concat|"; fi
					done
					# String para joinear
					loguear "[$archivo][JOIN] ffmpeg -i \"concat:$concat\" -c copy -map 0 $outdir/$archivo.mp4"
					ffmpeg -i \"concat:"$concat"\" -c copy -map 0 "$outdir"/"$archivo".mp4
					loguear "[$archivo][JOIN] Completado: $outdir/$archivo.mp4"
				fi
			done
		fi
	done
else
	echo "Solo el nodo MASTER puede ejecutar el JOINER"
	exit 1
fi

rm $lockfile
exit 0
