SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_1628ExtPackCfm01                                */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Pack confirm if doctype = 'N'                               */  
/*                                                                      */  
/* Called from: rdtfnc_Cluster_Pick                                     */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author      Purposes                                */  
/* 2021-04-08  1.0  James       WMS-16756 - Created                     */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_1628ExtPackCfm01] (  
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
   DECLARE @cDocType       NVARCHAR( 10)
   DECLARE @cTempPickSlipNo   NVARCHAR( 10)
   
   SELECT @cLoadKey = V_LoadKey
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile
   
   SELECT TOP 1 @cDocType = DocType
   FROM dbo.ORDERS WITH (NOLOCK)
   WHERE LoadKey = @cLoadKey
   ORDER BY 1
   
   IF @cDocType = 'E'
      GOTO ExitSub
      
   SET @nTranCount = @@TRANCOUNT  
  
   BEGIN TRAN  
   SAVE TRAN rdt_1628ExtPackCfm01  
   
   IF EXISTS ( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) 
               WHERE PickSlipNo = @cPickSlipNo 
               AND  [Status] = '0')
   BEGIN
         UPDATE dbo.PackHeader WITH (ROWLOCK) SET
            STATUS = '9'
         WHERE PickSlipNo = @cPickSlipNo

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 166501
            SET @cErrMsg = rdt.rdtgetmessage( 69348, @cLangCode, 'DSP') --'ConfPackFail'
            GOTO RollBackTran
         END
   END
 
   GOTO Quit

   RollBackTran:  
         ROLLBACK TRAN rdt_1628ExtPackCfm01  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount  
         COMMIT TRAN       

   ExitSub:                            
END

GO