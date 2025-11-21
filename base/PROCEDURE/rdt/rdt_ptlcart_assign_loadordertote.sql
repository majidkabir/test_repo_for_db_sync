SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_PTLCart_Assign_LoadOrderTote                          */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 14-07-2015 1.0  Ung      SOS336312 Created                                 */
/* 26-01-2018 1.1  Ung      Change to PTL.Schema                              */
/******************************************************************************/

CREATE PROC [RDT].[rdt_PTLCart_Assign_LoadOrderTote] (
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

   DECLARE @cLoadKey    NVARCHAR(10)
   DECLARE @cMaxTask    NVARCHAR(2)
   DECLARE @cOrderKey   NVARCHAR(10)
   DECLARE @cPosition   NVARCHAR(10)
   DECLARE @cToteID     NVARCHAR(20)
   DECLARE @nTotalOrder INT
   DECLARE @nTotalTote  INT
   DECLARE @nTotalPOS   INT
   DECLARE @nMaxTask    INT
   DECLARE @curPD       CURSOR

   SET @nTranCount = @@TRANCOUNT
      
   /***********************************************************************************************
                                                POPULATE
   ***********************************************************************************************/
   IF @cType = 'POPULATE-IN'
   BEGIN
      -- Get work info
      SET @cLoadKey = ''
      SET @nMaxTask = 0
      SELECT TOP 1 
         @cLoadKey = LoadKey, 
         @nMaxTask = MaxTask
      FROM rdt.rdtPTLCartLog WITH (NOLOCK) 
         WHERE CartID = @cCartID
      
      -- Default order count
      IF @nMaxTask = 0
      BEGIN
         IF rdt.rdtGetConfig( @nFunc, 'DefaultMaxTask', @cStorerKey) = '1'
            SELECT @nMaxTask = COUNT( 1)
            FROM DeviceProfile WITH (NOLOCK)
            WHERE DeviceType = 'CART'
               AND DeviceID = @cCartID
      END
      
      SELECT @nTotalOrder = COUNT(1) FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID
      SELECT @nTotalTote = COUNT(1) FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID AND ToteID <> ''

		-- Prepare next screen var
		SET @cOutField01 = @cCartID
		SET @cOutField02 = @cPickZone
		SET @cOutField03 = @cLoadKey
		SET @cOutField04 = CAST( @nMaxTask AS NVARCHAR(2))
		SET @cOutField05 = '' -- OrderKey
		SET @cOutField06 = '' -- Position
		SET @cOutField07 = '' -- ToteID
		SET @cOutField08 = CAST( @nTotalOrder AS NVARCHAR(5))
		SET @cOutField09 = CAST( @nTotalTote AS NVARCHAR(5))

      IF @cLoadKey = ''
      BEGIN
         -- Enable disable field
         SET @cFieldAttr03 = ''  -- LoadKey
         SET @cFieldAttr04 = ''  -- MaxTask
         SET @cFieldAttr05 = 'O' -- OrderKey
         SET @cFieldAttr07 = 'O' -- ToteID

   	   EXEC rdt.rdtSetFocusField @nMobile, 3 -- LoadKey
      END
      ELSE
      BEGIN
         SET @cFieldAttr03 = 'O'  -- LoadKey
         SET @cFieldAttr04 = 'O'  -- MaxTask
         SET @cFieldAttr05 = 'O'  -- OrderKey
         SET @cFieldAttr07 = 'O'  -- ToteID

         IF @nTotalOrder > @nTotalTote
         BEGIN
            -- Get tote not yet assign
            SELECT TOP 1 
               @cOrderKey = OrderKey, 
               @cPosition = Position
            FROM rdt.rdtPTLCartLog WITH (NOLOCK)
            WHERE CartID = @cCartID
               AND ToteID = ''
            ORDER BY RowRef 

      		-- Prepare next screen var
      		SET @cOutField05 = @cOrderKey
      		SET @cOutField06 = @cPosition 

            -- Enable field
            IF rdt.rdtGetConfig( @nFunc, 'DefaultToteIDAsPos', @cStorerKey) = '1'
            BEGIN
               SET @cToteID = @cPosition
               SET @cOutField07 = @cToteID
            END
            ELSE
            BEGIN
               SET @cFieldAttr07 = ''   -- ToteID
            END
         END
      END
		
		-- Go to load order tote screen
		SET @nScn = 4186
   END
      
   IF @cType = 'POPULATE-OUT'
   BEGIN
      -- Enable field
      SET @cFieldAttr03 = '' -- LoadKey
      SET @cFieldAttr04 = '' -- MaxTask
      SET @cFieldAttr05 = '' -- OrderKey
      SET @cFieldAttr07 = '' -- ToteID

		-- Go to cart screen
   END

   
   /***********************************************************************************************
                                                 CHECK
   ***********************************************************************************************/
   IF @cType = 'CHECK'
   BEGIN
      DECLARE @cDefaultToteIDAsPos NVARCHAR(1)
      DECLARE @cIPAddress NVARCHAR(40)
      DECLARE @cLOC NVARCHAR(10)
      DECLARE @cSKU NVARCHAR(20)
      DECLARE @nQTY INT
      
      -- Screen mapping
      SET @cLoadKey = CASE WHEN @cFieldAttr03 = '' THEN @cInField03 ELSE @cOutField03 END
      SET @cMaxTask = CASE WHEN @cFieldAttr04 = '' THEN @cInField04 ELSE @cOutField04 END
      SET @cOrderKey = @cOutField05
      SET @cPosition = @cOutField06
      SET @cToteID   = CASE WHEN @cFieldAttr07 = '' THEN @cInField07 ELSE @cOutField07 END

      -- Get storer config
      SET @cDefaultToteIDAsPos = rdt.rdtGetConfig( @nFunc, 'DefaultToteIDAsPos', @cStorerKey)

      -- LoadKey field enabled (when auto assign order)
      IF @cFieldAttr03 = ''
      BEGIN
   		-- Check blank
   		IF @cLoadKey = '' 
         BEGIN
            SET @nErrNo = 55551
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need LoadKey
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- LoadKey
            GOTO Quit
         END

         -- Check LoadKey valid
         IF NOT EXISTS( SELECT 1 FROM LoadPlanDetail WITH (NOLOCK) WHERE LoadKey = @cLoadKey)
         BEGIN
            SET @nErrNo = 55552
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad LoadKey
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- LoadKey
            SET @cOutField03 = ''
            GOTO Quit
         END
         SET @cOutField03 = @cLoadKey

   		-- Check blank
   		IF @cMaxTask = '' 
         BEGIN
            SET @nErrNo = 55553
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need tasks
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- MaxTask
            GOTO Quit
         END

         -- Check order count
         IF rdt.rdtIsValidQTY( @cMaxTask, 1) = 0
         BEGIN
            SET @nErrNo = 55554
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid tasks
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- MaxTask
            SET @cOutField04 = ''
            GOTO Quit
         END
         SET @nMaxTask = CAST( @cMaxTask AS INT)

         DECLARE @nMaxPos INT
         SELECT @nMaxPos = COUNT(1) FROM DeviceProfile WITH (NOLOCK) WHERE DeviceType = 'CART' AND DeviceID = @cCartID

         -- Check order count more then pos
         IF @nMaxTask > @nMaxPos
         BEGIN
            SET @nErrNo = 55555
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TskMoreThanPos
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- MaxTask
            SET @cOutField04 = ''
            GOTO Quit
         END
         SET @cOutField04 = @cMaxTask

         -- Assign order
         IF NOT EXISTS( SELECT 1 FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID)
         BEGIN
            SET @nTotalOrder = 0
            SET @nTotalTote = 0
            
            DECLARE @curOrders CURSOR
            IF @cPickZone = ''
               SET @curOrders = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  SELECT O.OrderKey 
                  FROM LoadPlanDetail LPD WITH (NOLOCK) 
                     JOIN Orders O WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey)
                  WHERE LPD.LoadKey = @cLoadKey
                     AND O.StorerKey = @cStorerKey
                     AND O.Facility = @cFacility
                     AND O.Status <> 'CANC' 
                     AND O.SOStatus <> 'CANC' 
                     AND O.Status > '0' AND O.Status < '5'
                     AND NOT EXISTS( SELECT 1 FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE OrderKey = O.OrderKey)
                     AND EXISTS(
                        SELECT 1 FROM PickDetail PD WITH (NOLOCK) 
                        WHERE PD.OrderKey = O.OrderKey
                           AND PD.Status < '4'
                           AND PD.QTY > 0)
                  ORDER BY O.OrderKey
            ELSE
               SET @curOrders = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  SELECT O.OrderKey 
                  FROM LoadPlanDetail LPD WITH (NOLOCK) 
                     JOIN Orders O WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey)
                  WHERE LPD.LoadKey = @cLoadKey
                     AND O.StorerKey = @cStorerKey
                     AND O.Facility = @cFacility
                     AND O.Status <> 'CANC' 
                     AND O.SOStatus <> 'CANC' 
                     AND O.Status > '0' AND O.Status < '5'
                     AND NOT EXISTS( SELECT 1 FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE OrderKey = O.OrderKey AND (PickZone = @cPickZone OR PickZone = ''))
                     AND EXISTS(
                        SELECT 1 
                        FROM PickDetail PD WITH (NOLOCK) 
                           JOIN dbo.LOC LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
                        WHERE PD.OrderKey = O.OrderKey
                           AND PD.Status < '4'
                           AND PD.QTY > 0
                           AND LOC.PickZone = @cPickZone)
                  ORDER BY O.OrderKey

            SET @nTranCount = @@TRANCOUNT
            BEGIN TRAN
            SAVE TRAN rdt_PTLCart_Assign_LoadOrderTote      
            
            OPEN @curOrders
            FETCH NEXT FROM @curOrders INTO @cOrderKey
            WHILE @@FETCH_STATUS = 0
            BEGIN
               SET @cPosition = ''
               SET @cToteID = ''

               -- Get position not yet assign
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
                  BREAK

               -- Tote ID as position
               IF @cDefaultToteIDAsPos = '1'
                  SET @cToteID = @cPosition
                  
               -- Save assign
               INSERT INTO rdt.rdtPTLCartLog (CartID, Position, ToteID, DeviceProfileLogKey, Method, PickZone, PickSeq, LoadKey, MaxTask, OrderKey, StorerKey)
               VALUES (@cCartID, @cPosition, @cToteID, @cDPLKey, @cMethod, @cPickZone, @cPickSeq, @cLoadKey, @nMaxTask, @cOrderKey, @cStorerKey)
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 55556
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log Fail
                  GOTO RollBackTran
               END

               -- Insert PTLTran
               IF @cDefaultToteIDAsPos = '1'
               BEGIN
                  -- Get position info
                  SELECT @cIPAddress = IPAddress
                  FROM DeviceProfile WITH (NOLOCK)
                  WHERE DeviceType = 'CART'
                     AND DeviceID = @cCartID
                     AND DevicePosition = @cPosition
                  
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
                        SET @nErrNo = 55557
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode ,'DSP') --INS PTL Fail
                        GOTO RollBackTran
                     END
                     
                     FETCH NEXT FROM @curPD INTO @cLOC, @cSKU, @nQTY
                  END

                  SET @nTotalTote = @nTotalTote + 1
               END
   
               SET @nTotalOrder = @nTotalOrder + 1
               IF @nTotalOrder = @nMaxTask
                  BREAK
               
               FETCH NEXT FROM @curOrders INTO @cOrderKey
            END
            
            COMMIT TRAN rdt_PTLCart_Assign_LoadOrderTote

            -- Check empty load
            IF @nTotalOrder = 0
            BEGIN
               SET @nErrNo = 55558
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --load No Task!
               GOTO Quit
            END
            
            -- Check finish assign
            IF @nTotalOrder > 0 AND @nTotalTote = @nTotalOrder
            BEGIN
               IF @nTotalOrder = @nMaxTask
               BEGIN
                  -- Enable field
                  SET @cFieldAttr03 = '' -- LoadKey
                  SET @cFieldAttr04 = '' -- MaxTask
                  SET @cFieldAttr05 = '' -- OrderKey
                  SET @cFieldAttr07 = '' -- ToteID
               END
               ELSE
               BEGIN
                  SET @cOutField08 = CAST( @nTotalOrder AS NVARCHAR(5))
                  SET @cOutField09 = CAST( @nTotalTote AS NVARCHAR(5))
                  
                  -- Enable field
                  SET @cFieldAttr03 = 'O' -- LoadKey
                  SET @cFieldAttr04 = 'O' -- MaxTask
                  SET @cFieldAttr05 = 'O' -- OrderKey
                  SET @cFieldAttr07 = 'O' -- ToteID
                  
                  -- Stay in current page
                  SET @nErrNo = -1 
               END
               GOTO Quit
            END
         END

         -- Get tote not yet assign
         SELECT TOP 1 
            @cOrderKey = OrderKey, 
            @cPosition = Position, 
            @cToteID = CASE WHEN @cDefaultToteIDAsPos = '1' THEN Position ELSE '' END
         FROM rdt.rdtPTLCartLog WITH (NOLOCK)
         WHERE CartID = @cCartID
            AND ToteID = ''
         ORDER BY RowRef 

         -- Prepare current screen var
         SET @cOutField05 = @cOrderKey
         SET @cOutField06 = @cPosition
         SET @cOutField07 = @cToteID
         SET @cOutField08 = CAST( @nTotalOrder AS NVARCHAR(5))
         SET @cOutField09 = CAST( @nTotalTote AS NVARCHAR(5))

         -- Enable disable field
         SET @cFieldAttr03 = 'O' -- LoadKey
         SET @cFieldAttr04 = 'O' -- MaxTask
         SET @cFieldAttr05 = 'O' -- OrderKey
         SET @cFieldAttr07 = CASE WHEN @cDefaultToteIDAsPos = '1' THEN 'O' ELSE '' END -- ToteID

         -- Stay in current page
         SET @nErrNo = -1 
         GOTO Quit
      END

      -- OrderKey field enabled (when not enought order)
      IF @cFieldAttr05 = ''
      BEGIN
         -- Check finish assign
         IF @nTotalOrder > 0 AND @cOrderKey = '' AND (@cFieldAttr07 = '' AND @cToteID = '')
         BEGIN
            GOTO Quit
         END
         
         -- Check blank
   		IF @cOrderKey = '' 
         BEGIN
            SET @nErrNo = 55559
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need OrderKey
            EXEC rdt.rdtSetFocusField @nMobile, 5 -- OrderKey
            SET @cOutField05 = ''
            GOTO Quit
         END

         DECLARE @cChkFacility  NVARCHAR(5)
         DECLARE @cChkStorerKey NVARCHAR(15)
         DECLARE @cChkStatus    NVARCHAR(10)
         DECLARE @cChkSOStatus  NVARCHAR(10)
         
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
            SET @nErrNo = 55560
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad OrderKey
            EXEC rdt.rdtSetFocusField @nMobile, 5 -- OrderKey
            SET @cOutField05 = ''
            GOTO Quit
         END
   
         -- Check storer
         IF @cStorerKey <> @cChkStorerKey
         BEGIN
            SET @nErrNo = 55561
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storer
            EXEC rdt.rdtSetFocusField @nMobile, 5 -- OrderKey
            SET @cOutField05 = ''
            GOTO Quit
         END
   
         -- Check facility
         IF @cFacility <> @cChkFacility
         BEGIN
            SET @nErrNo = 55562
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
            EXEC rdt.rdtSetFocusField @nMobile, 5 -- OrderKey
            SET @cOutField05 = ''
            GOTO Quit
         END
               
         -- Check order CANC
         IF @cChkStatus = 'CANC' OR @cChkSOStatus = 'CANC' 
         BEGIN
            SET @nErrNo = 55563
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order CANCEL
            EXEC rdt.rdtSetFocusField @nMobile, 5 -- OrderKey
            SET @cOutField05 = ''
            GOTO Quit
         END
         
         -- Check order status
         IF @cChkStatus = '0'
         BEGIN
            SET @nErrNo = 55564
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order NotAlloc
            EXEC rdt.rdtSetFocusField @nMobile, 5 -- OrderKey
            SET @cOutField05 = ''
            GOTO Quit
         END
         
         -- Check order status
         IF @cChkStatus >= '5'
         BEGIN
            SET @nErrNo = 55565
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order picked
            EXEC rdt.rdtSetFocusField @nMobile, 5 -- OrderKey
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
            SET @nErrNo = 55566
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrderAssigned
            EXEC rdt.rdtSetFocusField @nMobile, 5 -- OrderKey
            SET @cOutField03 = ''
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
            SET @nErrNo = 55567
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order no task
            EXEC rdt.rdtSetFocusField @nMobile, 5 -- OrderKey
            SET @cOutField05 = ''
            GOTO Quit
         END
         
         -- Check order belong to load
         IF NOT EXISTS( SELECT 1 FROM LoadPlanDetail WITH (NOLOCK) WHERE LoadKey = @cLoadKey AND OrderKey = @cOrderKey)
         BEGIN
            SET @nErrNo = 55568
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrderNotInLoad
            EXEC rdt.rdtSetFocusField @nMobile, 5 -- OrderKey
            SET @cOutField05 = ''
            GOTO Quit
         END      
         SET @cOutField05 = @cOrderKey
      END
      
      -- ToteID field enabled (when not DefaultToteIDAsPos)
      IF @cFieldAttr07 = ''
      BEGIN
         -- Check blank tote
         IF @cToteID = ''
         BEGIN
            SET @nErrNo = 55569
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ToteID
            EXEC rdt.rdtSetFocusField @nMobile, 7 -- ToteID
            SET @cOutField07 = ''
            GOTO Quit
         END
   
         -- Check tote assigned
         IF EXISTS( SELECT 1
            FROM rdt.rdtPTLCartLog WITH (NOLOCK)
            WHERE CartID = @cCartID
               AND ToteID = @cToteID)
         BEGIN
            SET @nErrNo = 55570
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote Assigned
            EXEC rdt.rdtSetFocusField @nMobile, 7 -- ToteID
            SET @cOutField07 = ''
            GOTO Quit
         END
         SET @cOutField07 = @cToteID

         -- Get position info
         SELECT @cIPAddress = IPAddress
         FROM DeviceProfile WITH (NOLOCK)
         WHERE DeviceType = 'CART'
            AND DeviceID = @cCartID
            AND DevicePosition = @cPosition
   
         SET @nTranCount = @@TRANCOUNT
         BEGIN TRAN
         SAVE TRAN rdt_PTLCart_Assign_LoadOrderTote
         
         -- Save assign
         UPDATE rdt.rdtPTLCartLog SET
            ToteID = @cToteID
         WHERE CartID = @cCartID
            AND OrderKey = @cOrderKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 55572
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
               SET @nErrNo = 55573
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode ,'DSP') --INS PTL Fail
               GOTO RollBackTran
            END
            FETCH NEXT FROM @curPD INTO @cLOC, @cSKU, @nQTY
         END
   
         COMMIT TRAN rdt_PTLCart_Assign_LoadOrderTote
      END

      -- Get Total
      SELECT @nTotalOrder = COUNT(1) FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID
      SELECT @nTotalTote = COUNT(1) FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID AND ToteID <> ''

      -- Check finish assign
      IF @nTotalOrder > 0 AND @nTotalOrder = @nTotalTote
      BEGIN
         -- Enable field
         SET @cFieldAttr03 = '' -- LoadKey
         SET @cFieldAttr04 = '' -- MaxTask
         SET @cFieldAttr05 = '' -- OrderKey
         SET @cFieldAttr07 = '' -- ToteID
         
         GOTO Quit
      END

      -- Get tote not yet assign
      SELECT TOP 1 
         @cOrderKey = OrderKey, 
         @cPosition = Position
      FROM rdt.rdtPTLCartLog WITH (NOLOCK)
      WHERE CartID = @cCartID
         AND ToteID = ''
      ORDER BY RowRef 

      -- Prepare current screen var
      SET @cOutField05 = @cOrderKey
      SET @cOutField06 = @cPosition
      SET @cOutField07 = '' -- ToteID
      SET @cOutField08 = CAST( @nTotalOrder AS NVARCHAR(5))
      SET @cOutField09 = CAST( @nTotalTote AS NVARCHAR(5))
      
      -- Stay in current page
      SET @nErrNo = -1 
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_PTLCart_Assign_LoadOrderTote

Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO