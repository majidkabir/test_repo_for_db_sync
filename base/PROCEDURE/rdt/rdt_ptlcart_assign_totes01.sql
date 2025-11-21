SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_PTLCart_Assign_Totes01                                */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 01-11-2018 1.0  Ung      WMS-6818 Created                                  */
/* 25-02-2019 1.1  Ung      Change to PTL.Schema                              */
/******************************************************************************/

CREATE PROC [RDT].[rdt_PTLCart_Assign_Totes01] (
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

   DECLARE @cOrderKey   NVARCHAR(10)
   DECLARE @cPosition   NVARCHAR(10)
   DECLARE @cToteID     NVARCHAR(20)

   SET @nTranCount = @@TRANCOUNT
      
   /***********************************************************************************************
                                                POPULATE
   ***********************************************************************************************/
   IF @cType = 'POPULATE-IN'
   BEGIN
      -- Get total tote
      SELECT @nTotalTote = COUNT(1) FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID

		-- Prepare next screen var
		SET @cOutField01 = @cCartID
		SET @cOutField02 = @cPickZone
		SET @cOutField03 = '' -- OrderKey
		SET @cOutField04 = '' -- Position
		SET @cOutField05 = '' -- ToteID
		SET @cOutField06 = CAST( @nTotalTote AS NVARCHAR(5))

	   EXEC rdt.rdtSetFocusField @nMobile, 5 -- ToteID

		-- Go to totes screen
		SET @nScn = 4183
   END
      
   /*   
   IF @cType = 'POPULATE-OUT'
   BEGIN
		-- Go to cart screen
   END
   */

   /***********************************************************************************************
                                                 CHECK
   ***********************************************************************************************/
   IF @cType = 'CHECK'
   BEGIN
      DECLARE @cPickConfirmStatus NVARCHAR( 1)
      SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
      IF @cPickConfirmStatus = '0'
         SET @cPickConfirmStatus = '5'

      IF @cPickConfirmStatus NOT IN ('3', '5')
         SET @cPickConfirmStatus = '5'

      -- Screen mapping
      SET @cOrderKey = @cInField05
      SET @cToteID = @cInField05

      -- Get total tote
      SELECT @nTotalTote = COUNT(1) FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID

      -- Check finish assign
      IF @nTotalTote > 0 AND @cToteID = ''
      BEGIN
         GOTO Quit
      END

      -- Check blank tote
      IF @cToteID = ''
      BEGIN
         SET @nErrNo = 131301
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
         SET @nErrNo = 131302
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote Assigned
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- ToteID
         SET @cOutField05 = ''
         GOTO Quit
      END
         
      -- Check tote valid
      IF NOT EXISTS( SELECT TOP 1 1
         FROM PackDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND LabelNo = @cToteID)
      BEGIN
         SET @nErrNo = 131303
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Tote ID
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- ToteID
         SET @cOutField05 = ''
         GOTO Quit
      END

      -- Check tote have task
      IF NOT EXISTS( SELECT TOP 1 1
         FROM PickDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND CaseID = @cToteID
            AND Status <> '4'
            AND Status < @cPickConfirmStatus
            AND QTY > 0)
      BEGIN
         SET @nErrNo = 131304
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote no task
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- ToteID
         SET @cOutField05 = ''
         GOTO Quit
      END
      
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
      
      -- Check position blank
      IF @cPosition = ''
      BEGIN
         SET @nErrNo = 131305
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoMorePosition
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
      SAVE TRAN rdt_PTLCart_Assign_Totes01
      
      -- Save assign
      INSERT INTO rdt.rdtPTLCartLog (CartID, Position, ToteID, DeviceProfileLogKey, Method, PickZone, PickSeq, CaseID, StorerKey)
      VALUES (@cCartID, @cPosition, @cToteID, @cDPLKey, @cMethod, @cPickZone, @cPickSeq, @cToteID, @cStorerKey)
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 131306
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log Fail
         GOTO RollBackTran
      END

      -- Insert PTLTran
      DECLARE @curPD CURSOR
      IF @cPickZone = ''
         SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT PD.LOC, PD.SKU, SUM( PD.QTY)
            FROM PickDetail PD WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND CaseID = @cToteID
               AND PD.Status <> '4'
               AND PD.Status < @cPickConfirmStatus
               AND PD.QTY > 0
            GROUP BY PD.LOC, PD.SKU
      ELSE
         SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT LOC.LOC, PD.SKU, SUM( PD.QTY)
            FROM PickDetail PD WITH (NOLOCK)
               JOIN LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            WHERE StorerKey = @cStorerKey
               AND CaseID = @cToteID
               AND PD.Status <> '4'
               AND PD.Status < @cPickConfirmStatus
               AND PD.QTY > 0
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
            @cDPLKey, '', @cToteID, @cStorerKey, @cSKU, @cLOC, @nQTY, 0)
   
         IF @@ERROR <> ''
         BEGIN
            SET @nErrNo = 131307
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode ,'DSP') --INS PTL Fail
            GOTO RollBackTran
         END
         FETCH NEXT FROM @curPD INTO @cLOC, @cSKU, @nQTY
      END

      COMMIT TRAN rdt_PTLCart_Assign_Totes01

      SET @nTotalTote = @nTotalTote + 1

      -- Prepare current screen var
      SET @cOutField03 = '' 
      SET @cOutField04 = @cPosition
      SET @cOutField05 = '' -- ToteID
      SET @cOutField06 = CAST( @nTotalTote AS NVARCHAR(5))
      
      -- Stay in current page
      SET @nErrNo = -1 
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_PTLCart_Assign_Totes01
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO