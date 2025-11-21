SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_839ExtValidSP11                                 */  
/* Purpose: Validate multiple users performing on same pick task        */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2022-04-16 1.0  YeeKung     WMS-19311 Created                        */ 
/************************************************************************/  
CREATE   PROC [RDT].[rdt_839ExtValidSP11] (  
   @nMobile      INT,           
   @nFunc        INT,           
   @cLangCode    NVARCHAR( 3),  
   @nStep        INT,           
   @nInputKey    INT,           
   @cFacility    NVARCHAR( 5) , 
   @cStorerKey   NVARCHAR( 15), 
   @cType        NVARCHAR( 10), 
   @cPickSlipNo  NVARCHAR( 10), 
   @cPickZone    NVARCHAR( 10),  
   @cDropID      NVARCHAR( 20), 
   @cLOC         NVARCHAR( 10), 
   @cSKU         NVARCHAR( 20), 
   @nQTY         INT,           
   @cPackData1   NVARCHAR( 30),
   @cPackData2   NVARCHAR( 30),
   @cPackData3   NVARCHAR( 30),
   @nErrNo       INT           OUTPUT, 
   @cErrMsg      NVARCHAR(250) OUTPUT  
)  
AS  

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF
  
IF @nFunc = 839  
BEGIN  
   DECLARE @cOrderKey         NVARCHAR( 20)

          
   SET @nErrNo          = 0
   SET @cErrMSG         = ''


   IF @nStep = 2 
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         SELECT TOP 1        
            @cOrderKey = OrderKey
         FROM dbo.PickHeader WITH (NOLOCK)        
        WHERE PickHeaderKey = @cPickSlipNo 
        
         IF EXISTS(SELECT 1 FROM ORDERS (NOLOCK)
                   WHERE orderkey=@cOrderKey
                   AND storerkey=@cStorerKey
                   AND doctype<>'E')
         BEGIN
            -- Check DropID format        
            IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'DROPIDE', @cDropID) = 0        
            BEGIN        
               SET @nErrNo = 186151        
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
               EXEC rdt.rdtSetFocusField @nMobile, 3 -- DropID 
               GOTO quit        
            END 
         END
         
      END
   END

   IF @nStep = 11
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
        
         IF ISNULL(@cPackData1,'')<>''
         BEGIN
            IF NOT EXISTS (SELECT 1
                     FROM CODELKUP (NOLOCK)
                     WHERE LISTNAME='VFCOO'
                     AND storerkey=@cStorerKey
                     AND code=@cPackData1)
            BEGIN  
               SET @nErrNo = 186152 
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail  
               GOTO QUIT  
            END 
         END
         
      END
   END
END  
  
QUIT:  


GO