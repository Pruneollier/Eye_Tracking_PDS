import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
import numpy as np

# Function to convert "mm:ss.sss" to total seconds
def convert_time_to_seconds(timestring):
    minutes, seconds = timestring.split(':')
    return float(minutes) * 60 + float(seconds)

# Read CSV Files
file1 = "/Users/pruneollier/Documents/BA5/PDS/ET_PDS/plot_difference/ptsData.csv"
file2 = "/Users/pruneollier/Documents/BA5/PDS/ET_PDS/plot_difference/touchData.csv"

df1 = pd.read_csv(file1)
df2 = pd.read_csv(file2)


# Convert 'Timestamp' to seconds
df1['Timestamp'] = df1['Timestamp'].apply(convert_time_to_seconds)
df2['Timestamp'] = df2['Timestamp'].apply(convert_time_to_seconds)


# Find the first timestamp in df2 with X non-zero
first_non_zero_timestamp = df2.loc[df2['Y'] != 0, 'Timestamp'].min()
# Filter df1 and df2 to start plotting from the first_non_zero_timestamp
df1 = df1[df1['Timestamp'] >= first_non_zero_timestamp]
df2 = df2[df2['Timestamp'] >= first_non_zero_timestamp]

# Plotting
plt.plot(df1['Timestamp'], df1['Y'], label='Y coordinate of gaze estimation indicator')
plt.plot(df2['Timestamp'], df2['Y'], label='Y coordinate of touch')

# Customize the plot
plt.xlabel('Time (mm:ss)')
plt.ylabel('Y (CGFloat)')
plt.title('Comparison of Y coordinates over time')
plt.legend()

# Set x-axis ticks
ax = plt.gca()
tick_interval = 10  # Change this value to adjust the interval
ticks = np.arange(min(df1['Timestamp'].min(), df2['Timestamp'].min()), 
                  max(df1['Timestamp'].max(), df2['Timestamp'].max()), 
                  tick_interval)
ax.set_xticks(ticks)

# Set x-axis labels to "mm:ss" format (without milliseconds)
ax.set_xticklabels([f'{int(tick//60):02d}:{int(tick%60):02d}' for tick in ticks])

# Calculate the y-coordinate difference at each timestamp
x_diff = abs(df1['Y'] - df2['Y'])

# Compute the average difference
average_difference = x_diff.mean()

print(f"Average Difference: {average_difference}")


plt.show()

