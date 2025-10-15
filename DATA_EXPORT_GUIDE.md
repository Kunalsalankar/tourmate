# Data Export and Analytics Guide

## Overview

TourMate provides comprehensive data export and analytics capabilities designed specifically for transportation planning and research. This guide covers all available export formats, analytics tools, and how to use them for transportation planning analysis.

## Available Export Formats

### 1. All Trips Export (CSV)

**Purpose**: Complete dataset of all trips with detailed information

**Fields Included**:
- Trip ID
- User ID
- Type (Manual/Auto)
- Date
- Start Time
- End Time
- Duration (minutes)
- Origin
- Destination
- Distance (km)
- Mode
- Detected Mode
- Average Speed (km/h)
- Maximum Speed (km/h)
- Purpose
- Activities
- Companions
- Cost
- Notes

**Use Cases**:
- Comprehensive trip database for analysis
- Import into statistical software (R, Python, SPSS)
- GIS analysis with origin-destination coordinates
- Travel behavior modeling
- Demand forecasting

**How to Export**:
```dart
final exportService = DataExportService();
final csvData = await exportService.exportAllTripsToCSV();
// Save to file or process as needed
```

### 2. Origin-Destination Matrix

**Purpose**: Trip counts between origin-destination pairs

**Fields Included**:
- Origin
- Destination
- Trip Count

**Use Cases**:
- Transportation demand modeling
- Route planning
- Public transit network design
- Traffic flow analysis
- Infrastructure investment prioritization

**Sample Output**:
```csv
Origin,Destination,Trip Count
Kozhikode,Kochi,45
Kochi,Trivandrum,32
Kozhikode,Calicut University,28
...
```

**How to Export**:
```dart
final csvData = await exportService.exportODMatrix();
```

### 3. Mode Share Analysis

**Purpose**: Distribution of trips by transport mode

**Fields Included**:
- Mode
- Trip Count
- Percentage
- Total Distance (km)
- Average Distance (km)

**Use Cases**:
- Public transit planning
- Active transportation promotion
- Environmental impact assessment
- Policy evaluation
- Modal shift analysis

**Sample Output**:
```csv
Mode,Trip Count,Percentage,Total Distance (km),Avg Distance (km)
Car,450,45.0%,5400.0,12.0
Bus,300,30.0%,4200.0,14.0
Walking,150,15.0%,300.0,2.0
Cycling,100,10.0%,500.0,5.0
```

**How to Export**:
```dart
final csvData = await exportService.exportModeShareAnalysis();
```

### 4. Trip Purpose Analysis

**Purpose**: Distribution of trips by purpose

**Fields Included**:
- Purpose
- Trip Count
- Percentage
- Total Distance (km)
- Average Distance (km)

**Use Cases**:
- Land use planning
- Activity-based modeling
- Peak hour analysis
- Facility location planning
- Economic impact studies

**Sample Output**:
```csv
Purpose,Trip Count,Percentage,Total Distance (km),Avg Distance (km)
Work,400,40.0%,6000.0,15.0
Shopping,200,20.0%,1000.0,5.0
Education,150,15.0%,2250.0,15.0
Recreation,150,15.0%,1500.0,10.0
Healthcare,100,10.0%,800.0,8.0
```

**How to Export**:
```dart
final csvData = await exportService.exportTripPurposeAnalysis();
```

### 5. Hourly Distribution

**Purpose**: Trip counts by hour of day

**Fields Included**:
- Hour
- Trip Count

**Use Cases**:
- Peak hour identification
- Traffic signal timing
- Public transit scheduling
- Congestion pricing analysis
- Time-of-day pricing

**Sample Output**:
```csv
Hour,Trip Count
0:00,5
1:00,2
...
7:00,120
8:00,250
9:00,180
...
17:00,220
18:00,280
...
```

**How to Export**:
```dart
final csvData = await exportService.exportHourlyDistribution();
```

## Analytics Dashboard

### Overview Statistics

The analytics dashboard provides real-time statistics:

