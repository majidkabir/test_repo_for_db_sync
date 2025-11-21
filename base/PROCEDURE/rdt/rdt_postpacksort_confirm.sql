SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_PostPackSort_Confirm                            */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Close pallet and create tm task to move pallet              */
/*                                                                      */
/* Called from: rdtfnc_PostPackSort                                     */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 2019-09-26   1.0  James    WMS-10316. Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_PostPackSort_Confirm] (
   @nMobile             INT,
   @nFunc               INT,
   @cLangCode           NVARCHAR( 3),
   @cStorerKey          NVARCHAR( 15),
   @cFacility           NVARCHAR( 5), 
   @cCartonID           NVARCHAR( 20), 
   @cPalletID           NVARCHAR( 20), 
   @cLoadKey            NVARCHAR( 10), 
   @cLoc                NVARCHAR( 10), 
   @cOption             NVARCHAR( 1), 
   @cPickDetailCartonID NVARCHAR( 20),    
   @tPostPackSortCfm    VariableTable  READONLY, 
   @nErrNo              INT            OUTPUT,
   @cErrMsg             NVARCHAR( 20)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount        INT,
           @nQty              INT,
           @cSKU              NVARCHAR( 20),
           @cToLoc            NVARCHAR( 10),
           @cFromLOC          NVARCHAR( 10),
           @cFromLOT          NVARCHAR( 10),
           @cFromID           NVARCHAR( 18),
           @cCaseID           NVARCHAR( 20),
           @cDropID           NVARCHAR( 20)

   SET @nErrNo = 0

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_PostPackSort_Confirm

   IF NOT EXISTS ( SELECT 1 FROM rdt.rdtSortLaneLocLog WITH (NOLOCK)
                     WHERE ID = @cPalletID
                  AND   Status = '1'
                  AND   Loc = @cLoc)
   BEGIN
      UPDATE  rdt.rdtSortLaneLocLog WITH (ROWLOCK) SET 
         ID = @cPalletID
      WHERE Loc = @cLoc
      AND   Status = '1'

      IF @@ROWCOUNT <> 1
      BEGIN
         SET @nErrNo = 144451
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode,'DSP') --Assign Loc Err
         GOTO RollBackTran  
      END
   END

   SET @cDropID = ''
   SET @cCaseID = ''

   IF @cPickDetailCartonID = 'DROPID'
      SET @cDropID = @cCartonID
   ELSE 
      SET @cCaseID = @cCartonID

   -- Move carton
   DECLARE @curPD CURSOR
   SET @curPD = CURSOR FOR
      SELECT PD.LOT, PD.LOC, PD.ID, PD.SKU, SUM( PD.QTY)
      FROM PickDetail PD WITH (NOLOCK)
      WHERE PD.StorerKey = @cStorerKey
      AND (( @cPickDetailCartonID = 'DROPID' AND PD.DropID = @cDropID) OR 
            ( @cPickDetailCartonID = 'CASEID' AND PD.CaseID = @cCaseID))
      AND   PD.Status = '5'
      AND   PD.QTY > 0
      AND  (PD.LOC <> @cLOC OR PD.ID <> @cPalletID) -- Change LOC / ID
   GROUP BY PD.OrderKey, PD.StorerKey, PD.SKU, PD.LOT, PD.LOC, PD.ID
   ORDER BY PD.OrderKey, PD.StorerKey, PD.SKU, PD.LOT, PD.LOC, PD.ID -- To reduce deadlock, for conso carton
   OPEN @curPD
   FETCH NEXT FROM @curPD INTO @cFromLOT, @cFromLOC, @cFromID, @cSKU, @nQTY
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- EXEC move
      EXECUTE rdt.rdt_Move
         @nMobile     = @nMobile,
         @cLangCode   = @cLangCode,
         @nErrNo      = @nErrNo  OUTPUT,
         @cErrMsg     = @cErrMsg OUTPUT, 
         @cSourceType = 'rdt_PostPackSort_Confirm',
         @cStorerKey  = @cStorerKey,
         @cFacility   = @cFacility,
         @cFromLOC    = @cFromLOC,
         @cToLOC      = @cLOC,
         @cFromID     = @cFromID,     
         @cToID       = @cPalletID,      
         @cFromLOT    = @cFromLOT,  
         @cSKU        = @cSKU,
         @nQTY        = @nQTY,
         @nQTYAlloc   = 0,
         @nQTYPick    = @nQTY, 
         @nFunc       = @nFunc, 
         @cCaseID     = @cCaseID,
         @cDropID     = @cDropID

      IF @nErrNo <> 0
         GOTO RollbackTran
               
      FETCH NEXT FROM @curPD INTO @cFromLOT, @cFromLOC, @cFromID, @cSKU, @nQTY
   END

   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN rdt_PostPackSort_Confirm

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN rdt_PostPackSort_Confirm

   Fail:
   --delete from traceinfo where tracename = '1837'
   --insert into traceinfo (tracename, timein, col1, col2, col3, col4, col5) values
   --('1837', getdate(), @cFromLOT, @cFromLOC, @cFromID, @cSKU, @nQTY)
END

GO