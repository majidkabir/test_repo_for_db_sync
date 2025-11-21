SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispGenDocStatusLog                                 */
/* Creation Date:                                                       */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Generate Orders Status, Receipt Status                      */   
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 02/05/2017   NJOW01   1.0  WMS-1742 allow config to disable logging  */
/*                            by tablename.                             */
/************************************************************************/

CREATE  PROC   [dbo].[ispGenDocStatusLog]  
               @c_TableName    NVARCHAR(30)  
,              @c_StorerKey    NVARCHAR(15)
,              @c_DocumentNo   NVARCHAR(20)  
,              @c_Key1         NVARCHAR(20)  
,              @c_Key2         NVARCHAR(20)  
,              @c_DocStatus    NVARCHAR(10)   
--,              @d_TransDate    Datetime
,              @b_Success      INT        OUTPUT  
,              @n_err          INT        OUTPUT  
,              @c_errmsg       NVARCHAR(250)  OUTPUT  
AS  
BEGIN
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @n_continue INT
          ,@n_starttcnt INT   -- Holds the current transaction count
          ,@c_preprocess NVARCHAR(250) -- preprocess
          ,@c_pstprocess NVARCHAR(250) -- post process
          ,@n_err2 INT -- For Additional Error Detection  
   
--   DECLARE @c_trmlogkey NVARCHAR(10)  
   
   SELECT @n_starttcnt = @@TRANCOUNT
         ,@n_continue = 1
         ,@b_success = 0
         ,@n_err = 0
         ,@c_errmsg = ""
         ,@n_err2 = 0 
   /* #INCLUDE <SPIAD1.SQL> */       
   
   IF RTrim(@c_DocumentNo) IS NULL OR RTrim(@c_DocumentNo) = ''
   BEGIN
      RETURN
   END  

   IF RTrim(@c_TableName) IS NULL OR RTrim(@c_TableName) = ''
   BEGIN
      RETURN
   END     
     
   SELECT @c_Key1 = ISNULL(RTrim(@c_Key1) ,'')  
   SELECT @c_Key2 = ISNULL(RTrim(@c_Key2) ,'')  
   SELECT @c_DocStatus = ISNULL(RTrim(@c_DocStatus) ,'')  
   SELECT @c_StorerKey = ISNULL(RTrim(@c_StorerKey) ,'')    
   
   --NJOW01  ORDERS = STSORDERS
   IF EXISTS(SELECT 1 FROM STORERCONFIG(NOLOCK) WHERE Storerkey = @c_Storerkey 
             AND Configkey = 'DisableDocStatusLog' AND Svalue = '1' AND 
             (Option1 = @c_TableName OR Option2 = @c_TableName OR Option3 = @c_TableName
              OR Option4 = @c_TableName OR Option5 = @c_TableName OR Option1 = 'ALL')
             )
   BEGIN
   	  SET @b_success = 1
   	  RETURN
   END
   
   IF @n_continue = 1
   OR @n_continue = 2
   BEGIN 
       IF NOT EXISTS (
              SELECT 1
              FROM   DocStatusTrack with (NOLOCK)
              WHERE  TableName = @c_TableName
              AND    DocumentNo = @c_DocumentNo
              AND    Key1 = @c_Key1
              AND    Key2 = @c_Key2
              AND    DocStatus = @c_DocStatus
          ) 
       BEGIN
                     
               INSERT INTO DocStatusTrack
                 ( StorerKey
                  ,tablename
                  ,DocumentNo
                  ,key1
                  ,key2
                  ,DocStatus
                  ,TransDate
                 )
               VALUES
                 (
                   @c_StorerKey
                  ,@c_TableName
                  ,@c_DocumentNo
                  ,@c_Key1
                  ,@c_Key2
                  ,@c_DocStatus
                  ,getdate()
                 )
           
         SET @n_err = @@ERROR  
  
         IF @n_err <> 0  
         BEGIN  
            SET @n_continue = 3  
            SET @n_err=62301   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Failed on DocStatusTrack. (ispGenDocStatusLog) ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
         END  
         
      END
   END
    /* #INCLUDE <SPIAD2.SQL> */  
    IF @n_continue = 3 -- Error Occured - Process And Return
    BEGIN
        SELECT @b_success = 0  
        IF @@TRANCOUNT = 1
        AND @@TRANCOUNT > @n_starttcnt
        BEGIN
            ROLLBACK TRAN
        END
        ELSE
        BEGIN
            WHILE @@TRANCOUNT > @n_starttcnt
            BEGIN
                COMMIT TRAN
            END
        END 
        EXECUTE nsp_logerror @n_err, @c_errmsg, "ispGenDocStatusLog" 
        RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012 
--        RAISERROR @n_err @c_errmsg 
        RETURN
    END
    ELSE
    BEGIN
        SELECT @b_success = 1  
        WHILE @@TRANCOUNT > @n_starttcnt
        BEGIN
            COMMIT TRAN
        END 
        RETURN
    END

END -- procedure   

GO