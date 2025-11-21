SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1770ExtVal02                                    */
/* Purpose: Send command to Junheinrich direct equipment to location    */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2014-07-08   Ung       1.0   SOS327467 Created                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1770ExtVal02]
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
            -- Check DropID
            IF @cDropID = ''
            BEGIN
               SET @nErrNo = 51751
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need DropID
               EXEC rdt.rdtSetFocusField @nMobile, 4 -- DropID
               GOTO Quit
            END
            
            -- Get storer
            DECLARE @cStorerKey NVARCHAR(15)
            SELECT @cStorerKey = StorerKey FROM TaskDetail WITH (NOLOCK) WHERE TaskDetailKey = @cTaskDetailKey
            
            -- Check duplicate
            IF EXISTS( SELECT 1 FROM PickDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND DropID = @cDropID)
            BEGIN
               SET @nErrNo = 51752
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DropID used
               EXEC rdt.rdtSetFocusField @nMobile, 4 -- DropID
               GOTO Quit
            END
         END
      END
   END
   GOTO Quit

Quit:

END

GO