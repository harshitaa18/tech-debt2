#!/usr/bin/env python3
import random
import os
from pathlib import Path

# Business terms for generating messy field namess
business_terms = [
    "Legacy", "Old", "Archive", "Historical", "Vintage", "Classic", "Retired", "Deprecated",
    "Discount", "Rate", "Percentage", "Value", "Amount", "Total", "Sum", "Balance",
    "Tax", "Fee", "Charge", "Cost", "Price", "Revenue", "Income", "Profit",
    "Region", "Territory", "District", "Zone", "Area", "Location", "Site", "Branch",
    "Identifier", "Code", "Number", "ID", "Reference", "Key", "Token", "Index",
    "Status", "State", "Condition", "Phase", "Stage", "Level", "Grade", "Rank",
    "Customer", "Client", "Account", "Partner", "Vendor", "Supplier", "Dealer", "Reseller",
    "Invoice", "Receipt", "Bill", "Statement", "Record", "Transaction", "Payment", "Settlement",
    "Product", "Service", "Item", "Goods", "Solution", "Package", "Bundle", "Offer",
    "Contract", "Agreement", "Deal", "Proposal", "Quote", "Estimate", "Bid", "Tender",
    "Date", "Time", "Period", "Duration", "Term", "Cycle", "Schedule", "Timeline",
    "Type", "Category", "Class", "Group", "Segment", "Division", "Unit", "Department",
    "Source", "Origin", "Target", "Destination", "Route", "Path", "Channel", "Pipeline",
    "Metric", "Measure", "Indicator", "Score", "Rating", "Benchmark", "Standard", "Target",
    "Process", "Workflow", "Procedure", "Method", "Approach", "Technique", "Strategy", "Plan",
    "System", "Platform", "Application", "Module", "Component", "Interface", "Gateway", "Portal",
    "Data", "Information", "Content", "Document", "File", "Record", "Entry", "Log",
    "Quality", "Performance", "Efficiency", "Capacity", "Volume", "Size", "Scale", "Scope",
    "Risk", "Issue", "Problem", "Error", "Exception", "Alert", "Warning", "Notice",
    "Approval", "Review", "Audit", "Check", "Validation", "Verification", "Confirmation", "Authorization"
]

suffixes = ["__c"]

def generate_field_name():
    """Generate a random messy field name"""
    # Randomly choose 1-3 business terms
    num_terms = random.randint(1, 3)
    selected_terms = random.sample(business_terms, num_terms)
    field_name = "_".join(selected_terms) + random.choice(suffixes)
    return field_name

def create_field_xml(field_name, field_type="Text"):
    """Generate XML content for a Salesforce custom field"""
    if field_type == "Text":
        xml_content = f'''<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>{field_name}</fullName>
    <label>{field_name.replace('__c', '').replace('_', ' ').title()}</label>
    <type>Text</type>
    <length>255</length>
</CustomField>'''
    else:  # Currency
        xml_content = f'''<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>{field_name}</fullName>
    <label>{field_name.replace('__c', '').replace('_', ' ').title()}</label>
    <type>Currency</type>
    <precision>18</precision>
    <scale>2</scale>
</CustomField>'''
    
    return xml_content

def main():
    # Create directory structure
    target_dir = Path("force-app/main/default/objects/Opportunity/fields")
    target_dir.mkdir(parents=True, exist_ok=True)
    
    print(f"Creating 150 Custom Field XML files in: {target_dir}")
    
    # Generate field names
    field_names = set()
    
    # Ensure Client_Total_Invoice_Value__c is included
    field_names.add("Client_Total_Invoice_Value__c")
    
    # Generate remaining field names
    while len(field_names) < 150:
        field_name = generate_field_name()
        field_names.add(field_name)
    
    # Convert to list and shuffle
    field_names = list(field_names)
    random.shuffle(field_names)
    
    # Create XML files
    for i, field_name in enumerate(field_names, 1):
        # Randomly choose between Text and Currency (60% Text, 40% Currency for more variety)
        field_type = "Currency" if random.random() < 0.4 else "Text"
        
        xml_content = create_field_xml(field_name, field_type)
        
        # Create file
        file_path = target_dir / f"{field_name}.field-meta.xml"
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(xml_content)
        
        print(f"[{i:3d}/150] Created: {field_name} ({field_type})")
    
    print(f"\nSuccessfully generated {len(field_names)} Custom Field XML files!")
    print(f"Files saved in: {target_dir.absolute()}")
    
    # Show a few examples
    print("\nSample field names generated:")
    sample_fields = random.sample(field_names, min(10, len(field_names)))
    for field in sample_fields:
        print(f"  - {field}")

if __name__ == "__main__":
    main()
