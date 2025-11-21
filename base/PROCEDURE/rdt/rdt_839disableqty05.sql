SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store procedure: rdt_839DisableQTY05                                       */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date         Rev  Author     Purposes                                      */
/* 2022-07-08   1.0  yeekung    WMS-20182 Created                             */
/******************************************************************************/

CREATE PROC [RDT].[rdt_839DisableQTY05] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT,
   @cFacility        NVARCHAR( 5),
   @cStorerKey       NVARCHAR( 15),
   @cPickSlipNo      NVARCHAR( 10),
   @cPickZone        NVARCHAR( 10),
   @cLOC             NVARCHAR( 10),
   @cSKU             NVARCHAR( 20),
   @nQTY             INT,
   @cDisableQTYField NVARCHAR( 1)   OUTPUT,
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cOrderKey NVARCHAR( 10)
   DECLARE @cLoadKey  NVARCHAR( 10)
   DECLARE @cZone     NVARCHAR( 18)
   DECLARE @cPickConfirmStatus NVARCHAR( 1)

   SET @cOrderKey = ''
   SET @cLoadKey = ''
   SET @cZone = ''

   -- Get storer config
   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
   IF @cPickConfirmStatus = '0'
      SET @cPickConfirmStatus = '5'

   -- Get PickHeader info
   SELECT TOP 1
      @cOrderKey = OrderKey,
      @cLoadKey = ExternOrderKey,
      @cZone = Zone
   FROM dbo.PickHeader WITH (NOLOCK)
   WHERE PickHeaderKey = @cPickSlipNo

   -- Cross dock PickSlip
   IF @cZone IN ('XD', 'LB', 'LP')
   BEGIN
      IF EXISTS( SELECT 1
         FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
            JOIN dbo.Orders O WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
         WHERE RKL.PickSlipNo = @cPickSlipNo
            AND PD.LOC = @cLOC
            AND PD.QTY > 0
            AND PD.Status <> '4'
            AND PD.Status < @cPickConfirmStatus
            AND O.ordergroup = 'ECOM')
         SET @cDisableQTYField = '1'
      ELSE
         SET @cDisableQTYField = ''
   END

   -- Discrete PickSlip
   ELSE IF @cOrderKey <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey AND ordergroup = 'ECOM')
         SET @cDisableQTYField = '1'
      ELSE
         SET @cDisableQTYField = ''
   END

   -- Conso PickSlip
   ELSE IF @cLoadKey <> ''
   BEGIN
      IF EXISTS( SELECT 1
         FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
            JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)
            JOIN dbo.Orders O WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
         WHERE LPD.LoadKey = @cLoadKey
            AND PD.QTY > 0
            AND PD.Status <> '4'
            AND PD.Status < @cPickConfirmStatus
            AND O.ordergroup = 'ECOM')
         SET @cDisableQTYField = '1'
      ELSE
         SET @cDisableQTYField = ''
   END
END

GO