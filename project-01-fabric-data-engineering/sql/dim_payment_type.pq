let
  Source = yellow_taxi_silver,
  #"Removed other columns" = Table.SelectColumns(Source, {"payment_type"}),
  #"Removed duplicates" = Table.Distinct(#"Removed other columns", {"payment_type"}),
  #"Added custom" = Table.AddColumn(#"Removed duplicates", "PaymentTypeName", each if [payment_type] = 0 then "Unspecified / Missing"
else if [payment_type] = 1 then "Credit card"
else if [payment_type] = 2 then "Cash"
else if [payment_type] = 3 then "No charge"
else if [payment_type] = 4 then "Dispute"
else if [payment_type] = 5 then "Unknown"
else if [payment_type] = 6 then "Voided trip"
else "Unmapped"),
  #"Added custom 1" = Table.AddColumn(#"Added custom", "PaymentCategory", each if [payment_type] = 1 then "Electronic"
else if [payment_type] = 2 then "Cash"
else if [payment_type] = 3 then "No charge"
else if [payment_type] = 4 then "Dispute"
else "Unclassified"),
  #"Added custom 2" = Table.AddColumn(#"Added custom 1", "IsStandardPayment", each [payment_type] = 1 or [payment_type] = 2),
  #"Changed column type" = Table.TransformColumnTypes(#"Added custom 2", {{"PaymentTypeName", type text}, {"PaymentCategory", type text}, {"IsStandardPayment", type logical}})
in
  #"Changed column type"