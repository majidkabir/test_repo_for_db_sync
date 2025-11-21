SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_PTLCart_Assign_BatchOneTote                           */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 25-07-2017 1.0  Ung      WMS-2305 Created                                  */
/* 11-09-2017 1.1  Ung      Workaround SQL bug, cursor fetch 2 times          */
/* 04-01-2018 1.2  Ung      WMS-3012 Prompt case ID reuse                     */
/* 26-02-2018 1.3  Ung      Change to PTL.Schema                              */
/* 29-07-2020 1.4  Chermaine WMS-14359 Allow Multi Orders-SKU in 1 batch(cc01)*/
/******************************************************************************/

CREATE PROC [RDT].[rdt_PTLCart_Assign_BatchOneTote] (
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
   DECLARE @cOrderKey   NVARCHAR(10)
   DECLARE @cPosition   NVARCHAR(10)
   DECLARE @cToteID     NVARCHAR(20)
   DECLARE @nTotalOrder INT
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
      SET @cToteID = ''
      SELECT TOP 1 
         @cBatchKey = BatchKey, 
         @cToteID = ToteID 
      FROM rdt.rdtPTLCartLog WITH (NOLOCK) 
      WHERE CartID = @cCartID

      SELECT @nTotalOrder = COUNT(1) FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID

		-- Prepare next screen var
		SET @cOutField01 = @cCartID
		SET @cOutField02 = @cPickZone
		SET @cOutField03 = @cBatchKey
		SET @cOutField04 = @cToteID
		SET @cOutField05 = CAST( @nTotalOrder AS NVARCHAR(5))

      SET @cFieldAttr03 = 'O' --  BatchKey
      SET @cFieldAttr04 = 'O'  -- ToteID

      IF @cBatchKey = ''
      BEGIN
         -- Enable disable field
         SET @cFieldAttr03 = ''  -- BatchKey
         SET @cFieldAttr04 = 'O' -- ToteID

   	   EXEC rdt.rdtSetFocusField @nMobile, 3 -- BatchKey
      END
      
      ELSE IF @cToteID = ''
      BEGIN
         -- Enable disable field
         SET @cFieldAttr03 = 'O'  -- BatchKey
         SET @cFieldAttr04 = '' -- ToteID

   	   EXEC rdt.rdtSetFocusField @nMobile, 4 -- ToteID
      END
		
		-- Go to batch totes screen
		SET @nScn = 4189
   END
      
   IF @cType = 'POPULATE-OUT'
   BEGIN
      -- Enable field
      SET @cFieldAttr03 = '' -- BatchKey
      SET @cFieldAttr04 = '' -- ToteID

		-- Go to cart screen
   END

   
   /***********************************************************************************************
                                                 CHECK
   ***********************************************************************************************/
   IF @cType = 'CHECK'
   BEGIN
      DECLARE @cPickConfirmStatus NVARCHAR( 1)
      DECLARE @cCheckBatchUsed NVARCHAR( 1)
      DECLARE @cMultiOrdersBatch NVARCHAR( 1)   --(cc01)
      DECLARE @cIPAddress NVARCHAR(40)
      DECLARE @cLOC NVARCHAR(10)
      DECLARE @cSKU NVARCHAR(20)
      DECLARE @nQTY INT
      DECLARE @curPD CURSOR

      SET @cCheckBatchUsed = rdt.rdtGetConfig( @nFunc, 'CheckBatchUsed', @cStorerKey)
      SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
      IF @cPickConfirmStatus = '0'
         SET @cPickConfirmStatus = '5'
         
      SET @cMultiOrdersBatch = rdt.RDTGetConfig( @nFunc, 'MultiOrdersBatch', @cStorerKey) --(cc01)

      -- Screen mapping
      SET @cBatchKey = CASE WHEN @cFieldAttr03 = '' THEN @cInField03 ELSE @cOutField03 END
      SET @cToteID   = CASE WHEN @cFieldAttr04 = '' THEN @cInField04 ELSE @cOutField04 END

      -- BatchKey field enabled
      IF @cFieldAttr03 = ''
      BEGIN
   		-- Check blank
   		IF @cBatchKey = '' 
         BEGIN
            SET @nErrNo = 113001
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need BatchKey
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- BatchKey
            GOTO Quit
         END

         -- Check BatchKey valid
         IF NOT EXISTS( SELECT 1 FROM PickDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND Status < @cPickConfirmStatus AND PickSlipNo = @cBatchKey)
         BEGIN
            SET @nErrNo = 113002
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad BatchKey
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- BatchKey
            SET @cOutField03 = ''
            GOTO Quit
         END

         -- Check BatchKey assigned
         IF EXISTS( SELECT 1 FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID AND BatchKey = @cBatchKey AND AddWho <> SUSER_SNAME())
         BEGIN
            SET @nErrNo = 113003
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Batch Assigned
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- BatchKey
            SET @cOutField03 = ''
            GOTO Quit
         END
         
         -- Check BatchKey used
         IF @cCheckBatchUsed = '1'
         BEGIN
            IF EXISTS( SELECT TOP 1 1 FROM PTL.PTLTran WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SourceKey = @cBatchKey AND Status = '9')
            BEGIN
               SET @nErrNo = 113021
               SET @cErrMsg1 = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Batch used
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '113021', @cErrMsg1
               SET @nErrNo = 0
            END
         END
         
         IF @cMultiOrdersBatch <> 1 --(cc01)
         BEGIN 
            -- Check single batch (1 order, 1 QTY)
            IF EXISTS( SELECT TOP 1 1 
               FROM PickDetail WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
                  AND PickSlipNo = @cBatchKey
               GROUP BY OrderKey
               HAVING SUM( QTY) > 1)
            BEGIN
               SET @nErrNo = 113020
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotSingleBatch
               EXEC rdt.rdtSetFocusField @nMobile, 3 -- BatchKey
               SET @cOutField03 = ''
               GOTO Quit
            END
         END

         -- Assign order
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
            SET @nTotalOrder = 0
            SET @nTotalTote = 0
            SET @cPosition = ''
   
            DECLARE @curBatch CURSOR
            SET @curBatch = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT DISTINCT O.OrderKey 
               FROM Orders O WITH (NOLOCK)
                  JOIN dbo.PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
               WHERE O.StorerKey = @cStorerKey 
                  AND PD.Status <> '4'
                  AND PD.Status < @cPickConfirmStatus
                  AND PickSlipNo = @cBatchKey
                  AND PD.QTY > 0
                  AND O.Status <> 'CANC'
                  AND O.SOStatus <> 'CANC'
               ORDER BY OrderKey

            SET @nTranCount = @@TRANCOUNT
            BEGIN TRAN
            SAVE TRAN rdt_PTLCart_Assign_BatchOneTote     

            OPEN @curBatch
            FETCH NEXT FROM @curBatch INTO @cOrderKey
            WHILE @@FETCH_STATUS = 0
            BEGIN
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
                  SET @nErrNo = 113004
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad OrderKey
                  GOTO RollBackTran
               END
         
               -- Check storer
               IF @cStorerKey <> @cChkStorerKey
               BEGIN
                  SET @nErrNo = 113005
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storer
                  GOTO RollBackTran
               END
         
               -- Check facility
               IF @cFacility <> @cChkFacility
               BEGIN
                  SET @nErrNo = 113006
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
                  GOTO RollBackTran
               END
                     
               -- Check order CANC
               IF @cChkStatus = 'CANC' OR @cChkSOStatus = 'CANC' 
               BEGIN
                  SET @nErrNo = 113007
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order CANCEL
                  GOTO RollBackTran
               END
               
               -- Check order status
               IF @cChkStatus = '0'
               BEGIN
                  SET @nErrNo = 113008
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order NotAlloc
                  GOTO RollBackTran
               END
               
               -- Check order status
               IF @cChkStatus >= '5'
               BEGIN
                  SET @nErrNo = 113009
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order picked
                  GOTO RollBackTran
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
                  SET @nErrNo = 113010
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrderAssigned
                  GOTO RollBackTran
               END
         
               --INSERT INTO Traceinfo (traceName,col1,col2,col3)
               --VALUES('cc808',@cPickZone,@cPickConfirmStatus,@cOrderKey)
               
               -- Check order have task
               SET @nErrNo = 1
               IF @cPickZone = '' OR @cMultiOrdersBatch = '1'
                  SELECT @nErrNo = 0
                  FROM Orders O WITH (NOLOCK)
                     JOIN dbo.PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
                  WHERE PD.OrderKey = @cOrderKey
                     AND PD.Status <> '4'
                     AND PD.Status < @cPickConfirmStatus
                     AND PD.QTY > 0
                     AND O.Status <> 'CANC'
                     AND O.SOStatus <> 'CANC'
               ELSE 
                  SELECT @nErrNo = 0 
                  FROM Orders O WITH (NOLOCK)
                     JOIN dbo.PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
                  WHERE PD.OrderKey = @cOrderKey
                     AND PD.Status <> '4'
                     AND PD.Status < @cPickConfirmStatus
                     AND PD.QTY > 0
                     AND O.Status <> 'CANC'
                     AND O.SOStatus <> 'CANC'
                     AND LOC.PickZone = @cPickZone
               IF @nErrNo <> 0
               BEGIN
                  SET @nErrNo = 113011
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order no task
                  --GOTO RollBackTran
                  GOTO Quit
               END
   
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
                  SET @nErrNo = 113012
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoMorePosition
                  GOTO RollBackTran
               END
   
               -- Save assign
               INSERT INTO rdt.rdtPTLCartLog (CartID, Position, ToteID, DeviceProfileLogKey, Method, PickZone, PickSeq, BatchKey, OrderKey, StorerKey)
               VALUES (@cCartID, @cPosition, '', @cDPLKey, @cMethod, @cPickZone, @cPickSeq, @cBatchKey, @cOrderKey, @cStorerKey)
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 113013
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log Fail
                  GOTO RollBackTran
               END
   
               SET @nTotalOrder = @nTotalOrder + 1
                  
               FETCH NEXT FROM @curBatch INTO @cOrderKey
            END
   
            COMMIT TRAN rdt_PTLCart_Assign_BatchOneTote
         END

         -- Clear earlier assigned 
         IF @nErrNo <> 0 AND @nTotalOrder > 0
         BEGIN
            DELETE rdt.rdtPTLCartLog WHERE CartID = @cCartID AND BatchKey = @cBatchKey AND AddWho = SUSER_SNAME()
            GOTO Quit
         END
         
         -- Check empty batch
         IF @nTotalOrder = 0
         BEGIN
            SET @nErrNo = 113014
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Batch No Task!
            GOTO Quit
         END

         -- Prepare current screen var
         SET @cOutField03 = @cBatchKey
         SET @cOutField04 = '' -- ToteID
         SET @cOutField05 = CAST( @nTotalOrder AS NVARCHAR(5))

         -- Enable / Disable field
         SET @cFieldAttr03 = 'O' -- BatchKey
         SET @cFieldAttr04 = ''  -- ToteID
         
         -- Remain in current screen
         SET @nErrNo = -1
         GOTO Quit
      END

      -- ToteID field enabled
      IF @cFieldAttr04 = ''
      BEGIN
         -- Check blank tote
         IF @cToteID = ''
         BEGIN
            SET @nErrNo = 113015
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ToteID
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- ToteID
            SET @cOutField04 = ''
            GOTO Quit
         END
   
         -- Check tote assigned
         IF EXISTS( SELECT 1
            FROM rdt.rdtPTLCartLog WITH (NOLOCK)
            WHERE CartID = @cCartID
               AND ToteID = @cToteID)
         BEGIN
            SET @nErrNo = 113016
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote Assigned
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- ToteID
            SET @cOutField04 = ''
            GOTO Quit
         END
         SET @cOutField04 = @cToteID
      
         -- Get position info
         SELECT TOP 1 
            @cPosition = Position 
         FROM rdt.rdtPTLCartLog WITH (NOLOCK) 
         WHERE CartID = @cCartID
         
         SELECT @cIPAddress = IPAddress
         FROM DeviceProfile WITH (NOLOCK)
         WHERE DeviceType = 'CART'
            AND DeviceID = @cCartID
            AND DevicePosition = @cPosition
   
         SET @nTranCount = @@TRANCOUNT
         BEGIN TRAN
         SAVE TRAN rdt_PTLCart_Assign_BatchOneTote
         
         -- DECLARE @curLog CURSOR
         -- SET @curLog = CURSOR FOR
            SET @nRowRef = 0
            SELECT TOP 1 
               @nRowRef = RowRef, 
               @cOrderKey = OrderKey
            FROM rdt.rdtPTLCartLog WITH (NOLOCK) 
            WHERE CartID = @cCartID
            ORDER BY RowRef
         -- OPEN @curLog
         -- FETCH NEXT FROM @curLog INTO @nRowRef, @cOrderKey
         -- WHILE @@FETCH_STATUS = 0
         WHILE @nRowRef > 0
         BEGIN
            -- Save assign
            UPDATE rdt.rdtPTLCartLog SET
               ToteID = @cToteID
            WHERE RowRef = @nRowRef
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 113017
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Log fail
               GOTO RollBackTran
            END
      
            -- Insert PTLTran
            IF @cPickZone = ''
               SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  SELECT PD.LOC, PD.SKU, SUM( PD.QTY)
                  FROM Orders O WITH (NOLOCK) 
                     JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
                  WHERE O.OrderKey = @cOrderKey
                     AND PD.Status <> '4'
                     AND PD.Status < @cPickConfirmStatus
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
                     AND PD.Status <> '4'
                     AND PD.Status < @cPickConfirmStatus
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
                  DeviceProfileLogKey, DropID, OrderKey, Storerkey, SKU, LOC, ExpectedQTY, QTY, SourceKey)
               VALUES (
                  @cIPAddress, @cCartID, @cPosition, '0', 'CART', 
                  @cDPLKey, '', @cOrderKey, @cStorerKey, @cSKU, @cLOC, @nQTY, 0, @cBatchKey)
         
               IF @@ERROR <> ''
               BEGIN
                  SET @nErrNo = 113018
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode ,'DSP') --INS PTL Fail
                  GOTO RollBackTran
               END
               FETCH NEXT FROM @curPD INTO @cLOC, @cSKU, @nQTY
            END
            
            --FETCH NEXT FROM @curLog INTO @nRowRef, @cOrderKey
            
            SELECT TOP 1 
               @nRowRef = RowRef, 
               @cOrderKey = OrderKey
            FROM rdt.rdtPTLCartLog WITH (NOLOCK) 
            WHERE CartID = @cCartID
               AND RowRef > @nRowRef 
            ORDER BY RowRef
            
            IF @@ROWCOUNT = 0
               BREAK
         END

         COMMIT TRAN rdt_PTLCart_Assign_BatchOneTote
      END

      -- Get Total
      SELECT @nTotalOrder = COUNT(1) FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID

      -- Check finish assign
      IF @nTotalOrder > 0 AND @cBatchKey <> '' AND @cToteID <> ''
      BEGIN
         -- Enable field
         SET @cFieldAttr03 = '' -- BatchKey
         SET @cFieldAttr04 = '' -- ToteID
         
         GOTO Quit
      END
      
      -- Stay in current page
      -- SET @nErrNo = -1 
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_PTLCart_Assign_BatchOneTote

Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO