#!/bin/bash

#set -e
#set -x

# Contar argumentos
args=("$@")
if [ ${#args[@]} -eq 0 ]; then
        echo "Uso: splitter {Nombre de servicio}." 1>&2
        exit 1
fi

args=("$@")
if [ ${#args[@]} -ne 1 ]; then
	echo "Demasiados argumentos." 1>&2
	echo "Uso: splitter {Nombre de servicio}." 1>&2
	exit 1
fi

# Importar y verificar variables de configuracion
if [ -f "/etc/transcode-cluster.cfg" ]; then
	source /etc/transcode-cluster.cfg
else
	echo "No se encuentra el script de configuracion de transcode-cluster"
	exit 1
fi

if [ "$currentnode" = "" || "$transcode_cache" = "" || "$transcode_final" = "" ]; then
	echo "Error en archivo de configuración."
	exit 1
fi

# Variables locales
servicio="$1"
indir="$transcode_cache/$servicio"
numnodes="$(wc -l < '/etc/transcodenode_list')"
lockfile="/tmp/transcode_splitter.lockfile"
logfile="$transcode_final/logs/$(date +'%Y-%m-%d')_node$currentnode.log"
mkdir "$transcode_final/logs"

# Funciones
function loguear {
	echo "$(date +'%H:%M:%S')(SPLITTER): $1" >> "$logfile"
}

# --- Inicio de tareas ---

if [ -f $lockfile ]; then 
	# Verificación de ejecucion del servicio.
	echo "El servicio ya se está ejecutando"
	exit 1
fi

touch "$lockfile"														# Creacion de lockfile para marcar el servicio "en ejecución".
loguear "---- Inicio de ejecución en NODO $currentnode ----" 			# Loguear inicio
loguear "[Cantidad de nodos = $numnodes]"

if [ "$currentnode" = "0" ]; then
loguear "[Inicio de proceso SPLITTER]"
	# Ejecución de nodo MASTER
	while :; do
		# Fijarse si apareció algun nuevo archivo.
		cnt=$(find "$indir" -maxdepth 1 -cmin +0.25 -name '*.mxf' | wc -l)
		if [ "$cnt" != "0" ]; then 
			# Procesar cada archivo.
			for i in "$indir"/*.mxf; do
				archivo=$(basename "$i" .mxf)
				loguear "[Archivo encontrado] $archivo"
				# Encontrar duración de archivo
				duracion_total=$(/usr/bin/printf '%.0f' "$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$i")")
				loguear "[$archivo] Duración en segundos (redondeada): $duracion_total"
				segmento=$((duracion_total/numnodes))
				loguear "[$archivo] Inicio de splitting"
				for ((n=1; n<=numnodes; n++)); do
					mkdir -v $indir/node$n
					#3. Generación de cada segmento
					# Ultimo segmento no tiene que tener -t
					if [ "$n" != "$numnodes" ]; then
						menost="-t $segmento "
					else
						menost=""
					fi
					echo "menost = $menost"
					loguear "[$archivo][Ejecución] ffmpeg -y -ss $(((n - 1) * segmento)) ${menost}-i $i -map 0 -c copy $indir/node$n/${archivo}.part${n}.mxf"
					ffmpeg -y -ss $(((n - 1) * segmento)) ${menost}-i "$i" -map 0 -c copy "$indir/node$n/${archivo}.part${n}".mxf
					loguear "[$archivo][Ejecución] Completado."
				done
				touch "$indir/.${archivo}_v"
				mkdir -v $indir/SPLIT
				loguear "[Mover] $(mv -v "$i" "$indir/SPLIT/$archivo.mxf")"
			done
		fi
	done
else
	echo "Solo el nodo MASTER puede ejecutar el SPLITER"
	exit 1
fi

loguear "---- Ejecución DETENDIA en NODO $currentnode ----"
rm $lockfile
exit 0
