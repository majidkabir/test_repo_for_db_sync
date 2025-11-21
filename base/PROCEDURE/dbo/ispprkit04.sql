SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/  
/* Stored Procedure: ispPRKIT04                                            */  
/* Creation Date: 22-SEP-2022                                              */  
/* Copyright: LFL                                                          */  
/* Written by:                                                             */  
/*                                                                         */  
/* Purpose: WMS-20808 CN Diageo pre-finalize kit Update tokitdetail        */                                 
/*                                                                         */  
/* Called By:                                                              */  
/*                                                                         */  
/*                                                                         */  
/* PVCS Version: 1.0                                                       */  
/*                                                                         */  
/* Version: 7.0                                                            */  
/*                                                                         */  
/* Data Modifications:                                                     */  
/*                                                                         */  
/* Updates:                                                                */  
/* Date       Ver  Author   Purposes                                       */  
/***************************************************************************/    
CREATE PROC [dbo].[ispPRKIT04]    
(     @c_Kitkey      NVARCHAR(10)     
  ,   @b_Success     INT           OUTPUT  
  ,   @n_Err         INT           OUTPUT  
  ,   @c_ErrMsg      NVARCHAR(255) OUTPUT     
)    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE @n_Continue           INT   
         , @n_StartTCount        INT
      
   SELECT @b_Success= 1, @n_Err = 0, @c_ErrMsg = '', @n_Continue = 1, @n_StartTCount = @@TRANCOUNT 
         
   UPDATE KITDETAIL WITH (ROWLOCK)
   SET KITDETAIL.Lottable08 = KIT.CustomerRefNo
   FROM KITDETAIL
   JOIN KIT (NOLOCK) ON KITDETAIL.Kitkey = KIT.Kitkey   
   WHERE KIT.Kitkey = @c_Kitkey
   AND KITDETAIL.Type = 'T'
 
   SET @n_err = @@ERROR     

   IF @n_err <> 0      
   BEGIN    
      SET @n_continue = 3      
      SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
      SET @n_err = 83010  -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update KITDETAIL Failed. (ispPRKIT04)'   
                   + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
   END 
          
   QUIT_SP:  
  
   IF @n_continue = 3  -- Error Occured - Process And Return  
   BEGIN  
      SET @b_success = 0  
  
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCount  
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_StartTCount  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
      Execute nsp_logerror @n_err, @c_errmsg, 'ispPRKIT04'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE  
   BEGIN  
      SET @b_success = 1  
      WHILE @@TRANCOUNT > @n_StartTCount  
      BEGIN  
         COMMIT TRAN  
      END   
  
      RETURN  
   END   
END 

GO