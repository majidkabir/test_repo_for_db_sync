SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_1638ExtUpd05                                       */
/* Copyright: LFLogistics                                                  */
/*                                                                         */
/* Date        Rev  Author    Purposes                                     */
/* 03-03-2021  1.0  Chermaine WMS-16430 Create(dup from rdt_1638ExtUpd01)  */
/***************************************************************************/

CREATE PROC [RDT].[rdt_1638ExtUpd05] (
   @nMobile      INT,           
   @nFunc        INT,           
   @nStep        INT,
   @nAfterStep   INT,        
   @nInputKey    INT,           
   @cLangCode    NVARCHAR( 3),  
   @cFacility    NVARCHAR( 5),  
   @cStorerkey   NVARCHAR( 15), 
   @cPalletKey   NVARCHAR( 30), 
   @cCartonType  NVARCHAR( 10), 
   @cCaseID      NVARCHAR( 20), 
   @cLOC         NVARCHAR( 10), 
   @cSKU         NVARCHAR( 20), 
   @nQTY         INT,            
   @cLength      NVARCHAR(5),    
   @cWidth       NVARCHAR(5),    
   @cHeight      NVARCHAR(5),    
   @cGrossWeight NVARCHAR(5),    
   @nErrNo       INT           OUTPUT,
   @cErrMsg      NVARCHAR( 20) OUTPUT 
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_1638ExtUpd05   
   
   IF @nFunc = 1638 -- Scan to pallet
   BEGIN
      IF @nAfterStep = 3  -- CaseID
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            DECLARE @cFromLOT  NVARCHAR(10)
            DECLARE @cFromLOC  NVARCHAR(10)
            DECLARE @cFromID   NVARCHAR(18)
            DECLARE @cPickDetailKey NVARCHAR(10)
            
            -- Pick confirm carton
            DECLARE @curPD CURSOR
            SET @curPD = CURSOR FOR
               SELECT PD.PickDetailKey
               FROM PickDetail PD WITH (NOLOCK)
                  JOIN LOT WITH (NOLOCK) ON (PD.LOT = LOT.LOT)
               WHERE PD.StorerKey = @cStorerKey
                  AND PD.DropID = @cCaseID
                  AND PD.Status <= '3'
                  AND PD.QTY > 0
               ORDER BY PD.OrderKey, PD.StorerKey, PD.SKU, PD.LOT -- To reduce deadlock, for conso carton
            OPEN @curPD
            FETCH NEXT FROM @curPD INTO @cPickDetailKey
            WHILE @@FETCH_STATUS = 0
            BEGIN
               UPDATE PickDetail SET 
                  Status = '5', 
                  EditWho = SUSER_SNAME(), 
                  EditDate = GETDATE()
               WHERE PickDetailKey = @cPickDetailKey
               SET @nErrNo = @@ERROR 
               IF @nErrNo <> 0
               BEGIN
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                  GOTO RollbackTran
               END
               FETCH NEXT FROM @curPD INTO @cPickDetailKey
            END
            
            -- Move carton
            SET @curPD = CURSOR FOR
               SELECT PD.LOT, PD.LOC, PD.ID, PD.SKU, SUM( PD.QTY)
               FROM PickDetail PD WITH (NOLOCK)
                  JOIN LOT WITH (NOLOCK) ON (PD.LOT = LOT.LOT)
               WHERE PD.StorerKey = @cStorerKey
                  AND PD.DropID = @cCaseID
                  AND PD.Status = '5'
                  AND PD.QTY > 0
                  AND (PD.LOC <> @cLOC OR PD.ID <> @cPalletKey) -- Change LOC / ID
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
                  @cSourceType = 'rdt_1638ExtUpd05',
                  @cStorerKey  = @cStorerKey,
                  @cFacility   = @cFacility,
                  @cFromLOC    = @cFromLOC,
                  @cToLOC      = @cLOC,
                  @cFromID     = @cFromID,     
                  @cToID       = @cPalletKey,      
                  @cFromLOT    = @cFromLOT,  
                  @cSKU        = @cSKU,
                  @nQTY        = @nQTY,
                  @nQTYAlloc   = 0,
                  @nQTYPick    = @nQTY, 
                  @nFunc       = @nFunc, 
                  @cDropID     = @cCaseID
               IF @nErrNo <> 0
                  GOTO RollbackTran
               
               FETCH NEXT FROM @curPD INTO @cFromLOT, @cFromLOC, @cFromID, @cSKU, @nQTY
            END
         END
      END
   END

   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_1638ExtUpd05 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN   
END

GO