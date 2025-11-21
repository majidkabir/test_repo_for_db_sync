SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_Scan_And_Pack_GetNext2SKU                       */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: To show 2 SKUs within the said pickslip no                  */
/*                                                                      */
/* Called from: rdtfnc_Scan_And_Pack                                    */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 25-Mar-2009 1.0  James       Created                                 */
/************************************************************************/

CREATE PROC [RDT].[rdt_Scan_And_Pack_GetNext2SKU] (
   @cStorerKey                NVARCHAR( 15),
   @cPickSlipNo               NVARCHAR( 10),
   @cPickSlipType             NVARCHAR( 10),
   @cSKU                      NVARCHAR( 20),
   @cType                     NVARCHAR( 1),   -- 1 = Next Rec; 0 = Prev Rec
   @cLangCode                 NVARCHAR( 3),
   @nErrNo                    INT          OUTPUT, 
   @cErrMsg     				 NVARCHAR( 20) OUTPUT, -- screen limitation, 20 char max 
   @cSKU1                     NVARCHAR( 20)    OUTPUT,
   @cSKU_Descr1               NVARCHAR( 20)    OUTPUT, -- Use NVARCHAR( 20) coz V_String variable only can hold 20 chars only
   @cQtyAlloc1                NVARCHAR( 5)     OUTPUT, -- Use CHAR instead of INT coz wanna set '' and display on screen ''
   @cQTYScan1                 NVARCHAR( 5)     OUTPUT, -- Use CHAR instead of INT coz wanna set '' and display on screen ''
   @cSKU2                     NVARCHAR( 20)    OUTPUT,
   @cSKU_Descr2               NVARCHAR( 20)    OUTPUT, -- Use NVARCHAR( 20) coz V_String variable only can hold 20 chars only
   @cQtyAlloc2                NVARCHAR( 5)     OUTPUT, -- Use CHAR instead of INT coz wanna set '' and display on screen ''
   @cQTYScan2                 NVARCHAR( 5)     OUTPUT  -- Use CHAR instead of INT coz wanna set '' and display on screen ''
)
AS
BEGIN
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_success INT
   DECLARE @n_err		 INT
   DECLARE @c_errmsg  NVARCHAR( 250)
   DECLARE @cLoadKey  NVARCHAR( 10)

   IF @cPickSlipType = 'CONSO'
      SELECT @cLoadKey = ExternOrderkey 
      FROM dbo.Pickheader WITH (NOLOCK) 
      WHERE PickHeaderKey = @cPickSlipNo
   ELSE
      SELECT @cLoadKey = O.LoadKey 
      FROM dbo.Pickheader PH WITH (NOLOCK) 
      JOIN dbo.Orders O WITH (NOLOCK) ON (PH.OrderKey = O.OrderKey)
      WHERE PickHeaderKey = @cPickSlipNo

   IF @cType = '1'   -- Next Rec
   BEGIN
      -- 1st record to show
      SELECT TOP 1 
         @cSKU1 = PD.SKU,
         @cSKU_Descr1 = SKU.DESCR
      FROM dbo.Orders O WITH (NOLOCK) 
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
      JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
      WHERE O.LoadKey = @cLoadKey
         AND PD.SKU > @cSKU
      GROUP BY PD.SKU, SKU.DESCR
      ORDER BY PD.SKU, SUM(PD.QTY)

      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 66351
         SET @cErrMsg = rdt.rdtgetmessage( 66351, @cLangCode, 'DSP') --'No More Rec'
         GOTO Quit
      END

      SELECT @cQTYAlloc1 = ISNULL(SUM(PD.QTY), 0)
      FROM dbo.Orders O WITH (NOLOCK) 
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
      WHERE O.LoadKey = @cLoadKey
         AND PD.SKU = @cSKU1

      SELECT @cQTYScan1 = ISNULL(SUM(QTY), 0)
      FROM dbo.PackDetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU1
         AND RefNo = @cPickSlipNo

      -- 2nd record o show
      SELECT TOP 1 
         @cSKU2 = PD.SKU,
         @cSKU_Descr2 = SKU.DESCR
      FROM dbo.Orders O WITH (NOLOCK) 
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
      JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
      WHERE O.LoadKey = @cLoadKey
         AND PD.SKU > @cSKU1
      GROUP BY PD.SKU, SKU.DESCR
      ORDER BY PD.SKU, SUM(PD.QTY)

      IF @@ROWCOUNT = 0
      BEGIN
         SET @cSKU2 = 'ZZZZZZZZZZZZZZZZZZZZ'
         SET @cSKU_Descr2 = ''
         SET @cQTYAlloc2 = ''
         SET @cQTYScan2 = ''
         GOTO Quit
      END

      SELECT TOP 1 
         @cQTYAlloc2 = ISNULL(SUM(PD.QTY), 0)
      FROM dbo.Orders O WITH (NOLOCK) 
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
      WHERE O.LoadKey = @cLoadKey
         AND PD.SKU = @cSKU2

      SELECT TOP 1 
         @cQTYScan2 = ISNULL(SUM(QTY), 0)
      FROM dbo.PackDetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU2
         AND RefNo = @cPickSlipNo
   END
   ELSE  -- @cType = '0'   -- Prev Rec
   BEGIN
      -- 1st record to show
      SELECT TOP 1 
         @cSKU2 = PD.SKU,
         @cSKU_Descr2 = SKU.DESCR
      FROM dbo.Orders O WITH (NOLOCK) 
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
      JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
      WHERE O.LoadKey = @cLoadKey
         AND PD.SKU < @cSKU1
      GROUP BY PD.SKU, SKU.DESCR
      ORDER BY PD.SKU DESC, SUM(PD.QTY) DESC

      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 66352
         SET @cErrMsg = rdt.rdtgetmessage( 66352, @cLangCode, 'DSP') --'No More Rec'
         GOTO Quit
      END

      SELECT TOP 1 
         @cQTYAlloc2 = ISNULL(SUM(PD.QTY), 0)
      FROM dbo.Orders O WITH (NOLOCK) 
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
      WHERE O.LoadKey = @cLoadKey
         AND PD.SKU = @cSKU2

      SELECT TOP 1 
         @cQTYScan2 = ISNULL(SUM(QTY), 0)
      FROM dbo.PackDetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU2
         AND RefNo = @cPickSlipNo

      -- 2nd record o show
      SELECT TOP 1 
         @cSKU1 = PD.SKU,
         @cSKU_Descr1 = SKU.DESCR
      FROM dbo.Orders O WITH (NOLOCK) 
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
      JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
      WHERE O.LoadKey = @cLoadKey
         AND PD.SKU < @cSKU2
      GROUP BY PD.SKU, SKU.DESCR
      ORDER BY PD.SKU DESC, SUM(PD.QTY) DESC

      SELECT TOP 1 
         @cQTYAlloc1 = ISNULL(SUM(PD.QTY), 0)
      FROM dbo.Orders O WITH (NOLOCK) 
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
      WHERE O.LoadKey = @cLoadKey
         AND PD.SKU = @cSKU1

      SELECT TOP 1 
         @cQTYScan1 = ISNULL(SUM(QTY), 0)
      FROM dbo.PackDetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU1
         AND RefNo = @cPickSlipNo
   END

Quit:
END

GO