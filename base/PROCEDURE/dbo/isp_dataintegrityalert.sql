SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Stored Proc : isp_DataIntegrityAlert                           	      */
/* Creation Date:  21th May 2009                                           */
/* Copyright: IDS                                                          */
/* Written by: Shong                                                       */
/*                                                                         */
/* Purpose: Stock Adjustments Alert Notification - Email                   */
/*                                                                         */
/*                                                                         */
/* Usage:                                                                  */
/*                                                                         */
/* Local Variables:                                                        */
/*                                                                         */
/* Called By: Back-end job                                 	               */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date        Author      Ver   Purposes                                  */
/***************************************************************************/
CREATE PROC [dbo].[isp_DataIntegrityAlert] 
  @cRecipientList NVARCHAR(max) 
AS
BEGIN 
   SET NOCOUNT ON

   DECLARE @tableHTML    NVARCHAR(MAX) ;
   DECLARE @tableResult  NVARCHAR(MAX) ;
   DECLARE @emailSubject NVARCHAR(MAX) ;

   DECLARE @cLOT  NVARCHAR(10), 
           @cLOC  NVARCHAR(10), 
           @cID   NVARCHAR(18), 
           @nQty  int, 
           @A_QtyAllocated  int, 
           @A_QtyPicked     int, 
           @P_QtyAllocated  int, 
           @P_QtyPicked     int

   DELETE InvBalIntegrityTrace 
   WHERE  DateDiff(minute, AddDate, GetDate()) > 10

   IF OBJECT_ID('tempdb..#Alert') IS NOT NULL
      DROP TABLE #Alert
  
   CREATE TABLE #Alert (
	   [CheckType] [varchar](60) NULL,
	   [LOT] [varchar](10) NULL,
	   [LOC] [varchar](10) NULL,
	   [ID]  [varchar](18) NULL,
	   [A_Qty] [int] NULL,
	   [A_QtyAllocated] [int] NULL,
	   [A_QtyPicked] [int] NULL,
	   [B_Qty] [int] NULL,
	   [B_QtyAllocated] [int] NULL,
	   [B_QtyPicked] [int] NULL
   )

	SET @emailSubject = '(LOTxLOCxID Vs PickDetail Status) Data Integrity Notification for ' + @@servername

   DECLARE CUR_CHECK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT  A.LOT, A.LOC, A.ID, A.Qty, A.QtyAllocated, A.QtyPicked, P.QtyAllocated, P.QtyPicked 
   FROM    LOTxLOCxID A WITH (NOLOCK) 
   INNER JOIN (SELECT LOT, LOC, ID, 
                   SUM(CASE WHEN Status Between '0' and '4' THEN Qty ELSE 0 END) AS QtyAllocated, 
                   SUM(CASE WHEN Status Between '5' and '8' THEN Qty ELSE 0 END) AS QtyPicked
                   FROM PICKDETAIL WITH (NOLOCK) 
                   WHERE STATUS <> '9'
                   GROUP BY LOT, LOC, ID) AS P ON P.LOT = A.LOT AND P.LOC = A.LOC AND P.ID = A.ID 
   WHERE A.QtyAllocated <> P.QtyAllocated   
      OR A.QtyPicked <> P.QtyPicked

   OPEN CUR_CHECK

   FETCH NEXT FROM CUR_CHECK INTO @cLOT, @cLOC, @cID, @nQty, @A_QtyAllocated, @A_QtyPicked, @P_QtyAllocated, @P_QtyPicked

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF NOT EXISTS(SELECT 1 FROM [InvBalIntegrityTrace] 
                    WHERE CheckType = 'LOTxLOCxID vs PICKDETAIL'
                      AND LOT = @cLOT AND LOC = @cLOC AND ID = @cID)
      BEGIN
            INSERT INTO [dbo].[InvBalIntegrityTrace]
                       ([CheckType]
                       ,[LOT]
                       ,[LOC]
                       ,[ID]
                       ,[A_Qty]
                       ,[A_QtyAllocated]
                       ,[A_QtyPicked]
                       ,[B_Qty]
                       ,[B_QtyAllocated]
                       ,[B_QtyPicked]
                       ,[AddDate])
            VALUES
               ('LOTxLOCxID vs PICKDETAIL', @cLOT, @cLOC, @cID, @nQty, @A_QtyAllocated, @A_QtyPicked, 
                 @nQty, @P_QtyAllocated, @P_QtyPicked, GetDate())
      END
      ELSE
      BEGIN
         INSERT INTO #Alert 
                       ([CheckType]
                       ,[LOT]
                       ,[LOC]
                       ,[ID]
                       ,[A_Qty]
                       ,[A_QtyAllocated]
                       ,[A_QtyPicked]
                       ,[B_Qty]
                       ,[B_QtyAllocated]
                       ,[B_QtyPicked])         
         VALUES ('LOTxLOCxID vs PICKDETAIL', @cLOT, @cLOC, @cID, @nQty, @A_QtyAllocated, @A_QtyPicked, 
                 @nQty, @P_QtyAllocated, @P_QtyPicked)

         DELETE FROM [InvBalIntegrityTrace] 
         WHERE CheckType = 'LOTxLOCxID vs PICKDETAIL'
           AND LOT = @cLOT AND LOC = @cLOC AND ID = @cID
      END                

      FETCH NEXT FROM CUR_CHECK INTO @cLOT, @cLOC, @cID, @nQty, @A_QtyAllocated, @A_QtyPicked, @P_QtyAllocated, @P_QtyPicked
   END -- While
   CLOSE CUR_CHECK
   DEALLOCATE CUR_CHECK 

   IF EXISTS(SELECT 1 FROM #Alert )
   BEGIN
      SET @tableHTML = 
            N'<head> ' + 
            N'    <style type="text/css"> ' + 
            N'        .style1 ' + 
            N'        { ' + 
            N'            text-decoration: underline; ' + 
            N'        } ' + 
            N'        .style2 ' + 
            N'        { ' + 
            N'            font-size: x-small; ' + 
            N'        } ' + 
            N'        .style4 ' + 
            N'        { ' + 
            N'            font-family: Arial; ' + 
            N'            font-size: xx-small; ' + 
            N'            background-color: #C0C0C0; ' + 
            N'        } ' + 
            N'        .style5 ' + 
            N'        { ' + 
            N'            font-size: x-small; ' + 
            N'        } ' + 
            N'        .newStyle1 ' + 
            N'        { ' + 
            N'            border-style: groove; ' + 
            N'            border-width: thin; ' + 
            N'        } ' + 
            N'    </style> ' + 
            N'</head> ' + 
            N'<h4 class="style1">Inventory Table Data Validation Email Alert</h4> ' + 
            N'<p> ' + 
            N'    Checking the integrity between the LOTxLOCxID Table Qty Allocated and Qty Picked  ' + 
            N'    against the PickDetail Status. ' + 
            N'</p> ' + 
            N'<p> ' + 
            N'    Please contact GIT for data patching.</p> ' + 
            N'<table border="2"> ' + 
            N'<tr><th class="style4">LOT</th><th class="style4">LOC</th><th class="style4">ID</th> ' + 
            N'    <th class="style4">LOT Qty</th><th class="style4">LOT Qty Allocated</th> ' + 
            N'    <th class="style4">LOT Qty Picked</th><th class="style4">PDET Qty Allocated</th> ' + 
            N'    <th class="style4">PDET QtyPicked</th></tr> ' 

          SELECT @tableResult = 
          CAST ( ( SELECT td = A.LOT, '', 
                          td = A.LOC, '', 
                          td = A.ID, '', 
                          td = A.A_Qty, '', 
                          td = A.A_QtyAllocated, '',  
                          td = A.A_QtyPicked, '',    
                          td = A.B_QtyAllocated, '',  
                          td = A.B_QtyPicked, ''   
                   FROM #Alert A WITH (NOLOCK)
            FOR XML PATH('tr'), TYPE 
          ) AS NVARCHAR(MAX) ) +
          N'</table>' +
          N'<H4 class="style1">From WMS Global Team.</H4>';

      SET @tableResult = REPLACE(@tableResult, '<tr>', '<tr style="font-size: x-small">')
      SET @tableHTML = @tableHTML + @tableResult
      EXEC msdb.dbo.sp_send_dbmail @recipients=@cRecipientList,
          @subject = @emailSubject,
          @body = @tableHTML,
          @body_format = 'HTML' ;
   END -- Records Exists
END -- Procedure

GO