SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtVFNMVExtUpd                                      */
/* Purpose: Overwrite DropID setting by TM Non-InventoryMove            */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2013-05-30   Ung       1.0   SOS279795 Created                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdtVFNMVExtUpd]
    @nMobile            INT 
   ,@nFunc              INT 
   ,@cLangCode          NVARCHAR( 3) 
   ,@nStep              INT 
   ,@cTaskdetailKey     NVARCHAR( 10) 
   ,@cToLOC             NVARCHAR( 10) 
   ,@cNextTaskDetailKey NVARCHAR( 10)
   ,@nErrNo             INT           OUTPUT 
   ,@cErrMsg            NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF


   -- TM Non-inventory move
   IF @nFunc = 1759
   BEGIN
      IF @nStep = 0 -- Init
         EXEC dbo.ispJungheinrich @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @nErrNo OUTPUT, @cErrMsg OUTPUT

      IF @nStep = 2 -- To LOC
      BEGIN
         DECLARE @cFromID NVARCHAR( 18)
         SET @cFromID = ''

         -- Get task info
         SELECT @cFromID = FromID
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE TaskDetailKey = @cTaskDetailKey

         -- Overwrite DropID setting that updated by TM Non-InventoryMove
         UPDATE dbo.DropID SET 
            DropLOC = @cToLOC,
            Status = '0', 
            Trafficcop = NULL
         WHERE DropID = @cFromID
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 81351
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdTaskdetFail
         END

         EXEC dbo.ispJungheinrich @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @nErrNo OUTPUT, @cErrMsg OUTPUT
      END
      
      IF @nStep = 4 -- Successful Message
      BEGIN
         DECLARE @cTaskType NVARCHAR( 10)
         
         -- Get task info
         SELECT @cTaskType = TaskType
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE TaskDetailKey = @cNextTaskDetailKey
         
         IF @cTaskType = 'NMV'
            EXEC dbo.ispJungheinrich @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cNextTaskDetailKey
      END

      IF @nStep = 5 -- From LOC
      BEGIN
         -- Get task info
         DECLARE @cSuggToLOC NVARCHAR(10)
         SET @cSuggToLOC = ''
         SELECT @cSuggToLOC = ToLOC FROM dbo.TaskDetail WITH (NOLOCK) WHERE TaskDetailKey = @cTaskDetailKey

         EXEC dbo.ispJungheinrich @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cSuggToLOC
      END

   END
END

Quit:

GO