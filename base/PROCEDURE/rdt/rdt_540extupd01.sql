SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_540ExtUpd01                                     */
/* Purpose: Insert DropID to indicate close carton                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2017-05-16   James     1.0   WMS907-Created                          */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_540ExtUpd01]
    @nMobile         INT 
   ,@nFunc           INT 
   ,@cLangCode       NVARCHAR( 3) 
   ,@nStep           INT 
   ,@cUserName       NVARCHAR( 18)
   ,@cFacility       NVARCHAR(  5)
   ,@cStorerKey      NVARCHAR( 15)
   ,@cLabelPrinter   NVARCHAR( 10)
   ,@cCloseCartonID  NVARCHAR( 20)
   ,@cLoadKey        NVARCHAR( 10)
   ,@cLabelNo        NVARCHAR( 20)
   ,@nErrNo          INT           OUTPUT 
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount INT,
           @cOrderKey         NVARCHAR( 10),
           @cConsigneeKey     NVARCHAR( 15),
           @cPSNO             NVARCHAR( 10),
           @cPickSlipNo       NVARCHAR( 10),
           @cCartonType       NVARCHAR(10), 
           @cPackByType       NVARCHAR( 10)

   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  
   SAVE TRAN rdt_540ExtUpd01  
   
   IF @nFunc = 540
   BEGIN
      IF @nStep IN ( 6, 8)
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cLabelNo)
         BEGIN
            SELECT @cOrderKey = V_OrderKey,
                   @cConsigneeKey = V_ConsigneeKey,
                   @cCartonType = V_String20
            FROM RDT.RDTMOBREC WITH (NOLOCK) 
            WHERE Mobile = @nMobile

            SET @cPackByType = rdt.RDTGetConfig( @nFunc, 'PackByType', @cStorerKey)    

            IF @cPackByType = 'CONSO'  
               SET @cOrderKey = ''  
  
            SET @cPSNO = ''

            -- Get PickSlipNo (PickHeader)  
            SELECT @cPSNO = PickHeaderKey  
            FROM dbo.PickHeader WITH (NOLOCK)  
            WHERE ExternOrderKey = @cLoadKey  
            AND   ((@cOrderKey = '') OR ( OrderKey = @cOrderKey))

            IF ISNULL( @cPSNO, '') = ''  
               -- Get PickSlipNo (PackHeader)  
               SELECT @cPSNO = PickSlipNo  
               FROM dbo.PackHeader WITH (NOLOCK)  
               WHERE LoadKey = @cLoadKey  
               AND   ((@cOrderKey = '') OR ( OrderKey = @cOrderKey))
               AND   ConsigneeKey = @cConsigneeKey

            IF @cPSNO <> ''  
               SET @cPickSlipNo = @cPSNO  

            INSERT INTO dbo.DropID 
            (DropID, LabelPrinted, ManifestPrinted, DropIDType, [Status], PickSlipNo, LoadKey, UDF01)
            VALUES 
            (@cLabelNo, '0', '0', @cCartonType, '0', @cPickSlipNo, @cLoadKey, @cConsigneeKey)
                     
            IF @@ERROR <> 0
            BEGIN  
               SET @nErrNo = 109501  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CLOSE CTN FAIL  
               GOTO RollBackTran  
            END                
         END
         ELSE
         BEGIN
            UPDATE dbo.DropID WITH (ROWLOCK) SET 
               [Status] = '9'
            WHERE DropID = @cLabelNo 
            AND   [Status] = '0'

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 109502
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'CLOSE CTN FAIL'
               GOTO RollBackTran
            END
         END
      END
   END
END

GOTO Quit  
  
RollBackTran:  
      ROLLBACK TRAN rdt_540ExtUpd01  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount  
      COMMIT TRAN  

GO