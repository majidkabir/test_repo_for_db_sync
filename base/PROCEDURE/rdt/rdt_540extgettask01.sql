SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_540ExtGetTask01                                 */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Get next SKU to Pack                                        */
/*                                                                      */
/* Called from: rdtfnc_SortAndPack                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2017-Mar-23 1.0  James       Created                                 */
/* 2018-Mar-29 1.1  James       Add type REFRESH (james01)              */
/************************************************************************/

CREATE PROC [RDT].[rdt_540ExtGetTask01] (
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
   @bSuccess                  INT               OUTPUT,
   @nErrNo                    INT               OUTPUT,
   @cErrMsg                   NVARCHAR( 20)      OUTPUT   -- screen limitation, 20 char max

)
AS
BEGIN
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cNextConsigneeKey NVARCHAR( 15), 
           @cNextOrderKey     NVARCHAR( 10), 
           @cCons_SKU         NVARCHAR( 20), 
           @cOrder_SKU        NVARCHAR( 20), 
           @cLOC_Seq          NVARCHAR( 20), 
           @nCons_QTY         INT,
           @nOrder_QTY        INT, 
           @nQTY              INT, 
           @nConsCNT_Total    INT,      
           @nConsCNT_Bal      INT,
           @nConsQTY_Total    INT,
           @nConsQTY_Bal      INT,
           @nOrderQTY_Total   INT,
           @nOrderQTY_Bal     INT,
           @nSKUQTY_Total     INT,
           @nSKUQTY_Bal       INT,
           @cNewConsigneeKey  NVARCHAR( 15),
           @cCurrentSeq       NVARCHAR( 60)

   IF @cType = 'REFRESH'
      GOTO Quit

   -- Get Consignee, OrderKey
   IF @cType = 'NEXT' 
   BEGIN
      -- @cType = NEXT meaning get next consignee to sort
      -- If this is the 1st time get sorting task then get ANY consignee
      -- based on the sequence setup from codelkup
      -- If previously already has some consignee sorted then get next consignee
      IF ISNULL( @cConsigneeKey, '') <> ''
      BEGIN
         SELECT @cCurrentSeq = UDF01
         FROM dbo.CODELKUP WITH (NOLOCK)
         WHERE Storerkey = @cStorerKey
         AND   LISTNAME = 'SORTLOC'
         AND   Code = @cConsigneeKey

         SELECT TOP 1 @cNewConsigneeKey = CODE
         FROM dbo.CODELKUP WITH (NOLOCK)
         WHERE Storerkey = @cStorerKey
         AND   LISTNAME = 'SORTLOC'
         AND   UDF01 > @cCurrentSeq
         ORDER BY UDF01

        -- Next consignee
         SELECT TOP 1 
            @cNextConsigneeKey = O.ConsigneeKey, 
            @cNextOrderKey = 'CONSO'
         FROM dbo.PickDetail PD WITH (NOLOCK) 
            JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
            JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
            JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
            JOIN dbo.Storer ST WITH (NOLOCK) ON (O.ConsigneeKey = ST.StorerKey AND ST.Type = '2')
            JOIN dbo.CodeLkUp CL WITH (NOLOCK) ON (ST.StorerKey = CL.Code AND O.StorerKey = CL.StorerKey)
         WHERE LPD.LoadKey = @cLoadKey
            AND PD.StorerKey = @cStorerKey
            AND PD.SKU = @cSKU
            AND PD.Status = '0'
            AND PD.QTY > 0
            AND CL.ListName = 'SORTLOC'
            AND O.ConsigneeKey = @cNewConsigneeKey
         ORDER BY CL.UDF01
      END
      ELSE
         -- Next consignee
         SELECT TOP 1 
            @cNextConsigneeKey = O.ConsigneeKey, 
            @cNextOrderKey = 'CONSO'
         FROM dbo.PickDetail PD WITH (NOLOCK) 
            JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
            JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
            JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
            JOIN dbo.Storer ST WITH (NOLOCK) ON (O.ConsigneeKey = ST.StorerKey AND ST.Type = '2')
            JOIN dbo.CodeLkUp CL WITH (NOLOCK) ON (ST.StorerKey = CL.Code AND O.StorerKey = CL.StorerKey)
         WHERE LPD.LoadKey = @cLoadKey
            AND PD.StorerKey = @cStorerKey
            AND PD.SKU = @cSKU
            AND PD.Status = '0'
            AND PD.QTY > 0
            AND CL.ListName = 'SORTLOC'
            AND O.ConsigneeKey > @cConsigneeKey -- get top 1 consignee
         ORDER BY CL.UDF01
   END
   ELSE
      -- Same or next consignee
      SELECT TOP 1 
         @cNextConsigneeKey = O.ConsigneeKey, 
         @cNextOrderKey = 'CONSO'
      FROM dbo.PickDetail PD WITH (NOLOCK) 
         JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
         JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
         JOIN dbo.Storer ST WITH (NOLOCK) ON (O.ConsigneeKey = ST.StorerKey AND ST.Type = '2')
         JOIN dbo.CodeLkUp CL WITH (NOLOCK) ON (ST.StorerKey = CL.Code AND O.StorerKey = CL.StorerKey)
      WHERE LPD.LoadKey = @cLoadKey
         AND PD.StorerKey = @cStorerKey
         AND PD.SKU = @cSKU
         AND PD.Status = '0'
         AND PD.QTY > 0
         AND CL.ListName = 'SORTLOC'
         AND O.ConsigneeKey >= @cConsigneeKey
      ORDER BY CL.UDF01
   
   IF ISNULL(@cNextConsigneeKey, '') = ''
   BEGIN
      SET @nErrNo = 77451
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No more task
      GOTO Quit
   END
   
   SET @cConsigneeKey = @cNextConsigneeKey
   SET @nQTY = 0
   SET @nConsCNT_Bal = 0
   SET @nConsCNT_Total = 0
   SET @nConsQTY_Bal = 0
   SET @nConsQTY_Total = 0
   SET @nSKUQTY_Bal = 0
   SET @nSKUQTY_Total = 0

   -- Get QTY
   SELECT @nQTY = ISNULL( SUM( PD.QTY), 0)
   FROM dbo.PickDetail PD WITH (NOLOCK) 
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
      JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
      JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
   WHERE LPD.LoadKey = @cLoadKey
      AND PD.StorerKey = @cStorerKey
      AND PD.SKU = @cSKU
      AND PD.Status = '0'
      AND O.ConsigneeKey = @cConsigneeKey

   -- Consignee balance count
   SELECT @nConsCNT_Bal = COUNT( DISTINCT O.ConsigneeKey)
   FROM dbo.PickDetail PD WITH (NOLOCK) 
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
      JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
      JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
   WHERE LPD.LoadKey = @cLoadKey
      AND PD.StorerKey = @cStorerKey
      AND PD.SKU = @cSKU
      AND PD.Status = '0'
      AND PD.QTY > 0
   
   -- Consignee total count
   SELECT @nConsCNT_Total = COUNT( DISTINCT O.ConsigneeKey)
   FROM dbo.PickDetail PD WITH (NOLOCK) 
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
      JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
      JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
   WHERE LPD.LoadKey = @cLoadKey
      AND PD.StorerKey = @cStorerKey
      AND PD.SKU = @cSKU
      AND PD.QTY > 0

   -- Consignee QTY balance
   SELECT @nConsQTY_Bal = ISNULL( SUM( PD.QTY), 0)
   FROM dbo.PickDetail PD WITH (NOLOCK) 
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
      JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
      JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
   WHERE LPD.LoadKey = @cLoadKey
      AND PD.Status = '0'
      AND PD.SKU = @cSKU

   -- Consignee QTY total
   /*
   SELECT @nConsQTY_Total = ISNULL( SUM( PD.QTY), 0) 
   FROM dbo.PickDetail PD WITH (NOLOCK) 
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
      JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
      JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
   WHERE LPD.LoadKey = @cLoadKey
      AND O.ConsigneeKey = @cConsigneeKey
   */

   DECLARE @curConsQTY_Total CURSOR
   SET @curConsQTY_Total = CURSOR FOR 
   SELECT PD.SKU, ISNULL( SUM( PD.QTY), 0) 
   FROM dbo.PickDetail PD WITH (NOLOCK) 
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
      JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
      JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
   WHERE LPD.LoadKey = @cLoadKey
      AND O.ConsigneeKey = @cConsigneeKey
      AND O.OrderKey = @cOrderKey
      AND ISNULL(OD.UserDefine04, '') <> 'M' -- (james02)
   GROUP BY PD.SKU
   OPEN @curConsQTY_Total
   FETCH NEXT FROM @curConsQTY_Total INTO @cCons_SKU, @nCons_QTY
   WHILE @@FETCH_STATUS = 0
   BEGIN
      EXEC ispInditexConvertQTY 'ToDispQTY', @cStorerkey, @cCons_SKU, @nCons_QTY OUTPUT
      SET @nConsQTY_Total = @nConsQTY_Total + @nCons_QTY
      FETCH NEXT FROM @curConsQTY_Total INTO @cCons_SKU, @nCons_QTY
   END
   CLOSE @curConsQTY_Total
   DEALLOCATE @curConsQTY_Total

   -- SKU balance
   SELECT @nSKUQTY_Bal = ISNULL( SUM( PD.QTY), 0)
   FROM dbo.PickDetail PD WITH (NOLOCK) 
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
      JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
      JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
   WHERE LPD.LoadKey = @cLoadKey
      AND PD.StorerKey = @cStorerKey
      AND PD.SKU = @cSKU
      AND PD.Status = '0'

   -- SKU total
   SELECT @nSKUQTY_Total = ISNULL( SUM( PD.QTY), 0)
   FROM dbo.PickDetail PD WITH (NOLOCK) 
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
      JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
      JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
   WHERE LPD.LoadKey = @cLoadKey
      AND PD.StorerKey = @cStorerKey
      AND PD.SKU = @cSKU

   SET @cOrderKey = ''
   SET @c_oFieled01 = CAST(@nQTY AS NVARCHAR( 5)) 
   SET @c_oFieled02 = CAST(@nConsCNT_Total AS NVARCHAR( 5))
   SET @c_oFieled03 = CAST(@nConsCNT_Bal AS NVARCHAR( 5))
   SET @c_oFieled04 = CAST(@nConsQTY_Total AS NVARCHAR( 5)) 
   SET @c_oFieled05 = CAST(@nConsQTY_Bal AS NVARCHAR( 5))   
   SET @c_oFieled06 = CAST(@nOrderQTY_Total AS NVARCHAR( 5))
   SET @c_oFieled07 = CAST(@nOrderQTY_Bal AS NVARCHAR( 5))
   SET @c_oFieled08 = CAST(@nSKUQTY_Total AS NVARCHAR( 5))
   SET @c_oFieled09 = CAST(@nSKUQTY_Bal AS NVARCHAR( 5))
  
Quit:
END


GO