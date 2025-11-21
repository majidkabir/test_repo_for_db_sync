SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_PalletPack_PackInfo                             */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Insert pack info                                            */
/*                                                                      */
/* Called from: rdtfnc_Pallet_Pack                                      */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2021-09-07  1.0  James       WMS17874 .Created                       */
/* 2021-10-18  1.1  James       WMS-18167 Add custom packinfosp(james01)*/
/************************************************************************/

CREATE PROC [RDT].[rdt_PalletPack_PackInfo] (
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

   DECLARE @cSQL        NVARCHAR( MAX)  
   DECLARE @cSQLParam   NVARCHAR( MAX)  
   DECLARE @cPackInfoSP NVARCHAR( 20)  
   
   -- Get storer config  
   SET @cPackInfoSP = rdt.RDTGetConfig( @nFunc, 'PackInfoSP', @cStorerKey)  
   IF @cPackInfoSP = '0'  
      SET @cPackInfoSP = ''  
  
   /***********************************************************************************************  
                                      Custom PackInfo  
   ***********************************************************************************************/  
   -- Check confirm SP blank  
   IF @cPackInfoSP <> ''  
   BEGIN  
      -- PackInfo SP  
      SET @cSQL = 'EXEC rdt.' + RTRIM( @cPackInfoSP) +  
         ' @nMobile, @nFunc, @cLangCode, @cStorerKey, @cFacility, @tPackInfo, ' +  
         ' @nErrNo OUTPUT, @cErrMsg OUTPUT '  
      SET @cSQLParam =  
         ' @nMobile        INT,           ' +  
         ' @nFunc          INT,           ' +  
         ' @cLangCode      NVARCHAR( 3),  ' +  
         ' @cStorerKey     NVARCHAR( 15), ' +  
         ' @cFacility      NVARCHAR( 5),  ' +
         ' @tPackInfo      VariableTable READONLY, ' +  
         ' @nErrNo         INT           OUTPUT, ' +  
         ' @cErrMsg        NVARCHAR(250) OUTPUT  '  
  
      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
         @nMobile, @nFunc, @cLangCode, @cStorerKey, @cFacility, @tPackInfo,  
         @nErrNo OUTPUT, @cErrMsg OUTPUT  
   END  
   ELSE
   BEGIN
      /***********************************************************************************************  
                                         Standard PackInfo  
      ***********************************************************************************************/  
      DECLARE @nTranCount     INT
      DECLARE @cPalletID      NVARCHAR( 20)
      DECLARE @cPackByPickDetailDropID NVARCHAR( 1)
      DECLARE @cPackByPickDetailID     NVARCHAR( 1)

   
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
      SAVE TRAN rdt_PalletPack_PackInfo
      
      DECLARE @curPackInfo CURSOR
      SET @curPackInfo = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
      SELECT CartonNo
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo
      AND   DropID = @cPalletID
      ORDER BY 1
      OPEN @curPackInfo
      FETCH NEXT FROM @curPackInfo INTO @nCartonNo
      WHILE @@FETCH_STATUS = 0
      BEGIN
         SELECT @nCartonQty = SUM( Qty) 
         FROM dbo.PackDetail WITH (NOLOCK) 
         WHERE PickSlipNo = @cPickSlipNo 
         AND   CartonNo = @nCartonNo 
  
         -- PackInfo  
         IF NOT EXISTS (SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo)  
         BEGIN  
            INSERT INTO dbo.PackInfo 
            (PickslipNo, CartonNo, Qty, Weight, Cube, CartonType, 
            RefNo, Length, Width, Height) VALUES 
            (@cPickSlipNo, @nCartonNo, @nCartonQty, CAST( @cWeight AS FLOAT), CAST( @cCube AS FLOAT), @cCartonType, 
            @cRefNo, CAST( @cLength AS FLOAT), CAST( @cWidth AS FLOAT), CAST( @cHeight AS FLOAT))  

            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 137101  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPackInfFail  
               GOTO RollBackTran  
            END  
         END  
         ELSE  
         BEGIN  
            UPDATE dbo.PackInfo SET  
               CartonType = @cCartonType,  
               Weight = CAST( @cWeight AS FLOAT),  
               [Cube] = CAST( @cCube AS FLOAT),  
               RefNo = @cRefNo,  
               Length = CAST( @cLength AS FLOAT),
               Width = CAST( @cLength AS FLOAT),
               Height = CAST( @cLength AS FLOAT)
            WHERE PickSlipNo = @cPickSlipNo  
               AND CartonNo = @nCartonNo  
            
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 137101  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDPackInfFail  
               GOTO RollBackTran  
            END  
         END  
         FETCH NEXT FROM @curPackInfo INTO @nCartonNo
      END

      GOTO Quit

      RollBackTran:
         ROLLBACK TRAN rdt_PalletPack_PackInfo

      Quit:
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN rdt_PalletPack_PackInfo
            

      Fail:
   END
END

GO