import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.dates import date2num

# Function to convert "mm:ss.sss" to total seconds
def convert_time_to_seconds(timestring):
    minutes, seconds = timestring.split(':')
    return float(minutes) * 60 + float(seconds)


def plot_rotations_and_diffs(csv_file):
    # Read CSV file
    df = pd.read_csv(csv_file)

    # Plotting
    fig, axs = plt.subplots(2, 1, sharex=True, figsize=(12, 10))

    # Convert timestamp to seconds
    df['Timestamp'] = df['Timestamp'].apply(convert_time_to_seconds)
    df['Yrot_normalized'] = (df['Yrot'] - df['Yrot'].min()) / (df['Yrot'].max() - df['Yrot'].min())
    df['Xdiff_normalized'] = (df['Xdiff'] - df['Xdiff'].min()) / (df['Xdiff'].max() - df['Xdiff'].min())
    df['Ydiff_normalized'] = (df['Ydiff'] - df['Ydiff'].min()) / (df['Ydiff'].max() - df['Ydiff'].min())


    # Plot Xrot, Yrot, Zrot over Timestamp
    axs[0].plot(df['Timestamp'], df['Yrot_normalized'], label='Yrot', color='orange')
    axs[0].plot(df['Timestamp'], df['Xdiff_normalized'], label='Xdiff', color='red')
    axs[0].set_ylabel('Yrot and Xdiff, normalized')
    axs[0].set_xlabel('time')
    axs[0].set_title('Influence of Yrot over Ydiff over time')
    axs[0].legend()



    axs[1].plot(df['Timestamp'], df['Yrot_normalized'], label='Yrot', color='orange')
    axs[1].plot(df['Timestamp'], df['Ydiff_normalized'], label='Ydiff', color='red')
    axs[1].set_ylabel('Yrot and Ydiff, normalized')
    axs[1].set_xlabel('time')
    axs[1].set_title('Influence of Yrot over Ydiff over time')
    axs[1].legend()

    

    # Customize the plot
    plt.xlabel('Time (mm:ss)')

    # Set x-axis ticks
    ax = plt.gca()
    tick_interval = 10  # Change this value to adjust the interval
    ticks = np.arange(df['Timestamp'].min(), 
                  df['Timestamp'].max(), 
                  tick_interval)
    ax.set_xticks(ticks)

    # Set x-axis labels to "mm:ss" format (without milliseconds)
    ax.set_xticklabels([f'{int(tick//60):02d}:{int(tick%60):02d}' for tick in ticks])
    # Adjust layout to prevent clipping of ylabel
    plt.tight_layout()
    plt.show()

file = "/Users/pruneollier/Documents/BA5/PDS/ET_PDS/plot_rot/eulerData.csv"

plot_rotations_and_diffs(file)