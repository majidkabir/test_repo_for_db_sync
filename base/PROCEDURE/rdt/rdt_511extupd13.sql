SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_511ExtUpd13                                     */
/* Copyright      : Maersk                                              */
/* Purpose: For Grape Galina                                            */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev    Author   Purposes                                  */
/* 2025-02-14 1.0.0  JCH507   FCR-2597. Created                         */
/************************************************************************/

CREATE   PROC [RDT].[rdt_511ExtUpd13] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cFromID        NVARCHAR( 18),
   @cFromLOC       NVARCHAR( 10),
   @cToLOC         NVARCHAR( 10),
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @bDebugFlag           BINARY = 0
   DECLARE @cNewTaskDetailKey    NVARCHAR( 10)
   DECLARE @cKITUsrDef4          NVARCHAR( 30)
   DECLARE @nSuccess             INT
   DECLARE @cPriority            NVARCHAR( 1)
   DECLARE @cTaskFromLogiLoc     NVARCHAR( 10)
   DECLARE @cTaskToLogiLoc       NVARCHAR( 10)
   DECLARE @cKitkey              NVARCHAR( 10)

   IF @nFunc = 511 -- Move by ID
   BEGIN
      IF @nStep = 3 -- ToLOC
      BEGIN
         IF @bDebugFlag = 1
            SELECT 'Step 3 validation'

         IF @nInputKey = 1
         BEGIN
            SELECT TOP 1
               @cKitkey = KIT.KITKey,
               @cKITUsrDef4 = ISNULL(KIT.USRDEF4, '')
            FROM KIT WITH (NOLOCK)
            JOIN KITDETAIL WITH (NOLOCK) 
               ON KIT.KITKey = KITDETAIL.KITKey
            WHERE KIT.Facility = @cFacility
               AND   KIT.StorerKey = @cStorerKey
               AND   KIT.[Status] <> '9'
               AND   KITDETAIL.Id = @cFromID
               AND   KITDETAIL.[Type] = 'F'

            IF @@ROWCOUNT = 0
            BEGIN
               SET @nErrNo = 233351
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ID not associated
               GOTO Quit
            END

            IF @cKITUsrDef4 = ''
            BEGIN
               SET @nErrNo = 233352
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No production line  
               GOTO Quit
            END

            IF @bDebugFlag = 1
               SELECT @cKITUsrDef4 AS FinalToLoc, @cFromID AS FromID, @cToLOC AS ToLOC

            --Task from loc is the location pallet move to
            --Task to loc is the final production line
            SELECT @cTaskFromLogiLoc = ISNULL(LogicalLocation,'') FROM LOC WITH (NOLOCK) 
            WHERE Facility = @cFacility 
               AND LOC = @cToLOC

            SELECT @cTaskToLogiLoc = ISNULL(LogicalLocation,'') FROM LOC WITH (NOLOCK) 
            WHERE Facility = @cFacility 
               AND LOC = @cKITUsrDef4

            
            -- Get new TaskDetailKeys      
            SET @nSuccess = 1
            EXECUTE dbo.nspg_getkey      
               'TASKDETAILKEY'      
               , 10      
               , @cNewTaskDetailKey OUTPUT      
               , @nSuccess          OUTPUT      
               , @nErrNo            OUTPUT      
               , @cErrMsg           OUTPUT      
            IF @nSuccess <> 1      
            BEGIN      
               SET @nErrNo = 128701      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nspg_getkey      
               GOTO Quit      
            END

            SET @cPriority = '9'
            -- Insert final task
            BEGIN TRY
               INSERT INTO TaskDetail (
                  TaskDetailKey, TaskType, Status, UserKey, FromLOC, LogicalFromLoc, FromID, ToLOC, LogicalToLoc, ToID, 
                  QTY, CaseID, AreaKey, UOMQty, PickMethod, StorerKey, SKU, LOT, ListKey, SourceType, SourceKey, WaveKey, 
                  Priority, TrafficCop)
               VALUES (
                  @cNewTaskDetailKey, 'ASTMV', '0', '', @cToLOC, @cTaskFromLogiLoc, @cFromID, @cKITUsrDef4, @cTaskToLogiLoc, @cFromID, 
                  0, '', '', 0, 'FP', @cStorerKey, '', '',  '', 'rdt_511ExtUpd13',  @cKitkey, '', 
                  @cPriority, NULL)
            END TRY
            BEGIN CATCH
               SET @nErrNo = 74303
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsTaskDetFail
               GOTO Quit
            END CATCH

         END
      END
   END

   Quit:
END

GO