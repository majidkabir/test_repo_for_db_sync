SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Proc : isp_StkAdj_AlertNotification_PH                          */
/* Creation Date: 2020-08-18                                               */
/* Copyright: LFL                                                          */
/* Written by: WLChooi                                                     */
/*                                                                         */
/* Purpose: WMS-14758 - Stock Adjustments Alert Notification - Email for PH*/
/*        : Copy from - isp_StkAdj_AlertNotification                       */
/*                                                                         */
/* Usage:                                                                  */
/*                                                                         */
/* Local Variables:                                                        */
/*                                                                         */
/* Called By: Back-end job                                 	               */
/*                                                                         */
/* GitLab Version: 1.0                                                     */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date        Author      Ver   Purposes                                  */
/* 31-Mar-2022 NJOW01      1.0   WMS-19535 add facility column             */
/* 31-Mar-2022 NJOW01      1.0   DEVOPS combine script                     */
/***************************************************************************/

CREATE PROC [dbo].[isp_StkAdj_AlertNotification_PH] 
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
          N'<tr><th>Storer</th><th>Storer Name</th><th>Facility</th><th>Adjustment No</th>' +
          N'<th>Remarks</th><th>Reasons</th>' +
          N'<th>Variances</th></tr>' +
          CAST ( ( SELECT td = A.StorerKey, '', 
                          td = STORER.CustomerGroupCode, '',
                          td = A.Facility, '',
                          td = A.AdjustmentKey, '', 
                          td = A.Remarks, '', 
                          td = ISNULL(CL.Description,'No Reason'), '', 
                          td = SUM(Qty)   
                   FROM Adjustment A WITH (NOLOCK)
                   JOIN AdjustmentDetail AD WITH (NOLOCK) ON A.AdjustmentKey = AD.Adjustmentkey 
                   --LEFT OUTER JOIN CODELKUP CL WITH (NOLOCK) ON CL.ListName = 'ADJREASON' 
                   --                                         AND CL.Code = AD.ReasonCode
                   OUTER APPLY (SELECT TOP 1 CODELKUP.Description
                                FROM CODELKUP (NOLOCK)
                                WHERE CODELKUP.Listname = 'ADJREASON'
                                AND CODELKUP.Code = AD.ReasonCode
                                AND (CODELKUP.Storerkey = A.Storerkey OR CODELKUP.Storerkey = '') 
                                ORDER BY CASE WHEN ISNULL(CODELKUP.Storerkey,'') = '' THEN 2 ELSE 1 END) AS CL
                   JOIN LOC WITH (NOLOCK) ON AD.LOC = LOC.LOC 
                   JOIN STORER WITH (NOLOCK) ON STORER.Storerkey = A.Storerkey
                   WHERE AD.EditDate Between @cStartDate and @cEndDate 
                     AND AD.StorerKey Between @cStartStorer and @cEndStorer 
                     AND LOC.Facility Between @cStartFacility and @cEndFacility 
                     AND AD.FinalizedFlag = 'Y'
                   GROUP BY A.StorerKey, A.AdjustmentKey, A.Remarks, ISNULL(CL.Description,'No Reason'), STORER.CustomerGroupCode, A.Facility  
                   ORDER BY A.StorerKey, A.AdjustmentKey
            FOR XML PATH('tr'), TYPE 
          ) AS NVARCHAR(MAX) ) +
          N'</table>' ;

      EXEC msdb.dbo.sp_send_dbmail @recipients = @cRecipientList,
          @subject = 'Stock Adjustments Alert Notification',
          @body = @tableHTML,
          @body_format = 'HTML' ;
   END -- Records Exists
END -- Procedure

GO