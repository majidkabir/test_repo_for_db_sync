SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: isp_RCM_DI_IIC_SendNoticeToITF                     */  
/* Creation Date: 03-Sep-2021                                           */  
/* Copyright: LFL                                                       */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose: WMS-17856 - KR_IIC_DocInfo_RCM_ITFTrigger                   */  
/*                                                                      */  
/* Called By: DocInfo Dynamic RCM configure at listname 'RCMConfig'     */   
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
/* 03-Sep-2021  WLChooi   1.0   DevOps Combine Script                   */
/************************************************************************/  
  
CREATE PROCEDURE [dbo].[isp_RCM_DI_IIC_SendNoticeToITF]  
   @c_RecordID   NVARCHAR(50),     
   @b_success    INT            OUTPUT,  
   @n_Err        INT            OUTPUT,  
   @c_errmsg     NVARCHAR(250)  OUTPUT,  
   @c_code       NVARCHAR(30) = ''  
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
           @c_Key1      NVARCHAR(20),
           @c_Key2      NVARCHAR(20),
           @c_TableName NVARCHAR(50) = 'WSEXDIFIIC'
                
   SELECT @n_Continue = 1, @b_success = 1, @n_Starttcnt = @@TRANCOUNT, @c_errmsg = '', @n_Err = 0   
     
   SELECT TOP 1 @c_Storerkey = DIF.Storerkey
              , @c_Key1      = DIF.Key1
              , @c_Key2      = DIF.Key2
   FROM DocInfo DIF (NOLOCK)  
   WHERE DIF.RecordID = @c_RecordID      
  
   EXEC dbo.ispGenTransmitLog2
      @c_TableName     = @c_TableName
    , @c_Key1          = @c_Key2
    , @c_Key2          = @c_Key1
    , @c_Key3          = ''
    , @c_TransmitBatch = ''
    , @b_Success       = @b_Success OUTPUT
    , @n_Err           = @n_Err     OUTPUT
    , @c_errmsg        = @c_Errmsg  OUTPUT

   IF @n_Err <> 0  
   BEGIN  
      SELECT @n_Continue = 3  
      SELECT @c_Errmsg = CONVERT(char(250),@n_Err), @n_Err = 65050   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
      SELECT @c_Errmsg ='NSQL'+CONVERT(char(5), @n_Err)+': Failed to EXEC ispGenTransmitLog2. (isp_RCM_DI_IIC_SendNoticeToITF)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '  
   END 
   ELSE   --Triggered Successfully
   BEGIN
      UPDATE dbo.DocInfo
      SET DataType = 'read'
      WHERE RecordID = @c_RecordID

      SELECT @n_Err = @@ERROR

      IF @n_Err <> 0  
      BEGIN  
         SELECT @n_Continue = 3  
         SELECT @c_Errmsg = CONVERT(char(250),@n_Err), @n_Err = 65055   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_Errmsg ='NSQL'+CONVERT(char(5), @n_Err)+': Failed to UPDATE DocInfo Table. (isp_RCM_DI_IIC_SendNoticeToITF)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '  
      END 
   END
       
QUIT_SP:    
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
      EXECUTE nsp_logerror @n_Err, @c_errmsg, 'isp_RCM_DI_IIC_SendNoticeToITF'  
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