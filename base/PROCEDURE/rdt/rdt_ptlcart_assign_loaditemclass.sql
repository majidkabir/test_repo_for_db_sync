SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_PTLCart_Assign_LoadItemClass                          */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 01-07-2018 1.0  Ung      WMS-5487 Created                                  */
/******************************************************************************/

CREATE PROC [RDT].[rdt_PTLCart_Assign_LoadItemClass] (
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

   DECLARE @nTranCount     INT
   DECLARE @nTotalLoad     INT
   DECLARE @nTotalTote     INT

   DECLARE @cLoadKey       NVARCHAR(10)
   DECLARE @cItemClass     NVARCHAR(10)
   DECLARE @cPosition      NVARCHAR(10)
   DECLARE @cToteID        NVARCHAR(20)

   DECLARE @cChkFacility   NVARCHAR(5)
   DECLARE @cChkStorerKey  NVARCHAR(15)
   DECLARE @cChkStatus     NVARCHAR(10)
   DECLARE @cChkSOStatus   NVARCHAR(10)

   SET @nTranCount = @@TRANCOUNT

   /***********************************************************************************************
                                                POPULATE
   ***********************************************************************************************/
   IF @cType = 'POPULATE-IN'
   BEGIN
      -- Get total
      SELECT @nTotalLoad = COUNT(1) FROM rdt.rdtPTLCartLog_Doc WITH (NOLOCK) WHERE CartID = @cCartID AND DocKey <> ''
      SELECT @nTotalTote = COUNT(1) FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID AND ToteID <> ''

		-- Prepare next screen var
		SET @cOutField01 = @cCartID
		SET @cOutField02 = @cPickZone
		SET @cOutField03 = '' -- LoadKey
		SET @cOutField04 = '' -- ItemClass
		SET @cOutField05 = '' -- Position
		SET @cOutField06 = '' -- ToteID
		SET @cOutField07 = CAST( @nTotalLoad AS NVARCHAR(5))
      SET @cOutField08 = CAST( @nTotalTote AS NVARCHAR(5))

      -- Not yet assign load
      IF @nTotalLoad = 0
      BEGIN
         SET @cFieldAttr03 = ''  -- LoadKey
         SET @cFieldAttr04 = 'O' -- ItemClass
         SET @cFieldAttr06 = 'O' -- ToteID
      END                  

      -- Assigned load
      ELSE 
      BEGIN
         SET @cFieldAttr03 = 'O' -- LoadKey
         SET @cFieldAttr04 = ''  -- ItemClass
         SET @cFieldAttr06 = ''  -- ToteID
      END

		-- Go to orders totes screen
		SET @nScn = 5041
   END
      
   IF @cType = 'POPULATE-OUT'
   BEGIN
		-- Enable diable field
		SET @cFieldAttr03 = '' -- LoadKey
		SET @cFieldAttr04 = '' -- ItemClass
		SET @cFieldAttr06 = '' -- ToteID

		-- Go to cart screen
   END


   /***********************************************************************************************
                                                 CHECK
   ***********************************************************************************************/
   IF @cType = 'CHECK'
   BEGIN
      -- Screen mapping
      SET @cLoadKey  = CASE WHEN @cFieldAttr03 = '' THEN @cInField03 ELSE @cOutField03 END
      SET @cItemClass = CASE WHEN @cFieldAttr04 = '' THEN @cInField04 ELSE @cOutField04 END
      SET @cPosition  = @cOutField05
      SET @cToteID    = CASE WHEN @cFieldAttr06 = '' THEN @cInField06 ELSE @cOutField06 END

      -- Get total
      SELECT @nTotalLoad = COUNT(1) FROM rdt.rdtPTLCartLog_Doc WITH (NOLOCK) WHERE CartID = @cCartID AND DocKey <> ''
      SELECT @nTotalTote = COUNT( DISTINCT ToteID) FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID AND ToteID <> ''

      -- LoadKey field enable
      IF @cFieldAttr03 = '' 
      BEGIN
   		-- Check finish assign load
   		IF @nTotalLoad > 0 AND @cLoadKey = ''
   		BEGIN
            SELECT @nTotalLoad = COUNT(1) FROM rdt.rdtPTLCartLog_Doc WITH (NOLOCK) WHERE CartID = @cCartID AND DocKey <> ''

            -- Prepare current screen var
            SET @cOutField03 = ''  -- LoadKey
            SET @cOutField04 = ''  -- ItemClass
            SET @cOutField05 = ''  --  Position
            SET @cOutField06 = ''  -- ToteID
            SET @cOutField07 = CAST( @nTotalLoad AS NVARCHAR(5))
            SET @cOutField08 = CAST( @nTotalTote AS NVARCHAR(5))

            -- Enable / Disable field
            SET @cFieldAttr03 = 'O' -- LoadKey
            SET @cFieldAttr04 = ''  -- ItemClass
            SET @cFieldAttr05 = ''  -- Position
            SET @cFieldAttr06 = ''  -- ToteID

            -- Remain in current screen
            SET @nErrNo = -1
            GOTO Quit
   		END
   		
   		-- Check blank
   		IF @cLoadKey = ''
         BEGIN
            SET @nErrNo = 125752
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need LoadKey
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- LoadKey
            GOTO Quit
         END

         -- Check LoadKey valid
         IF NOT EXISTS( SELECT 1 FROM LoadPlan WITH (NOLOCK) WHERE LoadKey = @cLoadKey AND Facility = @cFacility)
         BEGIN
            SET @nErrNo = 125753
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad LoadKey
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- LoadKey
            SET @cOutField03 = ''
            GOTO Quit
         END

         -- Check double scan
         IF EXISTS( SELECT 1 FROM rdt.rdtPTLCartLog_Doc WITH (NOLOCK) WHERE CartID = @cCartID AND DocKey = @cLoadKey)
         BEGIN
            SET @nErrNo = 125754
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LoadKeyScanned
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- LoadKey
            SET @cOutField03 = ''
            GOTO Quit
         END

         -- Save temp LoadKey
         INSERT INTO rdt.rdtPTLCartLog_Doc (CartID, DocKey) VALUES (@cCartID, @cLoadKey)
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 125755
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS DocLog Fail
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- LoadKey
            SET @cOutField03 = ''
            GOTO Quit
         END
         
         SET @nTotalLoad = @nTotalLoad + 1

         -- Prepare current screen var
         SET @cOutField03 = ''  -- LoadKey
         SET @cOutField04 = ''  -- ItemClass
         SET @cOutField05 = ''  -- Position
         SET @cOutField06 = ''  -- ToteID
         SET @cOutField07 = CAST( @nTotalLoad AS NVARCHAR(5))
         SET @cOutField08 = CAST( @nTotalTote AS NVARCHAR(5))

         -- Remain in current screen
         SET @nErrNo = -1
         GOTO Quit
      END

      -- ItemClass field enable
      IF @cFieldAttr04 = '' 
      BEGIN
         -- Check finish assign tote
         IF @nTotalTote > 0 AND @cItemClass = '' AND @cToteID = ''
         BEGIN
            -- Enable field
            SET @cFieldAttr03 = '' -- LoadKey
            SET @cFieldAttr04 = '' -- ItemClass
            SET @cFieldAttr06 = '' -- ToteID
            GOTO Quit
         END

   		-- Check blank
   		IF @cItemClass = ''
         BEGIN
            SET @nErrNo = 125756
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ItemClass
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- ItemClass
            GOTO Quit
         END

         -- Check assigned in own cart
         IF EXISTS( SELECT 1
            FROM rdt.rdtPTLCartLog WITH (NOLOCK)
            WHERE CartID = @cCartID
               AND Method = @cMethod
               AND ItemClass = @cItemClass)
         BEGIN
            SET @nErrNo = 125757
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ady assigned
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- ItemClass
            GOTO Quit
         END

         -- Check ItemClass in Load
         DECLARE @cItemClassInPickZone  NVARCHAR(1)
         SET @cItemClassInPickZone = 'N'
         IF @cPickZone = ''
            SELECT TOP 1 
               @cItemClassInPickZone = 'Y'
            FROM rdt.rdtPTLCartLog_Doc LP WITH (NOLOCK)
               JOIN LoadPlanDetail LPD WITH (NOLOCK) ON (LPD.LoadKey = LP.DocKey AND LP.CartID = @cCartID)
               JOIN Orders O WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
               JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
               JOIN SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
            WHERE SKU.StorerKey = @cStorerKey
               AND SKU.ItemClass = @cItemClass
               AND PD.Status < '4'
               AND PD.QTY > 0
               AND O.Status <> 'CANC'
               AND O.SOStatus <> 'CANC'
         ELSE
            SELECT TOP 1 
               @cItemClassInPickZone = 'Y'
            FROM rdt.rdtPTLCartLog_Doc LP WITH (NOLOCK)
               JOIN LoadPlanDetail LPD WITH (NOLOCK) ON (LPD.LoadKey = LP.DocKey AND LP.CartID = @cCartID)
               JOIN Orders O WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
               JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
               JOIN SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
               JOIN LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            WHERE SKU.StorerKey = @cStorerKey
               AND SKU.ItemClass = @cItemClass
               AND PD.Status < '4'
               AND PD.QTY > 0
               AND O.Status <> 'CANC'
               AND O.SOStatus <> 'CANC'
               AND LOC.PickZone = @cPickZone

         IF @cItemClassInPickZone = 'N'
         BEGIN
            SET @nErrNo = 125758
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not in load
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- ItemClass
            GOTO Quit
         END
/*
         -- Check assigned to other cart
         IF EXISTS( SELECT 1
            FROM rdt.rdtPTLCartLog L WITH (NOLOCK)
               JOIN rdt.rdtPTLCartLog_Doc D WITH (NOLOCK) ON (L.CartID = D.CartID)
            WHERE CartID <> @cCartID
               AND Method = @cMethod
               AND ItemClass = @cItemClass
               AND 
               (  @cPickZone = '' OR      -- Own cart lock all zones
                  PickZone = ''  OR       -- Other cart lock all zones
                  PickZone = @cPickZone   -- Both lock same zone
               ))
         BEGIN
            SET @nErrNo = 125759
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LockedByOthers
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- ItemClass
            GOTO Quit
         END
*/         
         IF @cPosition = ''
         BEGIN
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
            BEGIN
               SET @nErrNo = 125751
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Position
               EXEC rdt.rdtSetFocusField @nMobile, 4 -- ItemClass
               SET @cOutField03 = ''
               GOTO Quit
            END
            SET @cOutField05 = @cPosition
         END

         SET @cOutField04 = @cItemClass
         
         EXEC rdt.rdtSetFocusField @nMobile, 6 -- ToteID
      END

      -- ToteID field enable
      IF @cFieldAttr06 = ''
      BEGIN
         -- Check blank tote
         IF @cToteID = ''
         BEGIN
            SET @nErrNo = 125760
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ToteID
            EXEC rdt.rdtSetFocusField @nMobile, 6 -- ToteID
            SET @cOutField06 = ''
            GOTO Quit
         END

         -- Check format
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'ToteID', @cToteID) = 0
         BEGIN
            SET @nErrNo = 125761
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
            EXEC rdt.rdtSetFocusField @nMobile, 6 -- ToteID
            SET @cOutField06 = ''
            GOTO Quit
         END
   
         -- Check tote assigned
         IF EXISTS( SELECT 1
            FROM rdt.rdtPTLCartLog WITH (NOLOCK)
            WHERE CartID = @cCartID
               AND ToteID = @cToteID)
         BEGIN
            SET @nErrNo = 125762
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote Assigned
            EXEC rdt.rdtSetFocusField @nMobile, 6 -- ToteID
            SET @cOutField06 = ''
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
         SAVE TRAN rdt_PTLCart_Assign
         
         -- Save assign
         INSERT INTO rdt.rdtPTLCartLog (CartID, Position, ToteID, DeviceProfileLogKey, Method, PickZone, PickSeq, StorerKey, LoadKey, ItemClass)
         SELECT @cCartID, @cPosition, @cToteID, @cDPLKey, @cMethod, @cPickZone, @cPickSeq, @cStorerKey, LP.DocKey, @cItemClass
         FROM rdt.rdtPTLCartLog_Doc LP WITH (NOLOCK)
            JOIN LoadPlanDetail LPD WITH (NOLOCK) ON (LPD.LoadKey = LP.DocKey AND LP.CartID = @cCartID)
            JOIN Orders O WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
            JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
            JOIN SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
         WHERE SKU.StorerKey = @cStorerKey
            AND SKU.ItemClass = @cItemClass
            AND PD.Status < '4'
            AND PD.QTY > 0
            AND O.Status <> 'CANC'
            AND O.SOStatus <> 'CANC'
         GROUP BY LP.DocKey -- LoadKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 125763
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log Fail
            GOTO Quit
         END
   
         -- Insert PTLTran
         DECLARE @curPD CURSOR
         IF @cPickZone = ''
            SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT PD.LOC, SKU.SKU, SUM( PD.QTY)
               FROM rdt.rdtPTLCartLog_Doc LP WITH (NOLOCK)
                  JOIN LoadPlanDetail LPD WITH (NOLOCK) ON (LPD.LoadKey = LP.DocKey AND LP.CartID = @cCartID)
                  JOIN Orders O WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
                  JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
                  JOIN SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
               WHERE SKU.StorerKey = @cStorerKey
                  AND SKU.ItemClass = @cItemClass
                  AND PD.Status < '4'
                  AND PD.QTY > 0
                  AND O.Status <> 'CANC'
                  AND O.SOStatus <> 'CANC'
               GROUP BY PD.LOC, SKU.SKU
         ELSE
            SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT LOC.LOC, SKU.SKU, SUM( PD.QTY)
               FROM rdt.rdtPTLCartLog_Doc LP WITH (NOLOCK)
                  JOIN LoadPlanDetail LPD WITH (NOLOCK) ON (LPD.LoadKey = LP.DocKey AND LP.CartID = @cCartID)
                  JOIN Orders O WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
                  JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
                  JOIN SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
                  JOIN LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
               WHERE SKU.StorerKey = @cStorerKey
                  AND SKU.ItemClass = @cItemClass
                  AND PD.Status < '4'
                  AND PD.QTY > 0
                  AND O.Status <> 'CANC'
                  AND O.SOStatus <> 'CANC'
                  AND LOC.PickZone = @cPickZone
               GROUP BY LOC.LOC, SKU.SKU
   
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cLOC, @cSKU, @nQTY
         WHILE @@FETCH_STATUS = 0
         BEGIN
            INSERT INTO dbo.PTLTran (
               IPAddress, DeviceID, DevicePosition, Status, PTL_Type, 
               DeviceProfileLogKey, DropID, OrderKey, Storerkey, LOC, SKU, ExpectedQTY, QTY)
            VALUES (
               @cIPAddress, @cCartID, @cPosition, '0', 'CART', 
               @cDPLKey, '', '', @cStorerKey, @cLOC, @cSKU, @nQTY, 0)
   
            IF @@ERROR <> ''
            BEGIN
               SET @nErrNo = 125764
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode ,'DSP') --INS PTL Fail
               GOTO RollBackTran
            END
            FETCH NEXT FROM @curPD INTO @cLOC, @cSKU, @nQTY
         END

         COMMIT TRAN rdt_PTLCart_Assign
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
         SET @cOutField03 = '' -- @cLoadKey
         SET @cOutField04 = '' -- @cItemClass
         SET @cOutField05 = @cPosition
         SET @cOutField06 = '' -- ToteID
         SET @cOutField07 = CAST( @nTotalLoad AS NVARCHAR(5))
         SET @cOutField08 = CAST( @nTotalTote AS NVARCHAR(5))

         EXEC rdt.rdtSetFocusField @nMobile, 4 -- ItemClass

         -- Stay in current page
         SET @nErrNo = -1         
      END
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_PTLCart_Assign
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO