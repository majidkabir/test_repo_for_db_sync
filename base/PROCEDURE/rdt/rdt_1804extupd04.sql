SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_1804ExtUpd04                                    */
/* Purpose:                                                             */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2017-05-03   ChewKP    1.0   WMS-1996 Created                        */
/************************************************************************/
CREATE PROCEDURE [RDT].[rdt_1804ExtUpd04]
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR( 3)
   ,@nStep           INT
   ,@cStorerKey      NVARCHAR( 15)
   ,@cFacility       NVARCHAR(  5)
   ,@cFromLOC        NVARCHAR( 10)
   ,@cFromID         NVARCHAR( 18)
   ,@cSKU            NVARCHAR( 20)
   ,@nQTY            INT
   ,@cUCC            NVARCHAR( 20)
   ,@cToID           NVARCHAR( 18)
   ,@cToLOC          NVARCHAR( 10)
   ,@nErrNo          INT           OUTPUT
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount 			INT
   	    ,@cTaskDetailKey 	NVARCHAR(10) 
          ,@cToLocLogicalLoc  NVARCHAR(18) 
          ,@cToLocPutawayZone NVARCHAR(10) 
          ,@b_success         INT
   				
   SET @nTranCount = @@TRANCOUNT

   -- Move To UCC
   IF @nFunc = 1804
   BEGIN
      IF @nStep = 8 -- Close Pallet
      BEGIN
      		SELECT @cToLocLogicalLoc = LogicalLocation
      					,@cToLocPutawayZone = PutawayZone
      		FROM dbo.Loc WITH (NOLOCK) 
      		WHERE Facility = @cFacility 
      		AND Loc = @cToLoc
      		
      		-- Get new TaskDetailKey
		      SET @b_success = 1
		      EXECUTE dbo.nspg_getkey
		         'TaskDetailKey'
		         , 10
		         , @cTaskDetailKey OUTPUT
		         , @b_success OUTPUT
		         , @nErrNo    OUTPUT
		         , @cErrMsg   OUTPUT
		         
		      IF @b_success <> 1
		      BEGIN
		         SET @nErrNo = 108752
		         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKey Fail
		         GOTO Quit
		      END
      
		      -- Insert TaskDetail
		      INSERT INTO TaskDetail (
		         TaskDetailKey, RefTaskKey, ListKey, Status, UserKey, ReasonKey, DropID, QTY, SystemQTY, ToLOC, ToID, 
		         TaskType, Storerkey, Sku, LOT, UOM, UOMQTY, FromLOC, LogicalFromLOC, FromID, LogicalToLOC, CaseID, PickMethod, StatusMsg, Priority, SourcePriority, HoldKey, UserPosition, UserKeyOverRide, SourceType, SourceKey, PickDetailKey, OrderKey, OrderLineNumber, WaveKey, Message01, Message02, Message03, LoadKey, AreaKey)
		      VALUES (    
		         @cTaskDetailKey, '', '', '0', '', '', '', 0, 0, 
		         '', 
		         '', 
		         'PAF', @cStorerKey, '', '', '', '', @cToLOC, @cToLocLogicalLoc, @cToID, '', '', 'PP', '', '9', '9', '', '', '', 'rdt_1804ExtUpd04', @cToID, '', '', '', '', '', '', '', '', '' ) 
		      
		      IF @@ERROR <> 0
		      BEGIN
		         SET @nErrNo = 108751
		         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsTaskdetFail
		         GOTO Quit
		      END
      END
   END

Quit:

END

GO