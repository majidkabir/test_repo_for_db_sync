SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_1580ExtVal18                                    */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Purpose: Check TO ID valid.                                          */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2020-12-02 1.0  YeeKung    WMS-15666 Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_1580ExtVal18] (
   @nMobile      INT,
   @nFunc        INT,
   @nStep        INT,
   @nInputKey    INT,
   @cLangCode    NVARCHAR( 3),
   @cStorerkey   NVARCHAR( 15),
   @cReceiptKey  NVARCHAR( 10),
   @cPOKey    NVARCHAR( 10),
   @cExtASN      NVARCHAR( 20),
   @cToLOC       NVARCHAR( 10),
   @cToID        NVARCHAR( 18),
   @cLottable01  NVARCHAR( 18),
   @cLottable02  NVARCHAR( 18),
   @cLottable03  NVARCHAR( 18),
   @dLottable04  DATETIME,    
   @cSKU         NVARCHAR( 20),
   @nQTY         INT,
   @nErrNo       INT           OUTPUT,
   @cErrMsg      NVARCHAR( 20) OUTPUT          
)
AS
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nStep = 4 -- lottable
   BEGIN
      IF ISNULL(@clottable01,'')=''
      BEGIN
         SET @nErrNo = 161155
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Lot01
         EXEC rdt.rdtSetFocusField @nMobile, 1-- SKU  
         GOTO Quit
      END


      IF ISNULL(@clottable02,'')=''
      BEGIN
         SET @nErrNo = 161156
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Lot01
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- SKU  
         GOTO Quit
      END


      IF NOT EXISTS (SELECT 1 from receiptdetail (NOLOCK)
                     WHERE receiptkey=@cReceiptkey
                     and lottable01=@clottable01
                     and lottable02=@clottable02
                     and storerkey=@cstorerkey)
      BEGIN
         SET @nErrNo = 161152
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Lot01
         GOTO Quit
      END
   END
  

   IF @nStep = 5 -- SKU/QTY
   BEGIN
      IF NOT EXISTS ( SELECT 1 FROM dbo.receipt R (NOLOCK) join dbo.RECEIPTDETAIL RD WITH (NOLOCK)
            ON R.receiptkey=RD.receiptkey
            WHERE RD.ReceiptKey = @cReceiptKey
            and lottable01=@clottable01
            and lottable02=@clottable02
            AND   RD.SKU =@csku)
      BEGIN
         SET @nErrNo = 161153
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SKUNOTMIX
         GOTO Quit
      END

      IF EXISTS ( SELECT 1 FROM dbo.receipt R (NOLOCK) join dbo.RECEIPTDETAIL RD WITH (NOLOCK)
                  ON R.receiptkey=RD.receiptkey
                  WHERE RD.ReceiptKey = @cReceiptKey
                  AND   RD.beforereceivedqty<>0
                  AND   RD.SKU <>@csku
                  AND   RD.toid=@cToID
                  AND   R.status NOT IN ('9','canc'))
      BEGIN
         SET @nErrNo = 161151
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SKUNOTMIX
         GOTO Quit
      END
      ELSE IF EXISTS ( SELECT 1 FROM dbo.receipt R (NOLOCK) join dbo.RECEIPTDETAIL RD WITH (NOLOCK)
                  ON R.receiptkey=RD.receiptkey
                  WHERE RD.ReceiptKey = @cReceiptKey
                  AND   RD.beforereceivedqty<>0
                  AND   RD.SKU =@csku
                  and   lottable01<>@clottable01
                  and   lottable02<>@clottable02
                  AND   RD.toid=@cToID
                  AND   R.status NOT IN ('9','canc'))
      BEGIN
         SET @nErrNo = 161154
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SKUNOTMIX
         GOTO Quit
      END
   
   END

   Quit:


GO