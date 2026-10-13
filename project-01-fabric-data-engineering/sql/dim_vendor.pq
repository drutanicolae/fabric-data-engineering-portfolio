let
  Source = yellow_taxi_silver,
  #"Removed other columns" = Table.SelectColumns(Source, {"VendorID"}),
  #"Removed duplicates" = Table.Distinct(#"Removed other columns", {"VendorID"}),
  #"Added custom" = Table.AddColumn(#"Removed duplicates", "VendorName", each if [VendorID] = 1 then "Creative Mobile Technologies, LLC"
else if [VendorID] = 2 then "Curb Mobility, LLC"
else if [VendorID] = 6 then "Myle Technologies Inc"
else if [VendorID] = 7 then "Helix"
else "Unknown vendor"),
  #"Added custom 1" = Table.AddColumn(#"Added custom", "VendorDescription", each if [VendorID] = 1 then "TPEP provider identified by NYC TLC"
else if [VendorID] = 2 then "TPEP provider identified by NYC TLC"
else if [VendorID] = 6 then "TPEP provider identified by NYC TLC"
else if [VendorID] = 7 then "TPEP provider identified by NYC TLC"
else "Provider not identified in the source dictionary"),
  #"Changed column type" = Table.TransformColumnTypes(#"Added custom 1", {{"VendorName", type text}, {"VendorDescription", type text}})
in
  #"Changed column type"