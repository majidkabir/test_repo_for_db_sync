SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store procedure: rdt_608ExtVal05                                           */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Check if sku is in ASN for ASN.RecType = 'STO'                    */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 2019-06-25   James     1.0   WMS9458. Created                              */
/* 2019-07-12   YeeKung   1.1   WMS-9091 Validate overreceipt                 */
/* 2022-09-08   Ung       1.2   WMS-20348 Expand RefNo to 60 chars            */
/* 2022-08-30   Ung       1.3   WMS-20251 Add receive by carton               */
/******************************************************************************/

CREATE     PROCEDURE [RDT].[rdt_608ExtVal05]
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5),
   @cStorerKey    NVARCHAR( 15),
   @cReceiptKey   NVARCHAR( 10),
   @cPOKey        NVARCHAR( 10),
   @cRefNo        NVARCHAR( 60),
   @cID           NVARCHAR( 18),
   @cLOC          NVARCHAR( 10),
   @cMethod       NVARCHAR( 1),
   @cSKU          NVARCHAR( 20),
   @nQTY          INT,
   @cLottable01   NVARCHAR( 18),
   @cLottable02   NVARCHAR( 18),
   @cLottable03   NVARCHAR( 18),
   @dLottable04   DATETIME,
   @dLottable05   DATETIME,
   @cLottable06   NVARCHAR( 30),
   @cLottable07   NVARCHAR( 30),
   @cLottable08   NVARCHAR( 30),
   @cLottable09   NVARCHAR( 30),
   @cLottable10   NVARCHAR( 30),
   @cLottable11   NVARCHAR( 30),
   @cLottable12   NVARCHAR( 30),
   @dLottable13   DATETIME,
   @dLottable14   DATETIME,
   @dLottable15   DATETIME,
   @cRDLineNo     NVARCHAR( 10),
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nQTYExpected_Total         INT
   DECLARE @nBeforeReceivedQTY_Total   INT
   DECLARE @cErrMsg1                   NVARCHAR(20)
   DECLARE @cErrMsg2                   NVARCHAR(20)

   DECLARE @cRecType    NVARCHAR( 10)

   IF @nFunc = 608 -- Piece return
   BEGIN
      IF @nStep = 4 -- SKU, QTY
      BEGIN
         IF @nInputKey = 1 -- ESC
         BEGIN
            IF EXISTS ( SELECT 1
                        FROM dbo.Receipt WITH (NOLOCK)
                        WHERE Receiptkey = @cReceiptKey
                        AND   StorerKey = @cStorerKey
                        AND   RECType = 'STO')
            BEGIN
               IF NOT EXISTS( SELECT 1
                              FROM dbo.Receiptdetail WITH (NOLOCK)
                              WHERE Receiptkey = @cReceiptKey
                              AND   StorerKey = @cStorerKey
                              AND   SKU = @cSKU)
               BEGIN
                  SET @nErrNo = 141251
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU Not in ASN
                  GOTO Quit
               END
            END

            IF EXISTS (SELECT 1 FROM dbo.codelkup WITH (NOLOCK)
                       WHERE LISTNAME='UAASNTYPE'
                       AND NOTES='Y'
                       AND SHORT IN (SELECT RECTYPE FROM dbo.Receipt WITH (NOLOCK)
                                     WHERE  storerkey=@cStorerKey
                                     AND receiptkey= @cReceiptKey)
								               -- AND UDF03 = '1'
								            )
            BEGIN
               IF EXISTS(SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK)
                         WHERE  ReceiptKey = @cReceiptKey
                         AND Storerkey = @cStorerKey
                         AND SKU=@cSKU
                         GROUP BY ReceiptKey,SKU
                         HAVING SUM(QTYExpected) < (SUM(BeforeReceivedQTY) + @nQty))
               BEGIN
                  SET @nErrNo = 141252
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over Receipt
                  GOTO Quit
               END
            END

            -- Receive by carton ID
            IF EXISTS( SELECT TOP 1 1 
               FROM dbo.Receipt R WITH (NOLOCK) 
                  JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey)
               WHERE R.ReceiptKey = @cReceiptKey
                  AND RD.UserDefine08 = @cRefNo
                  AND ISNULL(RD.UserDefine08,'')<>'') -- Carton ID
            BEGIN
               -- Check SKU in carton ID
               IF NOT EXISTS( SELECT TOP 1 1 
                  FROM dbo.Receipt R WITH (NOLOCK) 
                     JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey)
                  WHERE R.ReceiptKey = @cReceiptKey
                     AND RD.UserDefine08 = @cRefNo
                     AND RD.SKU = @cSKU)
               BEGIN
                  SET @nErrNo = 141253
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKUNotInCarton
                  GOTO Quit
               END

               -- Check SKU in carton ID
               IF EXISTS( SELECT TOP 1 1 
                  FROM dbo.Receipt R WITH (NOLOCK) 
                     JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey)
                  WHERE R.ReceiptKey = @cReceiptKey
                     AND RD.UserDefine08 = @cRefNo
                     AND RD.SKU = @cSKU
                  HAVING SUM( RD.QTYExpected) < (SUM( RD.BeforeReceivedQTY) + @nQTY))
               BEGIN
                  SET @nErrNo = 141254
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over Receipt
                  GOTO Quit
               END
            END
         END
      END
   END

Quit:

END

GO