SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_PTLCart_Assign_CaseTote                               */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 06-05-2015 1.0  Ung      SOS361968 Created                                 */
/* 04-01-2018 1.1  Ung      WMS-3012 Prompt case ID reuse                     */
/* 26-01-2018 1.2  Ung      Change to PTL.Schema                              */
/* 07-12-2021 1.3  Chermain WMS-18487 Add CheckPickDone config when scan      */
/*                          same cartonID(cc01)                               */
/******************************************************************************/

CREATE PROC [RDT].[rdt_PTLCart_Assign_CaseTote] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT,
   @cFacility        NVARCHAR( 5),
   @cStorerKey       NVARCHAR( 15),
   @cCartID          NVARCHAR( 10),
   @cPickZone        NVARCHAR( 10),
   @cMethod          NVARCHAR( 1),
   @cPickSeq         NVARCHAR( 1),
   @cDPLKey          NVARCHAR( 10),
   @cType            NVARCHAR( 15), --POPULATE-IN/POPULATE-OUT/CHECK
   @cInField01       NVARCHAR( 60) OUTPUT,  @cOutField01 NVARCHAR( 60) OUTPUT,  @cFieldAttr01 NVARCHAR( 1) OUTPUT,
   @cInField02       NVARCHAR( 60) OUTPUT,  @cOutField02 NVARCHAR( 60) OUTPUT,  @cFieldAttr02 NVARCHAR( 1) OUTPUT,
   @cInField03       NVARCHAR( 60) OUTPUT,  @cOutField03 NVARCHAR( 60) OUTPUT,  @cFieldAttr03 NVARCHAR( 1) OUTPUT,
   @cInField04       NVARCHAR( 60) OUTPUT,  @cOutField04 NVARCHAR( 60) OUTPUT,  @cFieldAttr04 NVARCHAR( 1) OUTPUT,
   @cInField05       NVARCHAR( 60) OUTPUT,  @cOutField05 NVARCHAR( 60) OUTPUT,  @cFieldAttr05 NVARCHAR( 1) OUTPUT,
   @cInField06       NVARCHAR( 60) OUTPUT,  @cOutField06 NVARCHAR( 60) OUTPUT,  @cFieldAttr06 NVARCHAR( 1) OUTPUT,
   @cInField07       NVARCHAR( 60) OUTPUT,  @cOutField07 NVARCHAR( 60) OUTPUT,  @cFieldAttr07 NVARCHAR( 1) OUTPUT,
   @cInField08       NVARCHAR( 60) OUTPUT,  @cOutField08 NVARCHAR( 60) OUTPUT,  @cFieldAttr08 NVARCHAR( 1) OUTPUT,
   @cInField09       NVARCHAR( 60) OUTPUT,  @cOutField09 NVARCHAR( 60) OUTPUT,  @cFieldAttr09 NVARCHAR( 1) OUTPUT,
   @cInField10       NVARCHAR( 60) OUTPUT,  @cOutField10 NVARCHAR( 60) OUTPUT,  @cFieldAttr10 NVARCHAR( 1) OUTPUT,
   @cInField11       NVARCHAR( 60) OUTPUT,  @cOutField11 NVARCHAR( 60) OUTPUT,  @cFieldAttr11 NVARCHAR( 1) OUTPUT,
   @cInField12       NVARCHAR( 60) OUTPUT,  @cOutField12 NVARCHAR( 60) OUTPUT,  @cFieldAttr12 NVARCHAR( 1) OUTPUT,
   @cInField13       NVARCHAR( 60) OUTPUT,  @cOutField13 NVARCHAR( 60) OUTPUT,  @cFieldAttr13 NVARCHAR( 1) OUTPUT,
   @cInField14       NVARCHAR( 60) OUTPUT,  @cOutField14 NVARCHAR( 60) OUTPUT,  @cFieldAttr14 NVARCHAR( 1) OUTPUT,
   @cInField15       NVARCHAR( 60) OUTPUT,  @cOutField15 NVARCHAR( 60) OUTPUT,  @cFieldAttr15 NVARCHAR( 1) OUTPUT,
   @nScn             INT           OUTPUT,
   @nErrNo           INT           OUTPUT,
   @cErrMsg          NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount  INT
   DECLARE @nTotalTote  INT
   DECLARE @cErrMsg1    NVARCHAR(20)

   DECLARE @cCaseID     NVARCHAR(20)
   DECLARE @cPosition   NVARCHAR(10)
   DECLARE @cToteID     NVARCHAR(20)
   DECLARE @cOrderKey   NVARCHAR(10)

   SET @nTranCount = @@TRANCOUNT

   -- Get storer config
   DECLARE @cDefaultCaseIDAsToteID NVARCHAR(1)
   DECLARE @cCheckCaseIDUsed NVARCHAR(1)
   SET @cDefaultCaseIDAsToteID = rdt.rdtGetConfig( @nFunc, 'DefaultCaseIDAsToteID', @cStorerKey)
   SET @cCheckCaseIDUsed = rdt.rdtGetConfig( @nFunc, 'CheckCaseIDUsed', @cStorerKey)
   
   --(cc01)
   DECLARE @cCheckPickDone NVARCHAR(1)
   SET @cCheckPickDone = rdt.rdtGetConfig( @nFunc, 'CheckPickDone', @cStorerKey)

   /***********************************************************************************************
                                                POPULATE
   ***********************************************************************************************/
   IF @cType = 'POPULATE-IN'
   BEGIN
      -- Get total
      SELECT @nTotalTote = COUNT(1) FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID AND ToteID <> ''

		-- Prepare next screen var
		SET @cOutField01 = @cCartID
		SET @cOutField02 = @cPickZone
		SET @cOutField03 = '' -- CaseID
		SET @cOutField04 = '' -- Position
		SET @cOutField05 = '' -- ToteID
		SET @cOutField06 = CAST( @nTotalTote AS NVARCHAR(5))

      -- Start assign tote
      IF @nTotalTote = 0
      BEGIN
         SET @cFieldAttr03 = '' -- CaseID
         SET @cFieldAttr05 = CASE WHEN @cDefaultCaseIDAsToteID = '1' THEN 'O' ELSE '' END -- ToteID

         -- Get position not yet assign
         SET @cPosition = ''
         SELECT TOP 1
            @cPosition = DP.DevicePosition
         FROM dbo.DeviceProfile DP WITH (NOLOCK)
         WHERE DP.DeviceType = 'CART'
            AND DP.DeviceID = @cCartID
            AND NOT EXISTS( SELECT 1
               FROM rdt.rdtPTLCartLog PCLog WITH (NOLOCK)
               WHERE CartID = @cCartID
                  AND PCLog.Position = DP.DevicePosition)
         ORDER BY DP.DevicePosition
         
         SET @cOutField04 = @cPosition
      END                  
      -- Finish assign Tote
      ELSE
      BEGIN
         SET @cFieldAttr03 = 'O'  -- CaseID
         SET @cFieldAttr05 = 'O' -- ToteID
      END

		-- Go to orders totes screen
		SET @nScn = 4187
   END
      
   IF @cType = 'POPULATE-OUT'
   BEGIN
		-- Enable diable field
		SET @cFieldAttr03 = '' -- CaseID
		SET @cFieldAttr05 = '' -- ToteID

		-- Go to cart screen
   END


   /***********************************************************************************************
                                                 CHECK
   ***********************************************************************************************/
   IF @cType = 'CHECK'
   BEGIN
      -- Screen mapping
      SET @cCaseID   = @cInField03
      SET @cPosition = @cOutField04
      SET @cToteID   = CASE WHEN @cFieldAttr05 = '' THEN @cInField05 ELSE @cOutField05 END

      -- Get total
      SELECT @nTotalTote = COUNT(1) FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID AND ToteID <> ''

      -- Check finish assign tote
      IF @nTotalTote > 0 AND @cCaseID = '' AND @cToteID = ''
      BEGIN
         -- Enable field
         SET @cFieldAttr03 = '' -- CaseID
         SET @cFieldAttr05 = '' -- ToteID
         GOTO Quit
      END

      -- Check blank
		IF @cCaseID = ''
      BEGIN
         SET @nErrNo = 59651
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need CaseID
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- CaseID
         GOTO Quit
      END

      -- Get Order
      SELECT @cOrderKey = OrderKey
      FROM PickDetail PD WITH (NOLOCK)
         JOIN LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
      WHERE LOC.Facility = @cFacility
         AND PD.StorerKey = @cStorerKey
         AND PD.CaseID = @cCaseID
         AND PD.Status < '4'
         AND PD.QTY > 0

      -- Check case ID valid
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 59652
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad CaseID
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- CaseID
         SET @cOutField03 = ''
         GOTO Quit
      END

      -- Check order CANC
      IF EXISTS( SELECT 1 FROM Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey AND (Status = 'CANC' OR SOStatus = 'CANC'))
      BEGIN
         SET @nErrNo = 59653
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order CANCEL
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- CaseID
         SET @cOutField03 = ''
         GOTO Quit
      END

      -- Check case ID assigned
      IF @cPickZone = ''
         SELECT @nErrNo = 1
         FROM rdt.rdtPTLCartLog WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND CaseID = @cCaseID
      ELSE
         SELECT @nErrNo = 1
         FROM rdt.rdtPTLCartLog WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND CaseID = @cCaseID
            AND (PickZone = @cPickZone OR PickZone = '')
      IF @nErrNo <> 0
      BEGIN
         SET @nErrNo = 59654
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CaseIDAssigned
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- CaseID
         SET @cOutField03 = ''
         GOTO Quit
      END
      
      -- Check case ID in zone
      SET @nErrNo = 1
      IF @cPickZone <> ''
      BEGIN
         IF NOT EXISTS( SELECT 1 
            FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.LOC LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            WHERE LOC.Facility = @cFacility
               AND PD.StorerKey = @cStorerKey 
               AND PD.CaseID = @cCaseID
               AND PD.Status < '4'
               AND PD.QTY > 0
               AND LOC.PickZone = @cPickZone)
         BEGIN
            SET @nErrNo = 59655
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CaseNotInZone
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- CaseID
            SET @cOutField03 = ''
            GOTO Quit
         END
      END      
      
      --(cc01)
      IF @cCheckPickDone = '1'
      BEGIN
      	DECLARE @nPDQty      INT
      	DECLARE @nPTLTranQty INT
      	
      	IF @cPickZone = ''
      	BEGIN
      		SELECT @nPDQty = SUM( PD.QTY)
            FROM Orders O WITH (NOLOCK)
               JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
               JOIN LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            WHERE LOC.Facility = @cFacility
               AND PD.StorerKey = @cStorerKey
               AND PD.CaseID = @cCaseID
               AND PD.Status < '4'
               AND PD.QTY > 0
               AND O.Status <> 'CANC'
               AND O.SOStatus <> 'CANC'
      	END    
         ELSE
         BEGIN
            SELECT @nPDQty = SUM( PD.QTY)
            FROM Orders O WITH (NOLOCK)
               JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
               JOIN LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            WHERE LOC.Facility = @cFacility
               AND PD.StorerKey = @cStorerKey
               AND PD.CaseID = @cCaseID
               AND PD.Status < '4'
               AND PD.QTY > 0
               AND O.Status <> 'CANC'
               AND O.SOStatus <> 'CANC'
               AND LOC.PickZone = @cPickZone
         END
         
         SELECT @nPTLTranQty = SUM(QTY) 
         FROM PTL.PTLTran WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey 
         AND CaseID = @cCaseID 
         
            
      	IF @nPTLTranQty >= @nPDQty
      	BEGIN
      		SET @nErrNo = 59662
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PickingFinish
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- CaseID
            SET @cOutField03 = ''
            GOTO Quit
      	END
      END

      -- Check case ID used
      IF @cCheckCaseIDUsed = '1'
      BEGIN
         -- Case ID not yet passed all checking (to ensure this only prompt once)
         IF @cOutField03 <> @cCaseID
         BEGIN
            IF EXISTS( SELECT TOP 1 1 FROM PTL.PTLTran WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND CaseID = @cCaseID AND Status = '9')
            BEGIN
               SET @nErrNo = 59661
               SET @cErrMsg1 = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CaseID used
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '59661', @cErrMsg1
               SET @nErrNo = 0
            END
         END
      END
      
      SET @cOutField03 = @cCaseID
      
      -- Get position not yet assign
      IF @cPosition = ''
         SELECT TOP 1
            @cPosition = DP.DevicePosition
         FROM dbo.DeviceProfile DP WITH (NOLOCK)
         WHERE DP.DeviceType = 'CART'
            AND DP.DeviceID = @cCartID
            AND NOT EXISTS( SELECT 1
               FROM rdt.rdtPTLCartLog PCLog WITH (NOLOCK)
               WHERE CartID = @cCartID
                  AND PCLog.Position = DP.DevicePosition)
         ORDER BY DP.DevicePosition
      
      -- Check position blank
      IF @cPosition = ''
      BEGIN
         SET @nErrNo = 59656
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoMorePosition
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- Position
         SET @cOutField04 = ''
         GOTO Quit
      END
      SET @cOutField04 = @cPosition

      -- Auto assign ToteID
      IF @cToteID = '' AND @cDefaultCaseIDAsToteID = '1'
         SET @cToteID = @cCaseID
         
      -- Check blank tote
      IF @cToteID = ''
      BEGIN
         SET @nErrNo = 59657
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ToteID
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- ToteID
         SET @cOutField05 = ''
         GOTO Quit
      END

      -- Check tote assigned
      IF EXISTS( SELECT 1
         FROM rdt.rdtPTLCartLog WITH (NOLOCK)
         WHERE CartID = @cCartID
            AND ToteID = @cToteID)
      BEGIN
         SET @nErrNo = 59658
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote Assigned
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- ToteID
         SET @cOutField05 = ''
         GOTO Quit
      END

      DECLARE @cIPAddress NVARCHAR(40)
      DECLARE @cLOC NVARCHAR(10)
      DECLARE @cSKU NVARCHAR(20)
      DECLARE @nQTY INT

      -- Get position info
      SELECT @cIPAddress = IPAddress
      FROM DeviceProfile WITH (NOLOCK)
      WHERE DeviceType = 'CART'
         AND DeviceID = @cCartID
         AND DevicePosition = @cPosition

      BEGIN TRAN
      SAVE TRAN rdt_PTLCart_Assign_CaseTote

      -- Save assign
      INSERT INTO rdt.rdtPTLCartLog (CartID, Position, ToteID, DeviceProfileLogKey, Method, PickZone, PickSeq, CaseID, StorerKey)
      VALUES (@cCartID, @cPosition, @cToteID, @cDPLKey, @cMethod, @cPickZone, @cPickSeq, @cCaseID, @cStorerKey)
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 59659
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Log fail
         GOTO RollBackTran
      END

      -- Insert PTLTran
      DECLARE @curPD CURSOR
      IF @cPickZone = ''
         SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT PD.LOC, PD.SKU, SUM( PD.QTY)
            FROM Orders O WITH (NOLOCK)
               JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
               JOIN LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            WHERE LOC.Facility = @cFacility
               AND PD.StorerKey = @cStorerKey
               AND PD.CaseID = @cCaseID
               AND PD.Status < '4'
               AND PD.QTY > 0
               AND O.Status <> 'CANC'
               AND O.SOStatus <> 'CANC'
            GROUP BY PD.LOC, PD.SKU
      ELSE
         SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT LOC.LOC, PD.SKU, SUM( PD.QTY)
            FROM Orders O WITH (NOLOCK)
               JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
               JOIN LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            WHERE LOC.Facility = @cFacility
               AND PD.StorerKey = @cStorerKey
               AND PD.CaseID = @cCaseID
               AND PD.Status < '4'
               AND PD.QTY > 0
               AND O.Status <> 'CANC'
               AND O.SOStatus <> 'CANC'
               AND LOC.PickZone = @cPickZone
            GROUP BY LOC.LOC, PD.SKU

      OPEN @curPD
      FETCH NEXT FROM @curPD INTO @cLOC, @cSKU, @nQTY
      WHILE @@FETCH_STATUS = 0
      BEGIN
         INSERT INTO PTL.PTLTran (
            IPAddress, DeviceID, DevicePosition, Status, PTLType,
            DeviceProfileLogKey, DropID, CaseID, Storerkey, SKU, LOC, ExpectedQTY, QTY)
         VALUES (
            @cIPAddress, @cCartID, @cPosition, '0', 'CART',
            @cDPLKey, '', @cCaseID, @cStorerKey, @cSKU, @cLOC, @nQTY, 0)

         IF @@ERROR <> ''
         BEGIN
            SET @nErrNo = 59660
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode ,'DSP') --INS PTL Fail
            GOTO RollBackTran
         END
         FETCH NEXT FROM @curPD INTO @cLOC, @cSKU, @nQTY
      END
      
      COMMIT TRAN rdt_PTLCart_Assign_CaseTote

      SET @nTotalTote = @nTotalTote + 1

      -- Get position not yet assign
      SET @cPosition = ''
      SELECT TOP 1
         @cPosition = DP.DevicePosition
      FROM dbo.DeviceProfile DP WITH (NOLOCK)
      WHERE DP.DeviceType = 'CART'
         AND DP.DeviceID = @cCartID
         AND NOT EXISTS( SELECT 1
            FROM rdt.rdtPTLCartLog PCLog WITH (NOLOCK)
            WHERE CartID = @cCartID
               AND PCLog.Position = DP.DevicePosition)
      ORDER BY DP.DevicePosition

      -- Prepare current screen var
      SET @cOutField03 = '' --CaseID
      SET @cOutField04 = @cPosition
      SET @cOutField05 = '' -- ToteID
      SET @cOutField06 = CAST( @nTotalTote AS NVARCHAR(5))

      -- Stay in current page
      SET @nErrNo = -1
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_PTLCart_Assign_CaseTote
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO