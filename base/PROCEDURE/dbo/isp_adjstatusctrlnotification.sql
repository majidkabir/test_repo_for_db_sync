SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_AdjStatusCtrlNotification                      */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: Send Email Notification  (sos#236991)                       */
/*                                                                      */
/* Called By: SQL Job Secheduler                                        */ 
/*                                                                      */
/* Parameters:                                                          */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver. Purposes                                 */
/************************************************************************/

CREATE PROC [dbo].[isp_AdjStatusCtrlNotification] 
AS
BEGIN 
   DECLARE @n_ReturnCode      INT
         , @c_Subject         NVARCHAR(255)
         , @c_EmailBodyHeader NVARCHAR(255)
         , @c_TableHTML       NVARCHAR(MAX) 
         
   DECLARE @c_TableName       NVARCHAR(30)  
         , @c_TransmitlogKey  NVARCHAR(10)
         , @c_TransmitFlag    NVARCHAR(10)
         , @c_ListName        NVARCHAR(10)
         , @c_Storerkey       NVARCHAR(15)
         , @c_StatusFlag      NVARCHAR(10)
         , @c_StatusDesc      NVARCHAR(30)
         , @c_RecipientList   NVARCHAR(255)
         , @c_Userid          NVARCHAR(50)

   SET @n_ReturnCode      = 0
   SET @c_Subject         = ''
   SET @c_EmailBodyHeader = ''
   SET @c_TableHTML       = ''
   SET @c_TableName       = 'AdjStatusControl'
   SET @c_TransmitlogKey  = ''
   SET @c_TransmitFlag    = ''
   SET @c_ListName        = 'AdjApvMail'
   SET @c_Storerkey       = ''
   SET @c_StatusFlag      = 'N'
   SET @c_StatusDesc      = ''
   SET @c_RecipientList   = ''
   SET @c_Userid          = ''

   UPDATE TRANSMITLOG3 WITH (ROWLOCK)
   SET TransmitFlag = '1'
   WHERE TableName = @c_TableName
   AND   TransmitFlag = '0'

   IF EXISTS ( SELECT 1 
               FROM TRANSMITLOG3 WITH (NOLOCK)
               WHERE TableName = @c_TableName
               AND   TransmitFlag = '1')
   BEGIN
         SELECT AH.Storerkey
               ,AH.AdjustmentKey
               ,UserID = ISNULL(RTRIM(AH.UserDefine02),'')
               ,Remarks = ISNULL(RTRIM(AH.Remarks),'')
               ,Reason = ISNULL(RTRIM(CLR.Description),'No Reason')
               ,ReasonCode = ISNULL(RTRIM(AD.ReasonCode),'')
               ,Qty = SUM(ISNULL(AD.Qty,0))
               ,StatusFlag = ISNULL(RTRIM(CLF.Short),'')
               ,StatusDesc = ISNULL(RTRIM(CLF.Description),'')
               ,RecipientList = ISNULL(RTRIM(CLF.Long),'')
               ,TL3.TransmitLogKey
         INTO #Temp_EmailRecord
         FROM TRANSMITLOG3 TL3 WITH (NOLOCK)
         JOIN ADJUSTMENT  AH  WITH (NOLOCK) ON (TL3.Key1 = AH.AdjustmentKey)
                                            AND(TL3.Key3 = AH.Storerkey) 
         JOIN CODELKUP CLF WITH (NOLOCK) ON (CLF.ListName = @c_ListName)
                                         AND(CLF.Storerkey = AH.Storerkey)
                                         AND(CLF.Short = TL3.Key2)
         LEFT JOIN ADJUSTMENTDETAIL AD WITH (NOLOCK) ON (AH.AdjustmentKey = AD.AdjustmentKey) 
         LEFT JOIN LOC WITH (NOLOCK) ON AD.LOC = LOC.LOC 
         LEFT JOIN CODELKUP CLR WITH (NOLOCK) ON (CLR.ListName = 'ADJREASON')
                                              AND(CLR.Code = AD.ReasonCode)
         WHERE TL3.TableName = @c_TableName
         AND   TL3.TransmitFlag = '1'
         GROUP BY AH.Storerkey
               ,  AH.AdjustmentKey
               ,  ISNULL(RTRIM(AH.UserDefine02),'')
               ,  ISNULL(RTRIM(AH.Remarks),'')
               ,  ISNULL(RTRIM(CLR.Description),'No Reason')
               ,  ISNULL(RTRIM(AD.ReasonCode),'')
               ,  ISNULL(RTRIM(CLF.Short),'')
               ,  ISNULL(RTRIM(CLF.Description),'')
               ,  ISNULL(RTRIM(CLF.Long),'')
               ,  TL3.TransmitLogKey
   


      DECLARE C_EmailBatch CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT 
             Storerkey
            ,StatusFlag
            ,StatusDesc
            ,RecipientList
            ,UserID
      FROM #Temp_EmailRecord
      
      OPEN C_EmailBatch 
      FETCH NEXT FROM C_EmailBatch INTO @c_Storerkey, @c_StatusFlag, @c_StatusDesc, @c_RecipientList, @c_Userid
      

      WHILE (@@FETCH_STATUS <> -1) 
      BEGIN
         IF @c_StatusFlag = 'N' SET @c_StatusDesc = 'Created'
         IF @c_StatusFlag = 'S' SET @c_StatusDesc = 'Submitted'
         IF @c_StatusFlag = 'A' SET @c_StatusDesc = 'Approved' 
         IF @c_StatusFlag = 'R' SET @c_StatusDesc = 'Rejected' 
         IF @c_StatusFlag = 'Y' SET @c_StatusDesc = 'Finalized' 
         
         SET @c_subject = 'Stock Adjustments Alert Notification - ' + @c_StatusDesc + ' By ' + @c_Userid
         SET @c_EmailBodyHeader = @c_Storerkey + ' Adjustment '+ @c_StatusDesc + ' (' + @c_StatusDesc + ' By ' + @c_Userid + ')'
         IF @c_StatusFlag = 'R'
         BEGIN
            SET @c_tableHTML = 
                N'<H1>' + @c_EmailBodyHeader + '</H1>' +
                N'<table border="1">' +
                N'<tr><th>Adjustment No</th><th>Rejected Line</th>' +
                N'<th>Remarks</th><th>Reasons</th>' +
                N'<th>Variances</th></tr>' +
                CAST ( ( SELECT td = tmp.AdjustmentKey, '' 
                               ,td = AD.AdjustmentLineNumber, ''
                               ,td = tmp.Remarks, '' 
                               ,td = tmp.Reason, '' 
                               ,td = AD.Qty 
                         FROM #Temp_EmailRecord tmp
                         JOIN ADJUSTMENTDETAIL AD WITH (NOLOCK) ON (tmp.AdjustmentKey = AD.AdjustmentKey)
                                                          AND(tmp.ReasonCode = AD.ReasonCode)
                         WHERE tmp.Storerkey = @c_Storerkey
                           AND tmp.StatusFlag = @c_StatusFlag
                           AND tmp.RecipientList = @c_RecipientList 
                           AND tmp.UserID = @c_Userid
                           AND AD.FinalizedFlag = @c_StatusFlag
                         ORDER BY 1, 2
                  FOR XML PATH('tr'), TYPE 
                ) AS NVARCHAR(MAX) ) +
                N'</table>' ; 
         END
         ELSE
         BEGIN
            SET @c_tableHTML = 
                --N'<H1>Stock Adjustments Alert Notification</H1>' +
                N'<H1>' + @c_EmailBodyHeader + '</H1>' +
                N'<table border="1">' +
                N'<tr><th>Adjustment No</th>' +
                N'<th>Remarks</th><th>Reasons</th>' +
                N'<th>Variances</th></tr>' +
                CAST ( ( SELECT td = AdjustmentKey, '' 
                               ,td = Remarks, '' 
                               ,td = Reason, '' 
                               ,td = SUM(Qty)  

                         FROM #Temp_EmailRecord
                         WHERE Storerkey = @c_Storerkey
                           AND StatusFlag = @c_StatusFlag
                           AND RecipientList = @c_RecipientList 
                           AND UserID = @c_Userid
                         GROUP BY AdjustmentKey
                                 ,Remarks
                                 ,Reason
                         ORDER BY 1, 2
                  FOR XML PATH('tr'), TYPE 
                ) AS NVARCHAR(MAX) ) +
                N'</table>' ;
         END
         

         EXEC @n_ReturnCode = msdb.dbo.sp_send_dbmail @recipients=@c_RecipientList
                                                   ,  @subject=@c_Subject 
                                                   ,  @body=@c_tableHTML 
                                                   ,  @body_format='HTML';

         

         IF @n_ReturnCode = 0 
         BEGIN
            SET @c_TransmitFlag = '9'
         END 
         ELSE
         BEGIN 
            SET @c_TransmitFlag = '5'  
         END 

         DECLARE C_ProcessGroup CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT 
                TransmitlogKey
         FROM #Temp_EmailRecord
         WHERE StatusFlag = @c_StatusFlag
         AND RecipientList = @c_RecipientList 

         OPEN C_ProcessGroup 
         FETCH NEXT FROM C_ProcessGroup INTO @c_TransmitlogKey
         
         WHILE (@@FETCH_STATUS <> -1) 
         BEGIN
            UPDATE TRANSMITLOG3 WITH (ROWLOCK)
            SET   TransmitFlag = @c_TransmitFlag
            WHERE TransmitlogKey = @c_TransmitlogKey
            AND   TransmitFlag = '1'
            
            FETCH NEXT FROM C_ProcessGroup INTO @c_TransmitlogKey
         END
         CLOSE C_ProcessGroup
         DEALLOCATE C_ProcessGroup

         FETCH NEXT FROM C_EmailBatch INTO @c_Storerkey, @c_StatusFlag, @c_StatusDesc, @c_RecipientList, @c_Userid
         
      END
      CLOSE C_EmailBatch
      DEALLOCATE C_EmailBatch
   END
END -- Procedure

GO