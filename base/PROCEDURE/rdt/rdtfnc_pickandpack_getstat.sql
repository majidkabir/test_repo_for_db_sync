SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_PickAndPack_GetStat                          */
/* Copyright      : IDS                                                 */
/* FBR:                                                                 */
/* Purpose: RDT Pick And Pack                                           */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author     Purposes                                */
/* 14-Feb-2012  1.0  Ung        SOS235398 Add SKU QTY, DropID QTY       */
/* 12-Nov-2018  1.1  Gan        Performance tuning                      */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_PickAndPack_GetStat](
   @nMobile           int,
   @cOrderKey         NVARCHAR( 10),
   @cPickSlipNo       NVARCHAR( 10), 
   @cStorerKey        NVARCHAR( 15),
   @cSKU              NVARCHAR( 20), 
   @cDropID           NVARCHAR( 18), 
   @cLoadKey          NVARCHAR( 20), 
   @nTotal_Qty        int  OUTPUT, 
   @nTotal_Picked     int  OUTPUT, 
   @nTotal_SKU        int  OUTPUT, 
   @nTotal_SKU_Picked int  OUTPUT, 
   @nSKU_QTY          int  OUTPUT, 
   @nSKU_Picked       int  OUTPUT, 
   @nDropID_QTY       int  OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

IF ISNULL(@cLoadKey, '') = ''
BEGIN
   SELECT @nTotal_Qty = ISNULL( SUM(Qty), 0)
   FROM dbo.PickDetail PD WITH (NOLOCK)
   WHERE OrderKey = @cOrderKey

   SELECT @nTotal_Picked = ISNULL( SUM(PD.Qty), 0)
   FROM dbo.PackDetail PD WITH (NOLOCK)
   WHERE PD.PickSlipNo = @cPickSlipNo

   SELECT @nTotal_SKU = COUNT( DISTINCT SKU)
   FROM dbo.PickDetail WITH (NOLOCK)
   WHERE OrderKey = @cOrderKey

   SELECT @nTotal_SKU_Picked = COUNT( DISTINCT PD.SKU)
   FROM dbo.PackDetail PD WITH (NOLOCK)
   WHERE PD.PickSlipNo = @cPickSlipNo

   SELECT @nSKU_QTY = ISNULL( SUM(Qty), 0)
   FROM dbo.PickDetail WITH (NOLOCK)
   WHERE OrderKey = @cOrderKey
      AND SKU = @cSKU

   SELECT @nSKU_Picked = ISNULL( SUM(Qty), 0)
   FROM dbo.PackDetail PD WITH (NOLOCK)
   WHERE PD.PickSlipNo = @cPickSlipNo
      AND PD.StorerKey = @cStorerKey
      AND PD.SKU = @cSKU

   SELECT @nDropID_QTY = ISNULL( SUM( PD.QTY), 0)
   FROM dbo.PackDetail PD WITH (NOLOCK)
   WHERE PD.PickSlipNo = @cPickSlipNo
      AND PD.DropID = @cDropID
END
ELSE
BEGIN
   SELECT @nTotal_Qty = ISNULL( SUM(Qty), 0)
   FROM dbo.PickDetail PD WITH (NOLOCK) 
   JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PD.OrderKey = LPD.OrderKey
   WHERE LPD.LoadKey = @cLoadKey
   AND   PD.StorerKey = @cStorerKey

   SELECT @nTotal_Picked = ISNULL( SUM(PD.Qty), 0)
   FROM dbo.PackDetail PD WITH (NOLOCK)
   JOIN dbo.PackHeader PH WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
   WHERE PH.LoadKey = @cLoadKey
   AND   PH.StorerKey = @cStorerKey

   SELECT @nTotal_SKU = COUNT( DISTINCT SKU)
   FROM dbo.PickDetail PD WITH (NOLOCK)
   JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PD.OrderKey = LPD.OrderKey
   WHERE LPD.LoadKey = @cLoadKey
   AND   PD.StorerKey = @cStorerKey

   SELECT @nTotal_SKU_Picked = COUNT( DISTINCT PD.SKU)
   FROM dbo.PackDetail PD WITH (NOLOCK)
   JOIN dbo.PackHeader PH WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
   WHERE PH.LoadKey = @cLoadKey
   AND   PH.StorerKey = @cStorerKey

   SELECT @nSKU_QTY = ISNULL( SUM(Qty), 0)
   FROM dbo.PickDetail PD WITH (NOLOCK)
   JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PD.OrderKey = LPD.OrderKey
   WHERE LPD.LoadKey = @cLoadKey
   AND   PD.StorerKey = @cStorerKey
   AND   SKU = @cSKU

   SELECT @nSKU_Picked = ISNULL( SUM(Qty), 0)
   FROM dbo.PackDetail PD WITH (NOLOCK)
   JOIN dbo.PackHeader PH WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
   WHERE PH.LoadKey = @cLoadKey
   AND   PH.StorerKey = @cStorerKey
   AND   PD.SKU = @cSKU

   SELECT @nDropID_QTY = ISNULL( SUM( PD.QTY), 0)
   FROM dbo.PackDetail PD WITH (NOLOCK)
   JOIN dbo.PackHeader PH WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
   WHERE PH.LoadKey = @cLoadKey
   AND   PD.StorerKey = @cStorerKey
   AND   PD.DropID = @cDropID
END


GO