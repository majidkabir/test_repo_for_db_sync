SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Stored Proc : isp_StkAdj_AlertNotification_CPV_V2                       */
/* Copyright: LFL                                                          */
/* Written by: Calvin Khor                                                 */
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
/* GitLab Version: 1.0                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date              Author         Ver      Purposes                      */
/* 19-Aug-2019       Calvin Khor    1.0      Requested for CPV by Edmund   */
/***************************************************************************/

CREATE PROC [dbo].[isp_StkAdj_AlertNotification_CPV_V2]
  @cRecipientList NVARCHAR(max)

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
               AND AD.StorerKey = 'CPV'
               AND AD.FinalizedFlag = 'Y' )
   BEGIN
      SET @tableHTML =
          N'<H1>Stock Adjustments Alert Notification - CPV - V2</H1>' +
          N'<table border="1">' +
          N'<tr><th>Adjustment Ticket</th><th>Adjustment Type</th>' +
          N'<th>Remarks</th><th>Adjustment Reason</th>' +
          N'<th>Editwho</th></tr>' +
          CAST ( ( SELECT td = A.AdjustmentKey, '',
                          td = CL1.Description, '',
                          td = A.Remarks, '',
                          td = CL2.DESCRIPTION, '',
                          td = AD.Editwho, ''
                   FROM Adjustment A WITH (NOLOCK)
                   JOIN AdjustmentDetail AD WITH (NOLOCK) ON A.AdjustmentKey = AD.Adjustmentkey
               LEFT JOIN CODELKUP CL1 WITH (NOLOCK) ON (A.ADJUSTMENTTYPE = CL1.CODE AND CL1.LISTNAME = 'ADJTYPE' AND CL1.STORERKEY = 'CPV')
               LEFT JOIN CODELKUP CL2 WITH (NOLOCK) ON (AD.REASONCODE = CL2.CODE AND CL2.LISTNAME = 'ADJREASON' AND CL2.STORERKEY = 'CPV')
                   LEFT OUTER JOIN CODELKUP CL WITH (NOLOCK) ON CL.ListName = 'ADJREASON' AND
                         CL.Code = AD.ReasonCode
                   JOIN  LOC WITH (NOLOCK) ON AD.LOC = LOC.LOC
                   WHERE AD.EditDate Between @cStartDate and @cEndDate
                     AND AD.StorerKey = 'CPV'
                     AND AD.FinalizedFlag = 'Y'
      GROUP BY A.AdjustmentKey, CL1.Description, CL2.Description, A.Remarks, AD.EDITWHO
                   ORDER BY A.AdjustmentKey
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