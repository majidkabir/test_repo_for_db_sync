SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_PostPickAudit_Lottable_GetStat                        */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 12-06-2018 1.0  Ung        WMS-4238 Created                                */
/* 28-11-2019 1.1  Chermaine  WMS-11218 show total and                        */
/*                            counted quantity per SKU(cc01)                  */
/******************************************************************************/

CREATE PROC [RDT].[rdt_PostPickAudit_Lottable_GetStat] (
   @nMobile     INT, 
   @nFunc       INT, 
   @cLangCode   NVARCHAR( 3), 
   @nStep       INT, 
   @nInputKey   INT, 
   @cFacility   NVARCHAR( 5), 
   @cStorerKey  NVARCHAR( 15), 
   @cRefNo      NVARCHAR( 10), 
   @cPickSlipNo NVARCHAR( 10),
   @cLoadKey    NVARCHAR( 10),
   @cOrderKey   NVARCHAR( 10), 
   @cDropID     NVARCHAR( 20),
   @cSKU        NVARCHAR( 20)='',
   @nCSKU       INT = NULL OUTPUT, 
   @nCQTY       INT = NULL OUTPUT, 
   @nPSKU       INT = NULL OUTPUT, 
   @nPQTY       INT = NULL OUTPUT, 
   @nVariance   INT = NULL OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cPickConfirmStatus NVARCHAR( 1)
   DECLARE @cPH_LoadKey  NVARCHAR( 10)
   DECLARE @cPH_OrderKey NVARCHAR( 10)
   DECLARE @cZone        NVARCHAR( 18)

   -- Get storer config
   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
   IF @cPickConfirmStatus NOT IN ('3', '5')
      SET @cPickConfirmStatus = '5'

   IF @nVariance IS NOT NULL
   BEGIN
      DECLARE @tP TABLE (StorerKey NVARCHAR( 15), SKU NVARCHAR(20), QTY INT)
      DECLARE @tC TABLE (StorerKey NVARCHAR( 15), SKU NVARCHAR(20), QTY INT)
   END
   
   IF @cSKU <> '' AND @cSKU IS NOT NULL
   BEGIN
   	-- RefNo
      IF @cRefNo <> '' AND @cRefNo IS NOT NULL
      BEGIN     
         IF @nPQTY IS NOT NULL
            SELECT @nPQTY = SUM( PD.QTY)
            FROM dbo.LoadPlan AS LP WITH (NOLOCK)
               INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.LoadKey = LP.LoadKey
               INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber
            WHERE LP.UserDefine10 = @cRefNo
               AND PD.Status <> '4'
               AND PD.Status >= @cPickConfirmStatus
               AND PD.SKU = @cSKU

         IF @nCQTY IS NOT NULL
            SELECT 
               @nCQTY = SUM( CQTY)
            FROM rdt.rdtPPA WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
               AND RefKey = @cRefNo
               AND SKU = @cSKU
      END

      -- Pick Slip No
      IF @cPickSlipNo <> '' AND @cPickSlipNo IS NOT NULL
      BEGIN
         -- Get pickheader info
         SELECT TOP 1
            @cPH_LoadKey = ExternOrderkey, 
            @cPH_OrderKey = OrderKey, 
            @cZone = Zone
         FROM dbo.PickHeader WITH (NOLOCK)
         WHERE PickHeaderKey = @cPickSlipNo

         -- Cross dock
         IF @cZone = 'XD' OR @cZone = 'LB' OR @cZone = 'LP'
         BEGIN         
            IF @nPQTY IS NOT NULL
               SELECT @nPQTY = SUM( PD.QTY)
               FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
                  INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON RKL.PickDetailKey = PD.PickDetailKey
               WHERE RKL.PickSlipNo = @cPickSlipNo
                  AND PD.Status <> '4'
                  AND PD.Status >= @cPickConfirmStatus 
                  AND PD.SKU = @cSKU
         END
      
         -- Discrete
         ELSE IF @cOrderKey <> ''
         BEGIN
            IF @nPQTY IS NOT NULL
               SELECT @nPQTY = SUM( PD.QTY)
               FROM dbo.PickDetail PD WITH (NOLOCK)
               WHERE PD.OrderKey = @cPH_OrderKey
                  AND PD.Status <> '4'
                  AND PD.Status >= @cPickConfirmStatus 
                  AND PD.SKU = @cSKU
         END

         -- Conso
         ELSE
         BEGIN         
            IF @nPQTY IS NOT NULL
               SELECT @nPQTY = SUM( PD.QTY)
               FROM dbo.LoadPlanDetail AS LPD WITH (NOLOCK)
                  INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = LPD.OrderKey
                  INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber
               WHERE LPD.LoadKey = @cPH_LoadKey
                  AND PD.Status <> '4'
                  AND PD.Status >= @cPickConfirmStatus 
                  AND PD.SKU = @cSKU
         END

         IF @nCQTY IS NOT NULL
            SELECT 
               @nCQTY = SUM( CQTY)
            FROM rdt.rdtPPA WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
               AND PickSlipNo = @cPickSlipNo
               AND SKU = @cSKU
      END

      -- LoadKey
      IF @cLoadKey <> '' AND @cLoadKey IS NOT NULL
      BEGIN    
         IF @nPQTY IS NOT NULL
            SELECT @nPQTY = SUM( PD.QTY)
            FROM dbo.LoadPlanDetail AS LPD WITH (NOLOCK)
               INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = LPD.OrderKey
               INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber
            WHERE LPD.LoadKey = @cLoadKey
               AND PD.Status <> '4'
               AND PD.Status >= @cPickConfirmStatus 
               AND PD.SKU = @cSKU

         IF @nCQTY IS NOT NULL
            SELECT 
               @nCQTY = SUM( CQTY)
            FROM rdt.rdtPPA WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
               AND LoadKey = @cLoadKey
               AND SKU = @cSKU
      END

      -- OrderKey
      IF @cOrderKey <> '' AND @cOrderKey IS NOT NULL
      BEGIN
         IF @nPQTY IS NOT NULL
            SELECT @nPQTY = SUM( PD.QTY)
            FROM dbo.PickDetail PD WITH (NOLOCK)
            WHERE PD.OrderKey = @cOrderKey
               AND PD.Status <> '4'
               AND PD.Status >= @cPickConfirmStatus 
               AND PD.SKU = @cSKU

         IF @nCQTY IS NOT NULL
            SELECT 
               @nCQTY = SUM( CQTY)
            FROM rdt.rdtPPA WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
               AND OrderKey = @cOrderKey
               AND SKU = @cSKU
      END

      -- DropID
      IF @cDropID <> '' AND @cDropID IS NOT NULL
      BEGIN
         IF rdt.rdtGetConfig( @nFunc, 'PPACartonIDByPackDetailDropID', @cStorerKey) = '1'
         BEGIN         
            IF @nPQTY IS NOT NULL
               SELECT @nPQTY = SUM( PD.QTY)
               FROM dbo.PackDetail PD WITH (NOLOCK) 
                  INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU
               WHERE PD.StorerKey = @cStorerKey
                  AND PD.DropID = @cDropID
                  AND PD.SKU = @cSKU
         END
         ELSE
         IF rdt.rdtGetConfig( @nFunc, 'PPACartonIDByPackDetailLabelNo', @cStorerKey) = '1'
         BEGIN
            IF @nPQTY IS NOT NULL
               SELECT @nPQTY = SUM( PD.QTY)
               FROM dbo.PackDetail PD WITH (NOLOCK) 
                  INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU
               WHERE PD.StorerKey = @cStorerKey
                  AND PD.LabelNo = @cDropID
                  AND PD.SKU = @cSKU
         END
         ELSE
         IF rdt.rdtGetConfig( @nFunc, 'PPACartonIDByPickDetailCaseID', @cStorerKey) = '1'
         BEGIN         
            IF @nPQTY IS NOT NULL
               SELECT @nPQTY = SUM( PD.QTY)
               FROM dbo.PickDetail PD WITH (NOLOCK) 
               WHERE PD.StorerKey = @cStorerKey
                  AND PD.CaseID = @cDropID
                  AND PD.ShipFlag <> 'Y'
                  AND PD.Status <> '4'
                  AND PD.Status >= @cPickConfirmStatus 
                  AND PD.SKU = @cSKU
         END
         ELSE
         BEGIN        
            IF @nPQTY IS NOT NULL
               SELECT @nPQTY = SUM( PD.QTY)
               FROM dbo.PickDetail PD WITH (NOLOCK) 
               WHERE PD.StorerKey = @cStorerKey
                  AND PD.DropID = @cDropID
                  AND PD.ShipFlag <> 'Y'
                  AND PD.Status <> '4'
                  AND PD.Status >= @cPickConfirmStatus 
                  AND PD.SKU = @cSKU
         END

         IF @nCQTY IS NOT NULL
         BEGIN
            SELECT 
               @nCQTY = SUM( CQTY)
            FROM rdt.rdtPPA WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
            AND DropID = @cDropID
            AND SKU = @cSKU
         END
      END

      -- SUM() might return NULL when no record
      SET @nCQTY = IsNULL( @nCQTY, 0)
      SET @nPQTY = IsNULL( @nPQTY, 0)
   END
   ELSE
   BEGIN
      -- RefNo
      IF @cRefNo <> '' AND @cRefNo IS NOT NULL
      BEGIN
         IF @nPSKU IS NOT NULL
            SELECT @nPSKU = COUNT( DISTINCT PD.SKU)
            FROM dbo.LoadPlan AS LP WITH (NOLOCK)
               INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.LoadKey = LP.LoadKey
               INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber
            WHERE LP.UserDefine10 = @cRefNo
               AND PD.Status <> '4'
               AND PD.Status >= @cPickConfirmStatus 
      
         IF @nPQTY IS NOT NULL
            SELECT @nPQTY = SUM( PD.QTY)
            FROM dbo.LoadPlan AS LP WITH (NOLOCK)
               INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.LoadKey = LP.LoadKey
               INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber
            WHERE LP.UserDefine10 = @cRefNo
               AND PD.Status <> '4'
               AND PD.Status >= @cPickConfirmStatus

         IF @nVariance IS NOT NULL
            INSERT INTO @tP (StorerKey, SKU, QTY)
            SELECT PD.StorerKey, PD.SKU, ISNULL( SUM( PD.QTY), 0)
            FROM dbo.LoadPlan AS LP WITH (NOLOCK)
               INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.LoadKey = LP.LoadKey
               INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber
            WHERE LP.UserDefine10 = @cRefNo
               AND PD.Status <> '4'
               AND PD.Status >= @cPickConfirmStatus 
            GROUP BY PD.StorerKey, PD.SKU

         IF @nCSKU IS NOT NULL
            SELECT 
               @nCSKU = COUNT( DISTINCT SKU)
            FROM rdt.rdtPPA WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
               AND RefKey = @cRefNo

         IF @nCQTY IS NOT NULL
            SELECT 
               @nCQTY = SUM( CQTY)
            FROM rdt.rdtPPA WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
               AND RefKey = @cRefNo
         
         IF @nVariance IS NOT NULL
            INSERT INTO @tC (StorerKey, SKU, QTY)
            SELECT StorerKey, SKU, ISNULL( SUM( CQTY), 0)
            FROM rdt.rdtPPA WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
               AND RefKey = @cRefNo
            GROUP BY StorerKey, SKU
      END

      -- Pick Slip No
      IF @cPickSlipNo <> '' AND @cPickSlipNo IS NOT NULL
      BEGIN
         -- Get pickheader info
         SELECT TOP 1
            @cPH_LoadKey = ExternOrderkey, 
            @cPH_OrderKey = OrderKey, 
            @cZone = Zone
         FROM dbo.PickHeader WITH (NOLOCK)
         WHERE PickHeaderKey = @cPickSlipNo

         -- Cross dock
         IF @cZone = 'XD' OR @cZone = 'LB' OR @cZone = 'LP'
         BEGIN
            IF @nPSKU IS NOT NULL
               SELECT @nPSKU = COUNT( DISTINCT PD.SKU)
               FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
                  INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON RKL.PickDetailKey = PD.PickDetailKey
               WHERE RKL.PickSlipNo = @cPickSlipNo
                  AND PD.Status <> '4'
                  AND PD.Status >= @cPickConfirmStatus 
         
            IF @nPQTY IS NOT NULL
               SELECT @nPQTY = SUM( PD.QTY)
               FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
                  INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON RKL.PickDetailKey = PD.PickDetailKey
               WHERE RKL.PickSlipNo = @cPickSlipNo
                  AND PD.Status <> '4'
                  AND PD.Status >= @cPickConfirmStatus 
         
            IF @nVariance IS NOT NULL
               INSERT INTO @tP (StorerKey, SKU, QTY)
               SELECT PD.StorerKey, PD.SKU, ISNULL( SUM( PD.QTY), 0)
               FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
                  INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON RKL.PickDetailKey = PD.PickDetailKey
               WHERE RKL.PickSlipNo = @cPickSlipNo
                  AND PD.Status <> '4'
                  AND PD.Status >= @cPickConfirmStatus 
               GROUP BY PD.StorerKey, PD.SKU
         END
      
         -- Discrete
         ELSE IF @cOrderKey <> ''
         BEGIN
            IF @nPSKU IS NOT NULL
               SELECT @nPSKU = COUNT( DISTINCT PD.SKU)
               FROM dbo.PickDetail PD WITH (NOLOCK)
               WHERE PD.OrderKey = @cPH_OrderKey
                  AND PD.Status <> '4'
                  AND PD.Status >= @cPickConfirmStatus 

            IF @nPQTY IS NOT NULL
               SELECT @nPQTY = SUM( PD.QTY)
               FROM dbo.PickDetail PD WITH (NOLOCK)
               WHERE PD.OrderKey = @cPH_OrderKey
                  AND PD.Status <> '4'
                  AND PD.Status >= @cPickConfirmStatus 

            IF @nVariance IS NOT NULL
               INSERT INTO @tP (StorerKey, SKU, QTY)
               SELECT PD.StorerKey, PD.SKU, ISNULL( SUM( PD.QTY), 0)
               FROM dbo.PickDetail PD WITH (NOLOCK)
               WHERE PD.OrderKey = @cPH_OrderKey
                  AND PD.Status <> '4'
                  AND PD.Status >= @cPickConfirmStatus 
               GROUP BY PD.StorerKey, PD.SKU
         END

         -- Conso
         ELSE
         BEGIN
            IF @nPSKU IS NOT NULL
               SELECT @nPSKU = COUNT( DISTINCT PD.SKU)
               FROM dbo.LoadPlanDetail AS LPD WITH (NOLOCK)
                  INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = LPD.OrderKey
                  INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber
               WHERE LPD.LoadKey = @cPH_LoadKey
                  AND PD.Status <> '4'
                  AND PD.Status >= @cPickConfirmStatus 
         
            IF @nPQTY IS NOT NULL
               SELECT @nPQTY = SUM( PD.QTY)
               FROM dbo.LoadPlanDetail AS LPD WITH (NOLOCK)
                  INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = LPD.OrderKey
                  INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber
               WHERE LPD.LoadKey = @cPH_LoadKey
                  AND PD.Status <> '4'
                  AND PD.Status >= @cPickConfirmStatus 

            IF @nVariance IS NOT NULL
               INSERT INTO @tP (StorerKey, SKU, QTY)
               SELECT PD.StorerKey, PD.SKU, ISNULL( SUM( PD.QTY), 0)
               FROM dbo.LoadPlanDetail AS LPD WITH (NOLOCK)
                  INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = LPD.OrderKey
                  INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber
               WHERE LPD.LoadKey = @cPH_LoadKey
                  AND PD.Status <> '4'
                  AND PD.Status >= @cPickConfirmStatus 
               GROUP BY PD.StorerKey, PD.SKU
         END

         IF @nCSKU IS NOT NULL
            SELECT 
               @nCSKU = COUNT( DISTINCT SKU)
            FROM rdt.rdtPPA WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
               AND PickSlipNo = @cPickSlipNo

         IF @nCQTY IS NOT NULL
            SELECT 
               @nCQTY = SUM( CQTY)
            FROM rdt.rdtPPA WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
               AND PickSlipNo = @cPickSlipNo

         IF @nVariance IS NOT NULL
            INSERT INTO @tC (StorerKey, SKU, QTY)
            SELECT StorerKey, SKU, ISNULL( SUM( CQTY), 0)
            FROM rdt.rdtPPA WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
               AND PickSlipNo = @cPickSlipNo
            GROUP BY StorerKey, SKU
      END

      -- LoadKey
      IF @cLoadKey <> '' AND @cLoadKey IS NOT NULL
      BEGIN
         IF @nPSKU IS NOT NULL
            SELECT @nPSKU = COUNT( DISTINCT PD.SKU)
            FROM dbo.LoadPlanDetail AS LPD WITH (NOLOCK)
               INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = LPD.OrderKey
               INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber
            WHERE LPD.LoadKey = @cLoadKey
               AND PD.Status <> '4'
               AND PD.Status >= @cPickConfirmStatus 
      
         IF @nPQTY IS NOT NULL
            SELECT @nPQTY = SUM( PD.QTY)
            FROM dbo.LoadPlanDetail AS LPD WITH (NOLOCK)
               INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = LPD.OrderKey
               INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber
            WHERE LPD.LoadKey = @cLoadKey
               AND PD.Status <> '4'
               AND PD.Status >= @cPickConfirmStatus 

         IF @nVariance IS NOT NULL
            INSERT INTO @tP (StorerKey, SKU, QTY)
            SELECT PD.StorerKey, PD.SKU, ISNULL( SUM( PD.QTY), 0)
            FROM dbo.LoadPlanDetail AS LPD WITH (NOLOCK)
               INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = LPD.OrderKey
               INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber
            WHERE LPD.LoadKey = @cLoadKey
               AND PD.Status <> '4'
               AND PD.Status >= @cPickConfirmStatus 
            GROUP BY PD.StorerKey, PD.SKU

         IF @nCSKU IS NOT NULL
            SELECT 
               @nCSKU = COUNT( DISTINCT SKU)
            FROM rdt.rdtPPA WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
               AND LoadKey = @cLoadKey

         IF @nCQTY IS NOT NULL
            SELECT 
               @nCQTY = SUM( CQTY)
            FROM rdt.rdtPPA WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
               AND LoadKey = @cLoadKey
         
         IF @nVariance IS NOT NULL
            INSERT INTO @tC (StorerKey, SKU, QTY)
            SELECT StorerKey, SKU, ISNULL( SUM( CQTY), 0)
            FROM rdt.rdtPPA WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
               AND LoadKey = @cLoadKey
            GROUP BY StorerKey, SKU
      END

      -- OrderKey
      IF @cOrderKey <> '' AND @cOrderKey IS NOT NULL
      BEGIN
         IF @nPSKU IS NOT NULL
            SELECT @nPSKU = COUNT( DISTINCT PD.SKU)
            FROM dbo.PickDetail PD WITH (NOLOCK)
            WHERE PD.OrderKey = @cOrderKey
               AND PD.Status <> '4'
               AND PD.Status >= @cPickConfirmStatus 

         IF @nPQTY IS NOT NULL
            SELECT @nPQTY = SUM( PD.QTY)
            FROM dbo.PickDetail PD WITH (NOLOCK)
            WHERE PD.OrderKey = @cOrderKey
               AND PD.Status <> '4'
               AND PD.Status >= @cPickConfirmStatus 

         IF @nVariance IS NOT NULL
            INSERT INTO @tP (StorerKey, SKU, QTY)
            SELECT PD.StorerKey, PD.SKU, ISNULL( SUM( PD.QTY), 0)
            FROM dbo.PickDetail PD WITH (NOLOCK)
            WHERE PD.OrderKey = @cOrderKey
               AND PD.Status <> '4'
               AND PD.Status >= @cPickConfirmStatus 
            GROUP BY PD.StorerKey, PD.SKU

         IF @nCSKU IS NOT NULL
            SELECT 
               @nCSKU = COUNT( DISTINCT SKU)
            FROM rdt.rdtPPA WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
               AND OrderKey = @cOrderKey

         IF @nCQTY IS NOT NULL
            SELECT 
               @nCQTY = SUM( CQTY)
            FROM rdt.rdtPPA WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
               AND OrderKey = @cOrderKey
         
         IF @nVariance IS NOT NULL
            INSERT INTO @tC (StorerKey, SKU, QTY)
            SELECT StorerKey, SKU, ISNULL( SUM( CQTY), 0)
            FROM rdt.rdtPPA WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
               AND OrderKey = @cOrderKey
            GROUP BY StorerKey, SKU
      END

      -- DropID
      IF @cDropID <> '' AND @cDropID IS NOT NULL
      BEGIN
         IF rdt.rdtGetConfig( @nFunc, 'PPACartonIDByPackDetailDropID', @cStorerKey) = '1'
         BEGIN
            IF @nPSKU IS NOT NULL
               SELECT @nPSKU = COUNT( DISTINCT PD.SKU)
               FROM dbo.PackDetail PD WITH (NOLOCK)
                  INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU
               WHERE PD.StorerKey = @cStorerKey
                  AND PD.DropID = @cDropID
         
            IF @nPQTY IS NOT NULL
               SELECT @nPQTY = SUM( PD.QTY)
               FROM dbo.PackDetail PD WITH (NOLOCK) 
                  INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU
               WHERE PD.StorerKey = @cStorerKey
                  AND PD.DropID = @cDropID

            IF @nVariance IS NOT NULL
               INSERT INTO @tP (StorerKey, SKU, QTY)
               SELECT PD.StorerKey, PD.SKU, ISNULL( SUM( PD.QTY), 0)
               FROM dbo.PackDetail PD WITH (NOLOCK) 
                  INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU
               WHERE PD.StorerKey = @cStorerKey
                  AND PD.DropID = @cDropID
               GROUP BY PD.StorerKey, PD.SKU
         END
         ELSE
         IF rdt.rdtGetConfig( @nFunc, 'PPACartonIDByPackDetailLabelNo', @cStorerKey) = '1'
         BEGIN
            IF @nPSKU IS NOT NULL
               SELECT @nPSKU = COUNT( DISTINCT PD.SKU)
               FROM dbo.PackDetail PD WITH (NOLOCK)
                  INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU
               WHERE PD.StorerKey = @cStorerKey
                  AND PD.LabelNo = @cDropID

            IF @nPQTY IS NOT NULL
               SELECT @nPQTY = SUM( PD.QTY)
               FROM dbo.PackDetail PD WITH (NOLOCK) 
                  INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU
               WHERE PD.StorerKey = @cStorerKey
                  AND PD.LabelNo = @cDropID
         
            IF @nVariance IS NOT NULL
               INSERT INTO @tP (StorerKey, SKU, QTY)
               SELECT PD.StorerKey, PD.SKU, ISNULL( SUM( PD.QTY), 0)
               FROM dbo.PackDetail PD WITH (NOLOCK) 
                  INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU
               WHERE PD.StorerKey = @cStorerKey
                  AND PD.LabelNo = @cDropID
               GROUP BY PD.StorerKey, PD.SKU
         END
         ELSE
         IF rdt.rdtGetConfig( @nFunc, 'PPACartonIDByPickDetailCaseID', @cStorerKey) = '1'
         BEGIN
            IF @nPSKU IS NOT NULL
               SELECT @nPSKU = COUNT( DISTINCT PD.SKU)
               FROM dbo.PickDetail PD WITH (NOLOCK)
               WHERE PD.StorerKey = @cStorerKey
                  AND PD.CaseID = @cDropID
                  AND PD.ShipFlag <> 'Y'
                  AND PD.Status <> '4'
                  AND PD.Status >= @cPickConfirmStatus 
         
            IF @nPQTY IS NOT NULL
               SELECT @nPQTY = SUM( PD.QTY)
               FROM dbo.PickDetail PD WITH (NOLOCK) 
               WHERE PD.StorerKey = @cStorerKey
                  AND PD.CaseID = @cDropID
                  AND PD.ShipFlag <> 'Y'
                  AND PD.Status <> '4'
                  AND PD.Status >= @cPickConfirmStatus 

            IF @nVariance IS NOT NULL
               INSERT INTO @tP (StorerKey, SKU, QTY)
               SELECT PD.StorerKey, PD.SKU, ISNULL( SUM( PD.QTY), 0)
               FROM dbo.PickDetail PD WITH (NOLOCK) 
               WHERE PD.StorerKey = @cStorerKey
                  AND PD.CaseID = @cDropID
                  AND PD.ShipFlag <> 'Y'
                  AND PD.Status <> '4'
                  AND PD.Status >= @cPickConfirmStatus 

               GROUP BY PD.StorerKey, PD.SKU
         END
         ELSE
         BEGIN
            IF @nPSKU IS NOT NULL
               SELECT @nPSKU = COUNT( DISTINCT PD.SKU)
               FROM dbo.PickDetail PD WITH (NOLOCK)
               WHERE PD.StorerKey = @cStorerKey
                  AND PD.DropID = @cDropID
                  AND PD.ShipFlag <> 'Y'
                  AND PD.Status <> '4'
                  AND PD.Status >= @cPickConfirmStatus 
         
            IF @nPQTY IS NOT NULL
               SELECT @nPQTY = SUM( PD.QTY)
               FROM dbo.PickDetail PD WITH (NOLOCK) 
               WHERE PD.StorerKey = @cStorerKey
                  AND PD.DropID = @cDropID
                  AND PD.ShipFlag <> 'Y'
                  AND PD.Status <> '4'
                  AND PD.Status >= @cPickConfirmStatus 

            IF @nVariance IS NOT NULL
               INSERT INTO @tP (StorerKey, SKU, QTY)
               SELECT PD.StorerKey, PD.SKU, ISNULL( SUM( PD.QTY), 0)
               FROM dbo.PickDetail PD WITH (NOLOCK) 
               WHERE PD.StorerKey = @cStorerKey
                  AND PD.DropID = @cDropID
                  AND PD.ShipFlag <> 'Y'
                  AND PD.Status <> '4'
                  AND PD.Status >= @cPickConfirmStatus 
               GROUP BY PD.StorerKey, PD.SKU
         END

         IF @nCSKU IS NOT NULL
            SELECT 
               @nCSKU = COUNT( DISTINCT SKU)
            FROM rdt.rdtPPA WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
               AND DropID = @cDropID

         IF @nCQTY IS NOT NULL
         BEGIN
               SELECT 
                  @nCQTY = SUM( CQTY)
               FROM rdt.rdtPPA WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
                  AND DropID = @cDropID
         END

         IF @nVariance IS NOT NULL
            INSERT INTO @tC (StorerKey, SKU, QTY)
            SELECT StorerKey, SKU, ISNULL( SUM( CQTY), 0)
            FROM rdt.rdtPPA WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
               AND DropID = @cDropID
            GROUP BY StorerKey, SKU
      END

      -- SUM() might return NULL when no record
      SET @nCQTY = IsNULL( @nCQTY, 0)
      SET @nPQTY = IsNULL( @nPQTY, 0)

      -- Get variance
      IF @nVariance IS NOT NULL
      BEGIN
         IF EXISTS( SELECT TOP 1 1
            FROM @tP P
               FULL OUTER JOIN @tC C ON (P.SKU = C.SKU)
            WHERE P.SKU IS NULL
               OR C.SKU IS NULL
               OR P.QTY <> C.QTY)
            SET @nVariance = 1
         ELSE
            SET @nVariance = 0
      END
   END
END

GO