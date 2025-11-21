SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1580RefNoLKUP02                                       */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Lookup RefNo by multiple fields                                   */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 22-Jan-2018  James     1.0   Created                                       */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1580RefNoLKUP02]
   @nMobile       INT,           
   @nFunc         INT,           
   @cLangCode     NVARCHAR( 3),  
   @cFacility     NVARCHAR( 5),  
   @cStorerGroup  NVARCHAR( 20), 
   @cStorerKey    NVARCHAR( 15), 
   @cRefNo        NVARCHAR( 20), 
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

   IF @nFunc IN ( 1580, 1581) -- Piece receiving
   BEGIN  
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
         SET @nErrNo = 119951
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --RefNo NotInASN
         GOTO Quit
      END

      IF @nCount > 1
      BEGIN
         SET @nErrNo = 119952
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --RefNo NotInASN
         GOTO Quit
      END
   END
   
Quit:

END

SET QUOTED_IDENTIFIER OFF

GO