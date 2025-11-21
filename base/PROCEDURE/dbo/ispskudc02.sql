SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: ispSKUDC02                                         */  
/* Creation Date: 04-Aug-2018                                           */  
/* Copyright: LFL                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: WMS-6217 / WMS-6218 CN IKEA packing decode scanned sku code */  
/*                                                                      */  
/* Called By: Packing                                                   */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/************************************************************************/   

CREATE PROCEDURE [dbo].[ispSKUDC02]
   @c_Storerkey        NVARCHAR(15),
   @c_Sku              NVARCHAR(50),
   @c_NewSku           NVARCHAR(20) OUTPUT,
   @b_Success          INT      OUTPUT,
   @n_ErrNo            INT      OUTPUT, 
   @c_ErrMsg           NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF
                                 
   SELECT @b_Success = 1, @n_ErrNo = 0, @c_ErrMsg = ''
   
   SELECT @c_NewSku = LEFT(LTRIM(@c_Sku), 13)
   
END -- End Procedure


GO