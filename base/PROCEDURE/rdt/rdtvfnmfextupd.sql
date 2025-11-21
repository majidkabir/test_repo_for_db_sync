SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdtVFNMFExtUpd                                            */
/* Purpose: Send command to VNA truck                                         */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date        Ver   Author   Purposes                                        */
/* 07-05-2014  1.0   Ung      SOS309834. Created                              */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdtVFNMFExtUpd]
    @nMobile            INT 
   ,@nFunc              INT 
   ,@cLangCode          NVARCHAR( 3) 
   ,@nStep              INT 
   ,@cTaskdetailKey     NVARCHAR( 10) 
   ,@nErrNo             INT           OUTPUT 
   ,@cErrMsg            NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cTaskType NVARCHAR( 10)
   DECLARE @cSuggToLOC NVARCHAR(10)

   -- Get task info
   SELECT 
      @cTaskType = TaskType, 
      @cSuggToLOC = ToLOC
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE TaskDetailKey = @cTaskDetailKey

   -- Only NM1 need send VNA truck command
   IF @cTaskType <> 'NM1'
      GOTO Quit

   -- TM Non-inventory move
   IF @nFunc = 1746
   BEGIN
      IF @nStep = 0 -- Init
         EXEC dbo.ispJungheinrich @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @nErrNo OUTPUT, @cErrMsg OUTPUT

      IF @nStep = 2 -- From ID
         EXEC dbo.ispJungheinrich @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cSuggToLOC

      IF @nStep = 3 -- To LOC
         EXEC dbo.ispJungheinrich @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @nErrNo OUTPUT, @cErrMsg OUTPUT
      
      IF @nStep = 4 -- Successful Message
            EXEC dbo.ispJungheinrich @nMobile, @nFunc, @cLangCode, @nStep, @cTaskdetailKey, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cTaskDetailKey
   END
END

Quit:

GO