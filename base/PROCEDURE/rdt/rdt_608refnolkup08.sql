SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_608RefNoLKUP08                                        */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 28-07-2022   Ung       1.0   WMS-20348 Created                             */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_608RefNoLKUP08]
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
   
   DECLARE @nCount INT

   IF @nFunc = 608 -- Piece return
   BEGIN
       SET @cRefNo = RIGHT( @cRefNo, 19)
      
      -- Get ASN
      SELECT
         @cReceiptKey = MIN( R.ReceiptKey),
         @nCount = COUNT( DISTINCT R.ReceiptKey)
      FROM dbo.Receipt R WITH (NOLOCK)
         JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey)
      WHERE R.StorerKey = @cStorerKey
         AND RD.ExternReceiptKey = @cRefNo
      IF @nCount = 0
      BEGIN
         SET @nErrNo = 188851
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --RefNo NotInASN
         GOTO Quit
      END

      IF @nCount > 1
      BEGIN
         SET @nErrNo = 188852
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --RefNo MultiASN
         GOTO Quit
      END
   END
   
Quit:

END

SET QUOTED_IDENTIFIER OFF

GO