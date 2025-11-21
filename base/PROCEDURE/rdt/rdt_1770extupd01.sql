SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1770ExtUpd01                                    */
/* Purpose: Send command to Junheinrich direct equipment to location    */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2014-07-08   Ung       1.0   SOS311415 Created                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1770ExtUpd01]
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
            DECLARE @cSuggToLOC NVARCHAR(10)
            DECLARE @cStatus NVARCHAR(10)

            -- Get TaskDetail info
            SELECT @cStatus = Status FROM TaskDetail WITH (NOLOCK) WHERE TaskDetailKey = @cTaskDetailKey
            SELECT @cSuggToLOC = O_Field02 FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile
            
            -- Generate DropID
            IF @cDropID <> '' AND @cToLOC <> @cSuggToLOC AND @cStatus = '9' AND @nQTY > 0
            BEGIN
               IF NOT EXISTS( SELECT 1 FROM DropID WITH (NOLOCK) WHERE DropID = @cDropID)
               BEGIN
                  INSERT INTO DropID (DropID, DropLOC) VALUES (@cDropID, @cToLOC)
               END
            END
         END
      END
   END
   GOTO Quit

Quit:

END

GO