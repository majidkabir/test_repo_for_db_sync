SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: ispORD09                                           */  
/* Creation Date: 22-Jul-2019                                           */  
/* Copyright: LFL                                                       */  
/* Written by: Shong                                                    */  
/*                                                                      */  
/* Purpose: Update Print Flag back to N                                 */     
/*                                                                      */  
/* Called By: isp_OrderTrigger_Wrapper from Orders Trigger              */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 6.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */    
/* Date         Author   Ver  Purposes                                  */    
/************************************************************************/  
  
CREATE PROC [dbo].[ispORD09]     
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
           @c_Option1         NVARCHAR(50) = '',  
           @c_Option2         NVARCHAR(50) = '',  
           @c_Option3         NVARCHAR(50) = '',  
           @c_Option4         NVARCHAR(50) = '',  
           @c_Option5         NVARCHAR(4000) = '',  
           @c_Options         NVARCHAR(4000) = ''  
             
   SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1  
  
   IF @c_Action NOT IN('INSERT','UPDATE','DELETE')  
      GOTO QUIT_SP        
  
   IF OBJECT_ID('tempdb..#INSERTED') IS NULL  
   BEGIN  
      GOTO QUIT_SP  
   END  
  
   --IF(@n_Continue = 1 OR @n_Continue = 2)  
   --BEGIN  
   --   SELECT  @c_Option1 = ISNULL(Option1,'')  
   --          ,@c_Option2 = ISNULL(Option2,'')  
   --          ,@c_Option3 = ISNULL(Option3,'')  
   --          ,@c_Option4 = ISNULL(Option4,'')  
   --          ,@c_Option5 = ISNULL(Option5,'')  
   --   FROM STORERCONFIG (NOLOCK)  
   --   WHERE STORERKEY = @c_Storerkey AND CONFIGKEY = 'OrdersTrigger_SP'  
   --   AND SValue = 'ispORD09'   
  
   --   SELECT @c_Options = LTRIM(RTRIM(@c_Option1)) + ',' + LTRIM(RTRIM(@c_Option2)) + ',' + LTRIM(RTRIM(@c_Option3)) + ',' +   
   --                       LTRIM(RTRIM(@c_Option4)) + ',' + LTRIM(RTRIM(@c_Option5))    
   --END     
  
   IF @c_Action IN('UPDATE')  
   BEGIN      
      IF EXISTS(SELECT 1   
             FROM #DELETED D  
             JOIN ORDERS I (NOLOCK) ON D.OrderKey  = I.ORDERKEY  
               WHERE I.[Status] IN ('0','1')   
               AND  D.[Status] IN ('2','3','4','5','6','7','8')   
               AND  I.PrintFlag <> 'N')  
      BEGIN  
         UPDATE ORDERS  
         SET PrintFlag = 'N'  
            ,TrafficCop = NULL  
            ,ArchiveCop = NULL  
            ,EditDate = GETDATE()   
         FROM ORDERS  
         JOIN #DELETED D (NOLOCK) ON ORDERS.ORDERKEY = D.ORDERKEY  
         WHERE ORDERS.[Status] IN ('0','1')   
          AND  D.[Status] IN ('2','3','4','5','6','7','8')   
          AND  ORDERS.PrintFlag <> 'N'  
        
         IF @@ERROR <> 0   
         BEGIN   
            SELECT @n_Continue = 3  
            SELECT @n_Err = 38000  
            SELECT @c_ErrMsg = CONVERT(CHAR(5), @n_Err) + ': Error Update ORDERS Fail. (ispORD09)'   
            GOTO QUIT_SP   
         END   
      END        
  
   END              
                   
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
     EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispORD09'    
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