SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdtVFTWUCCRcvExtUpd                                 */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Check UCC scan to ID have same SKU, QTY, L02                */
/*                                                                      */
/* Called from:                                                         */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 12-09-2012  1.0  Ung         SOS255639. Created                      */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdtVFTWUCCRcvExtUpd]
    @nMobile     INT
   ,@nFunc       INT
   ,@nStep       INT
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
   ,@cSKU        NVARCHAR( 20)
   ,@nQTY        INT
   ,@cParam1     NVARCHAR( 20) OUTPUT
   ,@cParam2     NVARCHAR( 20) OUTPUT
   ,@cParam3     NVARCHAR( 20) OUTPUT
   ,@cParam4     NVARCHAR( 20) OUTPUT
   ,@cParam5     NVARCHAR( 20) OUTPUT
   ,@cOption     NVARCHAR( 1)
   ,@nErrNo      INT       OUTPUT
   ,@cErrMsg     NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   IF @nStep = 10 -- Param1..5
   BEGIN
      IF @cParam1 = '' -- UCC.ExternKey      
      BEGIN
         SET @nErrNo = 81451
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need CustPO
         GOTO Quit
      END

      -- Get ReceiptDetail info
      IF NOT EXISTS( SELECT TOP 1 1 
         FROM dbo.ReceiptDetail WITH (NOLOCK) 
         WHERE ReceiptKey = @cReceiptKey
            AND RTRIM( ExternReceiptKey) = @cParam1)
      BEGIN
         SET @nErrNo = 81452
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CustPONotFound
         GOTO Quit
      END

      -- Get Receipt info
      DECLARE @cStorerKey NVARCHAR( 15)
      SELECT @cStorerKey = StorerKey FROM Receipt WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey

      -- Insert new UCC
      IF NOT EXISTS( SELECT 1 FROM dbo.UCC WHERE UCCNo = @cUCC AND StorerKey = @cStorerKey)
      BEGIN
         INSERT INTO dbo.UCC (StorerKey, UCCNo, Status, SKU, QTY, LOC, ID, ExternKey)
         VALUES (@cStorerKey, @cUCC, '0', @cSKU, @nQTY, @cLOC, @cToID, @cParam1)
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 81453
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS UCC fail
            GOTO Quit
         END
      END
   END

QUIT:
END -- End Procedure


GO