SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/  
/* Stored Procedure: ispPOKIT02                                            */  
/* Creation Date: 14-OCT-2014                                              */  
/* Copyright: IDS                                                          */  
/* Written by: YTWan                                                       */  
/*                                                                         */  
/* Purpose: SOS#321081 - Finalize Kit enhancement                          */                                 
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
CREATE PROC [dbo].[ispPOKIT02]    
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
  
   DECLARE @n_BOMQty             INT
         , @n_ParentSkuGrossWgt  FLOAT 
         , @n_ParentSkuStdCube   FLOAT 

         , @c_Storerkey          NVARCHAR(15)
         , @c_ParentSku          NVARCHAR(20)
 
   SET @b_Success= 1   
   SET @n_Err    = 0    
   SET @c_ErrMsg = ''  
 
   SET @b_Debug  = 1
   SET @n_Continue = 1    
   SET @n_StartTCount = @@TRANCOUNT    

   IF NOT EXISTS (SELECT 1 
                  FROM BILLOFMATERIAL BOM WITH (NOLOCK) 
                  JOIN KITDETAIL      KD  WITH (NOLOCK) ON  (BOM.Storerkey = KD.Storerkey)
                                                        AND (BOM.Sku = KD.Sku)  
                  WHERE KD.KitKey = @c_KitKey  
                  AND   KD.Type = 'F'
                  ) 
   BEGIN
      GOTO QUIT_SP
   END

   DECLARE CUR_PARENTSKU CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT BOM.Storerkey
         ,BOM.Sku
        -- ,SUM(BOM.Qty)
   FROM BILLOFMATERIAL BOM WITH (NOLOCK) 
   JOIN KITDETAIL      KD  WITH (NOLOCK) ON  (BOM.Storerkey = KD.Storerkey)
                                         AND (BOM.Sku = KD.Sku)  
   WHERE KD.KitKey = @c_KitKey
   AND   KD.Type = 'F'
   GROUP BY BOM.Storerkey
         ,  BOM.Sku

   OPEN CUR_PARENTSKU  
  
   FETCH NEXT FROM CUR_PARENTSKU INTO  @c_Storerkey       
                                    ,  @c_ParentSku             
                                   -- ,  @n_BOMQty             
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
      IF NOT EXISTS (SELECT 1 
                     FROM KITDETAIL      KD  WITH (NOLOCK) 
                     JOIN BILLOFMATERIAL BOM WITH (NOLOCK) ON  (KD.Storerkey = BOM.Storerkey)
                                                           AND (BOM.Sku = @c_ParentSku)     
                                                           AND (KD.Sku = BOM.ComponentSku)  
                     WHERE KD.KitKey = @c_KitKey  
                     AND   KD.Type = 'T'
                     ) 
      BEGIN
         GOTO QUIT_SP
      END

      SET @n_ParentSkuGrossWgt = 0
      SET @n_ParentSkuStdCube  = 0
      SELECT @n_ParentSkuGrossWgt = SKU.StdGrossWgt 
            ,@n_ParentSkuStdCube  = SKU.StdCube  
      FROM SKU WITH (NOLOCK) 
      WHERE SKU.Storerkey = @c_Storerkey 
      AND   SKU.Sku = @c_ParentSku

      IF @n_ParentSkuGrossWgt = 0.00 OR @n_ParentSkuStdCube = 0.00
      BEGIN 
         SET @n_Continue = 3
         SET @n_err      = 83005   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SET @c_ErrMsg   = 'Both Prepack Sku''s StdGrossWgt and StdCube are 0.00'
         GOTO QUIT_SP
      END 

      SELECT @n_BOMQty = SUM(Qty)
      FROM BILLOFMATERIAL WITH (NOLOCK) 
      WHERE Storerkey = @c_Storerkey
      AND Sku = @c_ParentSku
       
      UPDATE SKU WITH (ROWLOCK)
         SET StdGrossWgt = ROUND(@n_ParentSkuGrossWgt / @n_BOMQty,5)   -- Round to 5 decimal place
            ,StdCube    =  ROUND(@n_ParentSkuStdCube / @n_BOMQty,5)    -- Round to 5 decimal place
            ,Trafficcop = NULL
            ,EditDate   = GETDATE()
            ,EditWho    = SUSER_NAME()
      FROM SKU
      JOIN BILLOFMATERIAL BOM WITH (NOLOCK) ON  (SKU.Storerkey = BOM.Storerkey)
                                            AND (SKU.Sku = BOM.ComponentSku)  
      WHERE BOM.Storerkey = @c_Storerkey
      AND   BOM.sku = @c_ParentSku

      SET @n_err = @@ERROR     

      IF @n_err <> 0      
      BEGIN    
         SET @n_continue = 3      
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
         SET @n_err = 83010  -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update SKU Failed. (ispPOKIT02)'   
                      + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
         GOTO QUIT_SP    
      END  
 
      FETCH NEXT FROM CUR_PARENTSKU INTO  @c_Storerkey       
                                       ,  @c_ParentSku             
                                     --  ,  @n_BOMQty  
   END
   QUIT_SP:  
  
   IF CURSOR_STATUS('LOCAL' , 'CUR_PARENTSKU') in (0 , 1)  
   BEGIN  
      CLOSE CUR_PARENTSKU  
      DEALLOCATE CUR_PARENTSKU  
   END 

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
      Execute nsp_logerror @n_err, @c_errmsg, 'ispPOKIT02'  
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