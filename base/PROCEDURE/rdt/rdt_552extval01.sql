SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_552ExtVal01                                     */    
/* Copyright      : LFLogistics                                         */    
/*                                                                      */    
/* Purpose: Display L03 on QTY screen                                   */    
/*                                                                      */    
/* Date       Rev  Author   Purposes                                    */    
/* 2017-10-06 1.0  Ung      WMS-3154 Created                            */   
/************************************************************************/    
    
CREATE PROCEDURE [RDT].[rdt_552ExtVal01]    
   @nMobile         INT, 
   @nFunc           INT, 
   @cLangCode       NVARCHAR( 3), 
   @nStep           INT, 
   @nInputKey       INT, 
   @cFacility       NVARCHAR( 5),
   @cStorerKey      NVARCHAR( 15),
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
   @nErrNo          INT           OUTPUT,
   @cErrMsg         NVARCHAR( 20) OUTPUT
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
       
   IF @nFunc = 552 -- Return
   BEGIN
      IF @nStep = 6 -- TO ID
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            DECLARE @cL03 NVARCHAR( 18)
            
            -- Get L03 from inventory
            SELECT TOP 1 
               @cL03 = LA.Lottable03
            FROM LOTxLOCxID LLI WITH (NOLOCK)
               JOIN LOTAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
               JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
            WHERE LOC.Facility = @cFacility
               AND LLI.StorerKey = @cStorerKey 
               AND LLI.ID = @cTOID
               AND (LLI.QTY - LLI.QTYPicked) > 0
               
            IF @@ROWCOUNT = 0
               -- Get L03 from ASN
               SELECT TOP 1 
                  @cL03 = RD.Lottable03
               FROM Receipt R WITH (NOLOCK)
                  JOIN ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey)
               WHERE R.StorerKey = @cStorerKey 
                  AND R.Facility = @cFacility
                  AND R.DocType = 'R'
                  AND RD.BeforeReceivedQTY > 0
                  AND RD.ToID = @cToID
                  AND RD.FinalizeFlag <> 'Y'
            
            -- Check different L03 on ID
            IF @cL03 IS NOT NULL AND @cL03 <> @cLottable03 
            BEGIN
               SET @nErrNo = 115651
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Wrong TO ID
            END
         END
      END
   END
END

GO