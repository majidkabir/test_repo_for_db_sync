SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: isp_MAST_AutoFinalizeADJ                              */
/* Creation Date: 02-Jun-2023                                              */
/* Copyright: MAERSK                                                       */
/* Written by: WLChooi                                                     */
/*                                                                         */
/* Purpose: WMS-22668 - CN MAST Exceed script for auto ship (ADJ)          */
/*                                                                         */
/* Called By: SQL Job                                                      */
/*                                                                         */
/* GitLab Version: 1.0                                                     */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 02-Jun-2023  WLChooi 1.0   DevOps Combine Script                        */
/***************************************************************************/  
CREATE   PROC [dbo].[isp_MAST_AutoFinalizeADJ]    
(
   @c_Storerkey     NVARCHAR(15) = '18455',
   @c_Recipients    NVARCHAR(2000) = '' --email address delimited by ;
)
AS  
BEGIN  	
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @b_Success            INT,
           @n_Err                INT,
           @c_ErrMsg             NVARCHAR(255),
           @n_Continue           INT,
           @n_StartTranCount     INT
   
   DECLARE @c_GetADJkey          NVARCHAR(10),
           @n_Cnt                INT,
           @b_debug              INT,
           @c_GetReason          NVARCHAR(500)

   DECLARE @c_Body         NVARCHAR(MAX),          
           @c_Subject      NVARCHAR(255),          
           @c_Date         NVARCHAR(20),           
           @c_SendEmail    NVARCHAR(1)

   DECLARE @c_Facility         NVARCHAR(5) = 'VSZTO'
         , @c_Type             NVARCHAR(10) = 'DP'
         , @c_Status           NVARCHAR(10) = 'N'
    
   SELECT @b_Success = 1, @n_Err = 0, @c_ErrMsg = '', @n_Continue = 1, @n_StartTranCount = @@TRANCOUNT
         
   IF @n_continue = 1 or @n_continue = 2
   BEGIN 
      CREATE TABLE #TMP_ADJ (  
         ADJkey   NVARCHAR(10)
      ) 
      
      CREATE TABLE #TMP_RESULT (  
         ADJkey     NVARCHAR(10)
       , Reason     NVARCHAR(255)
      ) 
           
   END

   INSERT INTO #TMP_ADJ (ADJkey)
   SELECT DISTINCT ADJ.AdjustmentKey
   FROM dbo.ADJUSTMENT ADJ (NOLOCK)
   WHERE ADJ.StorerKey = @c_Storerkey
   AND ADJ.FinalizedFlag = @c_Status
   AND ADJ.Facility = @c_Facility
   AND LEFT(ADJ.AdjustmentType,2) = @c_Type
   AND DATEDIFF(MINUTE, ADJ.AddDate, GETDATE()) >= 1

   DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT ADJkey
      FROM #TMP_ADJ

   OPEN CUR_LOOP

   FETCH NEXT FROM CUR_LOOP INTO @c_GetADJkey

   WHILE @@FETCH_STATUS <> -1 AND @n_Continue IN (1,2)
   BEGIN
      --Finalize Adjustment
      IF @n_Continue IN (1,2)
      BEGIN
         EXECUTE isp_FinalizeADJ
                  @c_ADJKey   = @c_GetADJkey
               ,  @b_Success  = @b_Success OUTPUT 
               ,  @n_err      = @n_err     OUTPUT 
               ,  @c_errmsg   = @c_errmsg  OUTPUT   
         
         IF @n_err <> 0  
         BEGIN
            INSERT INTO #TMP_RESULT (ADJkey, Reason)
            SELECT @c_GetADJkey, 'Execute isp_FinalizeADJ Failed'
               
            GOTO NEXT_LOOP
         END
         
         SET @n_Cnt = 0
         
         SELECT @n_Cnt = 1
         FROM ADJUSTMENTDETAIL WITH (NOLOCK)
         WHERE AdjustmentKey = @c_GetADJkey
         AND FinalizedFlag <> 'Y'
         
         IF @n_Cnt = 1
         BEGIN          
            UPDATE ADJUSTMENT WITH (ROWLOCK)
            SET FinalizedFlag = 'Y',
                TrafficCop = NULL,
                EditWho    = SUSER_SNAME(),
                EditDate   = GETDATE()
            WHERE AdjustmentKey = @c_GetADJkey
         
            IF @n_err <> 0  
            BEGIN 
               INSERT INTO #TMP_RESULT (ADJkey, Reason)
               SELECT @c_GetADJkey, 'Error Updating ADJUSTMENT'
               
               GOTO NEXT_LOOP
            END
         END
      END

      INSERT INTO #TMP_RESULT (ADJkey, Reason)
      SELECT @c_GetADJkey, 'Processed Successfully'

