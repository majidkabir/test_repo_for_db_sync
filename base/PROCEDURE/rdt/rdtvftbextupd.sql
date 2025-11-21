SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtVFTBExtUpd                                       */
/* Purpose: Trolley build                                               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2013-05-20 1.0  Ung        SOS259761. Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdtVFTBExtUpd] (
   @nMobile       INT,
   @nFunc         INT, 
   @cLangCode     NVARCHAR( 3), 
   @nStep         INT, 
   @cStorerKey    NVARCHAR( 15), 
   @cUCC          NVARCHAR( 20),
   @cPutawayZone  NVARCHAR( 10),
   @cSuggestedLOC NVARCHAR( 10),
   @cTrolleyNo    NVARCHAR( 10),
   @nErrNo        INT       OUTPUT, 
   @cErrMsg       NVARCHAR( 20) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

IF @nStep = 2
BEGIN
   IF LEFT( @cTrolleyNo, 3) <> 'TRO'
   BEGIN
      SET @nErrNo = 81201
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Bad TrolleyNo
   END
END

Quit:
Fail:

GO