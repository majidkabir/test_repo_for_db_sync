SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/  
/* Stored Procedure: ispPOKIT03                                            */  
/* Creation Date: 13-Jun-2017                                              */  
/* Copyright: LFL                                                          */  
/* Written by:                                                             */  
/*                                                                         */  
/* Purpose: WMS-2134 CN BeamSuntory finalize kit update workorder status   */                                 
/*                                                                         */  
/* Called By:                                                              */  
/*                                                                         */  
/*                                                                         */  
/* PVCS Version: 1.0                                                       */  
/*                                                                         */  
/* Version: 5.4                                                            */  
/*                                                                         */  
/* Data Modifications:                                                     */  
/*                                                                         */  
/* Updates:                                                                */  
/* Date       Ver  Author   Purposes                                       */  
/***************************************************************************/    
CREATE PROC [dbo].[ispPOKIT03]    
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
         , @c_Storerkey          NVARCHAR(15)
         , @c_WorkOrderkey       NVARCHAR(10)
 
   SET @b_Success= 1   
   SET @n_Err    = 0    
   SET @c_ErrMsg = ''   
   SET @n_Continue = 1    
   SET @n_StartTCount = @@TRANCOUNT    

   SELECT @c_WorkOrderkey = WO.WorkOrderKey,
          @c_Storerkey = KIT.Storerkey
   FROM KIT (NOLOCK)
   JOIN WORKORDER WO (NOLOCK) ON KIT.ExternKitkey = WO.WorkOrderKey AND KIT.Storerkey = WO.Storerkey
   WHERE KIT.Kitkey = @c_KitKey
   
   IF ISNULL(@c_WorkOrderkey,'') = ''
   BEGIN
   	  GOTO QUIT_SP
   END
   
   IF EXISTS(SELECT 1
             FROM KIT (NOLOCK)
             JOIN WORKORDER WO (NOLOCK) ON KIT.ExternKitkey = WO.WorkOrderKey AND KIT.Storerkey = WO.Storerkey
             WHERE KIT.Kitkey <> @c_KitKey
             AND KIT.ExternKitkey = @c_WorkOrderkey
             AND KIT.Storerkey = @c_Storerkey
             AND KIT.Status <> '9')
   BEGIN
   	 GOTO QUIT_SP
   END
   
   UPDATE WORKORDER WITH (ROWLOCK)
   SET Status = '9'
   WHERE WorkorderKey = @c_WorkOrderkey
    
   SET @n_err = @@ERROR     

   IF @n_err <> 0      
   BEGIN    
      SET @n_continue = 3      
      SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
      SET @n_err = 83010  -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update WorkOrder Failed. (ispPOKIT03)'   
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
      Execute nsp_logerror @n_err, @c_errmsg, 'ispPOKIT03'  
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