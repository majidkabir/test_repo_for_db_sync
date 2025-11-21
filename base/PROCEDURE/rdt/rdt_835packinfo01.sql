SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_835PackInfo01                                   */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Insert pack info                                            */
/*                                                                      */
/* Called from: rdt_PalletPack_PackInfo                                 */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2021-10-18  1.0  James       WMS-18167 .Created                      */
/************************************************************************/

CREATE PROC [RDT].[rdt_835PackInfo01] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @cStorerKey    NVARCHAR( 15),
   @cFacility     NVARCHAR( 5), 
   @tPackInfo     VariableTable READONLY, 
   @nErrNo        INT            OUTPUT,
   @cErrMsg       NVARCHAR( 20)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF


   /***********************************************************************************************  
                                       Standard PackInfo  
   ***********************************************************************************************/  
   DECLARE @nTranCount     INT
   DECLARE @cPalletID      NVARCHAR( 20)
   DECLARE @cPackByPickDetailDropID NVARCHAR( 1)
   DECLARE @cPackByPickDetailID     NVARCHAR( 1)

   DECLARE @cSKU           NVARCHAR( 20)
   DECLARE @cPickSlipNo    NVARCHAR( 10)
   DECLARE @cCartonType    NVARCHAR( 10)
   DECLARE @cCube          NVARCHAR( 10)  
   DECLARE @cWeight        NVARCHAR( 10)  
   DECLARE @cRefNo         NVARCHAR( 20)  
   DECLARE @cLength        NVARCHAR( 10) 
   DECLARE @cWidth         NVARCHAR( 10) 
   DECLARE @cHeight        NVARCHAR( 10) 
   DECLARE @nCartonQty     INT
   DECLARE @nCartonNo      INT
   DECLARE @fCartonWeight  FLOAT
   DECLARE @fCartonCube    FLOAT
   DECLARE @fSKUNetWeight  FLOAT
   DECLARE @fTtl_SKUNetWeight FLOAT
   
   SET @nErrNo = 0
   
   -- Variable mapping
   SELECT @cPalletID = Value FROM @tPackInfo WHERE Variable = '@cPltValue'
   SELECT @cPackByPickDetailDropID = Value FROM @tPackInfo WHERE Variable = '@cPackByPickDetailDropID'
   SELECT @cPackByPickDetailID = Value FROM @tPackInfo WHERE Variable = '@cPackByPickDetailID'
   SELECT @cCartonType = Value FROM @tPackInfo WHERE Variable = '@cCartonType'
   SELECT @cCube = Value FROM @tPackInfo WHERE Variable = '@cCube'
   SELECT @cWeight = Value FROM @tPackInfo WHERE Variable = '@cWeight'
   SELECT @cRefNo = Value FROM @tPackInfo WHERE Variable = '@cRefNo'
   SELECT @cLength = Value FROM @tPackInfo WHERE Variable = '@cLength'
   SELECT @cWidth = Value FROM @tPackInfo WHERE Variable = '@cWidth'
   SELECT @cHeight = Value FROM @tPackInfo WHERE Variable = '@cHeight'
   
   SELECT TOP 1 @cPickSlipNo = PH.PickSlipNo
   FROM dbo.PackDetail PD WITH (NOLOCK)
   JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickSlipNo = PH.PickSlipNo)
   WHERE PD.StorerKey = @cStorerKey
   AND   PD.DropID = @cPalletID
   AND   PH.OrderKey IN (
         SELECT DISTINCT OrderKey
         FROM dbo.PickDetail WITH (NOLOCK) 
         WHERE ( ( @cPackByPickDetailDropID = '1' AND DropID = @cPalletID) OR 
                  ( @cPackByPickDetailID = '1' AND ID = @cPalletID))
         AND   PD.StorerKey  = @cStorerKey)
   ORDER BY 1

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_835PackInfo01

   -- 1st update carton related info (carton type, cube)
   DECLARE @curPackInfo CURSOR
   SET @curPackInfo = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
   SELECT CartonNo
   FROM dbo.PackDetail WITH (NOLOCK)
   WHERE PickSlipNo = @cPickSlipNo
   AND   DropID = @cPalletID
   GROUP BY CartonNo, SKU
   ORDER BY 1
   OPEN @curPackInfo
   FETCH NEXT FROM @curPackInfo INTO @nCartonNo
   WHILE @@FETCH_STATUS = 0
   BEGIN
      SELECT 
         @fCartonWeight = CZ.CartonWeight, 
         @fCartonCube = CZ.[Cube]
      FROM dbo.CARTONIZATION CZ WITH (NOLOCK)
      JOIN dbo.STORER ST WITH (NOLOCK) ON ( CZ.CartonizationGroup = ST.CartonGroup)
      WHERE CZ.CartonType = @cCartonType
      AND   ST.StorerKey = @cStorerKey
      
      UPDATE dbo.PackInfo SET  
         CartonType = @cCartonType,  
         Weight = @fCartonWeight,  
         [Cube] = @fCartonCube,  
         RefNo = @cRefNo,  
         Length = CAST( @cLength AS FLOAT),
         Width = CAST( @cLength AS FLOAT),
         Height = CAST( @cLength AS FLOAT)
      WHERE PickSlipNo = @cPickSlipNo  
         AND CartonNo = @nCartonNo  
            
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 177351  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDPackInfFail  
         GOTO RollBackTran  
      END  
  
      FETCH NEXT FROM @curPackInfo INTO @nCartonNo
   END
   CLOSE @curPackInfo
   DEALLOCATE @curPackInfo

   -- 2nd update sku related info ( qty)
   SET @curPackInfo = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
   SELECT CartonNo, SKU, SUM( Qty)
   FROM dbo.PackDetail WITH (NOLOCK)
   WHERE PickSlipNo = @cPickSlipNo
   AND   DropID = @cPalletID
   GROUP BY CartonNo, SKU
   ORDER BY 1
   OPEN @curPackInfo
   FETCH NEXT FROM @curPackInfo INTO @nCartonNo, @cSKU, @nCartonQty
   WHILE @@FETCH_STATUS = 0
   BEGIN
      SELECT @fSKUNetWeight = STDNETWGT
      FROM dbo.SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   Sku = @cSKU
      
      UPDATE dbo.PackInfo SET  
         Weight = [Weight] + ( @fSKUNetWeight * @nCartonQty)   
      WHERE PickSlipNo = @cPickSlipNo  
         AND CartonNo = @nCartonNo  
            
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 177352  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDPackInfFail  
         GOTO RollBackTran  
      END  
  
      FETCH NEXT FROM @curPackInfo INTO @nCartonNo, @cSKU, @nCartonQty
   END
   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN rdt_835PackInfo01

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN rdt_835PackInfo01
            

   Fail:
END

GO