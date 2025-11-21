SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: ispORD12                                           */  
/* Creation Date: 20-Oct-2020                                           */  
/* Copyright: LFL                                                       */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose: WMS-15758 - Update InvoiceNo = 'PC' if SOStatus = 'PENDCANC'*/     
/*                                                                      */  
/* Called By: isp_OrderTrigger_Wrapper from Orders Trigger              */  
/*                                                                      */  
/* GitLab Version: 1.0                                                  */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */    
/* Date         Author   Ver  Purposes                                  */   
/* 2021-09-22   mingle   1.1  WMS-17938 add new error message(ML01)     */  
/* 2021-10-14   Mingle   1.1  DevOps Combine Script                     */
/************************************************************************/  
  
CREATE PROC [dbo].[ispORD12]  
   @c_Action        NVARCHAR(10),  
   @c_Storerkey     NVARCHAR(15),    
   @b_Success       INT      OUTPUT,  
   @n_Err           INT      OUTPUT,   
   @c_ErrMsg        NVARCHAR(250) OUTPUT  
AS     
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF     
   SET ANSI_NULLS OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF    
       
   DECLARE @n_Continue        INT,  
           @n_StartTCnt       INT,  
           @c_Orderkey        NVARCHAR(10),  
           @c_CheckStatus     NVARCHAR(10) = ''  
                                                         
   SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1  
  
   IF @c_Action NOT IN('INSERT','UPDATE','DELETE')  
      GOTO QUIT_SP        
  
   IF OBJECT_ID('tempdb..#INSERTED') IS NULL OR OBJECT_ID('tempdb..#DELETED') IS NULL  
   BEGIN  
      GOTO QUIT_SP  
   END     
  
   SELECT @c_Orderkey = I.OrderKey  
   FROM #INSERTED I  
   WHERE I.Storerkey = @c_Storerkey  
     
   SET @c_CheckStatus = 'PENDCANC'  
     
   BEGIN TRAN  
     
   IF @c_Action IN ('UPDATE')   
   BEGIN  
    --Update InvoiceNo = 'PC' if SOStatus = 'PENDCANC'  
    IF EXISTS ( SELECT 1  
                  FROM #INSERTED I  
                  WHERE I.Storerkey = @c_Storerkey  
                  AND I.SOStatus = @c_CheckStatus  
                  AND I.Orderkey = @c_Orderkey )  
    BEGIN   
         UPDATE ORDERS WITH (ROWLOCK)  
         SET InvoiceNo = N'PC'  
         WHERE OrderKey = @c_Orderkey  
         
       SELECT @n_err = @@ERROR  
         
       IF @n_err <> 0  
       BEGIN  
            SET @n_continue = 3      
            SET @n_err = 63900-- Should Be Set To The SQL Errmessage but I don't know how to do so.   
            SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Failed to UPDATE ORDERS table. (ispORD12)'     
         END  
      END      
   END  
     
   IF @c_Action IN ('UPDATE')   
   BEGIN  
    --Update InvoiceNo = 'PC' if SOStatus = 'PENDCANC'  
    IF EXISTS ( SELECT 1  
                  FROM #INSERTED I  
                  JOIN #DELETED D ON I.Orderkey = D.Orderkey  
                  AND I.Storerkey = @c_Storerkey  
                  AND I.Orderkey = D.Orderkey  
                  AND I.SOStatus = @c_CheckStatus  
                  AND I.SOStatus <> D.SOStatus  
                  AND I.Orderkey = @c_Orderkey )  
    BEGIN   
         UPDATE ORDERS WITH (ROWLOCK)  
         SET InvoiceNo = N'PC'  
         WHERE OrderKey = @c_Orderkey
         
   SELECT @n_err = @@ERROR  
         
       IF @n_err <> 0  
       BEGIN  
            SET @n_continue = 3      
            SET @n_err = 63905-- Should Be Set To The SQL Errmessage but I don't know how to do so.   
            SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Failed to UPDATE ORDERS table. (ispORD12)'     
         END  
      END      
      ELSE  
      BEGIN   
       IF EXISTS ( SELECT 1  
                  FROM #INSERTED I  
                  JOIN #DELETED D ON I.Orderkey = D.Orderkey  
                  AND I.Storerkey = @c_Storerkey  
                  AND I.Orderkey = D.Orderkey  
                  AND D.SOStatus = @c_CheckStatus  
                  AND I.SOStatus <> D.SOStatus  
                  AND I.Orderkey = @c_Orderkey )  
       BEGIN   
            UPDATE ORDERS WITH (ROWLOCK)  
            SET InvoiceNo = N''  
            WHERE OrderKey = @c_Orderkey  
            
          SELECT @n_err = @@ERROR  
            
          IF @n_err <> 0  
          BEGIN  
               SET @n_continue = 3      
               SET @n_err = 63910-- Should Be Set To The SQL Errmessage but I don't know how to do so.   
               SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Failed to UPDATE ORDERS table. (ispORD12)'     
          END  
       END  
      END  

      
        
      --Block SOStatus update to CANC if InvoiceNo is blank  
      IF EXISTS ( SELECT 1  
                  FROM #INSERTED I  
                  JOIN #DELETED D ON I.Orderkey = D.Orderkey  
                  AND I.Storerkey = @c_Storerkey  
                  AND I.Orderkey = D.Orderkey  
                  AND I.InvoiceNo = ''  
                  AND I.SOStatus = 'CANC'  
                  AND I.SOStatus <> D.SOStatus  
                  AND I.Orderkey = @c_Orderkey )  
    BEGIN   
         SET @n_continue = 3      
         SET @n_err = 63915-- Should Be Set To The SQL Errmessage but I don't know how to do so.   
         SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Cannot Update SOStatus to CANC due to InvoiceNo is blank. (ispORD12)'     
      END            
  
  
   --START(ML01)  
   --Block SOStatus update to CANC if Status and openqty <> '0'   
      IF EXISTS ( SELECT 1  
                  FROM #INSERTED I  
                  JOIN #DELETED D ON I.Orderkey = D.Orderkey  
                  AND I.Storerkey = @c_Storerkey  
                  AND I.Orderkey = D.Orderkey  
                  --AND I.Status = 0  
                  AND I.Openqty <> 0 
                  AND I.SOStatus = 'CANC'  
                  AND I.SOStatus <> D.SOStatus  
                  AND I.Orderkey = @c_Orderkey )  
    BEGIN   
         SET @n_continue = 3      
         SET @n_err = 63920-- Should Be Set To The SQL Errmessage but I don't know how to do so.   
         SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Cannot Update SOStatus to CANC due to Status and Openqty not equal to 0 . (ispORD12)'     
      END            
   END  
   --END(ML01)  
                  
QUIT_SP:  
   IF @n_Continue=3  -- Error Occured - Process AND Return  
   BEGIN  
      SELECT @b_Success = 0  
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
      EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispORD12'    
      --RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE  
   BEGIN  
      SELECT @b_Success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN  
   END    
END   

GO