SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1580RefNoLKUP01                                       */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Lookup RefNo by multiple fields                                   */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 22-Jan-2018  James     1.0   WMS3799. Created                              */
/* 15-Mar-2018  James     1.1   Add filter ASNStatus (james01)                */
/* 24-May-2019  James     1.2   WMS-9128 Add ASNStatus 1 (james02)            */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1580RefNoLKUP01]
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
   
   DECLARE @nRowCount INT

   IF @nFunc IN ( 1580, 1581) -- Piece receiving
   BEGIN  

      IF @cReceiptKey = ''
      BEGIN
         SELECT @cReceiptKey = ReceiptKey 
         FROM dbo.Receipt WITH (NOLOCK) 
         WHERE Facility = @cFacility
         AND   StorerKey = @cStorerKey
         AND   Status <> '9'
         AND   UserDefine04 = @cRefNo
         AND   ASNStatus IN ( '0', '1')   -- (james01)/(james02)
         SELECT @nRowCount = @@ROWCOUNT
      END

      IF @cReceiptKey = ''
      BEGIN
         SELECT @cReceiptKey = R.ReceiptKey 
         FROM dbo.Receipt R WITH (NOLOCK) 
         JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON R.ReceiptKey = RD.ReceiptKey
         WHERE R.Facility = @cFacility
         AND   R.StorerKey = @cStorerKey
         AND   R.Status <> '9'
         AND   RD.UserDefine03 = @cRefNo
         AND   R.ASNStatus IN ( '0', '1')   -- (james01)/(james02)
         SELECT @nRowCount = @@ROWCOUNT
      END

      -- Check RefNo in ASN
      IF @nRowCount = 0
      BEGIN
         SET @nErrNo = 118851
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --RefNo NotInASN
         GOTO Quit
      END

      -- Check RefNo in ASN
      IF @nRowCount > 1
      BEGIN
         SET @nErrNo = 118852
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --RefNo MultiASN
         GOTO Quit
      END
   END
   
Quit:

END

SET QUOTED_IDENTIFIER OFF

GO