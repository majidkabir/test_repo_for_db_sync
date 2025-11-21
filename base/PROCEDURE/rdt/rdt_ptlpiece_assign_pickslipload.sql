SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_PTLPiece_Assign_PickSlipLoad                          */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 16-11-2022 1.0  Ung      WMS-21112 Create                                  */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_PTLPiece_Assign_PickSlipLoad] (
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
   DECLARE @bSuccess       INT
   DECLARE @cSQL           NVARCHAR(MAX)
   DECLARE @cSQLParam      NVARCHAR(MAX)

   DECLARE @cPickSlipNo    NVARCHAR(10)
   DECLARE @cZone          NVARCHAR(18)
   DECLARE @cOrderKey      NVARCHAR(10)
   DECLARE @cLoadKey       NVARCHAR(10)
   DECLARE @cIPAddress     NVARCHAR(40)
   DECLARE @cPosition      NVARCHAR(10)
   DECLARE @cLOC           NVARCHAR(10)
   DECLARE @cCartonID      NVARCHAR(20)
   DECLARE @cSKU           NVARCHAR(20)
   DECLARE @cDropID        NVARCHAR(20)
   DECLARE @nTotalLoad      INT

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

      SELECT @nTotalLoad = COUNT(1) FROM rdt.rdtPTLPieceLog WITH (NOLOCK) WHERE Station = @cStation AND LoadKey <> ''
      
		-- Prepare next screen var
		SET @cOutField01 = @cPickSlipNo
		SET @cOutField02 = CAST( @nTotalLoad AS NVARCHAR(5))
		-- SET @cOutField03 = '' -- CartonID

      IF @cPickSlipNo = ''
      BEGIN
         -- Enable disable field
         SET @cFieldAttr01 = ''  -- PickSlipNo
         -- SET @cFieldAttr03 = 'O' -- DropID

   	   EXEC rdt.rdtSetFocusField @nMobile, 1 -- PickSlipNo
      END
      ELSE
      BEGIN
         SET @cFieldAttr01 = 'O' -- PickSlipNo
         -- SET @cFieldAttr03 = ''  -- DropID
      END

		-- Go to batch, drop ID screen
		SET @nScn = 6160
   END
      
   IF @cType = 'POPULATE-OUT'
   BEGIN
      SET @cFieldAttr01 = '' -- PickSlipNo
      -- SET @cFieldAttr03 = '' -- CartonID
      
		-- Go to station screen
   END
   
   /***********************************************************************************************
                                                 CHECK
   ***********************************************************************************************/
   IF @cType = 'CHECK'
   BEGIN
      -- Screen mapping
      SET @cPickSlipNo = CASE WHEN @cFieldAttr01 = '' THEN @cInField01 ELSE @cOutField01 END
      --SET @cDropID = CASE WHEN @cFieldAttr03 = '' THEN @cInField03 ELSE @cOutField03 END
      
      -- PickSlipNo enable
      IF @cFieldAttr01 = ''
      BEGIN
   		-- Check blank
   		IF @cPickSlipNo = '' 
         BEGIN
            SET @nErrNo = 194001
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need PickSlipNo
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- PickSlipNo
            GOTO Quit
         END

         -- Check pickslip assigned
         IF EXISTS( SELECT 1
            FROM rdt.rdtPTLPieceLog WITH (NOLOCK)
            WHERE Station <> @cStation
               AND PickSlipNo = @cPickSlipNo)
         BEGIN
            SET @nErrNo = 194002
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PSNO assigned
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
         
         DECLARE @curLoad CURSOR

         -- Cross dock PickSlip
         IF @cZone IN ('XD', 'LB', 'LP')
         BEGIN
            -- Check PickSlipNo valid
            IF NOT EXISTS( SELECT TOP 1 1 FROM dbo.RefKeyLookup RKL WITH (NOLOCK) WHERE RKL.PickSlipNo = @cPickSlipNo)
            BEGIN
               SET @nErrNo = 194003
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid PSNO
               SET @cOutField01 = ''
               GOTO Quit
            END

            SET @curLoad = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT DISTINCT O.LoadKey
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
               SET @nErrNo = 194004
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad OrderKey
               SET @cOutField01 = ''
               GOTO Quit
            END

            -- Check storer
            IF @cStorerKey <> @cChkStorerKey
            BEGIN
               SET @nErrNo = 194005
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storer
               SET @cOutField01 = ''
               GOTO Quit
            END

            -- Check facility
            IF @cFacility <> @cChkFacility
            BEGIN
               SET @nErrNo = 194006
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
               SET @cOutField01 = ''
               GOTO Quit
            END

            -- Check order CANC
            IF @cChkStatus = 'CANC' OR @cChkSOStatus = 'CANC'
            BEGIN
               SET @nErrNo = 194007
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order CANCEL
               SET @cOutField01 = ''
               GOTO Quit
            END
            
            SET @curLoad = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT DISTINCT O.LoadKey
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
               SET @nErrNo = 194008
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid PSNO
               SET @cOutField01 = ''
               GOTO Quit
            END

            SET @curLoad = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT DISTINCT LPD.LoadKey
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
               SET @nErrNo = 194009
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid PSNO
               SET @cOutField01 = ''
               GOTO Quit
            END

            SET @curLoad = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT DISTINCT O.LoadKey
               FROM Orders O WITH (NOLOCK)
                  JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
               WHERE PD.PickSlipNo = @cPickSlipNo
                  AND PD.Status <> '4'
                  AND PD.QTY > 0
         END

         -- Storer config
         DECLARE @cUpdatePackDetail NVARCHAR( 1)
         SET @cUpdatePackDetail = rdt.RDTGetConfig( @nFunc, 'UpdatePackDetail', @cStorerkey)

         -- Handling transaction
         BEGIN TRAN  -- Begin our own transaction
         SAVE TRAN rdt_PTLPiece_Assign -- For rollback or commit only our own transaction
         
         -- Loop load
         OPEN @curLoad
         FETCH NEXT FROM @curLoad INTO @cLoadKey
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
               SET @nErrNo = 194010
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not enuf Pos
               SET @cOutField01 = ''
               GOTO RollBackTran
            END 
            
            -- Save assign
            INSERT rdt.rdtPTLPieceLog (Station, IPAddress, Position, LOC, PickSlipNo, LoadKey)
            VALUES (@cStation, @cIPAddress, @cPosition, @cLOC, @cPickSlipNo, @cLoadKey)
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 194011
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log fail
               GOTO RollBackTran
            END

            -- Generate PackDetail.LabelNo
            IF @cUpdatePackDetail = '1'
            BEGIN
               -- Custom carton ID
               SET @cCartonID = ''
               EXEC rdt.rdt_PTLPiece_CustomCartonID @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
                  @cStation, 
                  @cPosition, 
                  @cMethod, 
                  @cSKU, 
                  @nErrNo     OUTPUT, 
                  @cErrMsg    OUTPUT, 
                  @cCartonID  OUTPUT 
               IF @nErrNo <> 0
                  GOTO RollBackTran

               IF @cCartonID <> ''
               BEGIN
                  UPDATE rdt.rdtPTLPieceLog SET
                     CartonID = @cCartonID, 
                     EditDate = GETDATE(), 
                     EditWho = SUSER_SNAME()
                  WHERE Station = @cStation
                     AND Position = @cPosition
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 194012
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Log fail
                     GOTO RollBackTran
                  END
               END
            END
   
            FETCH NEXT FROM @curLoad INTO @cLoadKey
         END
   
         COMMIT TRAN rdt_PTLPiece_Assign
      END

      -- Enable field
      SET @cFieldAttr01 = '' -- PickSlipNo
   END
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_PTLPiece_Assign
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO