SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_844ExtVal02                                     */    
/* Purpose: Check if user login with printer                            */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author    Purposes                                   */    
/* 2018-12-18 1.0  ChewKP    WMS-7281 Created                           */
/* 2019-11-04 1.1  Ung       INC0918985 Fix to exclude shipped pallet   */ 
/* 2019-03-29 1.2  James     WMS-8002 Add TaskDetailKey param (james01) */  
/* 2019-04-22 1.3  James     WMS-7983 Add VariableTable (james02)       */    
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_844ExtVal02] (    
   @nMobile     INT,    
   @nFunc       INT,     
   @cLangCode   NVARCHAR(3),     
   @nStep       INT,     
   @cStorerKey  NVARCHAR(15),     
   @cFacility   NVARCHAR(5),  
   @cRefNo      NVARCHAR( 10),  
   @cOrderKey   NVARCHAR( 10),  
   @cDropID     NVARCHAR( 20),  
   @cLoadKey    NVARCHAR( 10),  
   @cPickSlipNo NVARCHAR( 10),  
   @nErrNo      INT           OUTPUT,     
   @cErrMsg     NVARCHAR( 20) OUTPUT,   
   @cID         NVARCHAR( 18) = '',  
   @cTaskDetailKey   NVARCHAR( 10) = '',  
   @tExtValidate   VariableTable READONLY   
)    
AS    
    
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @nInputKey INT  
          ,@cPQty     NVARCHAR(5)  
          ,@cMQty     NVARCHAR(5)  
          ,@nCountOrder INT  
             
   IF @nFunc = 844 -- Post pick audit (Pallet ID)  
   BEGIN  
      IF @nStep = 1 -- Pallet ID  
      BEGIN  
         -- Get session info  
         SELECT @nInputKey = InputKey FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile  
  
         IF @nInputKey = 1 -- ENTER  
         BEGIN    
            -- Check pallet at stage  
            IF NOT EXISTS( SELECT TOP 1 1   
               FROM LOTxLOCxID LLI WITH (NOLOCK)     
                  JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)  
               WHERE LOC.Facility = @cFacility  
                  AND LLI.ID = @cID  
                  AND LOC.LocationCategory = 'STAGING')  
            BEGIN  
               SET @nErrNo = 133251  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID NotOnStage   
               GOTO Quit  
            END      
              
            SET @nCountOrder = 0   
            SELECT @nCountOrder = Count ( Distinct OrderKey)          
            FROM dbo.PickDetail WITH (NOLOCK)   
            WHERE StorerKey = @cStorerKey  
			AND Status < '9'				
            AND ID = @cID   
              
            IF @nCountOrder > 1   
            BEGIN  
               SET @nErrNo = 133253  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --IDMoreThan1Order  
               GOTO Quit  
            END  
         END  
      END  
        
--      IF @nStep = 3 -- SKU, Qty  
--      BEGIN  
         -- Get session info  
--         SELECT @nInputKey = InputKey   
--                @cPQTY    = I_Field09,  
--                @cMQTY    = I_Field10  
--         FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile  
--  
--         IF @nInputKey = 1 -- ENTER  
--         BEGIN    
--            SELECT @cProductModel = ProductModel   
--            FROM dbo.SKU WITH (NOLOCK)   
--            WHERE StorerKey = @cStorerKey  
--            AND SKU = @cSKU   
--  
--            IF @cProductModel = 'COPACK'  
--            BEGIN  
--               IF ISNULL(@cPQTY,'')  <> ''   
--               BEGIN  
--                  SET @nErrNo = 133252  -- CopackItemKeyInBT  
--                  GOTO Quit  
--               END  
--            END  
--      END  
   END  
     
Quit:    
   

GO