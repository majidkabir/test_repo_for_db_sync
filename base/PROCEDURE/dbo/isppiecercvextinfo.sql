SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: ispPieceRcvExtInfo                                  */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Decode Label No Scanned                                     */  
/*                                                                      */  
/* Called from:                                                         */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author      Purposes                                */  
/* 03-09-2012  1.0  Ung         SOS254312. Created                      */ 
/* 12-12-2012  1.1  James       Change InnerPack to Busr10 (james01)    */ 
/************************************************************************/  
  
CREATE PROCEDURE [dbo].[ispPieceRcvExtInfo]  
   @c_ReceiptKey     NVARCHAR(10),  
   @c_POKey          NVARCHAR(10),  
   @c_ToLOC          NVARCHAR(10),  
   @c_ToID           NVARCHAR(18),  
   @c_Lottable01     NVARCHAR(18),  
   @c_Lottable02     NVARCHAR(18),  
   @c_Lottable03     NVARCHAR(18),  
   @d_Lottable04     DATETIME,  
   @c_StorerKey      NVARCHAR(15),  
   @c_SKU            NVARCHAR(20),  
 @c_oFieled01      NVARCHAR(20) OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   -- Get SKU info  
   SELECT @c_oFieled01 = +  
      'SEC: ' + LEFT( ItemClass, 2) + ' ' +   
      'UNIT/LOT: ' + CAST( BUSR10 AS NVARCHAR(2))  -- (james01)
   FROM dbo.SKU WITH (NOLOCK)  
   WHERE StorerKey = @c_StorerKey  
      AND SKU = @c_SKU  
       
QUIT:  
END -- End Procedure  

GO