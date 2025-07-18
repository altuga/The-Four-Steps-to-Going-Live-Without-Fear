#!/bin/bash

# CPU Throttling Graph Generator
# Captures and visualizes CPU throttling data

CONTAINER_NAME=${1:-"spring-1cpu"}
DURATION=${2:-120}  # 2 minutes default
INTERVAL=${3:-1}    # 1 second sampling

echo "📊 CPU Throttling Graph Capture"
echo "==============================="
echo "Container: $CONTAINER_NAME"
echo "Duration: $DURATION seconds"
echo "Sampling: Every $INTERVAL seconds"
echo ""

# Create timestamped data file
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
DATA_FILE="cpu-throttling-data-$TIMESTAMP.csv"
GRAPH_FILE="cpu-throttling-graph-$TIMESTAMP.png"

# Check if container exists
if ! docker ps | grep -q "$CONTAINER_NAME"; then
    echo "❌ Container '$CONTAINER_NAME' not found!"
    exit 1
fi

echo "📝 Data file: $DATA_FILE"
echo "🖼️  Graph file: $GRAPH_FILE"
echo ""

# CSV header
echo "timestamp,seconds,cpu_percent,throttled_usec,throttled_periods,nr_periods" > $DATA_FILE

echo "🔍 Starting data collection..."
echo "Trigger your CPU load now: curl 'http://localhost:8080/cpuStress'"
echo ""

start_time=$(date +%s)
counter=0

while [ $counter -lt $DURATION ]; do
    current_time=$(date +%s)
    elapsed=$((current_time - start_time))
    
    # Get CPU percentage from docker stats
    cpu_percent=$(docker stats $CONTAINER_NAME --no-stream --format "{{.CPUPerc}}" | sed 's/%//')
    
    # Get throttling data from cgroup
    if docker exec $CONTAINER_NAME test -f /sys/fs/cgroup/cpu.stat 2>/dev/null; then
        throttled_usec=$(docker exec $CONTAINER_NAME cat /sys/fs/cgroup/cpu.stat 2>/dev/null | grep throttled_usec | awk '{print $2}' || echo "0")
        throttled_periods=$(docker exec $CONTAINER_NAME cat /sys/fs/cgroup/cpu.stat 2>/dev/null | grep throttled_periods | awk '{print $2}' || echo "0")
        nr_periods=$(docker exec $CONTAINER_NAME cat /sys/fs/cgroup/cpu.stat 2>/dev/null | grep nr_periods | awk '{print $2}' || echo "0")
    else
        # Fallback for different cgroup versions
        throttled_usec="0"
        throttled_periods="0"
        nr_periods="0"
    fi
    
    # Log data
    echo "$(date -Iseconds),$elapsed,$cpu_percent,$throttled_usec,$throttled_periods,$nr_periods" >> $DATA_FILE
    
    # Display progress
    printf "\r⏱️  %3d/%d seconds - CPU: %5.1f%% - Throttled: %s μs" \
        "$elapsed" "$DURATION" "$cpu_percent" "$throttled_usec"
    
    sleep $INTERVAL
    counter=$((counter + 1))
done

echo ""
echo ""
echo "✅ Data collection complete!"

# Check if gnuplot is available for graph generation
if command -v gnuplot >/dev/null 2>&1; then
    echo "📈 Generating graph with gnuplot..."
    
    # Create gnuplot script
    cat > /tmp/throttling_plot.gnu << EOF
set terminal png size 1200,800
set output '$GRAPH_FILE'
set title 'CPU Throttling Analysis - Container: $CONTAINER_NAME'
set xlabel 'Time (seconds)'
set ylabel 'CPU Usage (%)'
set y2label 'Throttled Time (microseconds)'
set ytics nomirror
set y2tics
set grid
set key outside right top vertical

# Set time range
set xrange [0:$DURATION]
set yrange [0:110]

# Plot CPU percentage
plot '$DATA_FILE' using 2:3 with lines linewidth 2 linecolor rgb 'blue' title 'CPU Usage (%)' axes x1y1, \\
     '$DATA_FILE' using 2:(\$4/1000) with lines linewidth 2 linecolor rgb 'red' title 'Throttled Time (ms)' axes x1y2
EOF

    gnuplot /tmp/throttling_plot.gnu
    rm /tmp/throttling_plot.gnu
    
    echo "✅ Graph saved as: $GRAPH_FILE"
else
    echo "⚠️  gnuplot not found. Install with: brew install gnuplot (macOS) or apt-get install gnuplot (Linux)"
    echo "📊 Creating simple ASCII graph..."
    
    # Create simple ASCII visualization
    echo ""
    echo "📊 CPU Usage Timeline (ASCII):"
    echo "=============================="
    
    awk -F',' 'NR>1 {
        cpu = $3
        bar_length = int(cpu / 2)  # Scale to 50 chars max
        printf "%3ds |", $2
        for(i=1; i<=bar_length; i++) printf "█"
        for(i=bar_length+1; i<=50; i++) printf " "
        printf "| %5.1f%%\n", cpu
    }' $DATA_FILE | tail -20
    
    echo ""
    echo "Scale: Each █ represents 2% CPU usage"
fi

# Generate summary statistics
echo ""
echo "📊 THROTTLING ANALYSIS SUMMARY"
echo "==============================="

# Calculate statistics from data
awk -F',' 'NR>1 {
    cpu_sum += $3; cpu_count++
    if($3 > cpu_max) cpu_max = $3
    if(cpu_min == "" || $3 < cpu_min) cpu_min = $3
    
    throttled_sum += $4; throttled_count++
    if($4 > throttled_max) throttled_max = $4
    
    periods_sum += $5; periods_count++
    if($5 > periods_max) periods_max = $5
}
END {
    print "CPU Statistics:"
    printf "  Average CPU: %.1f%%\n", cpu_sum/cpu_count
    printf "  Maximum CPU: %.1f%%\n", cpu_max
    printf "  Minimum CPU: %.1f%%\n", cpu_min
    print ""
    print "Throttling Statistics:"
    printf "  Total Throttled Time: %d microseconds (%.2f ms)\n", throttled_max, throttled_max/1000
    printf "  Average Throttled/Sample: %.1f μs\n", throttled_sum/throttled_count
    printf "  Maximum Throttled Periods: %d\n", periods_max
    print ""
    if(throttled_max > 1000) {
        print "🚨 SIGNIFICANT THROTTLING DETECTED!"
        print "   - Container is CPU constrained"
        print "   - Consider increasing CPU limits"
        print "   - Monitor application performance impact"
    } else {
        print "✅ Minimal throttling observed"
        print "   - CPU limits appear adequate"
        print "   - Good resource allocation"
    }
}' $DATA_FILE

echo ""
echo "📁 Files created:"
echo "  Data: $DATA_FILE"
if [ -f "$GRAPH_FILE" ]; then
    echo "  Graph: $GRAPH_FILE"
fi

echo ""
echo "💡 Next steps:"
echo "  1. Open $GRAPH_FILE to view the visual graph"
echo "  2. Analyze patterns in $DATA_FILE"
echo "  3. Compare with different CPU limits"
echo "  4. Correlate with application response times"
