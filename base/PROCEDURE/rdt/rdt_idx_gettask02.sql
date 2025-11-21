SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_IDX_GetTask02                                   */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Dummy sp to by pass get task                                */
/*                                                                      */
/* Called from: rdtfnc_SortAndPack                                      */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2014-01-01  1.0  James       SOS299153 Created                       */  
/* 2014-05-20  1.1  James       SOS307345 Prompt if over pick (james01) */  
/************************************************************************/

CREATE PROC [RDT].[rdt_IDX_GetTask02] (
   @nMobile                   INT,
   @nFunc                     INT, 
   @cLangCode                 NVARCHAR( 3),
   @cPackByType               NVARCHAR( 10),
   @cType                     NVARCHAR( 10),
   @cLoadKey                  NVARCHAR( 10),
   @cStorerKey                NVARCHAR( 15),
   @cSKU                      NVARCHAR( 20),
   @cConsigneeKey             NVARCHAR( 15)      OUTPUT,
   @cOrderKey                 NVARCHAR( 10)      OUTPUT,
	@c_oFieled01               NVARCHAR( 20)      OUTPUT,
	@c_oFieled02               NVARCHAR( 20)      OUTPUT,
   @c_oFieled03               NVARCHAR( 20)      OUTPUT,
   @c_oFieled04               NVARCHAR( 20)      OUTPUT,
   @c_oFieled05               NVARCHAR( 20)      OUTPUT,
   @c_oFieled06               NVARCHAR( 20)      OUTPUT,
   @c_oFieled07               NVARCHAR( 20)      OUTPUT,
   @c_oFieled08               NVARCHAR( 20)      OUTPUT,
   @c_oFieled09               NVARCHAR( 20)      OUTPUT,
   @c_oFieled10               NVARCHAR( 20)      OUTPUT,
	@c_oFieled11               NVARCHAR( 20)      OUTPUT,
	@c_oFieled12               NVARCHAR( 20)      OUTPUT,
   @c_oFieled13               NVARCHAR( 20)      OUTPUT,
   @c_oFieled14               NVARCHAR( 20)      OUTPUT,
   @c_oFieled15               NVARCHAR( 20)      OUTPUT, 
   @bSuccess                  INT                OUTPUT,
   @nErrNo                    INT                OUTPUT,
   @cErrMsg                   NVARCHAR( 20)      OUTPUT   -- screen limitation, 20 char max

)
AS
BEGIN
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cDefaultQTY NVARCHAR( 5),
           @nPickQty       INT, 
           @nPackQty       INT 

   SET @cDefaultQTY = rdt.RDTGetConfig( @nFunc, 'DefaultQTY', @cStorerKey)    

   -- Get pickdetail qty for current load
   SELECT @nPickQty = ISNULL( SUM( PD.Qty), 0)
   FROM dbo.PickDetail PD WITH (NOLOCK) 
   JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
   JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
   JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
   WHERE LPD.LoadKey = @cLoadKey
         AND PD.StorerKey = @cStorerKey
         AND PD.SKU = @cSKU
         --AND PD.Status = '0'
         AND PD.QTY > 0
         AND ISNULL(OD.UserDefine04, '') <> 'M'

   -- Get packdetail qty for current load   
   SELECT @nPackQTY = ISNULL( SUM( PD.QTY), 0)
   FROM dbo.PackDetail PD WITH (NOLOCK) 
   JOIN dbo.PackHeader PH WITH (NOLOCK) ON (PD.PickSlipNo = PH.PickSlipNo)
   JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PH.OrderKey = OD.OrderKey AND PD.SKU = OD.SKU)
   WHERE PH.LoadKey = @cLoadKey
   AND   PH.StorerKey = @cStorerKey
   AND   PD.SKU = @cSKU
   AND   ISNULL( OD.UserDefine04, '') <> 'M'  
   
   
   -- Return dummy values
   SET @c_oFieled01 = @cDefaultQTY
   SET @c_oFieled02 = ''
   SET @c_oFieled03 = ''
   SET @c_oFieled04 = ''
   SET @c_oFieled05 = ''
   SET @c_oFieled06 = ''
   SET @c_oFieled07 = ''
   SET @c_oFieled08 = @nPickQty
   SET @c_oFieled09 = @nPackQty
   SET @c_oFieled10 = ''
   SET @c_oFieled11 = ''
   SET @c_oFieled12 = ''
   SET @c_oFieled13 = ''
   SET @c_oFieled14 = ''
   SET @c_oFieled15 = ''

   IF @nPickQty = @nPackQty
   BEGIN
      SET @nErrNo = 84251
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No more task
      GOTO Quit
   END

   IF @nPickQty < @nPackQty
   BEGIN
      SET @nErrNo = 84252
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over Pack
      GOTO Quit
   END
Quit:
END

GO