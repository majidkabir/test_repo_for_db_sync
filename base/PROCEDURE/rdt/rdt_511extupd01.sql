SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_511ExtUpd01                                     */  
/* Purpose: Validate UCC                                                */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2015-04-23 1.0  Ung        SOS340174 Created                         */ 
/* 2015-06-11 1.1  Ung        SOS340174 Fix only generate task for VNAKP*/
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_511ExtUpd01] (  
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
  
   IF @nFunc = 511 -- Move by ID
   BEGIN  
      IF @nStep = 3 -- ToLOC
      BEGIN
         -- Generate putaway task
         IF EXISTS( SELECT 1 FROM LOC WITH (NOLOCK) WHERE LOC = @cToLOC AND LocationCategory = 'VNAKP')
         BEGIN
            IF NOT EXISTS( SELECT 1 
               FROM dbo.TaskDetail TD WITH (NOLOCK) 
                  JOIN LOC WITH (NOLOCK) ON (TD.FromLOC = LOC.LOC AND LOC.LocationCategory = 'VNAKP')
               WHERE TaskType = 'PAF' 
                  AND StorerKey = @cStorerKey 
                  AND FromID = @cFromID)
            BEGIN
               -- Get PickMethod (1 SKU 1 QTY = FP, the rest = PP)
               DECLARE @cPickMethod NVARCHAR(10)
               SELECT @cPickMethod = CASE WHEN COUNT( DISTINCT SKU) = 1 THEN 'FP' ELSE 'PP' END
               FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND LOC = @cToLOC
                  AND ID = @cFromID
                  AND QTY - QTYPicked > 0
               IF @cPickMethod = 'FP'
                  SELECT @cPickMethod = CASE WHEN COUNT( DISTINCT QTY) = 1 THEN 'FP' ELSE 'PP' END
                  FROM dbo.UCC WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey 
                     AND LOC = @cToLOC
                     AND ID = @cFromID
                     AND Status = '1'
                  
               -- Get new TaskDetailKey
               DECLARE @cTaskDetailKey NVARCHAR(10)
               DECLARE @nSuccess INT
            	SET @nSuccess = 1
            	EXECUTE dbo.nspg_getkey
            		'TASKDETAILKEY'
            		, 10
            		, @cTaskDetailKey OUTPUT
            		, @nSuccess       OUTPUT
            		, @nErrNo         OUTPUT
            		, @cErrMsg        OUTPUT
               IF @nSuccess <> 1
               BEGIN
                  SET @nErrNo = 53851
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKey Fail
                  GOTO Quit
               END
   
               -- Insert putaway task
               INSERT INTO TaskDetail (
                  TaskDetailKey, Storerkey, TaskType, Fromloc, FromID, PickMethod, Status, Priority, SourcePriority, SourceType, SourceKey, TrafficCop)
               VALUES (
                  @cTaskDetailKey, @cStorerKey, 'PAF', @cToLOC, @cFromID, @cPickMethod, '0', '5', '5', 'rdt_511ExtUpd01', '', NULL)
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 53852
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsTaskDetFail
                  GOTO Quit
               END
            END
         END
      END
   END  
  
Quit:  

END

GO