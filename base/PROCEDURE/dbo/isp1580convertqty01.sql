SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: isp1580ConvertQty01                                 */    
/* Copyright      : LFLogistics                                         */    
/*                                                                      */    
/* Called from: rdtfnc_PieceReceiving                                   */  
/*                                                                      */  
/* Purpose: Get lot03 (top 1) value from sku + lot02 as uom.            */  
/*          Return qty x uom                                            */  
/*                                                                      */  
/* Date         Rev  Author      Purposes                               */    
/* 18-Jun-2018  1.0  James       WMS5406 Created                        */    
/************************************************************************/    
CREATE PROCEDURE [dbo].[isp1580ConvertQty01]    
   @cType         NVARCHAR( 10),   
   @cStorerKey    NVARCHAR( 15),  
   @cSKU          NVARCHAR( 20),   
   @nQTY          INT OUTPUT  
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
  
   DECLARE @cQTY           NVARCHAR( 5),  
           @cReceiptKey    NVARCHAR( 10),  
           @cLottable02    NVARCHAR( 18),  
           @cLottable03    NVARCHAR( 18),  
           @cInField05     NVARCHAR( 60),  
           @nStep          INT  
  
   SELECT @nStep = Step,  
          @cReceiptKey = V_ReceiptKey,  
          @cLottable02 = V_Lottable02,  
          @cInField05 = I_Field05  
   FROM RDT.RDTMOBREC WITH (NOLOCK)  
   WHERE UserName = sUser_sName()  
  
   IF @nStep = 5  
   BEGIN  
      IF @cType = 'ToBaseQTY'  
      BEGIN  
         IF @cInField05 <> ''  
            GOTO Quit  
  
         SELECT TOP 1 @cLottable03 = Lottable03  
         FROM dbo.ReceiptDetail WITH (NOLOCK)  
         WHERE ReceiptKey = @cReceiptKey  
         AND   SKU = @cSKU  
         AND   Lottable02 = @cLottable02
         ORDER BY Lottable03 desc  
  
         IF ISNULL( @cLottable03, '') = ''  
            SET @cLottable03 = '0'  
  
         SET @nQTY = CAST( @cLottable03 AS INT)  
      END  
   END  
  
   QUIT:    
END -- End Procedure    

GO