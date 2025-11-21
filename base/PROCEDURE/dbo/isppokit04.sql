SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/  
/* Stored Procedure: ispPOKIT04                                            */  
/* Creation Date: 02-Aug-2018                                              */  
/* Copyright: LFL                                                          */  
/* Written by:                                                             */  
/*                                                                         */  
/* Purpose: WMS-5911 SG CPV post finalize adj update EXTERNLOTATTRIBUTE    */                                 
/*                                                                         */  
/* Called By: Storerconfig PostFinalizeKitSP                               */  
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
CREATE PROC [dbo].[ispPOKIT04]    
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
         , @c_Sku                NVARCHAR(20)
         , @c_ExternLot          NVARCHAR(60)
         , @dt_Lottable04        DATETIME
         , @c_Lottable07         NVARCHAR(30)
         , @c_Lottable08         NVARCHAR(30)
 
   SET @b_Success= 1   
   SET @n_Err    = 0    
   SET @c_ErrMsg = ''   
   SET @n_Continue = 1    
   SET @n_StartTCount = @@TRANCOUNT    

   IF @@TRANCOUNT = 0
      BEGIN TRAN
      	
   IF @n_continue IN(1,2)
   BEGIN
      DECLARE CUR_KIT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT DISTINCT KD.Storerkey, KD.Sku, KD.Lottable04, KD.Lottable07, KD.Lottable08
      FROM KIT (NOLOCK)
      JOIN KITDETAIL KD (NOLOCK) ON KIT.Kitkey = KD.KitKey
      WHERE KIT.KitKey = @c_Kitkey
      AND KD.Lottable07 <> '' 
      AND KD.Lottable07 IS NOT NULL
      AND KD.Type = 'T'
      
      OPEN CUR_KIT
      
      FETCH NEXT FROM CUR_KIT INTO @c_Storerkey, @c_Sku, @dt_Lottable04, @c_Lottable07, @c_Lottable08

      WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2)
      BEGIN      	
      	 SET @c_ExternLot = LTRIM(RTRIM(ISNULL(@c_Lottable07,''))) + LTRIM(RTRIM(ISNULL(@c_Lottable08,'')))
      	 
      	 IF NOT EXISTS (SELECT 1 
      	                FROM EXTERNLOTATTRIBUTE (NOLOCK) 
      	                WHERE Storerkey = @c_Storerkey
      	                AND Sku = @c_Sku
      	                AND ExternLot = @c_ExternLot)
      	 BEGIN
      	    INSERT INTO EXTERNLOTATTRIBUTE (Storerkey, Sku, ExternLot, ExternLottable04, ExternLotStatus)
      	    VALUES (@c_Storerkey, @c_Sku, @c_ExternLot, @dt_Lottable04, 'Active')
      	    
            SET @n_err = @@ERROR
            
            IF @n_err <> 0 
            BEGIN 
               SET @n_continue= 3 
               SET @n_err  = 72810
               SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Insert EXTERNLOTATTRIBUTE Table Failed. (ispPOADJ02)'
            END       	          	    
      	 END                     	                
      	                                   	 
         FETCH NEXT FROM CUR_KIT INTO @c_Storerkey, @c_Sku, @dt_Lottable04, @c_Lottable07, @c_Lottable08
      END
      CLOSE CUR_KIT
      DEALLOCATE CUR_KIT    
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
      Execute nsp_logerror @n_err, @c_errmsg, 'ispPOKIT04'  
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