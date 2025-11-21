SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1770ExtVal03                                    */
/* Purpose: FOR VLT                                                     */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2024-10-23   Dennis    1.0   FCR-775 Created                         */
/************************************************************************/

CREATE   PROCEDURE rdt.rdt_1770ExtVal03
    @nMobile         INT 
   ,@nFunc           INT 
   ,@cLangCode       NVARCHAR( 3) 
   ,@nStep           INT 
   ,@nInputKey       INT
   ,@cTaskdetailKey  NVARCHAR( 10)
   ,@nQTY            INT
   ,@cToLOC          NVARCHAR( 10)
   ,@cDropID         NVARCHAR( 20)
   ,@nErrNo          INT           OUTPUT 
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- TM Pallet Pick
   IF @nFunc = 1770
   BEGIN
      IF @nStep = 4 -- ToLOC, DropID
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Get storer
            DECLARE @cStorerKey NVARCHAR(15),
            @cSuggToLOC         NVARCHAR(10),
            @cFacility          NVARCHAR(5)

            SELECT @cFacility = Facility FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE  Mobile = @nMobile       
            SELECT @cStorerKey = StorerKey, @cSuggToLOC = TOLOC FROM TaskDetail WITH (NOLOCK) WHERE TaskDetailKey = @cTaskDetailKey

            IF rdt.rdtGetConfig(@nFunc,'HUSQGRPPICK',@cStorerKey) = '1'
            BEGIN
               IF @cSuggToLOC <> @cToLOC
               BEGIN
                  IF EXISTS ( SELECT 1 FROM LOC WHERE LOC= @cSuggToLOC AND LocationType = N'STAGEOB' AND Facility = @cFacility)
                  BEGIN
                     SET @nErrNo = 226101
                     SET @cErrMsg = rdt.rdtgetmessageLong( @nErrNo, @cLangCode, 'DSP') -- 226101Cannot Override Marshalling Location
                     GOTO Quit
                  END
                  ELSE IF EXISTS ( SELECT 1 FROM LOC WHERE LOC= @cSuggToLOC AND LocationType = N'VAS' AND Facility = @cFacility)
                  AND NOT EXISTS( SELECT 1 FROM LOC WHERE LOC= @cToLOC AND LocationType = N'VAS' AND Facility = @cFacility)
                  BEGIN
                     SET @nErrNo = 226102
                     SET @cErrMsg = rdt.rdtgetmessageLong( @nErrNo, @cLangCode, 'DSP') -- 226102Cannot Override Not a VAS Location
                     GOTO Quit
                  END
                  ELSE IF NOT EXISTS ( SELECT 1 FROM LOC WHERE LOC= @cSuggToLOC AND LocationType = N'VAS' AND Facility = @cFacility)
                  AND NOT EXISTS( SELECT 1 FROM LOC WHERE LOC= @cSuggToLOC AND LocationType = N'STAGEOB' AND Facility = @cFacility)
                  BEGIN
                     SET @nErrNo = 90763
                     SET @cErrMsg = rdt.rdtgetmessageLong( @nErrNo, @cLangCode, 'DSP') --ToLOC Diff   
                     GOTO Quit
                  END
               END
               IF CHARINDEX(' ',@cDropID)>0 OR LEN(@cDropID) <> 18 OR CONVERT(NVARCHAR(30),substring(@cDropID,1,3)) <> '050'
               BEGIN
                  SET @nErrNo = 226103
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 226103Invalid Drop ID
                  GOTO Quit
               END
            END
            
         END
      END
   END
   GOTO Quit

Quit:

END

GO