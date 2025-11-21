SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1804ExtValidSP07                                */
/* Purpose: Validate  UCC                                               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2022-04-11 1.0  Ung        WMS-19419 Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_1804ExtValidSP07] (
     @nMobile         INT,
     @nFunc           INT,
     @cLangCode       NVARCHAR(3),
     @nStep           INT,
     @cStorerKey      NVARCHAR(15),
     @cFacility       NVARCHAR(5),
     @cFromLOC        NVARCHAR(10),
     @cFromID         NVARCHAR(18),
     @cSKU            NVARCHAR(20),
     @nQTY            INT,
     @cUCC            NVARCHAR(20),
     @cToID           NVARCHAR(18),
     @cToLOC          NVARCHAR(10),
     @nErrNo          INT          OUTPUT,
     @cErrMsg         NVARCHAR(20) OUTPUT
)
AS
BEGIN 
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 1804
   BEGIN
      IF @nStep = 7
      BEGIN
         DECLARE @cStatus NVARCHAR( 1)
         SELECT @cStatus = Status
         FROM dbo.UCC WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND UCCNo = @cUCC

         -- No Record
         IF @cStatus >= '1'
         BEGIN
            SET @nErrNo = 185651
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid UCC
            GOTO Quit
         END
      END
   END

Quit:

END

GO