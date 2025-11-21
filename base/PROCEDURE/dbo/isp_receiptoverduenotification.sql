SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Stored Proc : isp_ReceiptOverdueNotification                           	*/
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

CREATE PROC [dbo].[isp_ReceiptOverdueNotification] 
  @cRecipientList NVARCHAR(max) = 'wantoh.shong@idsgroup.com' 
AS
BEGIN 
   SET NOCOUNT ON;

   DECLARE @tableHTML1  NVARCHAR(MAX) ;
   DECLARE @tableHTML2  NVARCHAR(MAX) ;

   DECLARE @cStartDate nvarchar(20), 
           @cEndDate   nvarchar(20)

   SET @cStartDate = Convert(nvarchar(20), GetDate(), 112)
   SET @cEndDate   = Convert(nvarchar(20), GetDate(), 112) + ' 23:59:59'

   DECLARE @t_Header Table (
      Ageing            NVARCHAR(60),
      NoOfReceipts      int, 
      NoOfLines         int,
      UnitsExpected     int,
      UnitsNotFinalized int)

   DECLARE @t_Detail Table (
      ReceiptKey        NVARCHAR(10),
      ExternPOKey       NVARCHAR(20), 
      Days              int, 
      SKU               Int,
      UnitExpected      int, 
      UnitNotFinalise   int )

   INSERT INTO @t_Header (Ageing, NoOfReceipts, NoOfLines, UnitsExpected, UnitsNotFinalized) 
   SELECT 
      CASE WHEN R.EffectiveDate > GetDate() THEN 'Advance' 
           WHEN DATEDIFF(hour, R.EffectiveDate, getdate()) > 48 THEN '48++ Hours'
           WHEN DATEDIFF(hour, R.EffectiveDate, getdate()) > 24 THEN '24++ Hours'
           WHEN DATEDIFF(hour, R.EffectiveDate, getdate()) > 12 THEN '12++ Hours' 
           WHEN DATEDIFF(hour, R.EffectiveDate, getdate()) <= 12 
               THEN RIGHT('0' + Cast(DATEDIFF(hour, R.EffectiveDate, getdate()) as NVARCHAR(2)),2) + ' Hours' 
      END 'Ageing', 
      COUNT(DISTINCT R.ReceiptKey) AS NoOfReceipts, 
      COUNT(1) AS NoOfLines, 
      SUM(QtyExpected) AS UnitsExpected, 
      SUM(RD.BeforeReceivedQty) As UnitsNotFinalized 
   FROM RECEIPT R (NOLOCK) 
   JOIN RECEIPTDETAIL RD (NOLOCK) ON R.REceiptKey = RD.ReceiptKey 
   WHERE ASNStatus NOT IN ('9', 'CANC') 
   AND   R.EffectiveDate < GETDATE() 
   AND   RD.QtyReceived = 0 
   AND   DATEDIFF(hour, R.EffectiveDate, getdate()) > 24 
   GROUP BY 
   CASE WHEN R.EffectiveDate > GetDate() THEN 'Advance' 
        WHEN DATEDIFF(hour, R.EffectiveDate, getdate()) > 48 THEN '48++ Hours' 
        WHEN DATEDIFF(hour, R.EffectiveDate, getdate()) > 24 THEN '24++ Hours'
        WHEN DATEDIFF(hour, R.EffectiveDate, getdate()) > 12 THEN '12++ Hours' 
        WHEN DATEDIFF(hour, R.EffectiveDate, getdate()) <= 12 
             THEN RIGHT('0' + Cast(DATEDIFF(hour, R.EffectiveDate, getdate()) as NVARCHAR(2)),2) + ' Hours' 
   END

   INSERT INTO  @t_Detail (ReceiptKey, ExternPOKey, Days, SKU, UnitExpected, UnitNotFinalise) 
   SELECT RD.ReceiptKey, PO.ExternPOKey, DateDiff(day,R.EffectiveDate, GetDate()), 
          COUNT(DISTINCT SKU), SUM(QtyExpected), SUM(BeforeReceivedQty)
   FROM   RECEIPTDETAIL RD WITH (NOLOCK) 
   JOIN   PO WITH (NOLOCK) ON PO.POkey = RD.POKey  
   JOIN   RECEIPT R (NOLOCK) ON R.REceiptKey = RD.ReceiptKey  
   WHERE ASNStatus NOT IN ('9', 'CANC') 
   AND   R.EffectiveDate < GETDATE() 
   AND   RD.QtyReceived = 0 
   AND   DATEDIFF(hour, R.EffectiveDate, getdate()) > 24
   GROUP BY RD.ReceiptKey, PO.ExternPOKey, DateDiff(day,R.EffectiveDate, GetDate()) 


   IF EXISTS(SELECT 1 FROM @t_Header)
   BEGIN
      SET @tableHTML1 = 
          N'<font size="-20">' + 
          N'<H2>Outstanding Receipt Notification</H2>' +
          N'<table border="1">' +
          N'<tr><th>Ageing</th><th>No Of Receipts</th>' +
          N'<th>Total Lines</th><th>Expected Qty</th>' +
          N'<th>Not Finalize Qty</th></tr>' +
          CAST ( ( SELECT td = Ageing, '', 
                          td = NoOfReceipts, '', 
                          td = NoOfLines, '', 
                          td = UnitsExpected, '', 
                          td = UnitsNotFinalized   
                   FROM @t_Header 
            FOR XML PATH('tr'), TYPE 
          ) AS NVARCHAR(MAX) ) +
          N'</table>' ;

      SET @tableHTML2 = 
          N'<H3>Details</H3>' +
          N'<table border="1">' +
          N'<tr><th>ReceiptKey</th><th>Customer POKey</th>' +
          N'<th>ETA Overdue (Days)</th><th>No of SKUs</th>' +
          N'<th>Expected Qty</th><th>Not Finalize Qty</th></tr>' +
          CAST ( ( SELECT td = ReceiptKey, '', 
                          td = ExternPOKey, '', 
                          td = Days, '', 
                          td = SKU, '', 
                          td = UnitExpected, '', 
                          td = UnitNotFinalise    
                   FROM @t_Detail 
            FOR XML PATH('tr'), TYPE 
          ) AS NVARCHAR(MAX) ) +
          N'</table>' ;

      SET @tableHTML1 = @tableHTML1 + master.dbo.fnc_GetCharASCII(13) + @tableHTML2

      EXEC msdb.dbo.sp_send_dbmail @recipients=@cRecipientList,
          @subject = 'Outstanding Receipt Notification',
          @body = @tableHTML1, 
          @body_format = 'HTML' ;

   END -- Records Exists
END -- Procedure

GO