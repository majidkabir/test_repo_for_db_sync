SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: ispPieceRcvExtInfo07                                */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: RDT Piece Receiving show extended info @ step5              */  
/*          Show SKU Received over total SKU per ID                     */  
/*                                                                      */  
/* Called from:                                                         */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author      Purposes                                */  
/* 2020-04-14  1.0  YeeKung      WMS-12737. Created                      */  
/************************************************************************/  
  
CREATE PROCEDURE [dbo].[ispPieceRcvExtInfo07]  
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
  
   DECLARE @cSUSR3 NVARCHAR(20),  
           @n_Step NVARCHAR(5)  
  
   -- Get user input qty here as not a pass in value  
   SELECT @n_Step = Step  
          --@c_Qty = I_Field05,  
          --@c_ExtASN = V_String26  
   FROM RDT.RDTMOBREC WITH (NOLOCK)  
   WHERE UserName = sUser_sName()  
  
   IF @n_Step = 5  
   BEGIN  
        
      SELECT @cSUSR3=SUSR3 FROM SKU (NOLOCK) WHERE SKU=@c_SKU  
  
      SELECT @c_oFieled01 = @cSUSR3     
  
   END  
  
QUIT:  
END -- End Procedure  

GO