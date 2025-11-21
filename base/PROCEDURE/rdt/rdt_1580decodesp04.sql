SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1580DecodeSP04                                        */
/* Copyright: Maersk                                                          */
/*                                                                            */
/* Purpose: For Defy                                                          */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 2024-07-31  JHU151     1.0   FCR-550   Created                             */
/******************************************************************************/

CREATE   PROC rdt.rdt_1580DecodeSP04 (
   @nMobile             INT,
   @nFunc               INT,
   @cLangCode           NVARCHAR( 3),
   @nStep               INT,
   @nInputKey           INT,
   @cStorerKey          NVARCHAR( 15),
   @cReceiptKey         NVARCHAR( 10),
   @cPOKey              NVARCHAR( 10),
   @cLOC                NVARCHAR( 10),
   @cID                 NVARCHAR( 18),
   @cBarcode            NVARCHAR( 120),
   @cSKU                NVARCHAR( 20)     OUTPUT,
   @nQTY                INT               OUTPUT,
   @cLottable01         NVARCHAR( 18)     OUTPUT,
   @cLottable02         NVARCHAR( 18)     OUTPUT,
   @cLottable03         NVARCHAR( 18)     OUTPUT,
   @dLottable04         DATETIME          OUTPUT,
   @cSerialNoCapture    NVARCHAR(1) = 0   OUTPUT,
   @nErrNo              INT               OUTPUT,
   @cErrMsg             NVARCHAR( 20)     OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nRcvQty     INT = 0
   DECLARE @nExpQty     INT = 0
   
   IF @nStep = 5 -- SKU/QTY
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         IF @cBarcode <> ''
         BEGIN
            DECLARE @cAddRCPTValidtn    NVARCHAR(30),
                    @cASNSNRCPTValidtn  NVARCHAR(30),
                    @cSNStatusValidtn   NVARCHAR(30),
                    @cSkipCheckingSKUNotInASN   NVARCHAR(30),
                    @cDisAllowRDTOverReceipt    NVARCHAR(30),
                    @cSNStatus          NVARCHAR(2)
                    
            SET @cAddRCPTValidtn = rdt.RDTGetConfig( @nFunc, 'AddRCPTValidtn', @cStorerKey)
            SET @cASNSNRCPTValidtn = rdt.RDTGetConfig( @nFunc, 'ASNSNRCPTValidtn', @cStorerKey)
            SET @cSNStatusValidtn = rdt.RDTGetConfig( @nFunc, 'SNStatusValidtn', @cStorerKey)
            SET @cSkipCheckingSKUNotInASN = rdt.RDTGetConfig( @nFunc, 'SkipCheckingSKUNotInASN', @cStorerKey)
            SET @cDisAllowRDTOverReceipt = rdt.RDTGetConfig( @nFunc, 'DisAllowRDTOverReceipt', @cStorerKey)

            
            
            IF (@cAddRCPTValidtn = '1')
            BEGIN
               SELECT @cSKU = Sku
               FROM SKU WITH(NOLOCK)
               WHERE storerkey = @cStorerkey
               AND (sku = SUBSTRING(@cBarcode,1,6)
                     OR SKU = SUBSTRING(@cBarcode,1,10)
               )

               IF ISNULL(@cSku,'') = ''
               BEGIN
                  SET @nErrNo = 220701  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU  
                  GOTO Quit
               END                                             
               
               SET @nQTY = 1
               SET @nErrNo = -1     
            END

            IF @cSNStatusValidtn = '1'
            Begin
               SELECT @cSNStatus = Status
               FROM SerialNo WITH(NOLOCK)
               WHERE sku = @cSku
               AND SerialNo = @cBarcode
               
               IF @@ROWCOUNT > 0
               BEGIN
                  IF ISNULL(@cSNStatus,'')  <> '9'
                  BEGIN
                     SET @nErrNo = 220705
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SN received
                     GOTO Quit
                  END
               END
            END
            
            IF (@cSkipCheckingSKUNotInASN = '0')
            BEGIN 
               IF NOT EXISTS ( SELECT 1 
                              FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
                              WHERE ReceiptKey = @cReceiptKey
                              AND   SKU = @cSKU
                              AND   FinalizeFlag <> 'Y')
               BEGIN
                  SET @nErrNo = 220702  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU Not In ASN  
                  GOTO Quit
               END
            END
            
            IF (@cDisAllowRDTOverReceipt = '1')
            BEGIN
               SELECT 
                  @nRcvQty = ISNULL( SUM( BeforeReceivedQty), 0), 
                  @nExpQty = ISNULL( SUM( QtyExpected), 0)
               FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
               WHERE ReceiptKey = @cReceiptKey
               AND   SKU = @cSKU
               AND   FinalizeFlag <> 'Y'
               
               IF ( @nRcvQty + 1) > @nExpQty
               BEGIN
                  SET @nErrNo = 220703  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU Over Rcv  
                  GOTO Quit
               END
            END

            

            IF (@cASNSNRCPTValidtn = '1')
            BEGIN               
               
               IF NOT EXISTS ( SELECT 1 
                                 FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
                                 WHERE ReceiptKey = @cReceiptKey
                                 AND   SKU = @cSku
                                 AND   userdefine01 = @cBarcode
                                 AND   FinalizeFlag <> 'Y')
               BEGIN
                  SET @nErrNo = 220704  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SerialNo 
                  GOTO Quit
               END
            END
         END
      END
   END

Quit:

END

GO