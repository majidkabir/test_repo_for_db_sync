SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_PTLCart_Assign_Totes                                  */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 06-05-2015 1.0  Ung      SOS333663 Created                                 */
/* 26-01-2018 1.1  Ung      Change to PTL.Schema                              */
/******************************************************************************/

CREATE PROC [RDT].[rdt_PTLCart_Assign_Totes] (
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

   DECLARE @cChkFacility  NVARCHAR(5)
   DECLARE @cChkStorerKey NVARCHAR(15)
   DECLARE @cChkStatus    NVARCHAR(10)
   DECLARE @cChkSOStatus  NVARCHAR(10)

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
         SET @nErrNo = 54063
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
         SET @nErrNo = 54064
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote Assigned
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- ToteID
         SET @cOutField05 = ''
         GOTO Quit
      END
      
      SET @cChkFacility = ''
      SET @cChkStorerKey = ''
      SET @cChkStatus = ''
      SET @cChkSOStatus = ''
         
      -- Get order info
      SELECT 
         @cChkFacility = Facility, 
         @cChkStorerKey = StorerKey, 
         @cChkStatus = Status, 
         @cChkSOStatus = SOStatus
      FROM Orders WITH (NOLOCK)
      WHERE OrderKey = @cOrderKey
      
      -- Check order valid
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 54052
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad OrderKey
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- ToteID
         SET @cOutField05 = ''
         GOTO Quit
      END

      -- Check storer
      IF @cStorerKey <> @cChkStorerKey
      BEGIN
         SET @nErrNo = 54053
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storer
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- ToteID
         SET @cOutField05 = ''
         GOTO Quit
      END

      -- Check facility
      IF @cFacility <> @cChkFacility
      BEGIN
         SET @nErrNo = 54054
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- ToteID
         SET @cOutField05 = ''
         GOTO Quit
      END
            
      -- Check order CANC
      IF @cChkStatus = 'CANC' OR @cChkSOStatus = 'CANC' 
      BEGIN
         SET @nErrNo = 54055
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order CANCEL
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- ToteID
         SET @cOutField05 = ''
         GOTO Quit
      END
      
      -- Check order status
      IF @cChkStatus = '0'
      BEGIN
         SET @nErrNo = 54056
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order NotAlloc
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- ToteID
         SET @cOutField05 = ''
         GOTO Quit
      END
      
      -- Check order status
      IF @cChkStatus >= '5'
      BEGIN
         SET @nErrNo = 54057
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order picked
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- ToteID
         SET @cOutField05 = ''
         GOTO Quit
      END

      -- Check order assigned
      IF @cPickZone = ''
         SELECT @nErrNo = 1
         FROM rdt.rdtPTLCartLog WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey
      ELSE
         SELECT @nErrNo = 1
         FROM rdt.rdtPTLCartLog WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey
            AND (PickZone = @cPickZone OR PickZone = '')
      IF @nErrNo <> 0
      BEGIN
         SET @nErrNo = 54058
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrderAssigned
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- ToteID
         SET @cOutField05 = ''
         GOTO Quit
      END

      -- Check order have task
      SET @nErrNo = 1
      IF @cPickZone = ''
         SELECT @nErrNo = 0
         FROM Orders O WITH (NOLOCK)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
         WHERE PD.OrderKey = @cOrderKey
            AND PD.Status < '4'
            AND PD.QTY > 0
            AND O.Status <> 'CANC'
            AND O.SOStatus <> 'CANC'
      ELSE 
         SELECT @nErrNo = 0 
         FROM Orders O WITH (NOLOCK)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
            JOIN dbo.LOC LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
         WHERE PD.OrderKey = @cOrderKey
            AND PD.Status < '4'
            AND PD.QTY > 0
            AND O.Status <> 'CANC'
            AND O.SOStatus <> 'CANC'
            AND LOC.PickZone = @cPickZone
      IF @nErrNo <> 0
      BEGIN
         SET @nErrNo = 54059
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order no task
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
         SET @nErrNo = 54060
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
      SAVE TRAN rdt_PTLCart_Assign_Totes
      
      -- Save assign
      INSERT INTO rdt.rdtPTLCartLog (CartID, Position, ToteID, DeviceProfileLogKey, Method, PickZone, PickSeq, OrderKey, StorerKey)
      VALUES (@cCartID, @cPosition, @cToteID, @cDPLKey, @cMethod, @cPickZone, @cPickSeq, @cOrderKey, @cStorerKey)
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 54065
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log Fail
         GOTO RollBackTran
      END

      -- Insert PTLTran
      DECLARE @curPD CURSOR
      IF @cPickZone = ''
         SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT PD.LOC, PD.SKU, SUM( PD.QTY)
            FROM Orders O WITH (NOLOCK) 
               JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
            WHERE O.OrderKey = @cOrderKey
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
            WHERE O.OrderKey = @cOrderKey
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
            DeviceProfileLogKey, DropID, OrderKey, Storerkey, SKU, LOC, ExpectedQTY, QTY)
         VALUES (
            @cIPAddress, @cCartID, @cPosition, '0', 'CART',
            @cDPLKey, '', @cOrderKey, @cStorerKey, @cSKU, @cLOC, @nQTY, 0)
   
         IF @@ERROR <> ''
         BEGIN
            SET @nErrNo = 54066
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode ,'DSP') --INS PTL Fail
            GOTO RollBackTran
         END
         FETCH NEXT FROM @curPD INTO @cLOC, @cSKU, @nQTY
      END

      COMMIT TRAN rdt_PTLCart_Assign_Totes

      SET @nTotalTote = @nTotalTote + 1

      -- Prepare current screen var
      SET @cOutField03 = @cOrderKey
      SET @cOutField04 = @cPosition
      SET @cOutField05 = '' -- ToteID
      SET @cOutField06 = CAST( @nTotalTote AS NVARCHAR(5))
      
      -- Stay in current page
      SET @nErrNo = -1 
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_PTLCart_Assign_Totes
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO