SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_840ExtValid11                                   */  
/* Purpose: If Orderkey retrieved already exist in packheader.orderkey  */  
/*          and user <> packheader.addwho then prompt error             */  
/*                                                                      */  
/* Called By: RDT Pack By Track No                                      */   
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2021-03-04 1.0  James      WMS-16464. Created                        */  
/* 2021-04-01 1.1  YeeKung    WMS-16717 Add serialno and serialqty      */  
/*                            Params (yeekung01)                        */  
/* 2023-10-20 1.2  James      WMS-23943 Check TrackNo exists (james01)  */
/************************************************************************/  
  
CREATE   PROC [RDT].[rdt_840ExtValid11] (  
   @nMobile                   INT,  
   @nFunc                     INT,  
   @cLangCode                 NVARCHAR( 3),  
   @nStep                     INT,  
   @nInputKey                 INT,   
   @cStorerkey                NVARCHAR( 15),  
   @cOrderKey                 NVARCHAR( 10),  
   @cPickSlipNo               NVARCHAR( 10),  
   @cTrackNo                  NVARCHAR( 20),  
   @cSKU                      NVARCHAR( 20),  
   @nCartonNo                 INT,  
   @cCtnType                  NVARCHAR( 10),  
   @cCtnWeight                NVARCHAR( 10),  
   @cSerialNo                 NVARCHAR( 30),   
   @nSerialQTY                INT,     
   @nErrNo                    INT           OUTPUT,  
   @cErrMsg                   NVARCHAR( 20) OUTPUT   
)  
AS  
  
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
  
   DECLARE @cPackUserName        NVARCHAR( 18)  
   DECLARE @cUserName            NVARCHAR( 18)  
   DECLARE @cTrackingNo          NVARCHAR( 40)
   DECLARE @cSalesman            NVARCHAR( 30)
   
   SET @nErrNo = 0  
  
   IF @nStep = 1  
   BEGIN  
      IF @nInputKey = 1  
      BEGIN  
         SET @cPickSlipNo = ''  
         SET @cPackUserName = ''  
         SET @cUserName = ''  
           
         SELECT @cPickSlipNo = PickSlipNo,   
                @cPackUserName = AddWho
         FROM dbo.PackHeader WITH (NOLOCK)  
         WHERE OrderKey = @cOrderKey  
           
         -- Check if something already packed  
         IF EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)  
                     WHERE PickSlipNo = @cPickSlipNo  
                     AND   Qty > 0)  
         BEGIN  
            SELECT @cUserName = UserName  
            FROM RDT.RDTMOBREC WITH (NOLOCK)  
            WHERE Mobile = @nMobile  
  
            IF @cPackUserName <> @cUserName  
            BEGIN  
               SET @nErrNo = 164151  
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode,'DSP') --Orders In Used  
               GOTO Quit  
            END              
         END  
         
         SELECT @cTrackingNo = TrackingNo, 
                @cSalesman = Salesman
         FROM dbo.ORDERS WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey
         
         IF ISNULL( @cTrackingNo, '') = ''
         BEGIN
         	IF EXISTS( SELECT 1 
         	           FROM dbo.CODELKUP WITH (NOLOCK)
         	           WHERE LISTNAME = 'COURIERLBL'
         	           AND   Code = @cSalesman
         	           AND   Storerkey = @cStorerkey
         	           AND   UDF05 ='Y')
            BEGIN  
               SET @nErrNo = 164152  
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode,'DSP') --No Track No
               GOTO Quit  
            END      
         END
       END     
   END  
     
   Quit:  

GO