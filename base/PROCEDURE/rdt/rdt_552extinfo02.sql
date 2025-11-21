SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_552ExtInfo02                                    */    
/* Copyright      : LFLogistics                                         */    
/*                                                                      */    
/* Purpose: Display L03 on QTY screen                                   */    
/*                                                                      */    
/* Date       Rev  Author   Purposes                                    */    
/* 2017-10-06 1.0  Ung      WMS-3153 Created                            */   
/************************************************************************/    
    
CREATE PROCEDURE [RDT].[rdt_552ExtInfo02]    
   @nMobile         INT, 
   @nFunc           INT, 
   @cLangCode       NVARCHAR( 3), 
   @nStep           INT, 
   @nInputKey       INT, 
   @cZone           NVARCHAR( 10),
   @cReceiptKey     NVARCHAR( 10),
   @cPOKey          NVARCHAR( 10),
   @cSKU            NVARCHAR( 20),
   @nQTY            INT,
   @cLottable01     NVARCHAR( 18),
   @cLottable02     NVARCHAR( 18),
   @cLottable03     NVARCHAR( 18),
   @dLottable04     DATETIME,
   @cConditionCode  NVARCHAR( 10),
   @cSubReason      NVARCHAR( 10),
   @cToLOC          NVARCHAR( 10),
   @cToID           NVARCHAR( 18),
   @cExtendedInfo   NVARCHAR( 20) OUTPUT, 
   @nErrNo          INT OUTPUT,
   @cErrMsg         NVARCHAR( 20) OUTPUT
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
       
   IF @nFunc = 552 -- Return
   BEGIN
      IF @nStep = 3 -- QTY
      BEGIN
         SELECT @cExtendedInfo = Lottable03
         FROM ReceiptDetail WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
            -- AND StorerKey = @cStorerKey
            AND SKU = @cSKU
      END
   END
END

GO