**Installation Instructions for AcousticSelling Pipeline Analytics**

**Current Version: 1.0.0.1**

**Last Updated: 1/30/2025 11:37 AM**

1.  Installation URL: <https://login.salesforce.com/packaging/installPackage.apexp?p0=04tUR0000014QhhYAE>

    Select Admins Only

2.  Permission Set Assignment


    -   **AS Multithreading Report Admin**: Read/Write access to all custom fields; can run batch job to retroactively analyze Opportunities, can access AcousticSelling Report Setting Page
    -   **AS Multithreading Report User:** Read Access to Custom Fields and Reports
3.  For Admins: Type “AcousticSelling” into App Launcher and select AcousticSelling Report Settings.

    **Step 1** shows the default lookback window of 45 days. That means that any Opportunity Contact Role whose Contact completed an Activity with 45 days of the Close Date will be counted as Active. Activities are Events, Completed Tasks, and Emails.

    To change the default, go to Quick Find-\>Custom Metadata-\>N Days-\>Manage Records-\>Active Contact Window/Edit


    **Step 2** gives you the ability to backfill Active OCR counts from a historical date you choose. Pressing “Start Batch Job” initiates an asynchronous batch job which will vary in duration based on the number of Opportunities its processes. You can check status on the next page and will receive an email once complete.

    **Step 3** is to activate the Flows by going to Quick Find-\>Custom Metadata-\>Toggle Switch-\>Manage Records-\>Master/Edit and check both boxes.

4.  The **Opportunities with Contact Engagement** Report is in the AcousticSelling Pipeline Analysis Folder.

This report buckets Active Opportunity Contact Roles (“Active OCRs”) vs Opportunity Amount in order to find the optimal amount of Contact Engagement for Win Rates and deal size. Customize the bucket settings and conditional formatting to meet your business requirements.


5.  The **Pipeline Analytics Dashboard** is located in the AcousticSelling Pipeline Analytics Folder and contains the Opportunities with Contact Engagement report and is a great place to include your derivative reports. More pipeline metrics will be added in future updates.

