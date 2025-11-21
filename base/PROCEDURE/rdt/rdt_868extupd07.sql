SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_868ExtUpd07                                     */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2021-06-15 1.0  Chermaine  WMS-17235 Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_868ExtUpd07] (
   @nMobile     INT,
   @nFunc       INT,
   @cLangCode   NVARCHAR( 3),
   @nStep       INT,
   @nInputKey   INT,
   @cStorerKey  NVARCHAR( 15),
   @cFacility   NVARCHAR( 5),
   @cOrderKey   NVARCHAR( 10),
   @cLoadKey    NVARCHAR( 10),
   @cDropID     NVARCHAR( 20),
   @cSKU        NVARCHAR( 20),
   @cADCode     NVARCHAR( 18),
   @nErrNo      INT           OUTPUT,
   @cErrMsg     NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bSuccess    INT
   DECLARE @cPickSlipNo NVARCHAR(10)  
   DECLARE @cUserName   NVARCHAR(18)
   DECLARE @cStatus     NVARCHAR(10)
   DECLARE @nSumPackQTY INT
   DECLARE @nSumPickQTY INT

   IF @nFunc = 868 -- Pick and pack
   BEGIN
      IF @nStep = 6 -- pick confirm
      BEGIN
         IF @nInputKey IN (1, 0) -- ENTER/ESC 
         BEGIN
            SELECT @cUserName = UserName, @cPickSlipNo = V_PickSlipNo  FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE Mobile = @nMobile 
            SELECT @cStatus = STATUS FROM Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey      
               
            IF (ISNULL(@cStatus,'')<>'' AND @cStatus <3 )    
            BEGIN    
               UPDATE Orders  WITH (ROWLOCK)    
               SET      
                  Status = '3',        
                  EditDate = GETDATE(),       
                  EditWho = SUSER_SNAME()      
               WHERE OrderKey = @cOrderKey     
                
               SET @nErrNo = @@ERROR       
               IF @nErrNo <> 0      
               BEGIN      
                  SET @nErrNo = 169401      
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD Order Fail      
                  GOTO QUIT      
               END      
            END 
            
            SELECT @nSumPackQTY = ISNULL(SUM(QTY)  , 0)    
            FROM dbo.PackDetail WITH (NOLOCK)    
            WHERE PickSlipNo = @cPickSlipNo    
               AND StorerKey = @cStorerKey    
    
            SELECT @nSumPickQTY = ISNULL(SUM(QTY), 0)    
            FROM dbo.PickDetail WITH (NOLOCK)    
            WHERE Orderkey = @cOrderKey    
            AND   StorerKey = @cStorerKey    
                  
            IF (@nSumPackQTY = @nSumPickQTY)
            BEGIN      
               UPDATE dbo.PackHeader WITH (ROWLOCK) SET    
                  STATUS = '9'    
               WHERE PickSlipNo = @cPickSlipNo    
    
               IF EXISTS (SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK)    
                  WHERE PickSlipNo = @cPickSlipNo AND ScanOutDate IS NULL)    
               BEGIN    
                  UPDATE dbo.PickingInfo WITH (ROWLOCK)    
                     SET SCANOUTDATE = GETDATE(),    
                           EditWho = @cUserName    
                  WHERE PickSlipNo = @cPickSlipNo    
               END    
    
               IF @@ERROR <> 0    
               BEGIN      
                  SET @nErrNo = 169402    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ConfPackFail'    
                  GOTO Quit    
               END    
            END  
         END
      END
   END
Quit:
Fail:

GO