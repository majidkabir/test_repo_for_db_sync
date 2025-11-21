SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_740ExtVal02                                     */
/* Purpose: Trolley build                                               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2017-04-07 1.0  James      WMS1398. Created                          */
/************************************************************************/

CREATE PROC [RDT].[rdt_740ExtVal02] (
   @nMobile       INT,
   @nFunc         INT, 
   @cLangCode     NVARCHAR( 3), 
   @nStep         INT, 
   @nInputKey     INT, 
   @cStorerKey    NVARCHAR( 15), 
   @cUCC          NVARCHAR( 20),
   @cPutawayZone  NVARCHAR( 10),
   @cSuggestedLOC NVARCHAR( 10),
   @cTrolleyNo    NVARCHAR( 10),
   @nErrNo        INT           OUTPUT, 
   @cErrMsg       NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   
   IF @nFunc = 740 -- Trolley build
   BEGIN
      IF @nStep = 2 -- Close trolley
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF NOT EXISTS ( SELECT 1 FROM DeviceProfile WITH (NOLOCK) WHERE DeviceID = @cTrolleyNo)
            BEGIN
               SET @nErrNo = 107601
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Bad TrolleyNo
               GOTO Fail
            END
         END
      END
   END
      
Quit:
Fail:

END

GO