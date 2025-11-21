SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_550ExtVal01                                     */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Purpose:                                                             */
/* Due to supplier provide pallet not according to standard pallet size,*/
/* check Pack.Pallet against pallet received QTY, prompt for restack    */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2014-08-15 1.0  Ung        SOS318341 Created                         */
/* 2014-11-26 1.1  Ung        SOS326375 Modify parameters               */
/*                            rename from rdt_550ExtUpd01               */
/************************************************************************/

CREATE PROC [RDT].[rdt_550ExtVal01] (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @nStep        INT,
   @nInputKey    INT,
   @cStorerKey   NVARCHAR( 15),
   @cReceiptKey  NVARCHAR( 10),
   @cPOKey       NVARCHAR( 10),
   @cLOC         NVARCHAR( 10),
   @cID          NVARCHAR( 18),
   @cSKU         NVARCHAR( 20),
   @nQTY         INT,
   @cLottable01  NVARCHAR(18),
   @cLottable02  NVARCHAR(18),
   @cLottable03  NVARCHAR(18),
   @dLottable04  DATETIME,
   @nErrNo       INT            OUTPUT,
   @cErrMsg      NVARCHAR( 20)  OUTPUT
)
AS

   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nQty_Received     INT, 
           @nQty_Expected     INT 
	Declare @nValid INT

   -- Initialise var
   SET @nValid = 1
   
   IF @nFunc = 550 -- Normal receiving
   BEGIN
      IF @nStep = 5 -- U0M, QTY
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Check whether it is a pallet
            IF ISNULL( @cID, '') = '' 
               GOTO Quit
      
            -- Get Pack info
            DECLARE @nPallet INT
            SELECT @nPallet = CAST( Pallet AS INT)
            FROM SKU WITH (NOLOCK)
               JOIN Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
            WHERE StorerKey = @cStorerKey
               AND SKU.SKU = @cSKU
      
            -- Check pallet count
            IF @nPallet = 0 
               GOTO Quit
               
            -- Check multi SKU pallet
            IF EXISTS( SELECT TOP 1 1
               FROM dbo.ReceiptDetail WITH (NOLOCK) 
               WHERE ReceiptKey = @cReceiptKey
                  AND ToID = @cID
                  AND SKU <> @cSKU
                  AND BeforeReceivedQTY > 0)
               GOTO QUIT
      
            -- Get received QTY
            DECLARE @nBeforeReceivedQTY INT
            SELECT @nBeforeReceivedQTY = ISNULL( SUM( BeforeReceivedQTY), 0)
            FROM dbo.ReceiptDetail WITH (NOLOCK) 
            WHERE ReceiptKey = @cReceiptKey
               AND ToID = @cID
               AND StorerKey = @cStorerKey
               AND SKU = @cSKU
            
            -- Check standard pallet size vs actual
            IF (@nQTY + @nBeforeReceivedQTY) > @nPallet
            BEGIN
               SET @nErrNo = 91451
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PalletOverQTY  
               GOTO Quit
            END
         END
      END
   END
Quit:


GO