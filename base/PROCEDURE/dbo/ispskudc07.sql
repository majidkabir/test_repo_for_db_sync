SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: ispSKUDC07                                         */  
/* Creation Date: 27-08-2021                                            */  
/* Copyright: LFL                                                       */  
/* Written by: Wan01                                                    */  
/*                                                                      */  
/* Purpose: WMS-17772 - SG- PMI - Packing scan 2D barcode [CR] v1.0     */ 
/*                                                                      */  
/* Called By: isp_SKUDecode_Wrapper                                     */  
/*                                                                      */  
/* GitLab Version: 1.0                                                  */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver   Purposes                                  */  
/* 27-08-2021  Wan01    1.0   Created.                                  */  
/************************************************************************/   

CREATE PROCEDURE [dbo].[ispSKUDC07]
     @c_Storerkey        NVARCHAR(15)
   , @c_Sku              NVARCHAR(60)
   , @c_NewSku           NVARCHAR(30)      OUTPUT     
   , @c_Code01           NVARCHAR(60) = '' OUTPUT      
   , @c_Code02           NVARCHAR(60) = '' OUTPUT      
   , @c_Code03           NVARCHAR(60) = '' OUTPUT       
   , @b_Success          INT          = 1  OUTPUT
   , @n_Err              INT          = 0  OUTPUT 
   , @c_ErrMsg           NVARCHAR(250)= '' OUTPUT
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @n_Continue     INT = 1 
         , @n_StartTcnt    INT = @@TRANCOUNT        

   SET @c_SKU = RTRIM(@c_SKU)
   SET @c_Code01 = 'N'
   
   IF LEN(@c_SKU) <= 30
   BEGIN
      GOTO QUIT_SP
   END
   
   IF LEFT(@c_SKU, 2) NOT IN ('01')
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 85010
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': GTIN prefix is not 01. (ispSKUDC07)'
      GOTO QUIT_SP
   END
   
   SET @c_NewSku = SUBSTRING( @c_Sku, 3, 14) 

   IF LEFT(@c_NewSku,1) = '0'
   BEGIN
      SET @c_NewSku = RIGHT(@c_NewSku,13)
   END
   
   SET @c_Code01 = 'Y'     --2DBarcode
   
QUIT_SP:   
   IF @n_Continue=3  -- Error Occured - Process AND Return
   BEGIN
      SET @b_Success = 0
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
      EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispSKUDC07'    
      RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END  

END -- End Procedure

GO