NEXT_LOOP:
      FETCH NEXT FROM CUR_LOOP INTO @c_GetADJkey
   END   --End Orders Loop
   CLOSE CUR_LOOP
   DEALLOCATE CUR_LOOP
   
   --SELECT * FROM #TMP_RESULT      
QUIT_SP:
   --Send alert by email
   IF EXISTS (SELECT 1 FROM #TMP_RESULT)
   BEGIN   	  
      SET @c_SendEmail = 'Y'                                                       
      SET @c_Date = CONVERT(NVARCHAR(10), GETDATE(), 103)  
      SET @c_Subject = TRIM(@c_Storerkey) + ' Auto Finalize Adjustment Alert - ' + @c_Date  
      
      SET @c_Body = '<style type="text/css">       
               p.a1  {  font-family: Arial; font-size: 12px;  }      
               table {  font-family: Arial; margin-left: 0em; border-collapse:collapse;}      
               table, td, th {padding:3px; font-size: 12px; }
               td { vertical-align: top}
               </style>'
   
      SET @c_Body = @c_Body + '<p>Dear All, </p>'  
      SET @c_Body = @c_Body + '<p>Please be informed that the Adjustmentkey below has been processed.</p>'  
      SET @c_Body = @c_Body + '<p>Kindly refer to the Remark for more info.</p>'  + CHAR(13)
         
      SET @c_Body = @c_Body + '<table border="1" cellspacing="0" cellpadding="5">'   
      SET @c_Body = @c_Body + '<tr bgcolor=silver><th>Adjustmentkey</th><th>Remark</th></tr>'  
      
      DECLARE CUR_EMAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                       
         SELECT T.ADJkey, T.Reason    
         FROM #TMP_RESULT T
         ORDER BY T.ADJkey
        
      OPEN CUR_EMAIL              
        
      FETCH NEXT FROM CUR_EMAIL INTO @c_GetADJkey, @c_GetReason   
        
      WHILE @@FETCH_STATUS <> -1       
      BEGIN  
         SET @c_Body = @c_Body + '<tr><td>' + RTRIM(@c_GetADJkey) + '</td>'  
         SET @c_Body = @c_Body + '<td>' + RTRIM(@c_GetReason) + '</td>'  
         SET @c_Body = @c_Body + '</tr>'  

         IF @c_GetReason <> 'Processed Successfully'
         BEGIN
            UPDATE dbo.ADJUSTMENT
            SET UserDefine10 = 'HOLD',
                TrafficCop = NULL,
                EditWho    = SUSER_SNAME(),
                EditDate   = GETDATE()
            WHERE AdjustmentKey = @c_GetADJkey
         END
                                            
         FETCH NEXT FROM CUR_EMAIL INTO @c_GetADJkey, @c_GetReason        
      END  
      CLOSE CUR_EMAIL              
      DEALLOCATE CUR_EMAIL           
      
      SET @c_Body = @c_Body + '</table>'  

      IF @b_debug = 1
      BEGIN 
         PRINT @c_Subject
         PRINT @c_Body
      END

      IF @c_SendEmail = 'Y' AND ISNULL(@c_Recipients,'') <> ''
      BEGIN           
         EXEC msdb.dbo.sp_send_dbmail   
               @recipients      = @c_Recipients,  
               @copy_recipients = NULL,  
               @subject         = @c_Subject,  
               @body            = @c_Body,  
               @body_format     = 'HTML' ;  
                 
         SET @n_Err = @@ERROR  
         
         IF @n_Err <> 0  
         BEGIN           
            UPDATE dbo.ADJUSTMENT
            SET UserDefine10 = 'EMAIL FAILED',
                TrafficCop = NULL,
                EditWho    = SUSER_SNAME(),
                EditDate   = GETDATE()
            WHERE AdjustmentKey = @c_GetADJkey
         END  
      END
   END

   IF OBJECT_ID('tempdb..#TMP_ADJ') IS NOT NULL
            DROP TABLE #TMP_ADJ

   IF OBJECT_ID('tempdb..#TMP_RESULT') IS NOT NULL
            DROP TABLE #TMP_RESULT

   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP') IN (0 , 1)
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP   
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_EMAIL') IN (0 , 1)
   BEGIN
      CLOSE CUR_EMAIL
      DEALLOCATE CUR_EMAIL   
   END
           
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTranCount
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_MAST_AutoFinalizeADJ'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012          
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTranCount  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN
   END 
END

GO