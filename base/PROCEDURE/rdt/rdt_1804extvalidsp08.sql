SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1804ExtValidSP08                                */
/* Purpose: Validate  UCC                                               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2023-03-13 1.0  Ung        WMS-21971 Created                         */
/************************************************************************/

CREATE   PROC [RDT].[rdt_1804ExtValidSP08] (
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
      IF @nStep = 3 -- From LOC
      BEGIN
         -- IF @nInputKey = 1 -- ENTER
         BEGIN
            -- For staging LOC
            IF EXISTS( SELECT 1
               FROM dbo.LOC WITH (NOLOCK)
               WHERE LOC = @cFromLOC
                  AND LocationHandling = '9' 
                  AND LocationCategory = 'STAGING')
            BEGIN
               SET @nErrNo = 197751
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NotForSTAGELOC
               GOTO Quit
            END
         END
      END
   END

Quit:

END

GO