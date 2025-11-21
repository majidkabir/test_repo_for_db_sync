SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_898UCCExtVal06                                  */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author  Purposes                                     */
/* 2022-04-13 1.0  Ung     WMS-19452 Created                            */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_898UCCExtVal06]
    @nMobile     INT
   ,@nFunc       INT
   ,@cLangCode   NVARCHAR(  3)
   ,@cReceiptKey NVARCHAR( 10)
   ,@cPOKey      NVARCHAR( 10)
   ,@cLOC        NVARCHAR( 10)
   ,@cToID       NVARCHAR( 18)
   ,@cLottable01 NVARCHAR( 18)
   ,@cLottable02 NVARCHAR( 18)
   ,@cLottable03 NVARCHAR( 18)
   ,@dLottable04 DATETIME
   ,@cUCC        NVARCHAR( 20)
   ,@nErrNo      INT           OUTPUT
   ,@cErrMsg     NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 898 -- Container receiving
   BEGIN
      -- Receive to pallet ID
      IF @cToID <> ''
      BEGIN
         DECLARE @cStorerKey NVARCHAR( 15)
         DECLARE @cSKU       NVARCHAR( 20)

         -- Get random SKU on pallet
         SELECT TOP 1 
            @cStorerKey = StorerKey, 
            @cSKU = SKU
         FROM dbo.ReceiptDetail WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
            AND ToID = @cToID
            AND BeforeReceivedQTY > 0
         
         IF @@ROWCOUNT = 1
         BEGIN
            -- Check SKU different with pallet SKU
            IF EXISTS( SELECT 1 
               FROM dbo.UCC WITH (NOLOCK) 
               WHERE UCCNo = @cUCC 
                  AND StorerKey = @cStorerKey 
                  AND SKU <> @cSKU)
            BEGIN
               SET @nErrNo = 185951
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pallet DiffSKU 
               GOTO Quit
            END
         END
      END
   END
   
Quit:

END

GO