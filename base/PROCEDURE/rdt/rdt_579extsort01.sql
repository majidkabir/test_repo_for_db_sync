SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdt_579ExtSort01                                          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Get statistics                                                    */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2017-01-20 1.0  Ung      WMS-1085 Created                                  */
/* 2017-03-15 1.1  Ung      IN00289179 Add rdtSortCaseLock                    */
/* 2017-03-15 1.2  Leong    IN00289179 Add info to PickDetail.Notes.          */
/* 2017-06-19 1.3  Ung      Fix deadlock                                      */
/* 2018-03-05 1.4  Ung      WMS-4202 Add SKU QTY                              */
/******************************************************************************/

CREATE PROC [RDT].[rdt_579ExtSort01] (
   @nMobile     INT,
   @nFunc       INT,
   @nScn        INT,
   @nStep       INT,
   @nInputKey   INT,
   @cLangCode   NVARCHAR( 3),
   @cStorerkey  NVARCHAR( 15),
   @cFacility   NVARCHAR( 5),
   @cType       NVARCHAR( 10), --STAT/CONFIRM
   @cLoadKey    NVARCHAR( 10) OUTPUT,
   @cUCCNo      NVARCHAR( 20),
   @cSKU        NVARCHAR( 20), 
   @nQTY        INT,
   @cScan       NVARCHAR( 5)  OUTPUT,
   @cTotal      NVARCHAR( 5)  OUTPUT,
   @cPOS        NVARCHAR( 20) OUTPUT,
   @cSortInf1   NVARCHAR( 20) OUTPUT,
   @cSortInf2   NVARCHAR( 20) OUTPUT,
   @cSortInf3   NVARCHAR( 20) OUTPUT,
   @cSortInf4   NVARCHAR( 20) OUTPUT,
   @cSortInf5   NVARCHAR( 20) OUTPUT,
   @nErrNo      INT           OUTPUT,
   @cErrMsg     NVARCHAR(20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT

   IF @cType = 'CONFIRM'
   BEGIN
      DECLARE @bSuccess          INT
      DECLARE @cOrderKey         NVARCHAR( 10)
      DECLARE @cExternOrderKey   NVARCHAR( 30)
      DECLARE @cPickDetailKey    NVARCHAR( 10)
      DECLARE @cLOC              NVARCHAR( 10)
      DECLARE @cID               NVARCHAR( 18)
      DECLARE @cStatus           NVARCHAR( 1)
      DECLARE @nQTY_UCC          INT
      DECLARE @nQTY_Bal          INT
      DECLARE @nQTY_PD           INT

      SET @cOrderKey = ''

      -- Get UCC info
      SELECT
         @cSKU = SKU,
         @nQTY_UCC = QTY,
         @cStatus = Status
      FROM UCC WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND UCCNo = @cUCCNo

      SET @nQTY_Bal = @nQTY_UCC

      -- Check full case exist
      SELECT TOP 1
         @cOrderKey = PD.OrderKey,
         @cLOC = PD.LOC,
         @cID = PD.ID
      FROM LoadPlanDetail LPD WITH (NOLOCK)
         JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)
         JOIN SKUxLOC SL WITH (NOLOCK) ON (PD.LOC = SL.LOC AND PD.StorerKey = SL.StorerKey AND PD.SKU = SL.SKU)
         JOIN SKU WITH (NOLOCK) ON (SKU.StorerKey = PD.StorerKey AND SKU.SKU = PD.SKU)
         JOIN Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
      WHERE LPD.LoadKey = @cLoadKey
         AND PD.SKU = @cSKU
         -- remark due to some alloc strategy not following UOM 2 = full case
         -- AND PD.UOM = '2' -- case
         -- AND PD.QTY >= @nQTY_UCC
         AND PD.Status < '5'
         AND PD.Status <> '4' -- Short
         AND PD.CaseID <> 'SORTED'
         AND SL.LocationType <> 'CASE'
         AND SL.LocationType <> 'PICK'
         AND Pack.CaseCnt > 0
      GROUP BY PD.OrderKey, PD.LOC, PD.ID, PD.SKU, Pack.CaseCnt
      HAVING CAST( SUM( PD.QTY) / Pack.CaseCnt AS INT) > 0

      -- Check full case available
      IF @cOrderKey = ''
      BEGIN
         SET @nErrNo = 105701
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No more case
         GOTO Quit
      END

      -- Handling transaction
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_579ExtSort01 -- For rollback or commit only our own transaction

      -- Lock the sorting criteria
      IF NOT EXISTS( SELECT 1
         FROM rdt.rdtSortCaseLock WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey
            AND StorerKey = @cStorerKey
            AND SKU = @cSKU
            AND AddWho = SUSER_SNAME())
      BEGIN
         INSERT INTO rdt.rdtSortCaseLock( OrderKey, StorerKey, SKU, AddWho)
         VALUES (@cOrderKey, @cStorerKey, @cSKU, SUSER_SNAME())
         IF @@ERROR <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UCCLock. Retry
            GOTO Quit
         END
      END

      -- Loop PickDetail
      DECLARE @curPD CURSOR
      SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PD.PickDetailKey, PD.QTY
         FROM PickDetail PD WITH (NOLOCK)
         WHERE PD.OrderKey = @cOrderKey
            AND PD.SKU = @cSKU
            AND PD.LOC = @cLOC
            AND PD.ID = @cID
            AND PD.Status < '5'
            AND PD.Status <> '4' -- Short
            AND PD.CaseID <> 'SORTED'
         ORDER BY PD.OrderLineNumber
      OPEN @curPD
      FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Exact match
         IF @nQTY_PD = @nQTY_Bal
         BEGIN
            -- Confirm PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               CaseID = 'SORTED',
               EditDate = GETDATE(),
               EditWho = SUSER_SNAME(),
               Trafficcop = NULL
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 102001
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
               GOTO RollBackTran
            END

            SET @nQTY_Bal = 0 -- Reduce balance
         END

         -- PickDetail have less
         ELSE IF @nQTY_PD < @nQTY_Bal
         BEGIN
            -- Confirm PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               CaseID = 'SORTED',
               EditDate = GETDATE(),
               EditWho = SUSER_SNAME(),
               Trafficcop = NULL
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 102002
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
               GOTO RollBackTran
            END

            SET @nQTY_Bal = @nQTY_Bal - @nQTY_PD -- Reduce balance
         END

         -- PickDetail have more
         ELSE IF @nQTY_PD > @nQTY_Bal
         BEGIN
            -- Get new PickDetailkey
            DECLARE @cNewPickDetailKey NVARCHAR( 10)
            EXECUTE dbo.nspg_GetKey
               'PICKDETAILKEY',
               10 ,
               @cNewPickDetailKey OUTPUT,
               @bSuccess          OUTPUT,
               @nErrNo            OUTPUT,
               @cErrMsg           OUTPUT
            IF @bSuccess <> 1
            BEGIN
               SET @nErrNo = 102004
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey
               GOTO RollBackTran
            END

            -- Create new a PickDetail to hold the balance
            INSERT INTO dbo.PickDetail (
               CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM,
               UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType,
               ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
               EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey,
               Notes
               , PickDetailKey,
               Status,
               QTY,
               TrafficCop,
               OptimizeCop)
            SELECT
               CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM,
               UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup,
               CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
               EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey,
               'RefPDKey: ' + @cPickDetailKey + ', PDQty: '+ CAST(@nQTY_PD AS VARCHAR) + ', BalQty: ' + CAST(@nQTY_Bal AS VARCHAR) -- IN00289179
               , @cNewPickDetailKey,
               Status,
               @nQTY_PD - @nQTY_Bal, -- QTY
               NULL, -- TrafficCop
               '1'   -- OptimizeCop
            FROM dbo.PickDetail WITH (NOLOCK)
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 102005
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS PKDtl Fail
               GOTO RollBackTran
            END

            -- Split RefKeyLookup
            IF EXISTS( SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @cPickDetailKey)
            BEGIN
               -- Insert into
               INSERT INTO dbo.RefKeyLookup (PickDetailkey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey)
               SELECT @cNewPickDetailKey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey
               FROM RefKeyLookup WITH (NOLOCK)
               WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 102006
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RefKeyFail
                  GOTO RollBackTran
               END
            END

            -- Change orginal PickDetail with exact QTY (with TrafficCop)
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               QTY = @nQTY_Bal,
               CaseID = 'SORTED',
               EditDate = GETDATE(),
               EditWho  = SUSER_SNAME(),
               Trafficcop = NULL
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 102007
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
               GOTO RollBackTran
            END

            SET @nQTY_Bal = 0 -- Reduce balance
         END

         IF @nQTY_Bal = 0
            BREAK

         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD
      END

      -- Update UCC
      UPDATE UCC SET
         Status = '5',  -- Picked
         EditWho = SUSER_SNAME(),
         EditDate = GETDATE(),
         TrafficCop = NULL
      WHERE StorerKey = @cStorerKey
         AND UCCNo = @cUCCNo
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 105707
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD UCC Fail
         GOTO RollBackTran
      END

      -- Unlock the sorting criteria
      DECLARE @nRowRef INT
      SELECT @nRowRef = RowRef
      FROM rdt.rdtSortCaseLock WITH (NOLOCK)
      WHERE OrderKey = @cOrderKey
         AND StorerKey = @cStorerKey
         AND SKU = @cSKU
         AND AddWho = SUSER_SNAME()

      IF @@ROWCOUNT = 1
      BEGIN
         DELETE rdt.rdtSortCaseLock
         WHERE @nRowRef = RowRef
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 105708
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DEL Log Fail
            GOTO Quit
         END
      END
      ELSE
      BEGIN
         DECLARE @curLog CURSOR
         SET @curLog = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT RowRef
            FROM rdt.rdtSortCaseLock WITH (NOLOCK)
            WHERE OrderKey = @cOrderKey
               AND StorerKey = @cStorerKey
               AND SKU = @cSKU
               AND AddWho = SUSER_SNAME()
         OPEN @curLog
         FETCH NEXT FROM @curLog INTO @nRowRef 
         WHILE @@FETCH_STATUS = 0
         BEGIN
            DELETE rdt.rdtSortCaseLock
            WHERE @nRowRef = RowRef
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 105709
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DEL Log Fail
               GOTO Quit
            END
            FETCH NEXT FROM @curLog INTO @nRowRef 
         END
      END
      
      COMMIT TRAN rdt_579ExtSort01

      -- Get order info
      SELECT @cExternOrderKey = ExternOrderKey
      FROM Orders WITH (NOLOCK)
      WHERE OrderKey = @cOrderKey

      -- Format
      SET @cExternOrderKey = RIGHT( RTRIM( @cExternOrderKey), 5)
      SET @cExternOrderKey = SUBSTRING( @cExternOrderKey, 1, 1) + '-' + SUBSTRING( @cExternOrderKey, 2, 4)

      -- Output sort info
      SET @cPOS = ''
      SET @cSortInf1 = 'SKU:'
      SET @cSortInf2 = @cSKU
      SET @cSortInf3 = 'QTY:' + CAST( @nQTY_UCC AS NVARCHAR( 5))
      SET @cSortInf4 = 'ORDERKEY: ' + @cOrderKey
      SET @cSortInf5 = 'EXTORDKEY: ' + LEFT( @cExternOrderKey, 9)
   END

   IF @cType = '' OR @cType = 'CONFIRM'
   BEGIN
      DECLARE @nScan  INT
      DECLARE @nTotal INT

      SET @nScan = 0
      SET @nTotal = 0

      -- Get total cartons
      SELECT @nTotal = SUM( Total)
      FROM
      (
         SELECT CAST( SUM( PD.QTY) / Pack.CaseCnt AS INT) AS Total
         FROM LoadPlanDetail LPD WITH (NOLOCK)
            JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)
            JOIN SKUxLOC SL WITH (NOLOCK) ON (PD.LOC = SL.LOC AND PD.StorerKey = SL.StorerKey AND PD.SKU = SL.SKU)
            JOIN SKU WITH (NOLOCK) ON (SKU.StorerKey = PD.StorerKey AND SKU.SKU = PD.SKU)
            JOIN Pack WITH (NOLOCK) ON (Pack.PackKey = SKU.PackKey)
         WHERE LPD.LoadKey = @cLoadKey
            AND PD.QTY > 0
            AND PD.Status < '5'
            AND PD.Status <> '4' -- Short
            AND SL.LocationType <> 'CASE'
            AND SL.LocationType <> 'PICK'
            AND Pack.CaseCnt > 0
         GROUP BY PD.OrderKey, PD.SKU, Pack.CaseCnt
         HAVING CAST( SUM( PD.QTY) / Pack.CaseCnt AS INT) > 0
      ) AS A

      -- Get scan cartons
      SELECT @nScan = SUM( Scan)
      FROM
      (
         SELECT CAST( SUM( PD.QTY) / Pack.CaseCnt AS INT) AS Scan
         FROM LoadPlanDetail LPD WITH (NOLOCK)
            JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)
            JOIN SKUxLOC SL WITH (NOLOCK) ON (PD.LOC = SL.LOC AND PD.StorerKey = SL.StorerKey AND PD.SKU = SL.SKU)
            JOIN SKU WITH (NOLOCK) ON (SKU.StorerKey = PD.StorerKey AND SKU.SKU = PD.SKU)
            JOIN Pack WITH (NOLOCK) ON (Pack.PackKey = SKU.PackKey)
         WHERE LPD.LoadKey = @cLoadKey
            AND PD.QTY > 0
            AND PD.Status < '5'
            AND PD.Status <> '4' -- Short
            AND PD.CaseID = 'SORTED'
            AND SL.LocationType <> 'CASE'
            AND SL.LocationType <> 'PICK'
            AND Pack.CaseCnt > 0
         GROUP BY PD.OrderKey, PD.SKU, Pack.CaseCnt
         HAVING CAST( SUM( PD.QTY) / Pack.CaseCnt AS INT) > 0
      ) AS A

      SET @cScan = CAST( @nScan AS NVARCHAR(5))
      SET @cTotal = CAST( @nTotal AS NVARCHAR(5))
   END
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_579ExtSort01 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO