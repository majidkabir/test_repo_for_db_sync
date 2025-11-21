SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: isp_GetTotalCube_ByPackInfo02                       */
/* Copyright: LFLogistics                                               */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 2020-12-07  1.0  James    WMS-15810. Created                         */
/************************************************************************/
 
CREATE PROCEDURE [dbo].[isp_GetTotalCube_ByPackInfo02] 
   @cPickSlipNo NVARCHAR( 10), 
   @cOrderKey   NVARCHAR( 10),  
   @nTotalCube  FLOAT OUTPUT, 
   @nCurrentTotalCube FLOAT = NULL, 
   @nCtnCnt1 INT = NULL, 
   @nCtnCnt2 INT = NULL, 
   @nCtnCnt3 INT = NULL, 
   @nCtnCnt4 INT = NULL, 
   @nCtnCnt5 INT = NULL,
   @nCartonNo     INT = NULL,
   @cCartonType   NVARCHAR( 10) = NULL
AS
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cStorerKey     NVARCHAR( 15)
   DECLARE @cCaseID        NVARCHAR( 20)
   DECLARE @nCartonTypeExists INT = 1
   
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

      SELECT TOP 1 @cStorerKey = StorerKey,
                   @cCaseID = LabelNo
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo
      AND   CartonNo = @nCartonNo
      ORDER BY 1

      IF @cCartonType = 'CTN01'
      BEGIN
         SELECT @nTotalCube = [Cube]
         FROM dbo.CARTONIZATION CZ WITH (NOLOCK) 
         JOIN dbo.STORER ST WITH (NOLOCK) ON ( CZ.CartonizationGroup = ST.CartonGroup)
         WHERE CZ.CartonType = @cCartonType
         AND   ST.StorerKey = @cStorerKey
      END
      
      IF @cCartonType = 'CTN02'
      BEGIN
         IF @cZone = 'XD' OR @cZone = 'LB' OR @cZone = 'LP'
         BEGIN
            SELECT @nTotalCube = ISNULL( SUM( SKU.StdCube * PD.QTY), 0)
            FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON RKL.PickDetailKey = PD.PickDetailKey
            JOIN dbo.SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
            WHERE RKL.PickSlipNo = @cPickSlipNo
            AND   PD.CaseID = @cCaseID
         END
         ELSE
         BEGIN
            SELECT @nTotalCube = ISNULL( SUM( SKU.StdCube * PD.QTY), 0)
            FROM dbo.OrderDetail OD WITH (NOLOCK)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber
            JOIN dbo.SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
            WHERE OD.LoadKey = @cExternOrderKey
            AND   ( ( ISNULL( @cOrderKey, '') = '') OR (OD.OrderKey = @cOrderKey))
            AND   PD.CaseID = @cCaseID
         END
      END
   END      

GO