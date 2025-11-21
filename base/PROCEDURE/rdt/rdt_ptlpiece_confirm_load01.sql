SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_PTLPiece_Confirm_Load01                         */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Confirm by load. Display matrix                             */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 2020-01-16 1.0  James       WMS-11427. Created                       */
/* 2023-06-06 1.2  James       WMS-22665 Enhance the way to lookup      */
/*                             device name instead of hardcoded(james01)*/
/************************************************************************/

CREATE   PROC [RDT].[rdt_PTLPiece_Confirm_Load01] (
    @nMobile      INT
   ,@nFunc        INT
   ,@cLangCode    NVARCHAR( 3)
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cFacility    NVARCHAR( 5)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cLight       NVARCHAR( 1)
   ,@cStation     NVARCHAR( 10)
   ,@cMethod      NVARCHAR( 1) 
   ,@cSKU         NVARCHAR( 20)
   ,@cIPAddress   NVARCHAR( 40) OUTPUT
   ,@cPosition    NVARCHAR( 10) OUTPUT
   ,@nErrNo       INT           OUTPUT
   ,@cErrMsg      NVARCHAR(250) OUTPUT
   ,@cResult01    NVARCHAR( 20) OUTPUT
   ,@cResult02    NVARCHAR( 20) OUTPUT
   ,@cResult03    NVARCHAR( 20) OUTPUT
   ,@cResult04    NVARCHAR( 20) OUTPUT
   ,@cResult05    NVARCHAR( 20) OUTPUT
   ,@cResult06    NVARCHAR( 20) OUTPUT
   ,@cResult07    NVARCHAR( 20) OUTPUT
   ,@cResult08    NVARCHAR( 20) OUTPUT
   ,@cResult09    NVARCHAR( 20) OUTPUT
   ,@cResult10    NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @bSuccess          INT
   DECLARE @nTranCount        INT
   DECLARE @nQTY_PD           INT

   DECLARE @cOrderKey         NVARCHAR( 10)
   DECLARE @cOrderLineNo      NVARCHAR( 5)
   DECLARE @cPickDetailKey    NVARCHAR( 10)
   DECLARE @cSortedPDKey      NVARCHAR(10)
   DECLARE @cLOT              NVARCHAR( 10)
   DECLARE @cLOC              NVARCHAR( 10)
   DECLARE @cID               NVARCHAR( 18)
   DECLARE @cDisplay          NVARCHAR( 5)
   DECLARE @cNewDropID        NVARCHAR( 20)
   DECLARE @cLogicalName      NVARCHAR( 10)    
   DECLARE @nQty              INT
   DECLARE @cDropID           NVARCHAR( 20)
   DECLARE @cPrefix           NVARCHAR( 10)
   DECLARE @nPosStart         INT
   DECLARE @nPosLength        INT
   DECLARE @nCustomPrefix     INT = 0
   
   SET @cDisplay = '' 
   SET @nQty = 1  -- Piece scanning
   SET @cNewDropID = ''

   /***********************************************************************************************

                                              CONFIRM ORDER

   ***********************************************************************************************/
   -- Handling transaction
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_PTLPiece_Confirm -- For rollback or commit only our own transaction

   -- Find PickDetail to offset
   SELECT TOP 1 
      @cPickDetailKey = PD.PickDetailKey, 
      @nQTY_PD = PD.QTY, 
      @cPosition = L.Position, 
      @cIPAddress = L.IPAddress
   FROM rdt.rdtPTLPieceLog L WITH (NOLOCK) 
   JOIN dbo.PickDetail PD WITH (NOLOCK) ON ( L.SourceKey = PD.DropID AND L.OrderKey = PD.OrderKey)
   JOIN dbo.Orders O WITH (NOLOCK) ON ( O.OrderKey = PD.OrderKey)
   WHERE L.Station = @cStation
   AND   PD.StorerKey = @cStorerKey
   AND   PD.SKU = @cSKU
   AND   PD.Status <= '5'
   AND   ISNULL( PD.Notes, '') = ''
   AND   PD.QTY > 0
   AND   PD.Status <> '4'
   AND   O.Status <> 'CANC' 
   AND   O.SOStatus <> 'CANC'
   ORDER BY 1

   IF @@ROWCOUNT = 1
   BEGIN
      SELECT @cOrderKey = OrderKey
      FROM dbo.PICKDETAIL WITH (NOLOCK)
      WHERE PickDetailKey = @cPickDetailKey

      SELECT 
         @cPrefix = Code,
         @nPosStart = Short,
         @nPosLength = Long
      FROM dbo.CODELKUP WITH (NOLOCK) 
      WHERE LISTNAME = 'PTLPREFMAP' 
      AND   Storerkey = @cStorerKey
      AND   code2 = @nFunc

      IF @cPrefix <> '' AND CAST( @nPosStart AS INT) > 0 AND CAST( @nPosLength AS INT) > 0
      BEGIN
      	SET @nCustomPrefix = 1
      	
         SELECT TOP 1 @cNewDropID = DropID    
         FROM dbo.PICKDETAIL WITH (NOLOCK)    
         WHERE Storerkey = @cStorerKey
         AND   OrderKey = @cOrderKey    
         AND   DropID LIKE RTRIM( @cPrefix) + '%'    
         ORDER BY 1 DESC
      END
      ELSE
      BEGIN
         -- 1 cart only allow 1 orderkey
         SELECT TOP 1 @cNewDropID = DropID
         FROM dbo.PICKDETAIL WITH (NOLOCK)
         WHERE Storerkey = @cStorerKey
         AND   OrderKey = @cOrderKey
         AND   DropID LIKE 'CART%'
         ORDER BY DropID DESC
      END
      
      IF ISNULL( @cNewDropID, '') = ''
      BEGIN
         -- Get logical name    
         SET @cLogicalName = @cPosition     
         SELECT @cLogicalName = LogicalName    
         FROM DeviceProfile WITH (NOLOCK)    
         WHERE DeviceType = 'STATION'    
            AND DeviceID = @cStation    
            AND DeviceID <> ''    
            AND IPAddress = @cIPAddress    
            AND DevicePosition = @cPosition   
      
         SET @cNewDropID = RTRIM( @cStation) + @cLogicalName
      END
      ELSE
      BEGIN
      	IF @nCustomPrefix = 1
      	   SET @cPosition = SUBSTRING( @cNewDropID, @nPosStart, @nPosLength)
      	ELSE
            SET @cPosition = SUBSTRING( @cNewDropID, 6, 2)
      END
      
      -- Exact match
      IF @nQTY_PD = 1
      BEGIN
         -- Confirm PickDetail
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
            DropID = @cNewDropID,
            Notes = 'SORTED', 
            EditDate = GETDATE(), 
            EditWho  = SUSER_SNAME(), 
            Trafficcop = NULL
         WHERE PickDetailKey = @cPickDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 155101
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
            GOTO RollBackTran
         END
      END
         
      -- PickDetail have more
   	ELSE IF @nQTY_PD > 1
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
            SET @nErrNo = 155102
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey
            GOTO RollBackTran
         END

         -- Create new a PickDetail to hold the balance
         INSERT INTO dbo.PickDetail (
            CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM, 
            UOMQTY, QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, 
            ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
            EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes, 
            PickDetailKey, 
            QTY, 
            TrafficCop,
            OptimizeCop)
         SELECT 
            CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM, 
            UOMQTY, QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, 
            CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
            EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes, 
            @cNewPickDetailKey, 
            @nQTY_PD - 1, -- QTY
            NULL, -- TrafficCop
            '1'   -- OptimizeCop
         FROM dbo.PickDetail WITH (NOLOCK) 
   		WHERE PickDetailKey = @cPickDetailKey			            
         IF @@ERROR <> 0
         BEGIN
   			SET @nErrNo = 155103
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
               SET @nErrNo = 155104
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RefKeyFail
               GOTO RollBackTran
            END
         END
         
         -- Change orginal PickDetail with exact QTY (with TrafficCop)
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
            QTY = 1, 
            DropID = @cNewDropID,
            Notes = 'SORTED', 
            EditDate = GETDATE(), 
            EditWho  = SUSER_SNAME(), 
            Trafficcop = NULL
         WHERE PickDetailKey = @cPickDetailKey 
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 155105
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
            GOTO RollBackTran
         END
      END
   END
   ELSE
   BEGIN
      SET @nErrNo = 155106
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Nothing 2 Sort
      GOTO RollBackTran
   END
         
   -- Draw matrix (and light up)
   EXEC rdt.rdt_PTLPiece_Matrix @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
      ,@cLight
      ,@cStation
      ,@cMethod
      ,@cSKU
      ,@cIPAddress 
      ,@cPosition
      ,@cDisplay
      ,@nErrNo     OUTPUT
      ,@cErrMsg    OUTPUT
      ,@cResult01  OUTPUT
      ,@cResult02  OUTPUT
      ,@cResult03  OUTPUT
      ,@cResult04  OUTPUT
      ,@cResult05  OUTPUT
      ,@cResult06  OUTPUT
      ,@cResult07  OUTPUT
      ,@cResult08  OUTPUT
      ,@cResult09  OUTPUT
      ,@cResult10  OUTPUT
   IF @nErrNo <> 0
      GOTO RollBackTran

   COMMIT TRAN rdt_PTLPiece_Confirm
   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_PTLPiece_Confirm -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO