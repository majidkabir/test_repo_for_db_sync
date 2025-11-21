SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_PTLCart_Assign_Case                                   */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 27-07-2022 1.0  Ung      WMS-19592 Created                                 */
/******************************************************************************/

CREATE PROC [RDT].[rdt_PTLCart_Assign_Case] (
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

   DECLARE @cCaseID     NVARCHAR(20) = ''
   DECLARE @cIPAddress  NVARCHAR(40)
   DECLARE @cPosition   NVARCHAR(10) = ''
   DECLARE @cLOC        NVARCHAR(10)
   DECLARE @cSKU        NVARCHAR(20)
   DECLARE @cStyle      NVARCHAR(10)
   DECLARE @nQTY        INT

   SET @nTranCount = @@TRANCOUNT

   /***********************************************************************************************
                                                POPULATE
   ***********************************************************************************************/
   IF @cType = 'POPULATE-IN'
   BEGIN
      -- Get case ID
      SELECT @cCaseID = CaseID FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID

		-- Prepare next screen var
		SET @cOutField01 = @cCartID
		SET @cOutField02 = @cPickZone
		SET @cOutField03 = '' -- CaseID

      -- Start assign
      IF @cCaseID = ''
      BEGIN
         SET @cFieldAttr03 = '' -- CaseID
      END
      -- Finish assign Tote
      ELSE
      BEGIN
         SET @cFieldAttr03 = 'O'  -- CaseID
         SET @cOutField03 = @cCaseID
      END

		-- Go to case ID screen
		SET @nScn = 5044
   END

   IF @cType = 'POPULATE-OUT'
   BEGIN
		-- Enable diable field
		SET @cFieldAttr03 = '' -- CaseID

		-- Go to cart screen
   END


   /***********************************************************************************************
                                                 CHECK
   ***********************************************************************************************/
   IF @cType = 'CHECK'
   BEGIN
      -- Screen mapping
      SET @cCaseID = @cInField03

      -- Get case ID
      SELECT @cCaseID = CaseID FROM rdt.rdtPTLCartLog WITH (NOLOCK) WHERE CartID = @cCartID

      -- Case ID
      IF @cFieldAttr03 = ''
      BEGIN
         -- Check blank
   		IF @cCaseID = ''
         BEGIN
            SET @nErrNo = 188751
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need CaseID
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- CaseID
            GOTO Quit
         END

         -- Check case ID valid
         IF NOT EXISTS( SELECT TOP 1 1
            FROM PickDetail PD WITH (NOLOCK)
               JOIN LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
            WHERE LOC.Facility = @cFacility
               AND PD.StorerKey = @cStorerKey
               AND PD.CaseID = @cCaseID
               AND PD.Status < '4'
               AND PD.QTY > 0)
         BEGIN
            SET @nErrNo = 188752
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad CaseID
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- CaseID
            SET @cOutField03 = ''
            GOTO Quit
         END

         -- Check case ID assigned
         SET @nErrNo = 0
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
               AND PickZone = @cPickZone
         IF @nErrNo <> 0
         BEGIN
            SET @nErrNo = 188753
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CaseIDAssigned
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- CaseID
            SET @cOutField03 = ''
            GOTO Quit
         END

         -- Check case ID in zone
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
               SET @nErrNo = 188754
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CaseNotInZone
               EXEC rdt.rdtSetFocusField @nMobile, 3 -- CaseID
               SET @cOutField03 = ''
               GOTO Quit
            END
         END
         
         -- Get position not yet assign
         IF @cPosition = ''
            SELECT TOP 1
               @cIPAddress = DP.IPAddress, 
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
            SET @nErrNo = 188755
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoMorePosition
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- CaseID
            SET @cOutField03 = ''
            GOTO Quit
         END

         -- Get case ID info
         DECLARE @nStyle INT
         IF @cPickZone = ''
            SELECT @nStyle = COUNT( DISTINCT SKU.ItemClass)
            FROM PickDetail PD WITH (NOLOCK)
               JOIN LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
               JOIN SKU WITH (NOLOCK) ON (SKU.StorerKey = PD.StorerKey AND SKU.SKU = PD.SKU)
            WHERE LOC.Facility = @cFacility
               AND PD.StorerKey = @cStorerKey
               AND PD.CaseID = @cCaseID
               AND PD.Status < '4'
               AND PD.QTY > 0
         ELSE
            SELECT @nStyle = COUNT( DISTINCT SKU.ItemClass)
            FROM PickDetail PD WITH (NOLOCK)
               JOIN LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
               JOIN SKU WITH (NOLOCK) ON (SKU.StorerKey = PD.StorerKey AND SKU.SKU = PD.SKU)
            WHERE LOC.Facility = @cFacility
               AND PD.StorerKey = @cStorerKey
               AND PD.CaseID = @cCaseID
               AND PD.Status < '4'
               AND PD.QTY > 0
               AND LOC.PickZone = @cPickZone

         BEGIN TRAN
         SAVE TRAN rdt_PTLCart_Assign_Case

         /***********************************************************************************************
                                             Insert rdt.rdtPTLCartLog
         ***********************************************************************************************/
         DECLARE @curLog CURSOR
         IF @cPickZone = ''
            SET @curLog = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT SKU.ItemClass, SKU.SKU
               FROM PickDetail PD WITH (NOLOCK)
                  JOIN LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
                  JOIN SKU WITH (NOLOCK) ON (SKU.StorerKey = PD.StorerKey AND SKU.SKU = PD.SKU)
                  JOIN ( -- Just for the style sequence
                     SELECT SKU.ItemClass, ROW_NUMBER() OVER (ORDER BY SUM( PD.QTY) desc) StyleSeq
                     FROM PickDetail PD WITH (NOLOCK)
                        JOIN LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
                        JOIN SKU WITH (NOLOCK) ON (SKU.StorerKey = PD.StorerKey AND SKU.SKU = PD.SKU)
                     WHERE LOC.Facility = @cFacility
                        AND PD.StorerKey = @cStorerKey
                        AND PD.CaseID = @cCaseID
                        AND PD.Status < '4'
                        AND PD.QTY > 0
                     GROUP BY SKU.ItemClass
                  ) Style ON (Style.ItemClass = SKU.ItemClass)
               WHERE LOC.Facility = @cFacility
                  AND PD.StorerKey = @cStorerKey
                  AND PD.CaseID = @cCaseID
                  AND PD.Status < '4'
                  AND PD.QTY > 0
               GROUP BY Style.StyleSeq, SKU.ItemClass, SKU.SKU
               ORDER BY Style.StyleSeq, SUM( PD.QTY) DESC
         ELSE
            SET @curLog = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT SKU.ItemClass, SKU.SKU
               FROM PickDetail PD WITH (NOLOCK)
                  JOIN LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
                  JOIN SKU WITH (NOLOCK) ON (SKU.StorerKey = PD.StorerKey AND SKU.SKU = PD.SKU)
                  JOIN ( -- Just for the style sequence
                     SELECT SKU.ItemClass, ROW_NUMBER() OVER (ORDER BY SUM( PD.QTY) desc) StyleSeq
                     FROM PickDetail PD WITH (NOLOCK)
                        JOIN LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
                        JOIN SKU WITH (NOLOCK) ON (SKU.StorerKey = PD.StorerKey AND SKU.SKU = PD.SKU)
                     WHERE LOC.Facility = @cFacility
                        AND PD.StorerKey = @cStorerKey
                        AND PD.CaseID = @cCaseID
                        AND PD.Status < '4'
                        AND PD.QTY > 0
                        AND LOC.PickZone = @cPickZone
                     GROUP BY SKU.ItemClass
                  ) Style ON (Style.ItemClass = SKU.ItemClass)
               WHERE LOC.Facility = @cFacility
                  AND PD.StorerKey = @cStorerKey
                  AND PD.CaseID = @cCaseID
                  AND PD.Status < '4'
                  AND PD.QTY > 0
                  AND LOC.PickZone = @cPickZone
               GROUP BY Style.StyleSeq, SKU.ItemClass, SKU.SKU
               ORDER BY Style.StyleSeq, SUM( PD.QTY) DESC

         OPEN @curLog
         FETCH NEXT FROM @curLog INTO @cStyle, @cSKU
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Single style (assign position by SKU)
            IF @nStyle = 1
            BEGIN
               -- Get SKU position
               SELECT @cPosition = Position
               FROM rdt.rdtPTLCartLog WITH (NOLOCK)
               WHERE CartID = @cCartID
                  AND SKU = @cSKU
                              
               -- New SKU
               IF @@ROWCOUNT = 0
                  -- Get new position
                  SELECT TOP 1
                     @cIPAddress = DP.IPAddress, 
                     @cPosition = DP.DevicePosition
                  FROM dbo.DeviceProfile DP WITH (NOLOCK)
                  WHERE DP.DeviceType = 'CART'
                     AND DP.DeviceID = @cCartID
                     AND NOT EXISTS( SELECT 1
                        FROM rdt.rdtPTLCartLog PCLog WITH (NOLOCK)
                        WHERE CartID = @cCartID
                           AND PCLog.Position = DP.DevicePosition)
                  ORDER BY DP.DevicePosition
            END
            
            -- Mix style (assign position by style)
            ELSE
            BEGIN
               -- Get style position
               SELECT @cPosition = Position
               FROM rdt.rdtPTLCartLog WITH (NOLOCK)
               WHERE CartID = @cCartID
                  AND ItemClass = @cStyle
                  
               -- New style
               IF @@ROWCOUNT = 0
                  -- Get new position
                  SELECT TOP 1
                     @cIPAddress = DP.IPAddress, 
                     @cPosition = DP.DevicePosition
                  FROM dbo.DeviceProfile DP WITH (NOLOCK)
                  WHERE DP.DeviceType = 'CART'
                     AND DP.DeviceID = @cCartID
                     AND NOT EXISTS( SELECT 1
                        FROM rdt.rdtPTLCartLog PCLog WITH (NOLOCK)
                        WHERE CartID = @cCartID
                           AND PCLog.Position = DP.DevicePosition)
                  ORDER BY DP.DevicePosition
            END

            -- Save assign
            INSERT INTO rdt.rdtPTLCartLog (CartID, Position, ToteID, DeviceProfileLogKey, Method, PickZone, PickSeq, CaseID, SKU, ItemClass, StorerKey)
            VALUES (@cCartID, @cPosition, @cPosition, @cDPLKey, @cMethod, @cPickZone, @cPickSeq, @cCaseID, @cSKU, @cStyle, @cStorerKey)
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 188756
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Log fail
               GOTO RollBackTran
            END

            FETCH NEXT FROM @curLog INTO @cStyle, @cSKU
         END
    
         /***********************************************************************************************
                                                Insert PTLTran
         ***********************************************************************************************/
         DECLARE @curPD CURSOR
         IF @cPickZone = ''
            SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT PD.LOC, PD.SKU, SKU.ItemClass, SUM( PD.QTY)
               FROM Orders O WITH (NOLOCK)
                  JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
                  JOIN SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
                  JOIN LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
               WHERE LOC.Facility = @cFacility
                  AND PD.StorerKey = @cStorerKey
                  AND PD.CaseID = @cCaseID
                  AND PD.Status < '4'
                  AND PD.QTY > 0
                  AND O.Status <> 'CANC'
                  AND O.SOStatus <> 'CANC'
               GROUP BY PD.LOC, PD.SKU, SKU.ItemClass
         ELSE
            SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT PD.LOC, PD.SKU, SKU.ItemClass, SUM( PD.QTY)
               FROM Orders O WITH (NOLOCK)
                  JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
                  JOIN SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
                  JOIN LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
               WHERE LOC.Facility = @cFacility
                  AND PD.StorerKey = @cStorerKey
                  AND PD.CaseID = @cCaseID
                  AND PD.Status < '4'
                  AND PD.QTY > 0
                  AND O.Status <> 'CANC'
                  AND O.SOStatus <> 'CANC'
                  AND LOC.PickZone = @cPickZone
               GROUP BY PD.LOC, PD.SKU, SKU.ItemClass

         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cLOC, @cSKU, @cStyle, @nQTY
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Get position assigned
            SELECT TOP 1 
               @cPosition = Position
            FROM rdt.rdtPTLCartLog WITH (NOLOCK)
            WHERE DeviceProfileLogKey = @cDPLKey
               AND ItemClass = @cStyle
            ORDER BY CASE WHEN SKU = @cSKU THEN 1 ELSE 2 END
            
            -- Get IPAddress
            SELECT @cIPAddress = IPAddress
            FROM dbo.DeviceProfile WITH (NOLOCK)
            WHERE DeviceType = 'CART'
               AND DeviceID = @cCartID
               AND DevicePosition = @cPosition
            
            INSERT INTO PTL.PTLTran (
               IPAddress, DeviceID, DevicePosition, Status, PTLType,
               DeviceProfileLogKey, DropID, CaseID, Storerkey, SKU, LOC, ExpectedQTY, QTY)
            VALUES (
               @cIPAddress, @cCartID, @cPosition, '0', 'CART',
               @cDPLKey, '', @cCaseID, @cStorerKey, @cSKU, @cLOC, @nQTY, 0)

            IF @@ERROR <> ''
            BEGIN
               SET @nErrNo = 188757
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode ,'DSP') --INS PTL Fail
               GOTO RollBackTran
            END
            FETCH NEXT FROM @curPD INTO @cLOC, @cSKU, @cStyle, @nQTY
         END

         COMMIT TRAN rdt_PTLCart_Assign_Case
      END
   END
   
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_PTLCart_Assign_Case
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO