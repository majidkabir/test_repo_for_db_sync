SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_898UCCExtVal07                                     */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Date       Rev  Author     Purposes                                     */
/* 20-05-2022 1.0  yeekung     WMS-19671 Created                           */
/***************************************************************************/

CREATE PROCEDURE [RDT].[rdt_898UCCExtVal07]
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
   
   IF @nFunc = 898 -- UCC receiving
   BEGIN
      DECLARE @cItemClass NVARCHAR(20),
              @cRDLottable01 NVARCHAR(20),
              @cRDLottable02 NVARCHAR(20),
              @cStorerkey     NVARCHAR(20),
              @cSKU        NVARCHAR(20)
      DECLARE @cUCCUDF03   NVARCHAR( 20)
      DECLARE @cExterKey   NVARCHAR( 20),
              @cCodelkupDesc NVARCHAR(60),
              @cSKUItemClass NVARCHAR(20)

      SELECT @cStorerkey=storerkey
      FROM rdt.rdtmobrec (NOLOCK)
      where mobile=@nMobile
      
      -- Get UCC info
      SELECT 
         @cUCCUDF03 = UserDefined03, 
         @cExterKey = ExternKey
      FROM dbo.UCC WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey 
         AND UCCNo = @cUCC

      -- Check UCC format
      IF @@ROWCOUNT > 0
      BEGIN
         IF ISNULL( @cUCCUDF03, '') <> '' -- (james01)
         BEGIN
            -- Get ReceiptDetail info
            IF NOT EXISTS( SELECT TOP 1 1 
               FROM dbo.ReceiptDetail WITH (NOLOCK) 
               WHERE ReceiptKey = @cReceiptKey
                  AND RTRIM( UserDefine03) + RTRIM( UserDefine02) = @cUCCUDF03)
            BEGIN
               SET @nErrNo = 186802
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UDF3 Not In RD
               GOTO Quit
            END
         END
      
         -- Check ExternKey in ASN
         IF @cExterKey <> ''
         BEGIN
            IF NOT EXISTS( SELECT TOP 1 1 
               FROM dbo.ReceiptDetail WITH (NOLOCK) 
               WHERE ReceiptKey = @cReceiptKey
                  AND ExternReceiptKey = @cExterKey)
            BEGIN
               SET @nErrNo = 186803
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ExtKey NotInRD
               GOTO Quit
            END
         END
      END
      
      -- If pallet not receive before then no need further check
      IF EXISTS ( SELECT 1 FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
                  WHERE receiptkey=@cReceiptkey
                        AND TOID =@cToID
                        AND storerkey=@cStorerkey) 
      BEGIN
         SELECT   @cItemClass=itemclass,
                  @cRDLottable01=RD.lottable01,
                  @cRDLottable02=RD.lottable02
         FROM RECEIPTDETAIL RD (NOLOCK) 
         JOIN SKU SKU (NOLOCK) ON RD.SKU=SKU.SKU AND RD.storerkey=SKU.storerkey
         WHERE receiptkey=@cReceiptkey
            AND TOID =@cToID
            AND SKU.storerkey=@cStorerkey

         SELECT @cSKU=sku
         FROM UCC (NOLOCK)
         WHERE uccno=@cUCC
         AND storerkey=@cStorerkey


         SELECT @cCodelkupDesc=description
         FROM codelkup (NOLOCK)
         WHERE LISTNAME='Itemclass'
         AND storerkey=@cStorerkey
         AND code=@cItemClass

         SELECT @cSkuItemclass =itemclass
         FROM SKU (NOLOCK)
         WHERE SKU =@cSKU
         AND storerkey = @cStorerkey

         IF EXISTS(SELECT 1
                     FROM codelkup (NOLOCK)
                     WHERE LISTNAME='Itemclass'
                     AND storerkey=@cStorerkey
                     AND code=@cSkuItemclass
                     AND description <>@cCodelkupDesc) 
               OR @cRDLottable01<>@cLottable01
               OR @cRDLottable02<>@cLottable02
         BEGIN
            SET @nErrNo = 186801 
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Lot03<>HostWh
            GOTO Quit
         END
      END
   END
   

Quit:

END

GO