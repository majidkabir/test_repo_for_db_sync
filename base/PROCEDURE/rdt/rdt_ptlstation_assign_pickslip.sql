SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_PTLStation_Assign_Pickslip                            */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 18-10-2022 1.0  Ung      WMS-21024 Created                                 */
/******************************************************************************/

CREATE PROC [RDT].[rdt_PTLStation_Assign_Pickslip] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT,
   @cFacility        NVARCHAR( 5),
   @cStorerKey       NVARCHAR( 15),
   @cStation1        NVARCHAR( 10),
   @cStation2        NVARCHAR( 10),
   @cStation3        NVARCHAR( 10),
   @cStation4        NVARCHAR( 10),
   @cStation5        NVARCHAR( 10),
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
   DECLARE @nTotalOrder    INT

   DECLARE @cPickSlipNo    NVARCHAR(10) = ''
   DECLARE @cStation       NVARCHAR(10)
   DECLARE @cIPAddress     NVARCHAR(40)
   DECLARE @cPosition      NVARCHAR(10)

   DECLARE @cZone          NVARCHAR(18) = ''
   DECLARE @cOrderKey      NVARCHAR(10) = ''
   DECLARE @cLoadKey       NVARCHAR(10) = ''

   DECLARE @cChkFacility   NVARCHAR(5)
   DECLARE @cChkStorerKey  NVARCHAR(15)
   DECLARE @cChkStatus     NVARCHAR(10)
   DECLARE @cChkSOStatus   NVARCHAR(10)
   DECLARE @curOrder       CURSOR

   SET @nTranCount = @@TRANCOUNT

   /***********************************************************************************************
                                                POPULATE
   ***********************************************************************************************/
   IF @cType = 'POPULATE-IN'
   BEGIN      
      -- Get pickslip
      SELECT TOP 1 
         @cPickSlipNo = PickSlipNo
      FROM rdt.rdtPTLStationLog WITH (NOLOCK)
      WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
         AND PickSlipNo <> ''

      -- Get total
      SELECT @nTotalOrder = COUNT(1) 
      FROM rdt.rdtPTLStationLog WITH (NOLOCK)
      WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)

      IF @cPickSlipNo <> ''
         SET @cFieldAttr01 = 'O' -- PickSlipNo
      ELSE
         SET @cFieldAttr01 = ''

		-- Prepare next screen var
		SET @cOutField01 = @cPickSlipNo
		SET @cOutField02 = CAST( @nTotalOrder AS NVARCHAR( 5))

		-- Go to pickslip screen
		SET @nScn = 4494
   END

   IF @cType = 'POPULATE-OUT'
   BEGIN
      -- Enable field
      SET @cFieldAttr01 = '' -- PickSlipNo

      -- Go to station screen
   END


   /***********************************************************************************************
                                                 CHECK
   ***********************************************************************************************/
   IF @cType = 'CHECK'
   BEGIN
      -- Screen mapping
      SET @cPickSlipNo = CASE WHEN @cFieldAttr01 = '' THEN @cInField01 ELSE @cOutField01 END

      -- PickSlipNo enable
      IF @cFieldAttr01 = ''
      BEGIN
         -- Check blank
   		IF @cPickSlipNo = ''
         BEGIN
            SET @nErrNo = 192951
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need PSNO
            GOTO Quit
         END

         -- Check pickslip assigned
         IF EXISTS( SELECT 1
            FROM rdt.rdtPTLStationLog WITH (NOLOCK)
            WHERE Station NOT IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
               AND PickSlipNo = @cPickSlipNo)
         BEGIN
            SET @nErrNo = 192952
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PSNO Assigned
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

         -- Cross dock PickSlip
         IF @cZone IN ('XD', 'LB', 'LP')
         BEGIN
            -- Check PickSlipNo valid
            IF NOT EXISTS( SELECT TOP 1 1 FROM dbo.RefKeyLookup RKL WITH (NOLOCK) WHERE RKL.PickSlipNo = @cPickSlipNo)
            BEGIN
               SET @nErrNo = 192953
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid PSNO
               SET @cOutField01 = ''
               GOTO Quit
            END

            SET @curOrder = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT DISTINCT O.OrderKey
               FROM Orders O WITH (NOLOCK)
                  JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
                  JOIN RefKeyLookup RKL WITH (NOLOCK) ON (RKL.PickDetailKey = PD.PickDetailKey)
               WHERE RKL.PickslipNo = @cPickSlipNo
         END

         -- Discrete PickSlip
         ELSE IF @cOrderKey <> ''
         BEGIN
            SET @curOrder = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT @cOrderKey
         END

         -- Conso PickSlip
         ELSE IF @cLoadKey <> ''
         BEGIN
            -- Check PickSlip valid
            IF NOT EXISTS( SELECT TOP 1 1 FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) WHERE LPD.LoadKey = @cLoadKey)
            BEGIN
               SET @nErrNo = 192954
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid PSNO
               SET @cOutField01 = ''
               GOTO Quit
            END

            SET @curOrder = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT DISTINCT O.OrderKey
               FROM LoadPlanDetail LPD WITH (NOLOCK)
                  JOIN Orders O WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey)
               WHERE LPD.Loadkey = @cLoadKey
         END

         -- Custom PickSlip
         ELSE
         BEGIN
            -- Check PickSlip valid
            IF NOT EXISTS( SELECT 1 FROM PickDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)
            BEGIN
               SET @nErrNo = 192955
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid PSNO
               SET @cOutField01 = ''
               GOTO Quit
            END

            SET @curOrder = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT DISTINCT O.OrderKey
               FROM Orders O WITH (NOLOCK)
                  JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
               WHERE PD.PickSlipNo = @cPickSlipNo
         END

         SET @nTranCount = @@TRANCOUNT
         BEGIN TRAN
         SAVE TRAN rdt_PTLStation_Assign_Pickslip

         OPEN @curOrder
         FETCH NEXT FROM @curOrder INTO @cOrderKey
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
               SET @nErrNo = 192956
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad OrderKey
               SET @cOutField01 = ''
               GOTO RollBackTran
            END

            -- Check storer
            IF @cStorerKey <> @cChkStorerKey
            BEGIN
               SET @nErrNo = 192957
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storer
               SET @cOutField01 = ''
               GOTO RollBackTran
            END

            -- Check facility
            IF @cFacility <> @cChkFacility
            BEGIN
               SET @nErrNo = 192958
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility
               SET @cOutField01 = ''
               GOTO RollBackTran
            END

            -- Check order CANC
            IF @cChkStatus = 'CANC' OR @cChkSOStatus = 'CANC'
            BEGIN
               SET @nErrNo = 192959
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order CANCEL
               SET @cOutField01 = ''
               GOTO RollBackTran
            END

            -- Check order assigned
            IF EXISTS( SELECT 1
               FROM rdt.rdtPTLStationLog WITH (NOLOCK)
               WHERE Station NOT IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
                  AND OrderKey = @cOrderKey)
            BEGIN
               SET @nErrNo = 192960
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order Assigned
               SET @cOutField01 = ''
               GOTO RollBackTran
            END

            -- Get position not yet assign
            SELECT TOP 1
               @cStation = DP.DeviceID,
               @cIPAddress = DP.IPAddress,
               @cPosition = DP.DevicePosition
            FROM DeviceProfile DP WITH (NOLOCK)
               LEFT JOIN rdt.rdtPTLStationLog L WITH (NOLOCK) ON (DP.DeviceID = L.Station AND DP.IPAddress = L.IPAddress AND DP.DevicePosition = L.Position)
            WHERE DeviceID IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
               AND DeviceType = 'STATION'
               AND DeviceID <> ''
               AND Position IS NULL
            ORDER BY DP.DeviceID, DP.LogicalPOS, DP.DevicePosition

            -- Check station blank
            IF @cStation = ''
            BEGIN
               SET @nErrNo = 192961
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoMorePosition
               SET @cOutField01 = ''
               GOTO Quit
            END

            -- Save assign
            INSERT INTO rdt.rdtPTLStationLog (Station, IPAddress, Position, CartonID, Method, OrderKey, StorerKey, PickSlipNo, LOC)
            VALUES (@cStation, @cIPAddress, @cPosition, @cPosition, @cMethod, @cOrderKey, @cStorerKey, @cPickSlipNo, @cPosition)
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 192962
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log Fail
               SET @cOutField01 = ''
               GOTO RollBackTran
            END
            
            SET @nTotalOrder = @nTotalOrder + 1

            FETCH NEXT FROM @curOrder INTO @cOrderKey
         END

         COMMIT TRAN rdt_PTLStation_Assign_Pickslip
      END
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_PTLStation_Assign_Pickslip
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO