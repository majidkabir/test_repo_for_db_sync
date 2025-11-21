SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_608RefNoLKUP02                                        */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Lookup RefNo by multiple fields                                   */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 04-Jan-2015  Ung       1.0   SOS359609 Created                             */
/* 08-Sep-2022  Ung       1.1   WMS-20348 Expand RefNo to 60 chars            */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_608RefNoLKUP02]
   @nMobile       INT,           
   @nFunc         INT,           
   @cLangCode     NVARCHAR( 3),  
   @cFacility     NVARCHAR( 5),  
   @cStorerGroup  NVARCHAR( 20), 
   @cStorerKey    NVARCHAR( 15), 
   @cRefNo        NVARCHAR( 60), 
   @cReceiptKey   NVARCHAR(10)  OUTPUT, 
   @nErrNo        INT           OUTPUT, 
   @cErrMsg       NVARCHAR( 20) OUTPUT  
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @nRowCount INT

   IF @nFunc = 608 -- Return V7
   BEGIN  
      IF @cStorerGroup <> ''
      BEGIN
         IF @cReceiptKey = ''
         BEGIN
            SELECT @cReceiptKey = ReceiptKey 
            FROM dbo.Receipt WITH (NOLOCK) 
            WHERE Facility = @cFacility
               AND EXISTS( SELECT 1 FROM StorerGroup WITH (NOLOCK) WHERE StorerGroup = @cStorerGroup AND StorerKey = @cStorerKey)
               AND Status <> '9'
               AND CarrierReference = @cRefNo
            SELECT @nRowCount = @@ROWCOUNT
         END

         IF @cReceiptKey = ''
         BEGIN
            SELECT @cReceiptKey = ReceiptKey 
            FROM dbo.Receipt WITH (NOLOCK) 
            WHERE Facility = @cFacility
               AND EXISTS( SELECT 1 FROM StorerGroup WITH (NOLOCK) WHERE StorerGroup = @cStorerGroup AND StorerKey = @cStorerKey)
               AND Status <> '9'
               AND UserDefine01 = @cRefNo
            SELECT @nRowCount = @@ROWCOUNT
         END
      END
      ELSE
      BEGIN
         IF @cReceiptKey = ''
         BEGIN
            SELECT @cReceiptKey = ReceiptKey 
            FROM dbo.Receipt WITH (NOLOCK) 
            WHERE Facility = @cFacility
               AND StorerKey = @cStorerKey
               AND Status <> '9'
               AND CarrierReference = @cRefNo
            SELECT @nRowCount = @@ROWCOUNT
         END

         IF @cReceiptKey = ''
         BEGIN
            SELECT @cReceiptKey = ReceiptKey 
            FROM dbo.Receipt WITH (NOLOCK) 
            WHERE Facility = @cFacility
               AND StorerKey = @cStorerKey
               AND Status <> '9'
               AND UserDefine01 = @cRefNo
            SELECT @nRowCount = @@ROWCOUNT
         END
      END
      
      -- Check RefNo in ASN
      IF @nRowCount = 0
      BEGIN
         SET @nErrNo = 59451
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --RefNo NotInASN
         GOTO Quit
      END

      -- Check RefNo in ASN
      IF @nRowCount > 1
      BEGIN
         SET @nErrNo = 59452
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --RefNo MultiASN
         GOTO Quit
      END
   END
   
Quit:

END

SET QUOTED_IDENTIFIER OFF

GO