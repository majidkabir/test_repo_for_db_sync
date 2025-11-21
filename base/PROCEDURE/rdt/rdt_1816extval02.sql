SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1816ExtVal02                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Validate location type                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2015-09-19   James     1.0   SOS335049 Created                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1816ExtVal02]
    @nMobile         INT 
   ,@nFunc           INT 
   ,@cLangCode       NVARCHAR( 3) 
   ,@nStep           INT 
   ,@nInputKey       INT
   ,@cTaskdetailKey  NVARCHAR( 10)
   ,@cFinalLOC       NVARCHAR( 10)
   ,@nErrNo          INT           OUTPUT 
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- TM assist NMV
   IF @nFunc = 1816
   BEGIN
      IF @nStep = 1 -- FinalLOC
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            DECLARE @cFromLOC NVARCHAR(10)
            DECLARE @cFromID  NVARCHAR(18)
            DECLARE @cOrderKey NVARCHAR(10)
            DECLARE @cLoadKey  NVARCHAR(10)
            DECLARE @cSuggToLOC NVARCHAR(10)
            DECLARE @cToLOCCategory NVARCHAR( 10)
            
            SET @cFromLOC = ''
            SET @cFromID = ''
            SET @cOrderKey = ''
            SET @cLoadKey = ''
            SET @cSuggToLOC = ''
            SET @cToLOCCategory = ''

            SELECT @cSuggToLOC = ToLOC FROM dbo.TaskDetail WITH (NOLOCK) WHERE TaskDetailKey = @cTaskdetailKey

            SELECT @cToLOCCategory = LocationCategory 
            FROM dbo.TaskDetail TD WITH (NOLOCK) 
            JOIN dbo.LOC LOC WITH (NOLOCK) ON TD.ToLOC = LOC.LOC
            WHERE TD.TaskDetailKey = @cTaskdetailKey
            
            IF @cToLOCCategory <> 'FMSTAGE'
            BEGIN
               -- Check LOC category
               IF NOT EXISTS( SELECT 1 FROM LOC WITH (NOLOCK) WHERE LOC = @cFinalLOC AND LocationCategory = 'STAGING')
               BEGIN
                  SET @nErrNo = 56551
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not stage LOC
                  GOTO Quit
               END
            END

            IF @cToLOCCategory = 'FMSTAGE'
            BEGIN
               -- Check LOC category
               IF NOT EXISTS( SELECT 1 FROM LOC WITH (NOLOCK) WHERE LOC = @cFinalLOC AND LocationCategory IN ('STAGING', 'FMSTAGE'))
               BEGIN
                  SET @nErrNo = 56552
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not stage LOC
                  GOTO Quit
               END
            END

            -- When ToLoc (TaskDetail.ToLoc) LocationCategory = FMSTAGE, Allow user to scan new ToLoc
            IF @cFinalLOC <> @cSuggToLOC AND @cToLOCCategory <> 'FMSTAGE'
            BEGIN
               SET @nErrNo = 56553
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Different LOC
               GOTO Quit
            END
         END
      END
   END

Quit:

END


GO