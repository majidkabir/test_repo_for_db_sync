SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: ispSKUDC06                                         */  
/* Creation Date: 27-Jan-2021                                           */  
/* Copyright: LFL                                                       */  
/* Written by: Wan01                                                    */  
/*                                                                      */  
/* Purpose: WMS-16079 - RG - LEGO - EXCEED Packing                      */ 
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
/* 27-Jan-2021 Wan01    1.0   Created.                                  */  
/************************************************************************/   

CREATE PROCEDURE [dbo].[ispSKUDC06]
     @c_Storerkey        NVARCHAR(15)
   , @c_Sku              NVARCHAR(60)
   , @c_NewSku           NVARCHAR(30)      OUTPUT   --SKU
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
   
   IF LEFT(@c_SKU, 2) = '02' AND LEN(@c_SKU) >= 16
   BEGIN
      SET @c_NewSku = SUBSTRING( @c_Sku, 3, 14) 
   END
   
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
      EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispSKUDC06'    
      --RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012
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