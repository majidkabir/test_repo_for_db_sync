SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_1580ExtVal08                                    */
/* Copyright      : LF logistics                                        */
/*                                                                      */
/* Purpose: Return must key-in carton ID (L01)                          */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author      Purposes                                */
/* 25-07-2017  1.0  Ung         WMS-5723 Created                        */
/* 04-03-2020  1.1  James       WMS-12231 Add pallet qty check (james01)*/
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1580ExtVal08]
    @nMobile      INT
   ,@nFunc        INT
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cLangCode    NVARCHAR( 3)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cReceiptKey  NVARCHAR( 10) 
   ,@cPOKey       NVARCHAR( 10) 
   ,@cExtASN      NVARCHAR( 20)
   ,@cToLOC       NVARCHAR( 10) 
   ,@cToID        NVARCHAR( 18) 
   ,@cLottable01  NVARCHAR( 18) 
   ,@cLottable02  NVARCHAR( 18) 
   ,@cLottable03  NVARCHAR( 18) 
   ,@dLottable04  DATETIME  
   ,@cSKU         NVARCHAR( 20) 
   ,@nQTY         INT
   ,@nErrNo       INT           OUTPUT 
   ,@cErrMsg      NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nPallet            INT           -- (james01)
   DECLARE @nID_Qty            INT           -- (james01)
   
   IF @nStep = 4 -- Lottables
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         -- Get receipt info
         DECLARE @cDocType NVARCHAR(1)
         SELECT @cDocType = DocType FROM Receipt WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey
         
         IF @cDocType = 'R' AND @cLottable01 = ''
         BEGIN
            SET @nErrNo = 127001
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need L01
            GOTO Quit
         END
      END
   END
   
   IF @nStep = 5  -- Qty
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         -- (james01)
         SELECT @nPallet = Pallet
         FROM dbo.SKU SKU WITH (NOLOCK)
         JOIN dbo.PACK PACK WITH (NOLOCK) ON ( SKU.PACKKey = PACK.PackKey)
         WHERE SKU.StorerKey = @cStorerKey
         AND   SKU.SKU = @cSKU
         
         SELECT @nID_Qty = ISNULL( SUM( BeforeReceivedQty), 0)
         FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
         AND   ToId = @cToID
         
         IF ( @nID_Qty + @nQTY) > @nPallet
         BEGIN
            SET @nErrNo = 127002
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --RCV>PALLET Qty
            GOTO Quit
         END
      END
   END
   

Quit:
END

GO