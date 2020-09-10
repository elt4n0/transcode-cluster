# transcode-cluster
Usar varios servidores para una sola transcodificación de FFMPEG.

De momento el repositorio es backup.
Si te interesa el proyecto avisame y lo arreglamos

## Transcode Cluster!
Un sistemita de scripts para transcodear archivos de video
en modo cluster

Archivos:

1. transcode-cluster.cfg
	Contiene el número de nodo actual y los path al cache y alamacenamiento
	final de video transcodificado.
	Ubicacion /etc/transcode-cluster.cfg
	
2. transcode-cluster.sh
	Script de inicio de trigger de servicios.
	Lo que hace es contar las carpetas en la ubicación de caché y considerar
	cada una como un servicio. Ejecutará una instacia de splitter y joiner
	por cada una si el nodo es 0, o ejecutará el script de transcodificacion
	correspondiente a cada servicio si es otro nodo. Los scripts de servicio
	deben tener el mismo nombre que la carpeta.
	
Como agregar un servicio:
	1. Crear una carpeta en la ubicación de CACHE con el nombre del
	servicio.
	2. Crear un script con el mismo nombre que la carpeta con el proceso de 
	transcodificacion del servicio.
	3. Poner el script en la ubicación de scripts para que los nodos puedan
	ejecutarlo.
	
Como agregar un nodo: