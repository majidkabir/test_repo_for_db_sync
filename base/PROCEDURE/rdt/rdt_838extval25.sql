SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_838ExtVal25                                        */
/* Copyright      : Maersk                                                 */
/*                                                                         */
/* Purpose: Created for SIWSS E                                            */
/*                                                                         */
/* Date       Rev     Author      Purposes                                 */
/* 2025-01-14 1.0.0   JCH507      FCR-2124 Created                         */
/***************************************************************************/

CREATE   PROC rdt.rdt_838ExtVal25 (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT,
   @cFacility        NVARCHAR( 5),
   @cStorerKey       NVARCHAR( 15),
   @cPickSlipNo      NVARCHAR( 10),
   @cFromDropID      NVARCHAR( 20),
   @nCartonNo        INT,
   @cLabelNo         NVARCHAR( 20),
   @cSKU             NVARCHAR( 20),
   @nQTY             INT,
   @cUCCNo           NVARCHAR( 20),
   @cCartonType      NVARCHAR( 10),
   @cCube            NVARCHAR( 10),
   @cWeight          NVARCHAR( 10),
   @cRefNo           NVARCHAR( 20),
   @cSerialNo        NVARCHAR( 30),
   @nSerialQTY       INT,
   @cOption          NVARCHAR( 1),
   @cPackDtlRefNo    NVARCHAR( 20), 
   @cPackDtlRefNo2   NVARCHAR( 20), 
   @cPackDtlUPC      NVARCHAR( 30), 
   @cPackDtlDropID   NVARCHAR( 20), 
   @cPackData1       NVARCHAR( 30), 
   @cPackData2       NVARCHAR( 30), 
   @cPackData3       NVARCHAR( 30),
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bDebugFlag  BINARY
   DECLARE @cOrderKey   NVARCHAR( 10)
   DECLARE @cLoadKey    NVARCHAR( 10)
   DECLARE @cZone       NVARCHAR( 18)
   DECLARE @nPickQTY    INT = 0
   DECLARE @nPackQTY    INT = 0
   DECLARE @cLottable01 NVARCHAR( 18)
   DECLARE @cPickStatus NVARCHAR(1)
   DECLARE @cSQL        NVARCHAR(MAX)
   DECLARE @cSQLParam   NVARCHAR(MAX)
   
   IF @nFunc = 838 -- Pack
   BEGIN
      IF @nStep = 10 -- Pack data
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            /***************************************************************************************************
                                                   Required Value Validation
            ***************************************************************************************************/
            -- Check FromDropID has value
            IF @cFromDropID = '' OR @cFromDropID IS NULL
            BEGIN
               SET @nErrNo = 232151
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need FromDropID
               EXEC rdt.rdtSetFocusField @nMobile, 1  -- DropID
               GOTO Quit
            END

            SET @cOrderKey = ''
            SET @cLoadKey = ''
            SET @cZone = ''

            -- Get PickHeader info
            SELECT TOP 1
               @cOrderKey = OrderKey,
               @cLoadKey = ExternOrderKey,
               @cZone = Zone
            FROM dbo.PickHeader WITH (NOLOCK)
            WHERE PickHeaderKey = @cPickSlipNo

            IF @bDebugFlag = 1
               SELECT @cOrderKey AS OrderKey, @cLoadKey AS LoadKey, @cZone AS Zone


            /***************************************************************************************************
                                                            PackData1
            ***************************************************************************************************/
            -- Check batch no blank
            IF @cPackData1 = ''
            BEGIN
               SET @nErrNo = 232152
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need batch no
               EXEC rdt.rdtSetFocusField @nMobile, 2  -- batch no
               GOTO Quit
            END

            -- Validate batch no
            BEGIN TRY
               IF @cZone IN ('XD', 'LB', 'LP')
               BEGIN
                  SET @cSQL = 
                  ' SELECT @nPickQty = ISNULL( SUM( PD.QTY), 0) ' + 
                  ' FROM dbo.RefKeyLookup RKL WITH (NOLOCK) ' + 
                     ' JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey) ' + 
                  ' WHERE RKL.PickSlipNo = @cPickSlipNo ' + 
                     ' AND PD.Storerkey = @cStorerkey ' +
                     ' AND PD.SKU = @cSKU ' + 
                     ' AND PD.DropID = @cFromDropID ' +
                     ' AND LA.Lottable01 = @cPackData1 '
               SET @cSQLParam = 
                  ' @cPickSlipNo NVARCHAR( 10), ' + 
                  ' @cStorerKey  NVARCHAR( 15), ' +
                  ' @cSKU        NVARCHAR( 20), ' +
                  ' @cFromDropID NVARCHAR( 20), ' +
                  ' @cPackData1  NVARCHAR( 30), ' +
                  ' @nPickQty  INT OUTPUT '
               EXEC sp_executeSQL @cSQL, @cSQLParam
                  ,@cPickSlipNo = @cPickSlipNo
                  ,@cStorerKey = @cStorerKey
                  ,@cSKU = @cSKU
                  ,@cFromDropID = @cFromDropID
                  ,@cPackData1 = @cPackData1
                  ,@nPickQTY  = @nPickQTY OUTPUT
               END -- Zone
               ELSE IF @cOrderKey <> ''
               BEGIN
                  SET @cSQL = 
                     ' SELECT @nPickQty = ISNULL( SUM( PD.QTY), 0) ' + 
                     ' FROM dbo.PickDetail PD WITH (NOLOCK) ' + 
                        ' JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON LA.LOT = PD.LOT ' + 
                     ' WHERE PD.OrderKey = @cOrderKey ' +
                        ' AND PD.Storerkey = @cStorerkey ' +
                        ' AND PD.SKU = @cSKU ' + 
                        ' AND PD.DropID = @cFromDropID ' +
                        ' AND LA.Lottable01 = @cPackData1 '
                  SET @cSQLParam = 
                     ' @cOrderKey   NVARCHAR( 10), ' +
                     ' @cStorerKey  NVARCHAR( 15), ' +
                     ' @cSKU        NVARCHAR( 20), ' +
                     ' @cFromDropID NVARCHAR( 20), ' +
                     ' @cPackData1 NVARCHAR( 30), ' +
                     ' @nPickQty    INT OUTPUT '
                  EXEC sp_executeSQL @cSQL, @cSQLParam
                     ,@cOrderKey = @cOrderKey
                     ,@cStorerKey = @cStorerKey
                     ,@cSKU = @cSKU
                     ,@cFromDropID = @cFromDropID
                     ,@cPackData1 = @cPackData1
                     ,@nPickQTY  = @nPickQTY OUTPUT
               END -- OrderKey
               ELSE IF @cLoadKey <> ''
               BEGIN
                  SET @cSQL = 
                  ' SELECT @nPickQty = ISNULL( SUM( PD.QTY), 0) ' + 
                  ' FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) ' + 
                     ' JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = LPD.OrderKey) ' + 
                     ' JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON LA.LOT = PD.LOT ' + 
                  ' WHERE LPD.LoadKey = @cLoadKey ' + 
                        ' AND PD.Storerkey = @cStorerkey ' +
                        ' AND PD.SKU = @cSKU ' + 
                        ' AND PD.DropID = @cFromDropID ' +
                        ' AND LA.Lottable01 = @cPackData1 ' 
                  SET @cSQLParam = 
                     ' @cLoadKey    NVARCHAR( 10), ' +
                     ' @cStorerKey  NVARCHAR( 15), ' +
                     ' @cSKU        NVARCHAR( 20), ' +
                     ' @cFromDropID NVARCHAR( 20), ' +
                     ' @cPackData1  NVARCHAR( 30), ' + 
                     ' @nPickQty    INT OUTPUT '
                  EXEC sp_executeSQL @cSQL, @cSQLParam
                     ,@cLoadKey    = @cLoadKey
                     ,@cStorerKey  = @cStorerKey
                     ,@cSKU        = @cSKU
                     ,@cFromDropID = @cFromDropID
                     ,@cPackData1  = @cPackData1
                     ,@nPickQTY  = @nPickQTY OUTPUT
               END -- loadkey
            END TRY
            BEGIN CATCH
               SET @nErrNo = 232155
               SET @cErrMsg = ERROR_MESSAGE()
               GOTO Quit
            END CATCH

            IF @bDebugFlag = 1
            BEGIN
               SELECT @cSQL AS BatchNoValidationSQL
               SELECT @nPickQty AS PickQty
            END

            IF @nPickQTY = 0
            BEGIN
               SET @nErrNo = 232153
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Wrong batch no
               EXEC rdt.rdtSetFocusField @nMobile, 1  -- batch no
               GOTO Quit
            END

            -- Get PackQty
            SET @nPackQTY = 0

            SELECT @nPackQTY = ISNULL(SUM(PDI.QTY), 0) 
            FROM dbo.PACKDETAILINFO PDI WITH (NOLOCK) 
            LEFT JOIN dbo.PACKDETAIL PD WITH (NOLOCK) 
               ON PD.PICKSLIPNO = PDI.PICKSLIPNO
               AND PD.CARTONNO = PDI.CARTONNO
               AND PD.LabelNo = PDI.LabelNo
               AND PD.LABELLINE = PDI.LABELLINE
               AND PD.SKU = PDI.SKU
            WHERE PDI.PickSlipNo = @cPickSlipNo
               AND PD.DROPID = @cFromDropID
               AND PDI.SKU = @cSKU
               AND PDI.USERDEFINE01 = @cPackData1

            --Get PickQty
            SET @cPickStatus = rdt.RDTGetConfig( @nFunc, 'PickStatus', @cStorerkey)
            IF @cPickStatus = '0'
               SET @cPickStatus = '5'

            SET @nPickQTY = 0

            BEGIN TRY
               IF @cZone IN ('XD', 'LB', 'LP')
               BEGIN
                  SET @cSQL = 
                  ' SELECT @nPickQty = ISNULL( SUM( PD.QTY), 0) ' + 
                  ' FROM dbo.RefKeyLookup RKL WITH (NOLOCK) ' + 
                     ' JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey) ' + 
                  ' WHERE RKL.PickSlipNo = @cPickSlipNo ' + 
                     ' AND PD.Storerkey = @cStorerkey ' +
                     ' AND PD.Status = @cPickStatus ' + 
                     ' AND PD.SKU = @cSKU ' + 
                     ' AND PD.DropID = @cFromDropID ' +
                     ' AND LA.Lottable01 = @cPackData1 '
                  SET @cSQLParam = 
                     ' @cPickSlipNo NVARCHAR( 10), ' + 
                     ' @cStorerKey  NVARCHAR( 15), ' +
                     ' @cPickStatus NVARCHAR( 1), ' +
                     ' @cSKU        NVARCHAR( 20), ' +
                     ' @cFromDropID NVARCHAR( 20), ' +
                     ' @cPackData1  NVARCHAR( 30), ' +
                     ' @nPickQty  INT OUTPUT '
                  EXEC sp_executeSQL @cSQL, @cSQLParam
                     ,@cPickSlipNo = @cPickSlipNo
                     ,@cStorerKey = @cStorerKey
                     ,@cPickStatus = @cPickStatus
                     ,@cSKU = @cSKU
                     ,@cFromDropID = @cFromDropID
                     ,@cPackData1 = @cPackData1
                     ,@nPickQTY  = @nPickQTY OUTPUT
               END -- Zone
               ELSE IF @cOrderKey <> ''
               BEGIN
                  SET @cSQL = 
                     ' SELECT @nPickQty = ISNULL( SUM( PD.QTY), 0) ' + 
                     ' FROM dbo.PickDetail PD WITH (NOLOCK) ' + 
                        ' JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON LA.LOT = PD.LOT ' + 
                     ' WHERE PD.OrderKey = @cOrderKey ' +
                        ' AND PD.Storerkey = @cStorerkey ' +
                        ' AND PD.Status = @cPickStatus ' + 
                        ' AND PD.SKU = @cSKU ' + 
                        ' AND PD.DropID = @cFromDropID ' +
                        ' AND LA.Lottable01 = @cPackData1 '
                  SET @cSQLParam = 
                     ' @cOrderKey   NVARCHAR( 10), ' +
                     ' @cStorerKey  NVARCHAR( 15), ' +
                     ' @cPickStatus NVARCHAR( 1), ' +
                     ' @cSKU        NVARCHAR( 20), ' +
                     ' @cFromDropID NVARCHAR( 20), ' +
                     ' @cPackData1 NVARCHAR( 30), ' +
                     ' @nPickQty    INT OUTPUT '
                  EXEC sp_executeSQL @cSQL, @cSQLParam
                     ,@cOrderKey = @cOrderKey
                     ,@cStorerKey = @cStorerKey
                     ,@cPickStatus = @cPickStatus
                     ,@cSKU = @cSKU
                     ,@cFromDropID = @cFromDropID
                     ,@cPackData1 = @cPackData1
                     ,@nPickQTY  = @nPickQTY OUTPUT
               END -- OrderKey
               ELSE IF @cLoadKey <> ''
               BEGIN
                  SET @cSQL = 
                  ' SELECT @nPickQty = ISNULL( SUM( PD.QTY), 0) ' + 
                  ' FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) ' + 
                     ' JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = LPD.OrderKey) ' + 
                     ' JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON LA.LOT = PD.LOT ' + 
                  ' WHERE LPD.LoadKey = @cLoadKey ' + 
                        ' AND PD.Storerkey = @cStorerkey ' +
                        ' AND PD.Status = @cPickStatus ' + 
                        ' AND PD.SKU = @cSKU ' + 
                        ' AND PD.DropID = @cFromDropID ' +
                        ' AND LA.Lottable01 = @cPackData1 ' 
                  SET @cSQLParam = 
                     ' @cLoadKey    NVARCHAR( 10), ' +
                     ' @cStorerKey  NVARCHAR( 15), ' +
                     ' @cPickStatus NVARCHAR( 1), ' +
                     ' @cSKU        NVARCHAR( 20), ' +
                     ' @cFromDropID NVARCHAR( 20), ' +
                     ' @cPackData1  NVARCHAR( 30), ' + 
                     ' @nPickQty    INT OUTPUT '
                  EXEC sp_executeSQL @cSQL, @cSQLParam
                     ,@cLoadKey    = @cLoadKey
                     ,@cStorerKey  = @cStorerKey
                     ,@cPickStatus = @cPickStatus
                     ,@cSKU        = @cSKU
                     ,@cFromDropID = @cFromDropID
                     ,@cPackData1  = @cPackData1
                     ,@nPickQTY  = @nPickQTY OUTPUT
               END -- loadkey
            END TRY
            BEGIN CATCH
               SET @nErrNo = 232156
               SET @cErrMsg = ERROR_MESSAGE()
               GOTO Quit
            END CATCH

            IF @bDebugFlag = 1
            BEGIN
               SELECT @cSQL AS PickQtySQL
               SELECT @nPickQTY AS PickQTY, @nPackQTY AS PackQTY, @nQTY AS QTY
            END

            -- Check over pack
            IF @nPackQTY + @nQTY > @nPickQTY
            BEGIN
               SET @nErrNo = 232154
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over pack
               GOTO Quit
            END
         END --inputkey = 1
      END --step_10   
   END --838

Quit:
   IF @bDebugFlag = 1
   BEGIN
      SELECT @nErrNo AS ErrNo, @cErrMsg AS ErrMsg
   END

END

GO