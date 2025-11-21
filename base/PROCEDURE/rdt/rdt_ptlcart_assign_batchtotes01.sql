SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*******************************************************************************/
/* Store procedure: rdt_PTLCart_Assign_BatchTotes01                            */
/* Copyright      : LFLogistics                                                */
/*                                                                             */
/* Date       Rev  Author   Purposes                                           */
/* 29-03-2019 1.0  Ung      WMS-8024 Creted                                    */
/* 01-09-2021 1.1  James    WMS-17826 Filter pickzone when assign cart(james01)*/
/* 30-09-2021 1.2  James    Prevent insert PTLTran for certain pickzone setup  */
/*                          under CODELKUP (james02)                           */
/*******************************************************************************/

CREATE PROC [RDT].[rdt_PTLCart_Assign_BatchTotes01] (
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
   DECLARE @cErrMsg1    NVARCHAR(20)

   DECLARE @cBatchKey   NVARCHAR(20)
   DECLARE @cPosition   NVARCHAR(10)
   DECLARE @cToteID     NVARCHAR(20)
   DECLARE @cCaseID     NVARCHAR(20)
   DECLARE @nTotalPOS   INT
   DECLARE @nTotalTote  INT
   DECLARE @nRowRef     BIGINT

   SET @nTranCount = @@TRANCOUNT
      
   /***********************************************************************************************
                                                POPULATE
   ***********************************************************************************************/
   IF @cType = 'POPULATE-IN'
   BEGIN
      -- Get work info
      SET @cBatchKey = ''
      SELECT TOP 1 @cBatchKey = BatchKey FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID
      SELECT @nTotalPOS = COUNT(1) FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID
      SELECT @nTotalTote = COUNT(1) FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID AND ToteID <> ''

		-- Prepare next screen var
		SET @cOutField01 = @cCartID
		SET @cOutField02 = @cPickZone
		SET @cOutField03 = @cBatchKey
		SET @cOutField04 = '' -- Position
		SET @cOutField05 = '' -- ToteID
		SET @cOutField06 = CAST( @nTotalPOS AS NVARCHAR(5))
		SET @cOutField07 = CAST( @nTotalTote AS NVARCHAR(5))

      IF @cBatchKey = ''
      BEGIN
         -- Enable disable field
         SET @cFieldAttr03 = ''  -- BatchKey
         SET @cFieldAttr05 = 'O' -- ToteID

   	   EXEC rdt.rdtSetFocusField @nMobile, 3 -- BatchKey
      END
      ELSE
      BEGIN
         SET @cFieldAttr03 = 'O' -- BatchKey
         SET @cFieldAttr05 = 'O'  -- ToteID

         IF @nTotalPOS > @nTotalTote
         BEGIN
            -- Get tote not yet assign
            SELECT TOP 1 
               @cPosition = Position
            FROM rdt.rdtPTLCartLog WITH (NOLOCK)
            WHERE CartID = @cCartID
               AND ToteID = ''
            ORDER BY RowRef 

      		-- Prepare next screen var
      		SET @cOutField04 = @cPosition 

            -- Enable field
            IF rdt.rdtGetConfig( @nFunc, 'DefaultToteIDAsPos', @cStorerKey) = '1'
            BEGIN
               SET @cToteID = @cPosition
               SET @cOutField06 = @cToteID
            END
            ELSE
            BEGIN
               SET @cFieldAttr05 = ''   -- ToteID
            END
         END
      END
		
		-- Go to batch totes screen
		--SET @nScn = 5142 -- remarked coz 5142 scn is for other module
      SET @nScn = 5042
   END
      
   IF @cType = 'POPULATE-OUT'
   BEGIN
      -- Enable field
      SET @cFieldAttr03 = '' -- BatchKey
      SET @cFieldAttr05 = '' -- ToteID

		-- Go to cart screen
   END

   
   /***********************************************************************************************
                                                 CHECK
   ***********************************************************************************************/
   IF @cType = 'CHECK'
   BEGIN
      DECLARE @cCheckBatchUsed NVARCHAR( 1)
      DECLARE @cMultiPickerBatch NVARCHAR( 1)
      DECLARE @cPickConfirmStatus NVARCHAR( 1)
      DECLARE @cIPAddress NVARCHAR(40)
      DECLARE @cLOC NVARCHAR(10)
      DECLARE @cSKU NVARCHAR(20)
      DECLARE @nQTY INT
      DECLARE @curPD CURSOR
      
      SET @cCheckBatchUsed = rdt.rdtGetConfig( @nFunc, 'CheckBatchUsed', @cStorerKey)
      SET @cMultiPickerBatch = rdt.RDTGetConfig( @nFunc, 'MultiPickerBatch', @cStorerKey)
      SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
      IF @cPickConfirmStatus = '0'
         SET @cPickConfirmStatus = '5'

      IF @cMultiPickerBatch = '1'
         SET @cPickZone = ''

      -- Screen mapping
      SET @cBatchKey = CASE WHEN @cFieldAttr03 = '' THEN @cInField03 ELSE @cOutField03 END
      SET @cPosition = @cOutField04
      SET @cToteID   = CASE WHEN @cFieldAttr05 = '' THEN @cInField05 ELSE @cOutField05 END

      -- Get storer config
      DECLARE @cDefaultToteIDAsPos NVARCHAR(1)
      SET @cDefaultToteIDAsPos = rdt.rdtGetConfig( @nFunc, 'DefaultToteIDAsPos', @cStorerKey)

      -- (james01)
      DECLARE @tPTL TABLE ( PickZone NVARCHAR( 10))
      INSERT INTO @tPTL (PickZone)
      SELECT DISTINCT Code
      FROM dbo.CODELKUP WITH (NOLOCK)
      WHERE LISTNAME = 'CartEPZone'
      AND   Storerkey = @cStorerKey
      AND   code2 = @nFunc
      AND   Short = @cFacility
      ORDER BY 1
            
      -- BatchKey field enabled
      IF @cFieldAttr03 = ''
      BEGIN
   		-- Check blank
   		IF @cBatchKey = '' 
         BEGIN
            SET @nErrNo = 136951
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need BatchKey
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- BatchKey
            GOTO Quit
         END

         -- Check BatchKey valid
         IF NOT EXISTS( SELECT 1 
            FROM PickDetail WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey 
               AND Status < @cPickConfirmStatus 
               AND PickSlipNo = @cBatchKey)
         BEGIN
            SET @nErrNo = 136952
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad BatchKey
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- BatchKey
            SET @cOutField03 = ''
            GOTO Quit
         END

         -- Check BatchKey used
         IF @cCheckBatchUsed = '1'
         BEGIN
            IF EXISTS( SELECT TOP 1 1 FROM PTL.PTLTran WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SourceKey = @cBatchKey AND Status = '9')
            BEGIN
               SET @nErrNo = 136953
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Batch used
               EXEC rdt.rdtSetFocusField @nMobile, 3 -- BatchKey
               SET @cOutField03 = ''
            END
         END
         
         -- Check BatchKey assigned
         IF @cMultiPickerBatch <> '1'
         BEGIN
            IF EXISTS( SELECT 1 FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID AND BatchKey = @cBatchKey AND AddWho <> SUSER_SNAME())
            BEGIN
               SET @nErrNo = 136954
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Batch Assigned
               EXEC rdt.rdtSetFocusField @nMobile, 3 -- BatchKey
               SET @cOutField03 = ''
               GOTO Quit
            END
         END

         -- Assign positions
         IF NOT EXISTS( SELECT 1 FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID)
         BEGIN
            DECLARE @cChkFacility  NVARCHAR(5)
            DECLARE @cChkStorerKey NVARCHAR(15)
            DECLARE @cChkStatus    NVARCHAR(10)
            DECLARE @cChkSOStatus  NVARCHAR(10)
            SET @cChkFacility = ''
            SET @cChkStorerKey = ''
            SET @cChkStatus = ''
            SET @cChkSOStatus = ''
            SET @nTotalPOS = 0
            SET @nTotalTote = 0
   
            DECLARE @curBatch CURSOR
            SET @curBatch = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT DISTINCT CaseID
               FROM PickDetail PD WITH (NOLOCK) 
                  JOIN LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
               WHERE PD.StorerKey = @cStorerKey 
                  AND PD.Status <> '4'
                  AND PD.Status < @cPickConfirmStatus
                  AND PD.PickSlipNo = @cBatchKey
                  AND LOC.LocationCategory NOT IN ('PND', 'VNA')
                  AND NOT EXISTS ( SELECT 1 FROM @tPTL PTL WHERE PTL.PickZone = LOC.PickZone)
               ORDER BY CaseID

            SET @nTranCount = @@TRANCOUNT
            BEGIN TRAN
            SAVE TRAN rdt_PTLCart_Assign_BatchTotes01     

            OPEN @curBatch
            FETCH NEXT FROM @curBatch INTO @cCaseID
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- Check case ID assigned
               IF @cPickZone = ''
                  SELECT @nErrNo = 1
                  FROM rdt.rdtPTLCartLog WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                     AND BatchKey = @cBatchKey
                     AND CaseID = @cCaseID
                     
               ELSE
                  SELECT @nErrNo = 1
                  FROM rdt.rdtPTLCartLog WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                     AND BatchKey = @cBatchKey
                     AND CaseID = @cCaseID
                     AND (PickZone = @cPickZone OR PickZone = '')
               IF @nErrNo <> 0
               BEGIN
                  SET @nErrNo = 136955
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --POS Assigned
                  GOTO RollBackTran
               END

               -- Check case ID have task  
               DECLARE @cTask NVARCHAR(1)
               SET @cTask = ''
               IF @cPickZone = ''  
                  SELECT TOP 1 
                     @cTask = 'Y'
                  FROM dbo.PickDetail PD WITH (NOLOCK)   
                     JOIN LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)  
                  WHERE PD.PickSlipNo = @cBatchKey  
                     AND PD.CaseID = @cCaseID
                     AND PD.Status <> '4'  
                     AND PD.Status < @cPickConfirmStatus  
                     AND PD.QTY > 0  
                     AND LOC.LocationCategory NOT IN ('PND', 'VNA')
               ELSE   
                  SELECT TOP 1 
                     @cTask = 'Y'
                  FROM dbo.PickDetail PD WITH (NOLOCK)   
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)  
                  WHERE PD.PickSlipNo = @cBatchKey  
                     AND CaseID = @cCaseID  
                     AND PD.Status <> '4'  
                     AND PD.Status < @cPickConfirmStatus  
                     AND PD.QTY > 0  
                     AND LOC.PickZone = @cPickZone  
                     AND LOC.LocationCategory NOT IN ('PND', 'VNA')  

               -- Skip current case ID
               IF @cTask = ''  
               BEGIN  
                  FETCH NEXT FROM @curBatch INTO @cCaseID
                  CONTINUE  
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
                  SET @nErrNo = 136956
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoMorePosition
                  GOTO RollBackTran
               END
               
               -- Save assign
               INSERT INTO rdt.rdtPTLCartLog (CartID, Position, ToteID, DeviceProfileLogKey, Method, PickZone, PickSeq, BatchKey, CaseID, StorerKey)
               VALUES (@cCartID, @cPosition, '', @cDPLKey, @cMethod, @cPickZone, @cPickSeq, @cBatchKey, @cCaseID, @cStorerKey)
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 136958
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log Fail
                  GOTO RollBackTran
               END

               SET @nTotalPOS = @nTotalPOS + 1
                  
               FETCH NEXT FROM @curBatch INTO @cCaseID
            END
   
            COMMIT TRAN rdt_PTLCart_Assign_BatchTotes01
         END

         -- Clear earlier assigned 
         IF @nErrNo <> 0 AND @nTotalPOS > 0
         BEGIN
            DELETE rdt.rdtPTLCartLog WHERE CartID = @cCartID AND BatchKey = @cBatchKey AND AddWho = SUSER_SNAME()
            GOTO Quit
         END
         
         -- Check empty batch
         IF @nTotalPOS = 0
         BEGIN
            SET @nErrNo = 136959
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Batch No Task!
            GOTO Quit
         END

         -- Get tote not yet assign
         SET @cPosition = ''
         SELECT TOP 1 
            @cPosition = Position, 
            @cToteID = ''
         FROM rdt.rdtPTLCartLog WITH (NOLOCK)
         WHERE CartID = @cCartID
            AND ToteID = ''
         ORDER BY RowRef 

         SELECT @nTotalPOS = COUNT(1) FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID
         SELECT @nTotalTote = COUNT(1) FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID AND ToteID <> ''
         
         -- Prepare current screen var
         SET @cOutField03 = @cBatchKey
         SET @cOutField04 = @cPosition
         SET @cOutField05 = '' -- ToteID
         SET @cOutField06 = CAST( @nTotalPOS AS NVARCHAR(5))
         SET @cOutField07 = CAST( @nTotalTote AS NVARCHAR(5))

         -- Enable / Disable field
         SET @cFieldAttr03 = 'O' -- BatchKey
         SET @cFieldAttr05 = ''  -- ToteID
         
         -- Remain in current screen
         SET @nErrNo = -1
         GOTO Quit
      END

      -- ToteID field enabled
      IF @cFieldAttr05 = ''
      BEGIN
         -- Check blank tote
         IF @cToteID = ''
         BEGIN
            SET @nErrNo = 136960
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ToteID
            EXEC rdt.rdtSetFocusField @nMobile, 5 -- ToteID
            SET @cOutField05 = ''
            GOTO Quit
         END

         -- Check format
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'ToteID', @cToteID) = 0
         BEGIN
            SET @nErrNo = 136964
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
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
            SET @nErrNo = 136961
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote Assigned
            EXEC rdt.rdtSetFocusField @nMobile, 5 -- ToteID
            SET @cOutField05 = ''
            GOTO Quit
         END
         SET @cOutField05 = @cToteID
      
         -- Get position info
         SELECT @cIPAddress = IPAddress
         FROM DeviceProfile WITH (NOLOCK)
         WHERE DeviceType = 'CART'
            AND DeviceID = @cCartID
            AND DevicePosition = @cPosition
   
         -- Get case ID
         SELECT @cCaseID = CaseID
         FROM rdt.rdtPTLCartLog WITH (NOLOCK)
         WHERE CartID = @cCartID
            AND Position = @cPosition
   
         SET @nTranCount = @@TRANCOUNT
         BEGIN TRAN
         SAVE TRAN rdt_PTLCart_Assign_BatchTotes01
         
         -- Save assign
         UPDATE rdt.rdtPTLCartLog SET
            ToteID = @cToteID
         WHERE CartID = @cCartID
            AND Position = @cPosition
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 136962
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Log fail
            GOTO RollBackTran
         END
   
         -- Insert PTLTran
         IF @cPickZone = ''
            SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT PD.LOC, PD.SKU, SUM( PD.QTY)
               FROM dbo.PickDetail PD WITH (NOLOCK) 
                  JOIN dbo.LOC LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
               WHERE PD.PickSlipNo = @cBatchKey
                  AND PD.CaseID = @cCaseID
                  AND PD.Status <> '4'
                  AND PD.Status < @cPickConfirmStatus
                  AND PD.QTY > 0
                  AND LOC.LocationCategory NOT IN ('PND', 'VNA')
                  AND NOT EXISTS ( SELECT 1 FROM @tPTL PTL WHERE PTL.PickZone = LOC.PickZone)
               GROUP BY PD.LOC, PD.SKU
         ELSE
            SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT LOC.LOC, PD.SKU, SUM( PD.QTY)
               FROM dbo.PickDetail PD WITH (NOLOCK) 
                  JOIN dbo.LOC LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
               WHERE PD.PickSlipNo = @cBatchKey
                  AND PD.CaseID = @cCaseID
                  AND PD.Status <> '4'
                  AND PD.Status < @cPickConfirmStatus
                  AND PD.QTY > 0
                  AND LOC.PickZone = @cPickZone
                  AND LOC.LocationCategory NOT IN ('PND', 'VNA')
                  AND NOT EXISTS ( SELECT 1 FROM @tPTL PTL WHERE PTL.PickZone = LOC.PickZone)
               GROUP BY LOC.LOC, PD.SKU
         
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cLOC, @cSKU, @nQTY
         WHILE @@FETCH_STATUS = 0
         BEGIN
            INSERT INTO PTL.PTLTran (
               IPAddress, DeviceID, DevicePosition, Status, PTLType, 
               DeviceProfileLogKey, DropID, OrderKey, Storerkey, SKU, LOC, ExpectedQTY, QTY, SourceKey, CaseID)
            VALUES (
               @cIPAddress, @cCartID, @cPosition, '0', 'CART',
               @cDPLKey, '', '', @cStorerKey, @cSKU, @cLOC, @nQTY, 0, @cBatchKey, @cCaseID)
      
            IF @@ERROR <> ''
            BEGIN
               SET @nErrNo = 136963
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode ,'DSP') --INS PTL Fail
               GOTO RollBackTran
            END
            FETCH NEXT FROM @curPD INTO @cLOC, @cSKU, @nQTY
         END

         COMMIT TRAN rdt_PTLCart_Assign_BatchTotes01
      END

      -- Get Total
      SELECT @nTotalPOS = COUNT(1) FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID
      SELECT @nTotalTote = COUNT(1) FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID AND ToteID <> ''

      -- Check finish assign
      IF @nTotalPOS > 0 AND @nTotalPOS = @nTotalTote
      BEGIN
         -- Enable field
         SET @cFieldAttr03 = '' -- BatchKey
         SET @cFieldAttr06 = '' -- ToteID
         
         GOTO Quit
      END

      -- Get tote not yet assign
      SELECT TOP 1 
         @cPosition = Position
      FROM rdt.rdtPTLCartLog WITH (NOLOCK)
      WHERE CartID = @cCartID
         AND ToteID = ''
      ORDER BY RowRef 

      -- Prepare current screen var
      SET @cOutField04 = @cPosition
      SET @cOutField05 = '' -- ToteID
      SET @cOutField06 = CAST( @nTotalPOS AS NVARCHAR(5))
      SET @cOutField07 = CAST( @nTotalTote AS NVARCHAR(5))
      
      -- Stay in current page
      SET @nErrNo = -1 
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_PTLCart_Assign_BatchTotes01

Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO