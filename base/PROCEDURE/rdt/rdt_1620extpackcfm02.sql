SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_1620ExtPackCfm02                                */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Pack confirm by orders                                      */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author      Purposes                                */  
/* 2020-01-06  1.0  James       WMS-17162 - Created                     */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_1620ExtPackCfm02] (  
   @nMobile        INT,           
   @nFunc          INT,           
   @cLangCode      NVARCHAR( 3),  
   @nStep          INT,           
   @nInputKey      INT,           
   @cFacility      NVARCHAR( 5),  
   @cStorerKey     NVARCHAR( 15), 
   @cPickSlipNo    NVARCHAR( 10), 
   @tAutoPackCfm   VariableTable READONLY, 
   @nErrNo         INT           OUTPUT, 
   @cErrMsg        NVARCHAR( 20) OUTPUT  

)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @nTranCount     INT
   DECLARE @cLoadKey       NVARCHAR( 10)
   DECLARE @cOrderKey      NVARCHAR( 10)
   DECLARE @cPackConfirm   NVARCHAR(1)  
   DECLARE @nPickQTY       INT
   DECLARE @nPackQTY       INT
   
   SELECT @cLoadKey = Value FROM @tAutoPackCfm WHERE Variable = '@cLoadKey'  
   SELECT @cOrderKey = Value FROM @tAutoPackCfm WHERE Variable = '@cOrderKey'
   
   IF @cLoadKey = '' AND @cOrderKey <> ''
      SELECT @cLoadKey = LoadKey FROM dbo.ORDERS WITH (NOLOCK) WHERE OrderKey = @cOrderKey
      
   SET @nTranCount = @@TRANCOUNT  
  
   BEGIN TRAN  
   SAVE TRAN rdt_1620ExtPackCfm02  
   
   SET @cPackConfirm = ''

   DECLARE @curPackCfm  CURSOR
   SET @curPackCfm = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
   SELECT DISTINCT PD.OrderKey 
   FROM dbo.PickDetail PD WITH (NOLOCK)
   JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON ( PD.OrderKey = LPD.OrderKey)
   WHERE LPD.LoadKey = @cLoadKey
   AND   PD.[Status] < '9'
   ORDER BY 1
   OPEN @curPackCfm
   FETCH NEXT FROM @curPackCfm INTO @cOrderKey
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Check outstanding PickDetail  
      IF EXISTS( SELECT TOP 1 1   
                 FROM PickDetail WITH (NOLOCK)   
                 WHERE OrderKey = @cOrderKey  
                 AND  [Status] < '5'  
                 AND  ([Status] = '4' OR [Status] <> '0')
                 AND   QTY > 0)
         
         SET @cPackConfirm = 'N'  
      ELSE  
         SET @cPackConfirm = 'Y'  
  
      -- Check fully packed  
      IF @cPackConfirm = 'Y'  
      BEGIN  
         -- Calc pick QTY  
         SET @nPickQTY = 0  
         SELECT @nPickQTY = SUM( QTY)   
         FROM dbo.PickDetail WITH (NOLOCK)   
         WHERE OrderKey = @cOrderKey  

         -- Calc pack QTY  
         SET @nPackQTY = 0  
         SELECT @nPackQTY = ISNULL( SUM( QTY), 0) 
         FROM dbo.PackDetail PD WITH (NOLOCK) 
         JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickSlipNo = PH.PickSlipNo)
         WHERE PH.OrderKey = @cOrderKey
         AND   PH.[Status] = '0'

         IF @nPickQTY <> @nPackQTY  
            SET @cPackConfirm = 'N'  
      END
      
      IF @cPackConfirm = 'Y'
      BEGIN
         UPDATE dbo.PackHeader SET
            STATUS = '9'
         WHERE PickSlipNo = @cPickSlipNo

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 168801
            SET @cErrMsg = rdt.rdtgetmessage( 69348, @cLangCode, 'DSP') --'ConfPackFail'
            GOTO RollBackTran
         END
      END
      
      FETCH NEXT FROM @curPackCfm INTO @cOrderKey
   END
   
   GOTO Quit

   RollBackTran:  
         ROLLBACK TRAN rdt_1620ExtPackCfm02  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount  
         COMMIT TRAN       
                              
END

GO