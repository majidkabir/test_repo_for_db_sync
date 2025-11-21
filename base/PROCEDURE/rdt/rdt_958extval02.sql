SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/              
/* Store procedure: rdt_958ExtVal02                                     */              
/*                                                                      */              
/* Purpose: Get suggested loc                                           */              
/*                                                                      */              
/* Called from: rdt_UCCPutaway_GetSuggestLOC                            */              
/*                                                                      */              
/* Date         Rev  Author   Purposes                                  */              
/* 22-12-2022   1.0  yeekung  WMS-20847. Created                        */        
/************************************************************************/              
              
CREATE   PROC [RDT].[rdt_958ExtVal02] (              
   @nMobile          INT,               
   @nFunc            INT,               
   @cLangCode        NVARCHAR( 3), 
   @nStep            INT,
   @nInputKey        INT,                     
   @cFacility        NVARCHAR( 5)   ,
   @cStorerKey       NVARCHAR( 15)  ,
   @cPickSlipNo      NVARCHAR( 20)  ,
   @cSuggestedLOC    NVARCHAR( 10)  ,
   @cSuggSKU         NVARCHAR( 20)  ,
   @nQTY             INT            ,
   @cUCCNo           NVARCHAR( 20)  ,
   @cDropID          NVARCHAR( 20)  ,
   @cOption          NVARCHAR( 1)   ,
   @nErrNo           INT           OUTPUT,
   @cErrMsg          NVARCHAR( 20) OUTPUT         
) AS              
BEGIN              
   SET NOCOUNT ON              
   SET QUOTED_IDENTIFIER OFF              
   SET ANSI_NULLS OFF              
   SET CONCAT_NULL_YIELDS_NULL OFF     
   
   DECLARE @cOrderkey NVARCHAR(20),
           @cDocType NVARCHAR(1)
   
   IF @nStep='5'
   BEGIN
      IF @nInputKey='1'
      BEGIN
         IF @cDropID <> @cUCCNo
         BEGIN 
            SET @nErrNo = 195001
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidID
            GOTO QUIT
         END

         SELECT @cOrderkey=orderkey
         FROM PICKHEADER (NOLOCK)
         where pickheaderkey=@cPickSlipNo

         SELECT @cDocType=doctype
         FROM orders (nolock)
         WHERE orderkey=@cOrderkey

         IF @cDocType='N'
         BEGIN
            IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'DROPIDN', @cDropID) = 0 
            BEGIN        
               SET @nErrNo = 195002        
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format        
               GOTO QUIT        
            END  
         END
         ELSE IF @cDocType='E'
         BEGIN
            IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'DROPIDE', @cDropID) = 0 
            BEGIN        
               SET @nErrNo = 195003        
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format        
               GOTO QUIT        
            END  
         END

         IF EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
                   WHERE storerkey=@cstorerkey 
                     AND dropid=@cDropID)
         BEGIN
            SET @nErrNo = 195004
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DuplicateID
            GOTO QUIT
         END
      END
   END
              
    
Quit:              
END 

GO