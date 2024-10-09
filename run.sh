for f in *.out; do
    echo "Running $f"
    # Running under perf stat is required to get meaningful counters
    # (This relies on perf to configure everything.)
    perf stat ./$f
done
