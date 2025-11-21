SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_PTLPiece_Assign_PickSlipSKU                           */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 31-10-2022 1.0  Ung      WMS-21056 Create                                  */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_PTLPiece_Assign_PickSlipSKU] (
   @nMobile          INT, 
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3), 
   @nStep            INT, 
   @nInputKey        INT, 
   @cFacility        NVARCHAR( 5), 
   @cStorerKey       NVARCHAR( 15),  
   @cStation         NVARCHAR( 10),  
   @cMethod          NVARCHAR( 1),
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
   DECLARE @cSQL           NVARCHAR(MAX)
   DECLARE @cSQLParam      NVARCHAR(MAX)

   DECLARE @cPickSlipNo    NVARCHAR(10)
   DECLARE @cZone          NVARCHAR(18)
   DECLARE @cOrderKey      NVARCHAR(10)
   DECLARE @cLoadKey       NVARCHAR(10)
   DECLARE @cIPAddress     NVARCHAR(40)
   DECLARE @cPosition      NVARCHAR(10)
   DECLARE @cLOC           NVARCHAR(10)
   DECLARE @cSKU           NVARCHAR(20)
   DECLARE @cDropID        NVARCHAR(20)
   DECLARE @nTotalSKU      INT

   SET @nTranCount = @@TRANCOUNT

   /***********************************************************************************************
                                                POPULATE
   ***********************************************************************************************/
   IF @cType = 'POPULATE-IN'
   BEGIN
      -- Get batch 
      SET @cPickSlipNo = ''
      SELECT @cPickSlipNo = PickSlipNo
      FROM rdt.rdtPTLPieceLog WITH (NOLOCK) 
      WHERE Station = @cStation

      SELECT @nTotalSKU = COUNT(1) FROM rdt.rdtPTLPieceLog WITH (NOLOCK) WHERE Station = @cStation AND SKU <> ''
      
		-- Prepare next screen var
		SET @cOutField01 = @cPickSlipNo
		SET @cOutField02 = CAST( @nTotalSKU AS NVARCHAR(5))
		SET @cOutField03 = '' -- CartonID

      IF @cPickSlipNo = ''
      BEGIN
         -- Enable disable field
         SET @cFieldAttr01 = ''  -- PickSlipNo
         SET @cFieldAttr03 = 'O' -- DropID

   	   EXEC rdt.rdtSetFocusField @nMobile, 1 -- PickSlipNo
      END
      ELSE
      BEGIN
         SET @cFieldAttr01 = 'O' -- PickSlipNo
         SET @cFieldAttr03 = ''  -- DropID
      END

		-- Go to batch, drop ID screen
		SET @nScn = 6161
   END
      
   IF @cType = 'POPULATE-OUT'
   BEGIN
      SET @cFieldAttr01 = '' -- PickSlipNo
      SET @cFieldAttr03 = '' -- CartonID
      
		-- Go to station screen
   END
   
   /***********************************************************************************************
                                                 CHECK
   ***********************************************************************************************/
   IF @cType = 'CHECK'
   BEGIN
      -- Screen mapping
      SET @cPickSlipNo = CASE WHEN @cFieldAttr01 = '' THEN @cInField01 ELSE @cOutField01 END
      SET @cDropID = CASE WHEN @cFieldAttr03 = '' THEN @cInField03 ELSE @cOutField03 END
      
      -- PickSlipNo enable
      IF @cFieldAttr01 = ''
      BEGIN
   		-- Check blank
   		IF @cPickSlipNo = '' 
         BEGIN
            SET @nErrNo = 193451
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need PickSlipNo
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- PickSlipNo
            GOTO Quit
         END

         -- Check batch assigned
         IF EXISTS( SELECT 1
            FROM rdt.rdtPTLPieceLog WITH (NOLOCK)
            WHERE Station <> @cStation
               AND PickSlipNo = @cPickSlipNo)
         BEGIN
            SET @nErrNo = 193452
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Batch assigned
            SET @cOutField01 = ''
            GOTO Quit
         END

         -- Get PickHeader info
         SELECT
            @cZone = Zone,
            @cOrderKey = ISNULL( OrderKey, ''),
            @cLoadKey = ExternOrderKey
         FROM PickHeader WITH (NOLOCK)
         WHERE PickHeaderKey = @cPickSlipNo
         
         DECLARE @curSKU CURSOR

         -- Cross dock PickSlip
         IF @cZone IN ('XD', 'LB', 'LP')
         BEGIN
            -- Check PickSlipNo valid
            IF NOT EXISTS( SELECT TOP 1 1 FROM dbo.RefKeyLookup RKL WITH (NOLOCK) WHERE RKL.PickSlipNo = @cPickSlipNo)
            BEGIN
               SET @nErrNo = 193453
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid PSNO
               SET @cOutField01 = ''
               GOTO Quit
            END

            SET @curSKU = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT DISTINCT PD.SKU
               FROM Orders O WITH (NOLOCK)
                  JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
                  JOIN RefKeyLookup RKL WITH (NOLOCK) ON (RKL.PickDetailKey = PD.PickDetailKey)
               WHERE RKL.PickslipNo = @cPickSlipNo
                  AND PD.Status <> '4'
                  AND PD.QTY > 0
         END

         -- Discrete PickSlip
         ELSE IF @cOrderKey <> ''
         BEGIN
            -- Get order info
            DECLARE @cChkFacility  NVARCHAR( 5)
            DECLARE @cChkStorerKey NVARCHAR( 15)
            DECLARE @cChkStatus    NVARCHAR( 10)
            DECLARE @cChkSOStatus  NVARCHAR( 10)
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
               SET @nErrNo = 193454
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad OrderKey
               SET @cOutField01 = ''
               GOTO Quit
            END

            -- Check storer
            IF @cStorerKey <> @cChkStorerKey
            BEGIN
               SET @nErrNo = 193455
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storer
               SET @cOutField01 = ''
               GOTO Quit
            END

            -- Check facility
            IF @cFacility <> @cChkFacility
            BEGIN
               SET @nErrNo = 193456
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
               SET @cOutField01 = ''
               GOTO Quit
            END

            -- Check order CANC
            IF @cChkStatus = 'CANC' OR @cChkSOStatus = 'CANC'
            BEGIN
               SET @nErrNo = 193457
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order CANCEL
               SET @cOutField01 = ''
               GOTO Quit
            END
            
            SET @curSKU = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT DISTINCT PD.SKU
               FROM dbo.Orders O WITH (NOLOCK) 
                  JOIN dbo.PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
               WHERE O.OrderKey = @cOrderKey
                  AND PD.Status <> '4'
                  AND PD.QTY > 0
         END

         -- Conso PickSlip
         ELSE IF @cLoadKey <> ''
         BEGIN
            -- Check PickSlip valid
            IF NOT EXISTS( SELECT TOP 1 1 FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) WHERE LPD.LoadKey = @cLoadKey)
            BEGIN
               SET @nErrNo = 193458
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid PSNO
               SET @cOutField01 = ''
               GOTO Quit
            END

            SET @curSKU = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT DISTINCT PD.SKU
               FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
                  JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
               WHERE LPD.Loadkey = @cLoadKey
                  AND PD.Status <> '4'
                  AND PD.QTY > 0
         END

         -- Custom PickSlip
         ELSE
         BEGIN
            -- Check PickSlip valid
            IF NOT EXISTS( SELECT 1 FROM PickDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)
            BEGIN
               SET @nErrNo = 193459
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid PSNO
               SET @cOutField01 = ''
               GOTO Quit
            END

            SET @curSKU = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT DISTINCT PD.SKU
               FROM Orders O WITH (NOLOCK)
                  JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
               WHERE PD.PickSlipNo = @cPickSlipNo
                  AND PD.Status <> '4'
                  AND PD.QTY > 0
         END
            
         -- Handling transaction
         BEGIN TRAN  -- Begin our own transaction
         SAVE TRAN rdt_PTLPiece_Assign -- For rollback or commit only our own transaction
         
         -- Loop SKU
         OPEN @curSKU
         FETCH NEXT FROM @curSKU INTO @cSKU
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Get position not yet assign
            SET @cIPAddress = ''
            SET @cPosition = ''
            SELECT TOP 1
               @cIPAddress = DP.IPAddress, 
               @cPosition = DP.DevicePosition, 
               @cLOC = DP.LOC
            FROM dbo.DeviceProfile DP WITH (NOLOCK)
            WHERE DP.DeviceType = 'STATION'
               AND DP.DeviceID = @cStation
               AND NOT EXISTS( SELECT 1
                  FROM rdt.rdtPTLPieceLog Log WITH (NOLOCK)
                  WHERE Log.Station = @cStation
                     AND Log.Position = DP.DevicePosition)
            ORDER BY DP.LogicalPos, DP.DevicePosition

            -- Check order fit in station
            IF @cPosition = '' 
            BEGIN
               SET @nErrNo = 193460
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not enuf Pos
               SET @cOutField01 = ''
               GOTO RollBackTran
            END 
            
            -- Save assign
            INSERT rdt.rdtPTLPieceLog (Station, IPAddress, Position, LOC, PickSlipNo, SKU)
            VALUES (@cStation, @cIPAddress, @cPosition, @cLOC, @cPickSlipNo, @cSKU)
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 193461
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log fail
               GOTO RollBackTran
            END
   
            FETCH NEXT FROM @curSKU INTO @cSKU
         END
   
         COMMIT TRAN rdt_PTLStation_Assign

         SELECT @nTotalSKU = COUNT(1) FROM rdt.rdtPTLPieceLog WITH (NOLOCK) WHERE Station = @cStation AND SKU <> ''
         
         -- Prepare current screen var
         SET @cOutField01 = @cPickSlipNo
         SET @cOutField02 = CAST( @nTotalSKU AS NVARCHAR(5))
         SET @cOutField03 = '' -- DropID

         -- Enable / Disable field
         SET @cFieldAttr01 = 'O' -- PickSlipNo
         SET @cFieldAttr03 = ''  -- DropID
         
         -- Remain in current screen
         SET @nErrNo = -1
         GOTO Quit
      END
      
      -- DropID enable
      IF @cFieldAttr03 = ''
      BEGIN
   		-- Check blank
   		IF @cDropID = '' 
         BEGIN
            SET @nErrNo = 193462
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need DropID
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- DropID
            GOTO Quit
         END
         
         -- Check barcode format
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'DropID', @cDropID) = 0
         BEGIN
            SET @nErrNo = 193463
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- DropID
            GOTO Quit
         END
         
         UPDATE rdt.rdtMobRec SET
            V_DropID = @cDropID, 
            EditDate = GETDATE()
         WHERE Mobile = @nMobile
      END

      -- Enable field
      SET @cFieldAttr01 = '' -- PickSlipNo
      SET @cFieldAttr03 = '' -- DropID
   END
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_PTLStation_Assign
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO