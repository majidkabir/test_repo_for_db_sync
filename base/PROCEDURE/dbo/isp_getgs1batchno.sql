SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/ 
/* Object Name: isp_GetGS1BatchNo                                          */
/* Modification History:                                                   */  
/*                                                                         */  
/* Called By:  Exceed                                                      */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Date         Author    Ver.  Purposes                                   */
/* 05-Aug-2002            1.0   Initial revision                           */
/***************************************************************************/    
CREATE PROC [dbo].[isp_GetGS1BatchNo]   
(  
   @nFieldLength INT,   
   @cNewKey NVARCHAR(10) OUTPUT   
)  
AS  
BEGIN  
   SET NOCOUNT ON     
   SET QUOTED_IDENTIFIER OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF    
  
   DECLARE @n_count int     /* next key */  
   DECLARE @n_ncnt int  
   DECLARE @n_starttcnt int /* Holds the current transaction count */  
   DECLARE @n_continue int  /* Continuation flag: 1=Continue, 2=failed but continue processsing, 3=failed do not continue processing, 4=successful but skip furthur processing */  
   DECLARE @n_cnt int       /* Variable to record if @@ROWCOUNT=0 after UPDATE */  
   DECLARE @b_Success     int              
          ,@n_err         int              
          ,@c_errmsg      NVARCHAR(250)        
  
   SELECT  @n_starttcnt=@@TRANCOUNT, @n_continue=1, @b_success=0, @n_err=0, @c_errmsg=''  
  
   DECLARE @nNewBatchNo INT
   
   -- Temporary disable 
   SET @cNewKey = '00000'
   RETURN    
  
   BEGIN TRANSACTION  
   

  
   IF @nFieldLength < 1 OR @nFieldLength > 10   
      SET @nFieldLength = 10  
  
   INSERT INTO GS1BatchNo (AddDate) VALUES (GETDATE())  
   SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT, @nNewBatchNo = @@IDENTITY  
   IF @n_err <> 0  
   BEGIN  
     SELECT @n_continue = 3   
   END  
   --SELECT @nNewBatchNo = @@IDENTITY  
   
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
      IF @nNewBatchNo >= CAST(Replicate('9',@nFieldLength) AS INT)   
         TRUNCATE TABLE GS1BatchNo  
         SELECT @n_err = @@ERROR  
         IF @n_err <> 0  
         BEGIN  
           SELECT @n_continue = 3   
         END  
      ELSE   
      BEGIN  
         -- Only keep last BatchNo  
         DELETE GS1BatchNo WHERE BatchNo < @nNewBatchNo  
         SELECT @n_err = @@ERROR  
         IF @n_err <> 0  
         BEGIN  
           SELECT @n_continue = 3   
         END  
      END  
      SELECT @cNewKey = RIGHT(Replicate('0',@nFieldLength) + CAST(@nNewBatchNo As NVARCHAR(10)), @nFieldLength)   
   END  
   ELSE  
      SELECT @cNewKey = ''  
  
  
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'nspg_getkey'  
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