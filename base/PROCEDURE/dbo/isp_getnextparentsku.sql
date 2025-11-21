SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/      
/* Stored Procedure: isp_GetNextParentSKU                               */      
/* Creation Date:                                                       */      
/* Copyright: IDS                                                       */      
/* Written by:                                                          */      
/*                                                                      */      
/* Purpose: Generate the next ParentSKU for BOM                         */      
/*                                                                      */      
/* Called By:                                                           */      
/*                                                                      */      
/* PVCS Version: 1.2                                                    */      
/*                                                                      */      
/* Version: 5.4                                                         */      
/*                                                                      */      
/* Data Modifications:                                                  */      
/*                                                                      */      
/* Updates:                                                             */      
/* Date         Author   Ver  Purposes                                  */      
/* 21-05-2010   Vicky    1.0  Created                                   */
/* 21-05-2010   Larry    1.1  Fix difference Style, but first 10 char   */
/*                            are same    (lau001)                      */
/* 19-04-2011   James    1.2  SOS212200 - Prevent BOM SKU created same  */
/*                            same as SKU master (james01)              */
/************************************************************************/      
CREATE PROC [dbo].[isp_GetNextParentSKU]   
   @c_Storerkey     NVARCHAR(15),   
   @c_Style         NVARCHAR(20),  
   @c_NewParentSKU  NVARCHAR(18) OUTPUT
AS  
BEGIN
   SET NOCOUNT ON 
       
   DECLARE @t_ParentSKU TABLE (ParentSKU NVARCHAR(20))

   DECLARE @n_Index INT 

   SET @c_NewParentSKU = ''

   INSERT INTO @t_ParentSKU (ParentSKU)
   SELECT DISTINCT BOM.SKU 
   FROM BillOfMaterial BOM WITH (NOLOCK) 
   JOIN SKU WITH (NOLOCK) ON (BOM.ComponentSKU = SKU.SKU AND BOM.StorerKey = SKU.storerkey)
   WHERE LEFT(RTRIM(SKU.Style),10) = LEFT(BOM.SKU, LEN(LEFT(RTRIM(SKU.Style), 10))) 
   AND   LEN(BOM.SKU) = LEN(LEFT(RTRIM(SKU.Style), 10)) + 3 
   AND   ISNUMERIC(RIGHT(LEN(SKU.Style),3)) = 1 
--   AND   SKU.Style = RTRIM(@c_Style)  --lau001
   AND   LEFT(SKU.Style,10) = LEFT(RTRIM(@c_Style),10)    --lau001
   AND   SKU.Storerkey = @c_Storerkey

   SET @n_Index = 1
   WHILE @n_Index < 1000
   BEGIN
      SET @c_NewParentSKU = LEFT(RTRIM(@c_Style), 10) + RIGHT('00' + CONVERT(varchar(3), @n_Index), 3)

      IF NOT EXISTS( SELECT 1 FROM @t_ParentSKU WHERE ParentSKU = @c_NewParentSKU)
      BEGIN
        IF NOT EXISTS (SELECT 1 FROM dbo.SKU WITH (NOLOCK)     -- (james01)
           WHERE StorerKey = @c_Storerkey AND SKU = @c_NewParentSKU)
        BEGIN
           BREAK    
        END
      END

      SET @n_Index = @n_Index + 1 
   END  
END

GO