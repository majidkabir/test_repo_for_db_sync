SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_PrintQCC_GetStat                                */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Get lottables to display on screen                          */
/*                                                                      */
/* Called from: rdtfnc_PrintQCCLabel                                    */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2014-05-20  1.0  James       SOS310288 Created                       */  
/************************************************************************/

CREATE PROC [RDT].[rdt_PrintQCC_GetStat] (
   @nMobile                   INT,
   @nFunc                     INT, 
   @cLangCode                 NVARCHAR( 3),
   @cStorerKey                NVARCHAR( 15),
   @cUCCNo                    NVARCHAR( 20),
   @cType                     NVARCHAR( 10),
   @cSKU                      NVARCHAR( 20)      OUTPUT,
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

   DECLARE @cLottable01    NVARCHAR( 18), 
           @cTtl_Qty       NVARCHAR( 5), 
           @nTtl_Qty       INT, 
           @n              INT 
           
   -- Return dummy values
   SET @c_oFieled01 = ''
   SET @c_oFieled02 = ''
   SET @c_oFieled03 = ''
   SET @c_oFieled04 = ''
   SET @c_oFieled05 = ''
   SET @c_oFieled06 = ''
   SET @c_oFieled07 = ''
   SET @c_oFieled08 = ''
   SET @c_oFieled09 = ''
   SET @c_oFieled10 = ''
   SET @c_oFieled11 = ''
   SET @c_oFieled12 = ''
   SET @c_oFieled13 = ''
   SET @c_oFieled14 = ''
   SET @c_oFieled15 = ''

   IF @cType = ''
      SET @cSKU = ''
   
   -- Insert those SKU which have only 1 single lottable01   
   DECLARE @tTemp TABLE (SKU NVARCHAR( 20))
   INSERT INTO @tTemp (SKU)
   SELECT PID.SKU
   FROM dbo.PickDetail PID WITH (NOLOCK) 
   JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (PID.LOT = LA.LOT)
   WHERE PID.StorerKey = @cStorerKey
   AND   PID.Status < '9'
--   AND   ISNULL( PID.ALTSKU, '') <> ''
   AND   PID.SKU IN ( SELECT DISTINCT PD.SKU 
                  FROM dbo.PackHeader PH WITH (NOLOCK) 
                  JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo AND PID.SKU = PD.SKU)
                  WHERE PID.OrderKey = PH.OrderKey
                  AND   PD.LabelNo = @cUCCNo)
   GROUP BY PID.SKU
   HAVING COUNT( DISTINCT LA.Lottable01) = 1

   SELECT TOP 1 @cSKU = PID.SKU 
   FROM dbo.PickDetail PID WITH (NOLOCK) 
   WHERE PID.StorerKey = @cStorerKey
   AND   PID.Status < '9'
   -- exclude those SKU which has > 1 lottable01
   AND   NOT EXISTS ( SELECT 1 FROM @tTemp T WHERE PID.SKU = T.SKU)
   AND   PID.SKU > @cSKU
   AND   PID.OrderKey IN ( SELECT DISTINCT PH.OrderKey 
                           FROM dbo.PackHeader PH WITH (NOLOCK) 
                           JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo AND PID.SKU = PD.SKU)
                           WHERE PD.LabelNo = @cUCCNo
                           AND   PD.SKU = PID.SKU)
   ORDER BY 1

   IF @@ROWCOUNT = 0
   BEGIN
      SET @cSKU = ''
      GOTO Quit
   END
   
   SELECT @nTtl_Qty = ISNULL( SUM ( QTY), 0) 
   FROM dbo.PackDetail PD WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey
   AND   LabelNo = @cUCCNo
   AND   SKU = @cSKU
   
   SET @n = 1
   DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
   SELECT DISTINCT LA.Lottable01
   FROM dbo.PickDetail PID WITH (NOLOCK) 
   JOIN dbo.LotAttribute LA WITH (NOLOCK) ON PID.LOT = LA.LOT
   WHERE PID.StorerKey = @cStorerKey
   AND   PID.Status < '9'
   AND   PID.SKU = @cSKU
   AND   PID.CartonType <> 'FCP'
   AND   PID.OrderKey IN ( SELECT DISTINCT PH.OrderKey 
                           FROM dbo.PackHeader PH WITH (NOLOCK) 
                           JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo AND PID.SKU = PD.SKU)
                           WHERE PD.LabelNo = @cUCCNo)
   ORDER BY LA.Lottable01
   OPEN CUR_LOOP
   FETCH NEXT FROM CUR_LOOP INTO @cLottable01 
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      --insert into traceinfo (tracename, timein, col1, col2, col3, col4) values ('qcc', getdate(),@cStorerKey,@cSKU, @cUCCNo, @cLottable01)
      -- Lottable01
      SET @c_oFieled03 = CASE WHEN @n = 1 THEN @cLottable01 ELSE @c_oFieled03 END
      SET @c_oFieled04 = CASE WHEN @n = 2 THEN @cLottable01 ELSE @c_oFieled04 END
      SET @c_oFieled05 = CASE WHEN @n = 3 THEN @cLottable01 ELSE @c_oFieled05 END
      SET @c_oFieled06 = CASE WHEN @n = 4 THEN @cLottable01 ELSE @c_oFieled06 END
      SET @c_oFieled07 = CASE WHEN @n = 5 THEN @cLottable01 ELSE @c_oFieled07 END

      -- Ttl qty for each lottable; Assign blank if no qty
      SET @cTtl_Qty = CASE WHEN @nTtl_Qty = 0 THEN '' ELSE @nTtl_Qty END
      SET @c_oFieled08 = CASE WHEN @n = 1 THEN @cTtl_Qty ELSE @c_oFieled08 END
      SET @c_oFieled09 = CASE WHEN @n = 2 THEN @cTtl_Qty ELSE @c_oFieled09 END
      SET @c_oFieled10 = CASE WHEN @n = 3 THEN @cTtl_Qty ELSE @c_oFieled10 END
      SET @c_oFieled11 = CASE WHEN @n = 4 THEN @cTtl_Qty ELSE @c_oFieled11 END
      SET @c_oFieled12 = CASE WHEN @n = 5 THEN @cTtl_Qty ELSE @c_oFieled12 END
      SET @n = @n + 1
      
      IF @n > 5
         BREAK

      FETCH NEXT FROM CUR_LOOP INTO @cLottable01 
   END
   CLOSE CUR_LOOP
   DEALLOCATE CUR_LOOP

   
Quit:
END

GO