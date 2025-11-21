SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/  
/* Stored Procedure: ispPRKIT03                                            */  
/* Creation Date: 14-MAY-2019                                              */  
/* Copyright: LFL                                                          */  
/* Written by:CSCHONG                                                      */  
/*                                                                         */  
/* Purpose: WMS-8981-SG - CPV û Kitting Finalize RCM                       */                                 
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
CREATE PROC [dbo].[ispPRKIT03]    
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
    
   DECLARE @b_Debug              INT  
         , @n_Continue           INT   
         , @n_StartTCount        INT
         , @c_KDKitKey           NVARCHAR(10)
         , @c_StorerKey          NVARCHAR(10)
		 , @c_KDLOT              NVARCHAR(10)
		 , @c_KDLOC              NVARCHAR(10)
		 , @c_KSKU               NVARCHAR(20)
		 , @n_KQty               INT
		 , @n_ReplnQty           INT
		 , @n_MQty               INT
		 , @c_KExternKitKey      NVARCHAR(20)
		 , @c_KDExternKitKey     NVARCHAR(20)
		 , @d_lottable04         DATETIME
		 , @d_lottable05         DATETIME         
   
   SET @b_Success= 1   
   SET @n_Err    = 0    
   SET @c_ErrMsg = ''  
 
   SET @b_Debug  = 1
   SET @n_Continue = 1    
   SET @n_StartTCount = @@TRANCOUNT 
   
   DECLARE CUR_KDloop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT Storerkey,Kitkey,ExternKitkey,SKU,lot,loc,Qty   
   FROM   KITDETAIL KD WITH (NOLOCK) 
   WHERE  KITKEY = @c_KitKey
  
   OPEN CUR_KDloop   
     
   FETCH NEXT FROM CUR_KDloop INTO @c_StorerKey,@c_KDKitKey,@c_KDExternKitKey, @c_KSKU,@c_KDLOT,@c_KDLOC, @n_KQty
     
   WHILE @@FETCH_STATUS <> -1  
   BEGIN   
   
   SET @d_lottable04 = NULL
   SET @d_lottable05 = NULL

   SELECT @d_lottable04 = LOTT.lottable04
         ,@d_lottable05 = LOTT.lottable05
   FROM lotattribute LOTT WITH (NOLOCK)
   WHERE LOTT.Storerkey = @c_StorerKey
   AND  LOTT.Lot = @c_KDLOT
   AND LOTT.SKU = @c_KSKU 

   SET @c_KExternKitKey = ''
   

   SELECT @c_KExternKitKey = ExternKitkey
   FROM KIT WITH (NOLOCK)
   WHERE Kitkey = @c_KDKitKey

  BEGIN TRAN

  UPDATE KITDETAIL WITH (ROWLOCK)
   SET ExternKitkey = CASE WHEN ISNULL(@c_KDExternKitKey,'') = '' THEN @c_KExternKitKey ELSE ExternKitkey END
     , Lottable04 = @d_lottable04
     , Lottable05 = @d_lottable05
   WHERE KitKey = @c_KitKey
   AND Type = 'F'
   AND lot = @c_KDLOT
   AND loc = @c_KDLOC
   AND Sku = @c_KSKU
      
   SET @n_err = @@ERROR     

   IF @n_err <> 0      
   BEGIN    
      SET @n_continue = 3      
      SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
      SET @n_err = 83012  -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update KITDETAIL Failed. (ispPRKIT03)'   
                   + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
      GOTO QUIT_SP    
   END 

   SET @n_ReplnQty = 0
   SET @n_MQty = 0

   SELECT @n_ReplnQty = QtyReplen
   FROM lotxlocxid WITH (ROWLOCK)
   WHERE lot = @c_KDLOT
   AND loc = @c_KDLOC
   AND sku = @c_KSKU

   SET @n_MQty =  @n_ReplnQty - @n_KQty

   IF @n_MQty < 0
   BEGIN
     SET @n_MQty = 0
   END

   UPDATE lotxlocxid WITH (ROWLOCK)
   SET QtyReplen = @n_MQty --QtyReplen - @n_KQty
      ,TrafficCop = NULL
   WHERE lot = @c_KDLOT
   AND loc = @c_KDLOC
   AND sku = @c_KSKU

   SET @n_err = @@ERROR     

   IF @n_err <> 0      
   BEGIN    
      SET @n_continue = 3      
      SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
      SET @n_err = 83013 -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update lotxlocxid Failed. (ispPRKIT03)'   
                   + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
      GOTO QUIT_SP    
   END 
 
   
   FETCH NEXT FROM CUR_KDloop INTO @c_StorerKey,@c_KDKitKey,@c_KDExternKitKey, @c_KSKU,@c_KDLOT,@c_KDLOC, @n_KQty
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
      Execute nsp_logerror @n_err, @c_errmsg, 'ispPRKIT03'  
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