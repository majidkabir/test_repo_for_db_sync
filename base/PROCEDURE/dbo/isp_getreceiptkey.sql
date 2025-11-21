SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/  
/* Stored Procedure:  isp_GetReceiptKey                                 */  
/* Creation Date:                                                       */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose:  Generate ReceiptKey                                        */  
/*                                                                      */  
/* 27-Oct-2018  TLTING     1.1  Replace GetKey with isp_GetReceiptKey   */
/*                              to reduce blocking                      */
/************************************************************************/ 
CREATE PROC [dbo].[isp_GetReceiptKey]     
(   @n_FieldLength  INT     
  , @c_ReceiptKey     NVARCHAR(10)  OUTPUT     
  , @b_Success      INT           OUTPUT  
  , @n_Err          INT           OUTPUT  
  , @c_ErrMsg       NVARCHAR(250) OUTPUT    
)    
AS    
BEGIN    
   SET NOCOUNT ON       
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF       
   SET CONCAT_NULL_YIELDS_NULL OFF      
    
   DECLARE @n_count     INT /* next key */    
   DECLARE @n_ncnt      int    
   DECLARE @n_starttcnt int /* Holds the current transaction count */    
   DECLARE @n_continue  int /* Continuation flag: 1=Continue, 2=failed but continue processsing, 3=failed do not continue processing, 4=successful but skip furthur processing */    
   DECLARE @n_cnt       int /* Variable to record if @@ROWCOUNT=0 after UPDATE */    
    
   SELECT  @n_starttcnt=@@TRANCOUNT, @n_continue=1, @b_success=0, @n_err=0, @c_errmsg=''    
    
   DECLARE @n_NewReceiptKey INT     
  
   BEGIN TRANSACTION    
    
   IF @n_FieldLength < 1 OR @n_FieldLength > 10     
      SET @n_FieldLength = 10    
    
   INSERT INTO ReceiptKey (AddDate) VALUES (GETDATE())    
   SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT, @n_NewReceiptKey = @@IDENTITY    
   IF @n_err <> 0    
   BEGIN    
     SELECT @n_continue = 3     
   END    
   SELECT @n_NewReceiptKey = @@IDENTITY    
  
   IF @n_continue = 1 OR @n_continue = 2    
   BEGIN    
 
      SELECT @c_ReceiptKey = RIGHT(Replicate('0',@n_FieldLength) + CAST(@n_NewReceiptKey As VARCHAR(10)), @n_FieldLength)     
   END    
   ELSE    
      SELECT @c_ReceiptKey = ''    
    
   
   IF @n_continue=3  -- Error Occured - Process And Return    
   BEGIN    
      SELECT @b_success = 0         
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt     
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_GetReceiptKey'    
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012     
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
END 

GO