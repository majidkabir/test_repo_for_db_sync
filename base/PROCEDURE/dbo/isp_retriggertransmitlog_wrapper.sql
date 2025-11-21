SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store Procedure:  isp_ReTriggerTransmitLog_Wrapper                   */  
/* Creation Date: 23-Jan-2020                                           */  
/* Copyright:                                                           */  
/* Written by: CSCHONG                                                  */  
/*                                                                      */  
/* Purpose:  Re-Trigger records for interface wrapper                   */  
/*                                                                      */  
/* Input Parameters:      @c_TableName                                  */  
/*                        @c_Key1                                       */  
/*                        @c_Key2                                       */  
/*                        @c_Key3                                       */  
/*                        @c_Storerkey                                  */  
/*                        @b_debug                                      */   
/*                                                                      */  
/* Usage:  Re-Trigger records into TransmitLog Table for interface.     */  
/*                                                                      */  
/* Called By:nep_w_transmitlog_maintenance                              */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver.   Purposes                               */  
/* DD-MMM-YYYY                                                          */  
/* 22-FEB-2021  CSCHONG   1.1    WMs-10009 resturcture scripts (CS01)   */
/************************************************************************/  
  
CREATE PROC  [dbo].[isp_ReTriggerTransmitLog_Wrapper]  
             @c_Key1           NVARCHAR(20)  
           , @c_Key2           NVARCHAR(30)     = ''  
           , @c_Key3           NVARCHAR(20)     = ''  
           , @c_TableName      NVARCHAR(30)     = ''  
           , @c_Storerkey      NVARCHAR(20)     = ''  
           , @b_Success        int       OUTPUT  
           , @n_err            int       OUTPUT  
           , @c_errmsg         NVARCHAR(250) OUTPUT  
           , @b_debug          int              = 0   
AS  
BEGIN  
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @n_continue        int   
         , @c_SPCode          NVARCHAR(50)  
         , @c_SQL             NVARCHAR(MAX)  
         , @c_ARchiveDB       NVARCHAR(50)  
         , @c_Country         NVARCHAR(10)  
         , @c_SourceDB        NVARCHAR(10)  
         , @n_StartTCnt       INT    
  
   SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT     
   SET @c_SPCode = ''  
   SET @c_ARchiveDB = ''  
   SET @c_Country = ''  
   SET @c_SourceDB = ''  
  
   --WHILE @@TRANCOUNT > 0     
   --BEGIN    
   --   COMMIT TRAN    
   --END   
  
   SELECT @c_ARchiveDB = RTRIM(NSQLVALUE)  
   FROM NSQLCONFIG (NOLOCK)  
   WHERE CONFIGKEY = 'ArchiveDBName'  
  
  
   SET @c_country = LEFT(@c_ARchiveDB,2)  
  
   --SET @c_SourceDB = @c_country + 'WMS'  
   SET @c_SourceDB = DB_NAME()   
      
    --CS01 START
   --SELECT @c_SPCode = ISNULL(long,'')  
   --FROM CODELKUP C WITH (NOLOCK)   
   --WHERE C.listname = 'ITFRTriger'  
   --AND C.Code = @c_TableName  
   --AND C.storerkey = @c_Storerkey  
   --AND Code2 = 'SP'  

 SELECT @c_SPCode = ISNULL(long,'')  
   FROM CODELKUP C WITH (NOLOCK)   
   WHERE C.listname = 'ITFRTriger'  
   AND C.Code = @c_TableName  
   AND storerkey = ''
   --AND C.storerkey = @c_Storerkey  
   --AND Code2 = 'SP'
  --CS01 END
   IF (ISNULL(@c_SPCode,'') = '')   
   BEGIN  
    --  IF @b_debug = 1   
     -- BEGIN  
       SELECT @n_Continue = 3    
       SET @n_err = 700000  
       SELECT @c_errmsg = 'Codelkup SP not been setup for @c_TableName = ' + ISNULL(@c_TableName,'')  + ' for storerkey : ' + @c_Storerkey + '(isp_ReTriggerTransmitLog_Wrapper)'  
     -- END   
      RETURN  
   END  
  
    SET @c_SQL = 'EXEC ' + @c_SPCode + ' @c_Key1,@c_Key2,@c_Key3, @c_TableName, @c_Storerkey,@c_ARchiveDB ,@c_SourceDB'    
                 + ',@b_Success OUTPUT, @n_Err OUTPUT, @c_errmsg OUTPUT '  
        
      EXEC sp_executesql @c_SQL   
         , N'@c_Key1 NVARCHAR(20),@c_Key2 NVARCHAR(30),@c_Key3 NVARCHAR(20),@c_TableName NVARCHAR(30), @c_Storerkey NVARCHAR(15)  
         , @c_ARchiveDB NVARCHAR(50), @c_SourceDB NVARCHAR(10), @b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_errmsg NVARCHAR(250) OUTPUT'   
         , @c_Key1  
         , @c_Key2  
         , @c_Key3  
         , @c_TableName  
         , @c_StorerKey  
         , @c_ARchiveDB  
         , @c_SourceDB   
         , @b_Success         OUTPUT                         
         , @n_Err             OUTPUT    
         , @c_errmsg          OUTPUT  
  
   IF @b_debug=1  
   BEGIN  
     SELECT @c_SPCode '@c_SPCode',@n_Err '@n_Err',@c_errmsg '@c_errmsg'  
   END  
  
   IF ISNULL(@n_Err,0) > 1  
   BEGIN  
      SELECT @n_Continue = 3   
      SET @n_err = 700001  
      SELECT @c_errmsg = @c_errmsg + '(isp_ReTriggerTransmitLog_Wrapper)'   
      GOTO QUIT_SP  
   END  
   
   WHILE @@TRANCOUNT < @n_StartTCnt        
   BEGIN        
      BEGIN TRAN        
   END            
  
  QUIT_SP:  
     
   IF @n_continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SET @b_success = 0  
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_StartTCnt  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
      execute nsp_logerror @n_err, @c_errmsg, 'isp_ReTriggerTransmitLog_Wrapper'  
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE  
   BEGIN  
      SET @b_success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN  
   END   
END -- procedure   


GO