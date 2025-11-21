SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1841UCCNoLKUP01                                       */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Purpose: Lookup uccno from receiptdetail.userdefine01                      */
/*                                                                            */
/*                                                                            */
/* Date         Rev  Author     Purposes                                      */
/* 2021-04-06   1.0  James      WMS-16725. Created                            */
/******************************************************************************/
CREATE  PROC rdt.rdt_1841UCCNoLKUP01(
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5),
   @cStorerKey    NVARCHAR( 15),
   @cReceiptKey   NVARCHAR( 10),
   @cLane         NVARCHAR( 10),
   @cBarcode      NVARCHAR( 60),
   @cUCCNo        NVARCHAR( 20) OUTPUT,
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @cBarcode = ''
      GOTO Quit

   IF NOT EXISTS ( SELECT 1 FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
                   WHERE ReceiptKey = @cReceiptKey
                   AND   UserDefine01 = @cBarcode)
   BEGIN
      SET @nErrNo = 165601
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid UCCNo
      GOTO Quit
   END

   SET @cUCCNo = @cBarcode

Quit:

END

GO