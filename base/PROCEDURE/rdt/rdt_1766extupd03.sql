SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1766ExtUpd03                                    */
/* Purpose: For PAGE                                                    */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2025-02-11 1.0  JCH507     FCR-1917. Created                         */
/************************************************************************/

CREATE   PROC [RDT].[rdt_1766ExtUpd03] (
   @nMobile     INT,
   @nFunc       INT, 
   @cLangCode   NVARCHAR( 3), 
   @nStep       INT, 
   @nInputKey   INT, 
   @cFacility       NVARCHAR( 15), 
   @cStorerKey      NVARCHAR( 15), 
   @cTaskdetailkey  NVARCHAR( 20), 
   @cFromLoc        NVARCHAR( 20), 
   @cID             NVARCHAR( 20), 
   @cPickMethod     NVARCHAR( 20), 
   @nErrNo          INT           OUTPUT, 
   @cErrMsg         NVARCHAR( 20) OUTPUT  
)
AS
BEGIN

   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF 

   DECLARE
      @bDebugFlag      INT = 0,
      @cGroupkey       NVARCHAR( 10),
      @cTaskType       NVARCHAR( 10),
      @cUserName       NVARCHAR( 18),

      @cCCKey          NVARCHAR( 10),
      @cCCSheetNo      NVARCHAR( 10),
      @cCCDetailKey    NVARCHAR( 10),
      @cExcludeQtyPicked NVARCHAR( 1),
      @bSuccess        INT,
      @nSystemQty      INT

   SELECT
      @cGroupkey = GroupKey,
      @cTaskType = TaskType
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE TaskDetailKey = @cTaskdetailkey

   SELECT @cUserName = UserName FROM rdt.RDTMOBREC (NOLOCK) WHERE Mobile = @nMobile


   IF @bDebugFlag = 1
      SELECT @nFunc AS Func, @cTaskDetailKey AS TaskDetailKey, @cGroupkey AS GroupKey, @cTaskType AS TaskType, @nStep AS Step, @nInputKey AS InputKey

   IF @nFunc IN (1766,1794,1795) -- Handle CC & CCSUP
   BEGIN
      IF @nStep = 1
      BEGIN
         IF @nInputKey = 1
         BEGIN
            IF EXISTS (SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK) 
                        WHERE Storerkey = @cStorerKey 
                           AND TaskType = @cTaskType 
                           AND [Status] = '0' 
                           AND Groupkey = @cGroupkey
                           AND UserKeyOverRide = '')
            BEGIN
               BEGIN TRY
                  UPDATE dbo.TaskDetail SET
                     UserKeyOverRide = @cUserName
                  WHERE Storerkey = @cStorerKey
                     AND TaskType = @cTaskType
                     AND [Status] IN ('0','3')
                     AND (ISNULL(UserKey,'') = '' OR UserKey = @cUserName) 
                     AND Groupkey = @cGroupkey
               END TRY
               BEGIN CATCH
                  SET @nErrNo = 233051
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'
                  GOTO Quit
               END CATCH
            END
         END
      END

      IF @nStep = 6
      BEGIN
         IF @nInputKey = 0
         BEGIN
            BEGIN TRY
               --Clear the UserKeyOverRide when exit the task
               UPDATE dbo.TaskDetail SET
                  UserKeyOverRide = ''
               WHERE Storerkey = @cStorerKey
                  AND TaskType = @cTaskType
                  AND [Status] <> '9'
                  AND UserKeyOverRide = @cUserName 
                  AND Groupkey = @cGroupkey
            END TRY
            BEGIN CATCH
               SET @nErrNo = 233052
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'
               GOTO Quit
            END CATCH
         END
      END

      IF @nStep = 7
      BEGIN
         IF @nInputKey = 1
         BEGIN
            BEGIN TRY
               --Clear the UserKeyOverRide when exit the task
               UPDATE dbo.TaskDetail SET
                  UserKeyOverRide = ''
               WHERE Storerkey = @cStorerKey
                  AND TaskType = @cTaskType
                  AND [Status] <> '9'
                  AND UserKeyOverRide = @cUserName 
                  AND Groupkey = @cGroupkey
            END TRY
            BEGIN CATCH
               SET @nErrNo = 233053
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTaskFailed'
               GOTO Quit
            END CATCH
         END
      END
   END --Func

   Quit:
END

GO