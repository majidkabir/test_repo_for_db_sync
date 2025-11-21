SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: rdt_844ExtUpd02                                     */    
/* Purpose: Check if user login with printer                            */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author    Purposes                                   */    
/* 2018-12-18 1.0  ChewKP    WMS-7281 Created                           */    
/* 2019-12-06 1.1  James     INC0960994 Exclude shipped pallet (james01)*/  
/* 2019-03-29 1.2  James     WMS-8002 Add TaskDetailKey param (james02) */	
/* 2021-07-06 1.3  YeeKung   WMS-17278 Add Reasonkey (yeekung01)        */																		 
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_844ExtUpd02] (    
   @nMobile      INT,  
   @nFunc        INT,  
   @cLangCode    NVARCHAR( 3),   
   @nStep        INT,            
   @nInputKey    INT,            
   @cStorerKey   NVARCHAR( 15),  
   @cRefNo       NVARCHAR( 10),  
   @cPickSlipNo  NVARCHAR( 10),  
   @cLoadKey     NVARCHAR( 10),  
   @cOrderKey    NVARCHAR( 10),  
   @cDropID      NVARCHAR( 20),  
   @cSKU         NVARCHAR( 20),  
   @nQTY         INT,            
   @cOption      NVARCHAR( 1),   
   @nErrNo       INT           OUTPUT,  
   @cErrMsg      NVARCHAR( 20) OUTPUT,  
   @cID          NVARCHAR( 18) = '',
   @cTaskDetailKey   NVARCHAR( 10) = '',
   @cReasonCode  NVARCHAR(20) OUTPUT 		 
)    
AS    
    
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @cIDOrderKey NVARCHAR(10)  
          ,@cPQty       NVARCHAR(5)  
          ,@cMQty       NVARCHAR(5)  
          ,@cProductModel NVARCHAR(30)   
          ,@nOrderCount INT  
  
   
   IF @nFunc = 844 -- Post pick audit (Pallet ID)  
   BEGIN  
      IF @nStep = 3 -- SKU, QTY  
      BEGIN  
         IF @nInputKey = 1 -- ENTER  
         BEGIN    
             -- Get session info  
            SELECT   
                   @cPQTY    = I_Field09,  
                   @cMQTY    = I_Field10  
            FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile  
  
     
            SELECT @cProductModel = ProductModel   
            FROM dbo.SKU WITH (NOLOCK)   
            WHERE StorerKey = @cStorerKey  
            AND SKU = @cSKU   
  
            
            IF @cProductModel = 'COPACK'  
            BEGIN  
               

               IF ISNULL(@cPQTY,'')  <> ''   
               BEGIN  
                  SET @nErrNo = 133304  -- CopackItemKeyInBT  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CopackItemKeyInBT
                  GOTO Quit  
               END  
            END  
              
                 
            -- Check pallet at stage  
            IF EXISTS( SELECT TOP 1 1   
               FROM rdt.rdtPPA WITH (NOLOCK)  
               WHERE SKU = @cSKU  
                  AND StorerKey = @cStorerKey  
                  AND ID = @cID  
                  AND PQTY <> CQTY)  
            BEGIN  
               SET @nErrNo = 133301  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QTY not match  
               GOTO Quit  
            END        
              
            SELECT @nOrderCount = Count (Distinct OrderKey )   
            FROM dbo.PickDetail WITH (NOLOCK)   
            WHERE StorerKey = @cStorerKey  
            AND ID = @cID  
            AND Status < '9'  -- (james01)

            IF @nOrderCount > 1   
            BEGIN  
               SET @nErrNo = 133302  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --IDMoreThan1Ord  
               GOTO Quit  
            END  
              
            SELECT TOP 1 @cIDOrderKey = OrderKey   
            FROM dbo.PickDetail WITH (NOLOCK)   
            WHERE StorerKey = @cStorerKey  
            AND ID = @cID  
            AND SKU = @cSKU 
            AND Status < '9' -- (james01)
              
            UPDATE rdt.rdtPPA WITH (ROWLOCK)   
            SET OrderKey = @cIDOrderKey   
            WHERE StorerKey = @cStorerKey   
            AND SKU = @cSKU   
            AND ID = @cID   
            AND Status IN ( '0', '1' )   
              
            IF @@ERROR <> 0   
            BEGIN  
               SET @nErrNo = 133303  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPPAFail  
               GOTO Quit  
            END  
              
            
                    
         END  
      END  
   END  
     
Quit:    
   

GO