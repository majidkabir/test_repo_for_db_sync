SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_1855ExtValidSP02                                */    
/* Purpose: ToLoc must be same as suggest Loc                           */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev   Author      Purposes                                */    
/* 2024-12-16 1.0.0  NLT013     FCR-1755 Created                        */    
/************************************************************************/    
    
CREATE   PROC rdt.rdt_1855ExtValidSP02 (    
   @nMobile        INT,  
   @nFunc          INT,  
   @cLangCode      NVARCHAR( 3),  
   @nStep          INT,  
   @nInputKey      INT,  
   @cFacility      NVARCHAR( 5),  
   @cStorerKey     NVARCHAR( 15),  
   @cGroupKey      NVARCHAR( 10),  
   @cTaskDetailKey NVARCHAR( 10),  
   @cPickZone      NVARCHAR( 10),  
   @cCartId        NVARCHAR( 10),  
   @cMethod        NVARCHAR( 1),  
   @cFromLoc       NVARCHAR( 10),  
   @cCartonId      NVARCHAR( 20),  
   @cSKU           NVARCHAR( 20),  
   @nQty           INT,  
   @cOption        NVARCHAR( 1),  
   @cToLOC         NVARCHAR( 10),  
   @tExtValidate   VariableTable READONLY,  
   @nErrNo         INT           OUTPUT,  
   @cErrMsg        NVARCHAR( 20) OUTPUT  
)    
AS    
   SET NOCOUNT ON         
   SET QUOTED_IDENTIFIER OFF         
   SET ANSI_NULLS OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF     
    
   DECLARE 
      @cSuggToLOC       NVARCHAR( 10),
      @cUserName        NVARCHAR( 18)

   SELECT 
      @cUserName  = UserName
   FROM rdt.RDTMOBREC WITH (NOLOCK)  
   WHERE Mobile = @nMobile  

   SELECT @cSuggToLOC = ToLoc      
   FROM dbo.TaskDetail WITH (NOLOCK)      
   WHERE TaskDetailKey = @cTaskDetailKey      
     
   IF @nFunc = 1855
   BEGIN
      IF @nStep = 7  
      BEGIN  
         IF @nInputKey = 1  
         BEGIN  
            IF @cPickZone <>'PICK'
            BEGIN
               IF @cToLOC <> @cSuggToLOC
               BEGIN
                  SET @nErrNo = 231201
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Location override not allowed
                  GOTO Quit
               END
            END
         END  
      END  
   END

Quit:

GO