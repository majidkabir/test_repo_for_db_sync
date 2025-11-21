SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_638RefNoLKUP01                                        */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Lookup RefNo by multiple fields                                   */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 12-03-2020   YeeKung   1.0   WMS-12465 Created                             */
/* 13-07-2020   Ung       1.1   WMS-13555 Change params                       */
/* 28-08-2020   Ung       1.2   WMS-14796 Add TrackingNo                      */
/* 23-09-2022   YeeKung   1.3   WMS-20820 Extended refno length (yeekung01)   */
/* 04-01-2023   Ung       1.4   WMS-21385 Add RefNoSKULookup                  */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_638RefNoLKUP01]
    @nMobile      INT
   ,@nFunc        INT
   ,@cLangCode    NVARCHAR( 3)
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cFacility    NVARCHAR( 5)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cSKU         NVARCHAR( 20)  -- Optional, lookup by RefNo + SKU
   ,@cRefNo       NVARCHAR( 60)  OUTPUT --(yeekung01)
   ,@cReceiptKey  NVARCHAR( 10)  OUTPUT
   ,@nBalQTY      INT            OUTPUT
   ,@nErrNo       INT            OUTPUT
   ,@cErrMsg      NVARCHAR( 20)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nRowCount INT

   IF @nFunc = 638 -- ECOM return
   BEGIN
      IF @cReceiptKey = ''
      BEGIN
         SELECT @cReceiptKey = ReceiptKey
         FROM dbo.Receipt WITH (NOLOCK)
         WHERE Facility = @cFacility
            AND StorerKey = @cStorerKey
            AND Status <> '9'
            AND ASNStatus <> 'CANC'
            AND ReceiptGroup = 'ECOM'
            AND TrackingNo = @cRefNo
         SELECT @nRowCount = @@ROWCOUNT
      END

      IF @cReceiptKey = ''
      BEGIN
         SELECT @cReceiptKey = ReceiptKey
         FROM dbo.Receipt WITH (NOLOCK)
         WHERE Facility = @cFacility
            AND StorerKey = @cStorerKey
            AND Status <> '9'
            AND ASNStatus <> 'CANC'
            AND ReceiptGroup = 'ECOM'
            AND Userdefine09 = @cRefNo
         SELECT @nRowCount = @@ROWCOUNT
      END

      IF @cReceiptKey = ''
      BEGIN
         IF @nStep = 1 -- ASN, RefNo
         BEGIN
            SELECT @cReceiptKey = ReceiptKey
            FROM dbo.Receipt WITH (NOLOCK)
            WHERE Facility = @cFacility
               AND StorerKey = @cStorerKey
               AND Status <> '9'
               AND ASNStatus <> 'CANC'
               AND ReceiptGroup = 'ECOM'
               AND Userdefine02 = @cRefNo
            SELECT @nRowCount = @@ROWCOUNT
            
            -- It could return multiple ASN
            IF @nRowCount > 1
               SET @nRowCount = 1

            SET @cReceiptKey = ''
         END
         
         IF @nStep = 3 -- SKU
         BEGIN
            SELECT TOP 1 
               @cReceiptKey = R.ReceiptKey, 
               @cSKU = RD.SKU
            FROM dbo.Receipt R WITH (NOLOCK)
               JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey)
            WHERE R.Facility = @cFacility
               AND R.StorerKey = @cStorerKey
               AND R.Status <> '9'
               AND R.ASNStatus <> 'CANC'
               AND R.ReceiptGroup = 'ECOM'
               AND R.Userdefine02 = @cRefNo
               AND RD.SKU = @cSKU
               AND RD.QTYExpected > RD.BeforeReceivedQTY
            ORDER BY RD.ReceiptKey, RD.ReceiptLineNumber
            
            SELECT @nBalQTY = ISNULL( SUM( QTYExpected - BeforeReceivedQTY), 0)
            FROM dbo.ReceiptDetail WITH (NOLOCK)
            WHERE ReceiptKey = @cReceiptKey
            
            GOTO Quit
         END
      END

      -- Check RefNo in ASN
      IF @nRowCount = 0
      BEGIN
         SET @nErrNo = 149551
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --RefNo NotInASN
         GOTO Quit
      END
   END

Quit:

END

GO