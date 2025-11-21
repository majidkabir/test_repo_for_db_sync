SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: ispSKUDC05                                         */  
/* Creation Date: 07-Sep-2020                                           */  
/* Copyright: LFL                                                       */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose: WMS-14786 - PMI TW ScanNPack Decode SP                      */  
/*                                                                      */  
/* Called By: isp_SKUDecode_Wrapper                                     */  
/*                                                                      */  
/* GitLab Version: 1.0                                                  */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/************************************************************************/   

CREATE PROCEDURE [dbo].[ispSKUDC05]
   @c_Storerkey        NVARCHAR(15),
   @c_Sku              NVARCHAR(60),
   @c_NewSku           NVARCHAR(20)      OUTPUT,   --SKU
   @c_Code01           NVARCHAR(60) = '' OUTPUT,   --SerialNo
   @c_Code02           NVARCHAR(60) = '' OUTPUT,   --UPC
   @c_Code03           NVARCHAR(60) = '' OUTPUT,
   @b_Success          INT      OUTPUT,
   @n_ErrNo            INT      OUTPUT, 
   @c_ErrMsg           NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   --UPC      = 07622100825845 - Fixed 14 Chars
   --SERIALNO = 9VPWW3CFMMCQ - Varying
   --SKU      = DA000627.00 - Fixed 11 Chars
   
   SET @c_SKU = LTRIM(RTRIM(@c_SKU))
   
   SELECT @c_Code02 = SUBSTRING(@c_Sku, 3, 14)   --UPC
   
   SET @c_SKU = SUBSTRING(@c_SKU, 3 + 14, LEN(@c_SKU))   --SKU

   IF(LEFT(RIGHT(@c_SKU, 14), 3) = '240')
   BEGIN
   	SELECT @c_NewSKU = SUBSTRING(RIGHT(@c_SKU, 14), 4, 11)
   END

   IF(LEFT(@c_SKU, 2) = '21')
   BEGIN
      SET @c_Code01 = SUBSTRING(@c_SKU, 3, LEN(@c_SKU) - 14 - 2)   --SerialNo
   END

END -- End Procedure

GO