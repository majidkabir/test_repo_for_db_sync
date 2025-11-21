SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_521ExtValid06                                   */
/* Purpose: Validate putaway no allow reput                            */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2022-12-23 1.0  yeekung    WMS-21416. Created                        */
/************************************************************************/

CREATE   PROC [RDT].[rdt_521ExtValid06] (
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nInputKey       INT,
   @cStorerKey      NVARCHAR( 15),
   @cUCCNo          NVARCHAR( 20),
   @cSuggestedLOC   NVARCHAR( 10),
   @cToLOC          NVARCHAR( 10),
   @nErrNo          INT OUTPUT,
   @cErrMsg         NVARCHAR( 20) OUTPUT
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @cFromLOC      NVARCHAR( 10),
            @cFacility     NVARCHAR( 5)

   SET @nErrNo = 0
   SET @cErrMSG = ''

   IF @nInputKey = 1
   BEGIN
      IF @nStep = 1
      BEGIN
         IF EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                     AND   UCCNo = @cUCCNo
                     AND  ISNULL(ID,'')='')
         BEGIN
            SET @nErrNo = 194251
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidUCC'
            GOTO Quit
         END
      END
   END

QUIT:



GO