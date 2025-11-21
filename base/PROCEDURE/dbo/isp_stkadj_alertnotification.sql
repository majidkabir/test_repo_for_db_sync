SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Proc : isp_StkAdj_AlertNotification                              */
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
/* Called By: Back-end job                                                 */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date        Author      Ver   Purposes                                  */
/* 29-Nov-2021 CSCHONg     1.1   Devops Scripts Combine                    */
/* 29-Nov-2021 CSCHONG     1.2   WMS-18401 revised field logic (CS01)      */
/***************************************************************************/

CREATE PROC [dbo].[isp_StkAdj_AlertNotification] 
  @cRecipientList NVARCHAR(max), 
  @cStartStorer   NVARCHAR(60) = '',
  @cEndStorer     NVARCHAR(60) = 'ZZZZZZZZZZ',
  @cStartFacility NVARCHAR(60) = '',
  @cEndFacility   NVARCHAR(60) = 'ZZZZZZZZZZ'
AS
BEGIN 
   DECLARE @tableHTML  NVARCHAR(MAX) ;

   DECLARE @cStartDate nvarchar(20), 
           @cEndDate   nvarchar(20)

   SET @cStartDate = Convert(nvarchar(20), GetDate(), 112)
   SET @cEndDate   = Convert(nvarchar(20), GetDate(), 112) + ' 23:59:59'

   IF EXISTS(SELECT 1 FROM AdjustmentDetail AD WITH (NOLOCK) 
             JOIN  LOC WITH (NOLOCK) ON AD.LOC = LOC.LOC 
             WHERE AD.EditDate Between @cStartDate and @cEndDate 
               AND AD.StorerKey Between @cStartStorer and @cEndStorer 
               AND LOC.Facility Between @cStartFacility and @cEndFacility 
               AND AD.FinalizedFlag = 'Y' )
   BEGIN
      SET @tableHTML = 
          N'<H1>Stock Adjustments Alert Notification</H1>' +
          N'<table border="1">' +
          N'<tr><th>Storer</th><th>Adjustment No</th>' +
          N'<th>Remarks</th><th>Reasons</th>' +
          N'<th>Variances(PC)</th>' +                     --(CS01)
          N'<th>Variances(CS)</th></tr>' +                --(CS01)
          CAST ( ( SELECT td = A.StorerKey, '', 
                          td = A.AdjustmentKey, '', 
                          td = ISNULL(A.Remarks,''), '', 
                          td = ISNULL(CL.Description,'No Reason'), '', 
                          td = SUM(AD.Qty), '',  
                          td = SUM(AD.Qty/NULLIF(CAST(p.casecnt AS INT),0))                   --(CS01)
                   FROM Adjustment A WITH (NOLOCK)
                   JOIN AdjustmentDetail AD WITH (NOLOCK) ON A.AdjustmentKey = AD.Adjustmentkey 
                   LEFT OUTER JOIN CODELKUP CL WITH (NOLOCK) ON CL.ListName = 'ADJREASON' AND
                         CL.Code = AD.ReasonCode
                   JOIN  LOC WITH (NOLOCK) ON AD.LOC = LOC.LOC 
                   JOIN PACK P WITH (NOLOCK) ON P.PackKey = AD.PackKey            --CS01
                   WHERE AD.EditDate Between @cStartDate and @cEndDate 
                     AND AD.StorerKey Between @cStartStorer and @cEndStorer 
                     AND LOC.Facility Between @cStartFacility and @cEndFacility 
                     AND AD.FinalizedFlag = 'Y'
                   GROUP BY A.StorerKey, A.AdjustmentKey,ISNULL(A.Remarks,''), ISNULL(CL.Description,'No Reason') 
                   ORDER BY 1, 2
            FOR XML PATH('tr'), TYPE 
          ) AS NVARCHAR(MAX) ) +
          N'</table>' ;


      EXEC msdb.dbo.sp_send_dbmail @recipients=@cRecipientList,
          @subject = 'Stock Adjustments Alert Notification',
          @body = @tableHTML,
          @body_format = 'HTML' ;
   END -- Records Exists
END -- Procedure

GO