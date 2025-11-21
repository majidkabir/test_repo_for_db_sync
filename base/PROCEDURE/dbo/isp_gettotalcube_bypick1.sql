SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_GetTotalCube_ByPick1                           */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 25-May-2011  Ung           SOS216105 Configurable SP to calc         */
/*                            carton, cube and weight                   */
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length      */
/************************************************************************/
 
CREATE PROCEDURE [dbo].[isp_GetTotalCube_ByPick1] 
   @cPickSlipNo NVARCHAR( 10), 
   @cOrderKey   NVARCHAR( 10),  
   @nTotalCube  FLOAT OUTPUT, 
   @nCurrentTotalCube FLOAT = NULL, 
   @nCtnCnt1 INT = NULL, 
   @nCtnCnt2 INT = NULL, 
   @nCtnCnt3 INT = NULL, 
   @nCtnCnt4 INT = NULL, 
   @nCtnCnt5 INT = NULL
AS
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nCurrentTotalCube IS NULL
      SET @nTotalCube = 0  -- calc
   ELSE
   BEGIN
      SET @nTotalCube = @nCurrentTotalCube  -- avoid recalc
      RETURN 
   END
      
   IF @cOrderKey <> '' AND @cOrderKey IS NOT NULL
   BEGIN
      SELECT @nTotalCube = ISNULL( SUM( SKU.Cube * FLOOR( PD.QTY / Pack.CaseCnt)), 0)
      FROM PickDetail PD WITH (NOLOCK)
         INNER JOIN SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
         INNER JOIN Pack WITH (NOLOCK) ON (Pack.PackKey = SKU.PackKey)
      WHERE PD.OrderKey = @cOrderKey
         AND FLOOR( PD.QTY / CAST( Pack.CaseCnt AS INT)) > 0

      SELECT @nTotalCube = @nTotalCube + ISNULL( SUM( SKU.StdCube * (PD.QTY % CAST( Pack.CaseCnt AS INT))), 0)
      FROM PickDetail PD WITH (NOLOCK)
         INNER JOIN SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
         INNER JOIN Pack WITH (NOLOCK) ON (Pack.PackKey = SKU.PackKey)
      WHERE PD.OrderKey = @cOrderKey
         AND (PD.QTY % CAST( Pack.CaseCnt AS INT)) > 0
   END

   IF @cPickSlipNo <> '' AND @cPickSlipNo IS NOT NULL
   BEGIN
      -- Get pickheader info
      DECLARE @cExternOrderKey NVARCHAR( 50)  --tlting_ext
      DECLARE @cZone           NVARCHAR( 18)
      SELECT TOP 1
         @cExternOrderKey = ExternOrderkey, 
         @cOrderKey = OrderKey, 
         @cZone = Zone
      FROM dbo.PickHeader WITH (NOLOCK)
      WHERE PickHeaderKey = @cPickSlipNo
   
      IF @cZone = 'XD' OR @cZone = 'LB' OR @cZone = 'LP'
      BEGIN
         SELECT @nTotalCube = ISNULL( SUM( SKU.Cube * FLOOR( PD.QTY / Pack.CaseCnt)), 0)
         FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
            INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON RKL.PickDetailKey = PD.PickDetailKey
            INNER JOIN dbo.SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
            INNER JOIN dbo.Pack WITH (NOLOCK) ON SKU.PackKey = Pack.PackKey
         WHERE RKL.PickSlipNo = @cPickSlipNo
            AND FLOOR( PD.QTY / CAST( Pack.CaseCnt AS INT)) > 0
   
         SELECT @nTotalCube = @nTotalCube + ISNULL( SUM( SKU.StdCube * (PD.QTY % CAST( Pack.CaseCnt AS INT))), 0)
         FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
            INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON RKL.PickDetailKey = PD.PickDetailKey
            INNER JOIN dbo.SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
            INNER JOIN dbo.Pack WITH (NOLOCK) ON SKU.PackKey = Pack.PackKey
         WHERE RKL.PickSlipNo = @cPickSlipNo
            AND (PD.QTY % CAST( Pack.CaseCnt AS INT)) > 0
      END
      ELSE
      BEGIN
         SELECT @nTotalCube = ISNULL( SUM( SKU.Cube * FLOOR( PD.QTY / Pack.CaseCnt)), 0)
         FROM dbo.OrderDetail OD WITH (NOLOCK)
            INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber
            INNER JOIN dbo.SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
            INNER JOIN dbo.Pack WITH (NOLOCK) ON SKU.PackKey = Pack.PackKey
         WHERE OD.LoadKey = @cExternOrderKey
            AND OD.OrderKey = CASE WHEN @cOrderKey = '' THEN OD.OrderKey ELSE @cOrderKey END
            AND FLOOR( PD.QTY / CAST( Pack.CaseCnt AS INT)) > 0
            
         SELECT @nTotalCube = @nTotalCube + ISNULL( SUM( SKU.StdCube * (PD.QTY % CAST( Pack.CaseCnt AS INT))), 0)
         FROM dbo.OrderDetail OD WITH (NOLOCK)
            INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber
            INNER JOIN dbo.SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
            INNER JOIN dbo.Pack WITH (NOLOCK) ON SKU.PackKey = Pack.PackKey
         WHERE OD.LoadKey = @cExternOrderKey
            AND OD.OrderKey = CASE WHEN @cOrderKey = '' THEN OD.OrderKey ELSE @cOrderKey END
            AND (PD.QTY % CAST( Pack.CaseCnt AS INT)) > 0
      END
   END

GO