SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: isp_RCM_STP_IDSMED_TriggerITF                      */  
/* Creation Date: 03-Jan-2022                                           */  
/* Copyright: LFL                                                       */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose: WMS-18672 - IDSMED_Stock Take Sheet Parameter_RCM           */  
/*                                                                      */  
/* Called By: StockTakeSheetParameters Dynamic RCM configure at listname*/   
/*            'RCMConfig'                                               */
/*                                                                      */  
/* Parameters:                                                          */  
/*                                                                      */  
/* GitLab Version: 1.0                                                  */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver.  Purposes                                */ 
/* 03-Jan-2022  WLChooi   1.0   DevOps Combine Script                   */ 
/************************************************************************/  
  
CREATE PROCEDURE [dbo].[isp_RCM_STP_IDSMED_TriggerITF]  
   @c_StockTakeKey   NVARCHAR(50),     
   @b_success        INT            OUTPUT,  
   @n_Err            INT            OUTPUT,  
   @c_errmsg         NVARCHAR(250)  OUTPUT,  
   @c_code           NVARCHAR(30) = ''  
AS  
BEGIN   
   SET NOCOUNT ON  
   SET ANSI_DEFAULTS OFF    
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @n_Continue  INT,  
           @n_Cnt       INT,  
           @n_Starttcnt INT  
             
   DECLARE @c_Facility  NVARCHAR(5),  
           @c_Storerkey NVARCHAR(15),
           @c_TableName NVARCHAR(50),
           @n_SeqNo     BIGINT
                
   SELECT @n_Continue = 1, @b_success = 1, @n_Starttcnt = @@TRANCOUNT, @c_errmsg = '', @n_Err = 0   

   IF @n_Continue IN (1,2)
   BEGIN
      SELECT TOP 1 @c_Storerkey = STSP.Storerkey
      FROM StockTakeSheetParameters STSP WITH (NOLOCK)
      WHERE STSP.StockTakeKey = @c_StockTakeKey
      
      SELECT @c_TableName = ISNULL(CL.code2,'')
      FROM CODELKUP CL (NOLOCK)
      WHERE CL.LISTNAME = 'RCMConfig'
      AND CL.Code = @c_code
      AND CL.Storerkey = @c_Storerkey
      AND CL.UDF01 = 'StockTakeParm'
      AND CL.Long = 'isp_RCM_STP_IDSMED_TriggerITF'
      
      IF ISNULL(@c_TableName,'') = '' 
      BEGIN  
         SELECT @n_Continue = 3  
         SELECT @c_Errmsg = CONVERT(char(250),@n_Err), @n_Err = 65050   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_Errmsg ='NSQL'+CONVERT(char(5), @n_Err)+': TableName not set up in Codelkup.Code2. (isp_RCM_STP_IDSMED_TriggerITF)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '  
      END 
   END

   IF @n_Continue IN (1,2)
   BEGIN
      IF EXISTS (SELECT 1
                 FROM TRANSMITLOG3 TL3 (NOLOCK)
                 WHERE TL3.tablename = @c_TableName
                 AND TL3.key1 = @c_StockTakeKey
                 AND TL3.key2 = ''
                 AND TL3.key3 = @c_Storerkey)
      BEGIN
         UPDATE TRANSMITLOG3 WITH (ROWLOCK)
         SET TransmitFlag = '0'
         WHERE tablename = @c_TableName
         AND key1 = @c_StockTakeKey
         AND key2 = ''
         AND key3 = @c_Storerkey

         GOTO QUIT_SP
      END
   END 

   IF @n_Continue IN (1,2)
   BEGIN
      EXEC dbo.ispGenTransmitLog3
         @c_TableName     = @c_TableName
       , @c_Key1          = @c_StockTakeKey
       , @c_Key2          = ''
       , @c_Key3          = @c_Storerkey
       , @c_TransmitBatch = ''
       , @b_Success       = @b_Success OUTPUT
       , @n_Err           = @n_Err     OUTPUT
       , @c_errmsg        = @c_Errmsg  OUTPUT
      
      IF @n_Err <> 0  
      BEGIN  
         SELECT @n_Continue = 3  
         SELECT @c_Errmsg = CONVERT(char(250),@n_Err), @n_Err = 65050   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_Errmsg ='NSQL'+CONVERT(char(5), @n_Err)+': Failed to EXEC ispGenTransmitLog3. (isp_RCM_STP_IDSMED_TriggerITF)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '  
      END
   END 
  
QUIT_SP:    
   --INSERT INTO dbo.TraceInfo(TraceName, TimeIn, TimeOut, Step1, Step2, Step3, Step4, Col1, Col2, Col3, Col4)
   --SELECT 'isp_RCM_STP_IDSMED_TriggerITF', GETDATE(), GETDATE(), 'Storerkey', 'StockTakeKey', 'Code', 'TableName', @c_Storerkey, @c_StockTakeKey, @c_code, @c_TableName

   IF @n_Continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SELECT @b_success = 0  
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_Starttcnt  
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_Starttcnt  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
      EXECUTE nsp_logerror @n_Err, @c_errmsg, 'isp_RCM_STP_IDSMED_TriggerITF'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE  
   BEGIN  
      SELECT @b_success = 1  
      WHILE @@TRANCOUNT > @n_Starttcnt  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN  
   END      
END 

GO