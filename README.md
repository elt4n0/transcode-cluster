# transcode-cluster
Usar varios servidores para una sola transcodificación de FFMPEG.

Este script se usaba en BACUA para utilizar el poder de procesamiento de varios equipos para transcodificiar video más rápido.

El mecanismo era simple:

Uno de los equipos (nodos) es el MASTER.
Los demás son nodos esclavos.

El master tiene tres tareas:

1. Dividir el archivo que se va a transcodificar en partes semi-iguales.
> Como queremos que la transcodificación sea frame accurate, dividirlo en partes iguales puede dar un resultado indeseado.
2. Servir las partes en una estructura de directorios accesible mediante la red por los demás nodos
> En su implementación se usaba NFS por su velocidad, confianza y rebustez en sistemas linux, pero con otros FS también es posible.
3. Una vez que todos los nodos completaron su tarea, unir las piezas para obtener el resultado final.

Como dividir un video y unir varios es una tarea que no requiere procesar el video, FFMPEG la realiza en muy poco tiempo.
En caso de estar usando 4 equipos de igual capacidad de procesamiento se puede dividir el video en 4 partes, entregar cada una a un nodo, y volver a unirlas cuando termine para realizar la tarea de transcodificacion (casi) 4 veces mas rápido.

De momento el repositorio es un backup de los scripts realizado después de que se decidió cerrar Contenidos TDA.
Si te interesa el proyecto pueden contactarme para realizar consultas.

## README ORIGINAL INCOMPLETO

### Transcode Cluster!
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