- **Total Trips**: All trips in the system
- **Total Users**: Unique users contributing data
- **Auto Trips**: Automatically detected trips
- **Manual Trips**: User-entered trips
- **Total Distance**: Cumulative distance traveled
- **Average Distance**: Mean trip distance
- **Average Duration**: Mean trip duration

### Mode Distribution Visualization

Visual representation of mode share with:
- Percentage bars for each mode
- Trip counts
- Color-coded by mode type

### Access Analytics Dashboard

From the admin panel:
1. Navigate to Analytics Screen
2. View real-time statistics
3. Export data as needed
4. Refresh for updated data

## Integration with Analysis Tools

### R Integration

```r
# Load trip data
trips <- read.csv("all_trips.csv")

# Basic analysis
summary(trips)
table(trips$Mode)

# Trip length distribution
hist(trips$Distance..km., 
     main="Trip Distance Distribution",
     xlab="Distance (km)")

# Mode share by purpose
library(ggplot2)
ggplot(trips, aes(x=Purpose, fill=Mode)) +
  geom_bar(position="fill") +
  labs(y="Proportion")
```

### Python Integration

```python
import pandas as pd
import matplotlib.pyplot as plt

# Load trip data
trips = pd.read_csv('all_trips.csv')

# Basic statistics
print(trips.describe())
print(trips['Mode'].value_counts())

# Visualizations
trips['Mode'].value_counts().plot(kind='bar')
plt.title('Mode Share')
plt.show()

# Time series analysis
trips['Date'] = pd.to_datetime(trips['Date'])
trips.groupby('Date').size().plot()
plt.title('Daily Trip Counts')
plt.show()
```

### GIS Integration (QGIS/ArcGIS)

1. Export all trips with coordinates
2. Import CSV into GIS software
3. Create point layers from origin/destination coordinates
4. Perform spatial analysis:
   - Hot spot analysis
   - Kernel density estimation
   - Network analysis
   - Accessibility mapping

### Excel/Tableau Integration

1. Export CSV files
2. Import into Excel or Tableau
3. Create pivot tables and dashboards
4. Build interactive visualizations

## Transportation Planning Applications

### 1. Travel Demand Modeling

**Data Required**:
- All trips export
- OD matrix
- Mode share analysis

**Analysis Steps**:
1. Calibrate trip generation models
2. Develop trip distribution matrices
3. Estimate mode choice parameters
4. Validate with observed data

**Example**:
```python
# Trip generation model
from sklearn.linear_model import LinearRegression

# Predict trips based on demographics
model = LinearRegression()
model.fit(demographics, trip_counts)
```

### 2. Public Transit Planning

**Data Required**:
- OD matrix
- Mode share analysis
- Hourly distribution

**Analysis Steps**:
1. Identify high-demand corridors
2. Analyze peak hour patterns
3. Optimize route alignment
4. Schedule frequency planning

### 3. Active Transportation Planning

**Data Required**:
- Mode share (walking/cycling)
- Trip purpose analysis
- Distance distribution

**Analysis Steps**:
1. Identify short trips suitable for active modes
2. Map walking/cycling routes
3. Identify infrastructure gaps
4. Prioritize facility improvements

### 4. Congestion Analysis

**Data Required**:
- Hourly distribution
- Average speed data
- Route information

**Analysis Steps**:
1. Identify peak congestion periods
2. Analyze speed reductions
3. Estimate delay costs
4. Evaluate mitigation strategies

### 5. Environmental Impact Assessment

**Data Required**:
- Mode share
- Distance by mode
- Trip counts

**Calculations**:
```python
# Carbon emissions estimation
emission_factors = {
    'Car': 0.171,      # kg CO2/km
    'Bus': 0.089,      # kg CO2/km
    'Motorcycle': 0.103,
    'Walking': 0,
    'Cycling': 0
}

# Calculate total emissions
total_emissions = sum(
    trips[trips['Mode'] == mode]['Distance..km.'].sum() * factor
    for mode, factor in emission_factors.items()
)
```

### 6. Accessibility Analysis

**Data Required**:
- OD matrix
- Travel times
- Trip purposes

