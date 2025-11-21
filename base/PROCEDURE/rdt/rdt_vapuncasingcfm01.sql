SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_VAPUnCasingCfm01                                */
/* Purpose: VAP confirm uncasing module for DGE. Insert/Update into     */
/*          workorder_uncasing table.                                   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2016-02-02 1.0  James      SOS315942. Created                        */
/* 2016-02-17 1.1  James      Bug fix on qty move on pallet contain     */
/*                            same sku > 1 lot# (james01)               */
/* 2016-02-25 1.2  James      SOS364219 - Add total id qty for recon    */
/*                            purpose used in exceed (james02)          */
/************************************************************************/

CREATE PROC [RDT].[rdt_VAPUnCasingCfm01] (
   @nMobile          INT, 
   @nFunc            INT, 
   @nStep            INT, 
   @nInputKey        INT, 
   @cLangCode        NVARCHAR( 3),  
   @cStorerkey       NVARCHAR( 15), 
   @cWorkStation     NVARCHAR( 20),
   @cJobKey          NVARCHAR( 10),
   @cWorkOrderKey    NVARCHAR( 10),
   @cTaskDetailKey   NVARCHAR( 10),
   @cID              NVARCHAR( 18),
   @cSKU             NVARCHAR( 20),
   @cLOT             NVARCHAR( 10), 
   @nQty             INT, 
   @dStartDate       DATETIME, 
   @nErrNo           INT           OUTPUT, 
   @cErrMsg          NVARCHAR( 20) OUTPUT  
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @cFacility      NVARCHAR( 5), 
           @cUserName      NVARCHAR( 18), 
           @cFromLOC       NVARCHAR( 10), 
           @cToLOC         NVARCHAR( 10), 
           @cToID          NVARCHAR( 18), 
           @nQty2UnCase    INT,
           @nTtl_LotQty    INT,
           @nStartTCnt     INT,
           @nSystemQty     INT         -- (james02)

   DECLARE 	@cLottable01         NVARCHAR( 18),
	         @cLottable02         NVARCHAR( 18),
	         @cLottable03         NVARCHAR( 18),
            @dLottable04         DATETIME,
	         @dLottable05         DATETIME,
            @cLottable06         NVARCHAR( 30),
            @cLottable07         NVARCHAR( 30),
            @cLottable08         NVARCHAR( 30),
            @cLottable09         NVARCHAR( 30),
            @cLottable10         NVARCHAR( 30),
            @cLottable11         NVARCHAR( 30),
            @cLottable12         NVARCHAR( 30),
            @dLottable13         DATETIME,
            @dLottable14         DATETIME,
            @dLottable15         DATETIME

   SELECT @cUserName = UserName, 
          @cFacility = Facility 
   FROM RDT.RDTMOBREC WITH (NOLOCK) 
   WHERE MOBILE = @nMobile

   SET @nStartTCnt = @@TRANCOUNT  
   BEGIN TRAN  
   SAVE TRAN rdt_VAPUnCasingCfm01  
   
   SET @nErrNo = 0

   IF ISNULL( @cWorkStation, '') = ''
      SELECT @cWorkStation = WorkStation
      FROM dbo.WorkStation WITH (NOLOCK)
      WHERE WorkOrderKey = @cWorkOrderKey
      AND   JobKey = @cJobKey
      AND   [Status] = '1'

   SELECT @cToLOC = Location
   FROM dbo.WorkStationLoc WITH (NOLOCK)
   WHERE LocType = 'InLOC'
   AND WorkStation = @cWorkStation

   -- (james02)
   -- Get total pallet qty at the time of uncasing (for reconciliation purpose in exceed)
   SELECT @nSystemQty = ISNULL( SUM(Qty - QtyAllocated - QtyPicked), 0)
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
   JOIN dbo.LOC LOC WITH (NOLOCK) ON LLI.LOC = LOC.LOC
   WHERE StorerKey = @cStorerKey
   AND   ID = @cID
   AND   Facility = @cFacility

   DECLARE CUR_INS CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
   SELECT LLI.LOT, LLI.LOC, ISNULL( SUM( LLI.Qty - LLI.QtyPicked), 0)
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
   JOIN dbo.LOC LOC WITH (NOLOCK) ON LLI.LOC = LOC.LOC
   WHERE StorerKey = @cStorerKey
   AND   ID = @cID
   AND   Facility = @cFacility
   AND   ( Qty - QtyPicked) > 0
   AND   SKU = @cSKU
   AND   LOT = @cLOT
   GROUP BY LLI.LOT, LLI.LOC, LLI.SKU
   OPEN CUR_INS
   FETCH NEXT FROM CUR_INS INTO @cLOT, @cFromLOC, @nTtl_LotQty
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF @nQty < @nTtl_LotQty
         SET @nQty2UnCase = @nQty
      ELSE
         SET @nQty2UnCase = @nTtl_LotQty

      -- If it is inventory label then transfer to pallet id DGELABEL
      IF EXISTS ( SELECT 1 FROM dbo.SKU WITH (NOLOCK) 
                  WHERE StorerKey = @cStorerKey
                  AND   SKU = @cSKU
                  AND   BUSR3 = 'DGE-PKG')
         SET @cToID = 'DGELABEL'
      ELSE
         SET @cToID = @cID

      SELECT @cLottable01 = Lottable01, 
             @cLottable02 = Lottable02, 
             @cLottable03 = Lottable03, 
             @dLottable04 = Lottable04, 
             @dLottable05 = Lottable05,
             @cLottable06 = Lottable06, 
             @cLottable07 = Lottable07, 
             @cLottable08 = Lottable08, 
             @cLottable09 = Lottable09, 
             @cLottable10 = Lottable10,
             @cLottable11 = Lottable11, 
             @cLottable12 = Lottable12, 
             @dLottable13 = Lottable13, 
             @dLottable14 = Lottable14, 
             @dLottable15 = Lottable15, 
             @cSKU = SKU
      FROM dbo.LOTAttribute WITH (NOLOCK) 
      WHERE LOT = @cLot

      IF NOT EXISTS ( SELECT 1 FROM dbo.WorkOrder_UnCasing WITH (NOLOCK) 
                        WHERE ID = @cToID
                        AND   WorkStation = @cWorkStation
                        AND   WorkOrderKey = @cWorkOrderKey
                        AND   JobKey = @cJobKey
                        AND   Lot = @cLot
                        AND   [Status] = '3')
      BEGIN
         INSERT INTO dbo.WorkOrder_UnCasing 
            (WorkStation, JobKey, WorkOrderKey, StorerKey, 
            SKU, Qty, QtyRemaining, QtyCompleted, ID, SSCC, InLOC, OutLoc, Lot,
            Lottable01, Lottable02, Lottable03, Lottable04, Lottable05,
            Lottable06, Lottable07, Lottable08, Lottable09, Lottable10,
            Lottable11, Lottable12, Lottable13, Lottable14, Lottable15,
            Status, StartDate, EndDate, AddDate, EditDate, AddWho, EditWho, SystemQty)
         VALUES
            (@cWorkStation, @cJobKey, @cWorkOrderKey, @cStorerKey,
            @cSKU, @nQty2UnCase, @nQty2UnCase, 0, @cToID, '', @cFromLOC, @cToLOC, @cLOT,
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
            '3', GETDATE(), NULL, GETDATE(), GETDATE(), @cUserName, @cUserName, @nSystemQty)
      	   
	      IF @@ERROR <> 0 
	      BEGIN
            CLOSE CUR_INS
            DEALLOCATE CUR_INS
	      	SET @nErrNo = 59901
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins uncasing fail
            GOTO RollBackTran
	      END
      END
      ELSE
      BEGIN
         UPDATE dbo.WorkOrder_UnCasing WITH (ROWLOCK) SET 
            Qty = Qty + @nQty2UnCase, 
            QtyRemaining = QtyRemaining + @nQty2UnCase 
         WHERE ID = @cToID
         AND   WorkStation = @cWorkStation
         AND   WorkOrderKey = @cWorkOrderKey
         AND   JobKey = @cJobKey
         AND   Lot = @cLot
         AND   [Status] = '3'

	      IF @@ERROR <> 0 
	      BEGIN
            CLOSE CUR_INS
            DEALLOCATE CUR_INS
	      	SET @nErrNo = 59902
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd uncasing fail
            GOTO RollBackTran
	      END
      END

      EXECUTE rdt.rdt_Move
         @nMobile     = @nMobile,
         @cLangCode   = @cLangCode,
         @nErrNo      = @nErrNo  OUTPUT,
         @cErrMsg     = @cErrMsg OUTPUT, 
         @cSourceType = 'rdtfnc_VAP_Uncasing',
         @cStorerKey  = @cStorerKey,
         @cFacility   = @cFacility,
         @cFromLOC    = @cFromLOC,
         @cToLOC      = @cToLOC,
         @cFromID     = @cID,    
         @cToID       = @cToID,  
         @cSKU        = @cSKU,
         @nQTY        = @nQty2UnCase,
         @cFromLOT    = @cLot    -- (james01)


      IF @nErrNo <> 0
	   BEGIN
         CLOSE CUR_INS
         DEALLOCATE CUR_INS
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Move case fail
         GOTO RollBackTran
	   END

      SET @nQty = @nQty - @nQty2UnCase

      IF @nQty <= 0
         BREAK

      FETCH NEXT FROM CUR_INS INTO @cLOT, @cFromLOC, @nTtl_LotQty
   END
   CLOSE CUR_INS
   DEALLOCATE CUR_INS

   UPDATE dbo.TaskDetail WITH (ROWLOCK) SET 
      [Status] = '3', 
      UserKey = @cUserName
   WHERE TaskDetailKey = @cTaskDetailKey
   AND   [Status] = '0'

	IF @@ERROR <> 0 
	BEGIN
	   SET @nErrNo = 59903
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd task fail
      GOTO RollBackTran
	END

   GOTO Quit

   RollbackTran:
      ROLLBACK TRAN rdt_VAPUnCasingCfm01  
  
   Quit:
   WHILE @@TRANCOUNT > @nStartTCnt -- Commit until the level we started  
      COMMIT TRAN rdt_VAPUnCasingCfm01  




GO