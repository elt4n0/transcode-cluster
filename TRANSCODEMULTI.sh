#!/bin/bash

set -e
set -x

format="mp4"

while true; do
	mkdir -p /srv/workers
	date > /srv/workers/$(hostname)
	current_node=$(ls /srv/workers/ | grep -B99999 $(hostname) | wc -l)
	current_node=$((current_node-1))
	# look for work
	for d in $(ls -tF /srv/); do
		# check each job directory
		dir="/srv/$d"
		url=$(cat "$dir/URL" || echo "")
		if [ -e $dir/DOWNLOADED ]; then
			# found a completed download, check if this node's work is done
			basename=$(basename "$url")
			filename="$dir/$basename"
			if [ -e "$dir/DONE/${current_node}" ]; then
				# this node's work is done with this download, so check next job
				continue
			else
				# download is done, but transcoding is not, so let's work on it
				break
			fi
		elif [ -n "$url" ] && [ "$current_node" = "0" ]; then
			# not yet downloaded
			basename=$(basename "$url")
			if [ -s "$url" ]; then
				# local file name, copy over
				run-one rsync -aP "$url" "$dir/$basename" >$dir/DOWNLOAD.txt 2>&1
			elif echo "$url" | egrep -qs "^http:|^https:" >/dev/null 2>&1; then
				# url, download
				run-one wget -O "$dir/$basename" --continue "$url" >$dir/DOWNLOAD.txt 2>&1
			fi
			touch $dir/DOWNLOADED
		fi
		dir=
	done
	if [ -z "$dir" ]; then
		# Nothing to do, at this time, check back in a few seconds
		sleep 5
		continue
	fi
	if [ "$current_node" = "0" ]; then
		date > "$dir/RUNTIME"
	fi
	# Determine the duration (length) of the video
	hhmmss=$(avconv -i $filename 2>&1 | grep Duration: | sed -e "s/^.*Duration: //" -e "s/\..*$//")
	# Convert that HH:MM:SS.xxx to seconds
	seconds=$(date -u -d "1970-01-01 $hhmmss" +"%s")
	# Round up, to take care of the .xxx microseconds
	duration=$((seconds+1))
	# The length of each segment is the total length, divided by the total number of worker nodes
	total_nodes=$(ls /srv/workers/ | wc -l)
	length=$((duration/$total_nodes))
	# Calculate each node's start time
	start_time=$((length*current_node))
	# Only add the -s size parameter if the user wants to resize it
	size=$(cat $dir/SIZE)
	[ "$size" = "copy" ] && size_param="" || size_param="-s $size"
	# Kill off any previous running jobs
	killall -9 avconv 2>/dev/null || true
	# Write the command to a log file
	echo "avconv -ss $start_time -i $filename -t $length $size_param -vcodec libx264 -acodec aac -bsf:v h264_mp4toannexb -f mpegts -strict experimental -y ${filename}.part${current_node}.ts >>${filename}.part${current_node}.log.txt 2>&1" >${filename}.part${current_node}.log.txt
	# Split the video into N clips, one for each worker
	if ! avconv -ss $start_time -i $filename -t $length $size_param -vcodec libx264 -acodec aac -bsf:v h264_mp4toannexb -f mpegts -strict experimental -y ${filename}.part${current_node}.ts >>${filename}.part${current_node}.log.txt 2>&1; then
		mkdir -p "${dir}/FAILED/"
		touch "${dir}/FAILED/${current_node}"
	fi
	# Touch a file, so that the other workers know when its done
	mkdir -p "${dir}/DONE/"
	touch "${dir}/DONE/${current_node}"
	if [ "$current_node" = "0" ]; then
		# Node0 is responsible for putting everything back together
		while [ $(ls ${dir}/DONE/ | wc -l) -lt $total_nodes ]; do
			# Wait for all workers to finish
			sleep 1
		done
		concat="/dev/null"
		for i in $(seq 0 $total_nodes); do
			if [ -e "${filename}.part${i}.ts" ]; then
				concat="$concat|${filename}.part${i}.ts"
			fi
		done
		# Write the command to a log file
		echo "avconv -i concat:"$concat" -c copy -bsf:a aac_adtstoasc -y ${filename}_${size}_x264_aac.${format} >>${filename}_${size}_x264_aac.log.txt 2>&1" >${filename}_${size}_x264_aac.log.txt
		# Concatenate the clips together
		if ! avconv -i concat:"$concat" -c copy -bsf:a aac_adtstoasc -y ${filename}_${size}_x264_aac.${format} >>${filename}_${size}_x264_aac.log.txt 2>&1; then
			mkdir -p "${dir}/FAILED/"
			touch "${dir}/FAILED/concatenation"
		fi
		rm -f $dir/*.ts
		mkdir -p $dir/LOGS
		mv -f $dir/*txt $dir/LOGS
		date >> "$dir/RUNTIME"
	fi
done
exit 0