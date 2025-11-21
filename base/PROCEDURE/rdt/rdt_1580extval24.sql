SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdt_1580ExtVal24                                          */
/* Copyright      : LF logistics                                              */
/*                                                                            */
/* Purpose: check mix SKU on carton (L01)                                     */
/*                                                                            */
/* Modifications log:                                                         */
/* Date        Rev  Author      Purposes                                      */
/* 24-02-2021  1.1  Chermaine   WMS-16328 Remove Lottable01 &Lottable03       */
/*                              (base on ExtVal13)                            */
/* 22-12-2022  1.2   yeekung    WMS-21405 add step 1 validate (yeekung01)     */
/******************************************************************************/
CREATE   PROCEDURE [RDT].[rdt_1580ExtVal24]
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

   DECLARE @nReceivedQty   INT
          ,@nExpectedQty   INT

   IF @nStep = 1 -- Lottable
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN        
         -- Check L03
         IF  EXISTS (SELECT 1 FROM Receipt WITH (NOLOCK)
                        WHERE Storerkey = @cStorerKey 
                           AND Receiptkey = @cReceiptKey 
                           AND RECType   IN ('RSO-N','RSO-F')
                           AND ASNstatus = '0')
         BEGIN
            SET @nErrNo = 163655
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvaidReceiveRSO
            GOTO Quit
         END
      END
   END
   
          
   IF @nStep = 4 -- Lottable
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN        
         -- Check L03
         IF NOT EXISTS (SELECT 1 FROM codelkup WITH (NOLOCK) WHERE Storerkey = @cStorerKey AND listName = 'NKCNLOT3V' AND code = @cLottable03)
         BEGIN
            SET @nErrNo = 163653
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Lot03
            GOTO Quit
         END
      END
   END
   

   IF @nStep = 5 -- SKU, QTY
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         -- Check SKU in ASN
         IF NOT EXISTS( SELECT TOP 1 1 FROM ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND SKU = @cSKU)
         BEGIN
            SET @nErrNo = 163651
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
            GOTO Quit
         END
         
         -- Check UserDefine10 in OriLine ASN
         IF EXISTS( SELECT TOP 1 1 
                    FROM ReceiptDetail RD WITH (NOLOCK) 
                    JOIN Receipt R WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey AND R.StorerKey = RD.StorerKey)
                    WHERE RD.ReceiptKey = @cReceiptKey 
                    AND R.UserDefine03 <> 'DT' 
                    AND RD.SKU = @cSKU 
                    AND qtyexpected <> 0
                    AND RD.UserDefine10 = '')
         BEGIN
            IF NOT EXISTS( SELECT TOP 1 1 
                     FROM ReceiptDetail RD WITH (NOLOCK) 
                     JOIN Receipt R WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey AND R.StorerKey = RD.StorerKey)
                     WHERE RD.ReceiptKey = @cReceiptKey 
                     AND R.UserDefine03 <> 'DT' 
                     AND RD.SKU = @cSKU 
                     AND RD.UserDefine10 <>''
                     HAVING SUM(QTYexpected)>=sum(beforereceivedqty))
            BEGIN
               SET @nErrNo = 163654
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid UDF10
               GOTO Quit
            END
         END

         SET @nReceivedQty = 0 
         SET @nExpectedQty = 0 
         
       	SELECT 
            @nReceivedQty = SUM(BeforeReceivedQty), 
            @nExpectedQty = SUM(QtyExpected)
         FROM dbo.ReceiptDetail WITH (NOLOCK) 
         WHERE ReceiptKey = @cReceiptKey 
          --  AND Lottable02 = @clottable02 
            AND SKU = @cSKU
            AND QtyExpected<>0
         --GROUP BY ReceiptKey, Lottable01, SKU 

         IF (@nReceivedQty + @nQTY  )  > @nExpectedQty 
         BEGIN
            SET @nErrNo = 163652
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OverReceiveRSO
            GOTO Quit
         END
      END
   END
         
Quit:

END

GO