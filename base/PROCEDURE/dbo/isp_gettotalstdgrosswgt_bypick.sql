SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_GetTotalStdGrossWgt_ByPick                     */
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
/* 12-Nov-2016  Ung           Performance tuning                        */
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length      */
/************************************************************************/
 
CREATE PROCEDURE [dbo].[isp_GetTotalStdGrossWgt_ByPick] 
   @cPickSlipNo  NVARCHAR( 10), 
   @cOrderKey    NVARCHAR( 10),  
   @nTotalWeight FLOAT OUTPUT, 
   @nCurrentTotalWeight FLOAT = NULL
AS
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   SET @nTotalWeight = 0

   IF @cOrderKey <> '' AND @cOrderKey IS NOT NULL
      SELECT @nTotalWeight = ISNULL( SUM( SKU.StdGrossWgt * PD.QTY), 0)
      FROM PickDetail PD WITH (NOLOCK)
         INNER JOIN SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
      WHERE PD.OrderKey = @cOrderKey

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
         SELECT @nTotalWeight = ISNULL( SUM( SKU.StdGrossWgt * PD.QTY), 0)
         FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
            INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON RKL.PickDetailKey = PD.PickDetailKey
            INNER JOIN dbo.SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
         WHERE RKL.PickSlipNo = @cPickSlipNo
      END
      ELSE
      BEGIN
         IF @cOrderKey = ''
            SELECT @nTotalWeight = ISNULL( SUM( SKU.StdGrossWgt * PD.QTY), 0)
            FROM dbo.OrderDetail OD WITH (NOLOCK)
               INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber
               INNER JOIN dbo.SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
            WHERE OD.LoadKey = @cExternOrderKey
         ELSE
            SELECT @nTotalWeight = ISNULL( SUM( SKU.StdGrossWgt * PD.QTY), 0)
            FROM dbo.OrderDetail OD WITH (NOLOCK)
               INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber
               INNER JOIN dbo.SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
            WHERE OD.LoadKey = @cExternOrderKey
               AND OD.OrderKey = @cOrderKey

      END
   END      

GO