**Analysis Steps**:
1. Calculate accessibility indices
2. Identify underserved areas
3. Evaluate equity impacts
4. Prioritize improvements

## Data Quality Considerations

### Validation Checks

1. **Distance Validation**:
   - Check for unrealistic distances
   - Verify GPS accuracy
   - Compare with map distances

2. **Speed Validation**:
   - Identify speed outliers
   - Verify mode-speed consistency
   - Check for GPS errors

3. **Time Validation**:
   - Verify timestamp consistency
   - Check for duplicate trips
   - Validate trip durations

4. **Completeness**:
   - Check for missing fields
   - Verify coordinate accuracy
   - Ensure purpose classification

### Data Cleaning

```python
import pandas as pd

# Load data
trips = pd.read_csv('all_trips.csv')

# Remove invalid trips
trips = trips[trips['Distance..km.'] > 0.3]  # Minimum distance
trips = trips[trips['Distance..km.'] < 500]  # Maximum distance
trips = trips[trips['Duration..min.'] > 0]   # Valid duration

# Remove outliers
trips = trips[trips['Avg.Speed..km.h.'] < 150]  # Realistic speed

# Handle missing values
trips['Purpose'].fillna('Not Specified', inplace=True)
```

## Privacy and Ethics

### Data Anonymization

Before sharing data:
1. Remove user identifiers
2. Aggregate spatial data to zones
3. Suppress small cell counts
4. Apply differential privacy if needed

### Ethical Considerations

- Obtain informed consent
- Clearly communicate data usage
- Provide opt-out mechanisms
- Secure data storage and transmission
- Comply with data protection regulations

## Performance Optimization

### Large Dataset Handling

For datasets with >10,000 trips:

1. **Batch Processing**:
```dart
// Process in batches
const batchSize = 1000;
for (int i = 0; i < totalTrips; i += batchSize) {
  final batch = await _fetchTripBatch(i, batchSize);
  await _processBatch(batch);
}
```

2. **Streaming Export**:
```dart
// Stream data to file
final sink = file.openWrite();
await for (final trip in tripStream) {
  sink.writeln(_tripToCSVRow(trip));
}
await sink.close();
```

3. **Firestore Query Optimization**:
- Use composite indexes
- Limit query results
- Implement pagination
- Cache frequently accessed data

## Troubleshooting

### Common Issues

**Issue**: Export takes too long
- **Solution**: Implement batch processing, add progress indicators

**Issue**: CSV file too large
- **Solution**: Split by date range, compress files, use database export

**Issue**: Missing data in export
- **Solution**: Check Firestore security rules, verify query filters

**Issue**: Coordinate format issues
- **Solution**: Standardize to decimal degrees, verify coordinate system

## API Documentation

### DataExportService Methods

```dart
class DataExportService {
  // Export user trips to CSV
  Future<String> exportUserTripsToCSV(String userId)
  
  // Export all trips to CSV
  Future<String> exportAllTripsToCSV()
  
  // Export OD matrix
  Future<String> exportODMatrix()
  
  // Export mode share analysis
  Future<String> exportModeShareAnalysis()
  
  // Export trip purpose analysis
  Future<String> exportTripPurposeAnalysis()
  
  // Export hourly distribution
  Future<String> exportHourlyDistribution()
  
  // Get trip statistics
  Future<Map<String, dynamic>> exportTripStatistics()
}
```

## Future Enhancements

### Planned Features

1. **Real-time Streaming Export**: WebSocket-based live data export
2. **Custom Query Builder**: User-defined filters and aggregations
3. **Automated Reports**: Scheduled report generation
4. **API Endpoints**: REST API for external tools
5. **Advanced Visualizations**: Interactive charts and maps
6. **Machine Learning Integration**: Predictive analytics
7. **Multi-format Export**: JSON, XML, Parquet, GeoJSON
8. **Cloud Storage Integration**: Direct upload to S3, Google Cloud

## Support

For questions or issues:
- Review inline code documentation
- Check example implementations
- Contact development team
- Submit issues on repository

---

**Version**: 1.0.0  
**Last Updated**: 2025-01-14  
**Author**: TourMate Development Team
