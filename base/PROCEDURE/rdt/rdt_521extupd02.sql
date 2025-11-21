SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_521ExtUpd02                                     */  
/* Purpose: Extended update for H&M UCC Putaway (UNLOCK pendingmovein)  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2018-10-09 1.0  ChewKP     WMS-5157                                  */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_521ExtUpd02] (  
   @nMobile         INT,       
   @nFunc           INT,       
   @cLangCode       NVARCHAR( 3),  
   @nStep           INT,        
   @nInputKey       INT,       
   @cStorerKey      NVARCHAR( 15), 
   @cUCCNo          NVARCHAR( 18), 
   @cSuggestedLOC   NVARCHAR( 10), 
   @cToLOC          NVARCHAR( 10), 
   @nErrNo          INT OUTPUT,    
   @cErrMsg         NVARCHAR( 20) OUTPUT
)  
AS  
BEGIN
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    

   DECLARE @nTranCount  INT
   DECLARE @cLoseID     NVARCHAR( 1)
   
   DECLARE @cSKU        NVARCHAR( 20)
          ,@cUCC        NVARCHAR( 20) 
          ,@bSuccess    INT
          ,@cPutawayLoc NVARCHAR( 10) 
          ,@cTaskDetailKey NVARCHAR( 10) 
          ,@cAreaKey       NVARCHAR( 10) 
          ,@cFacility      NVARCHAR( 5) 
          ,@cFromLOC       NVARCHAR(10)
          ,@nPABookingKey  INT 
          ,@cPutawayZone   NVARCHAR(10) 
          ,@cTruckType   NVARCHAR(10)
          ,@cType        NVARCHAR( 10)
          ,@cVNAMessage  NVARCHAR(MAX)
          ,@cUserName    NVARCHAR(18)
          ,@cDeviceID     NVARCHAR(10) 
   
   SET @nTranCount = @@TRANCOUNT
          
   SELECT @cUserName = UserName 
                  ,@cFacility = Facility 
                  ,@nInputKey = InputKey 
                  ,@cDeviceID = DeviceID
                  ,@cStorerKey = StorerKey 
                  FROM rdt.rdtMobRec WITH (NOLOCK) 
                  WHERE Mobile = @nMobile 

   SET @cType = 'VNA'
   SET @cTruckType = ''

   -- Putaway By UCC
   IF @nFunc = 521
   BEGIN
      IF @nStep = 1 
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF ISNULL(@cDeviceID,'')  <> '' 
            BEGIN
               SELECT @cTruckType = Short 
               FROM dbo.Codelkup WITH (NOLOCK) 
               WHERE ListName = 'DEVICETYP'
               AND StorerKey = @cStorerKey
               AND Code = @nFunc

               
               
               IF ISNULL(@cTruckType ,'' ) = 'PL'
               BEGIN
                   SET @cVNAMessage = 'STXPUTPL;'  + @cSuggestedLOC + 'ETX'
               END
               ELSE IF ISNULL(@cTruckType,'') = 'CT'
               BEGIN
                   SET @cVNAMessage = 'STXPUTCT;'  + @cSuggestedLOC + 'ETX'  
               END
               
               EXEC [RDT].[rdt_GenericSendMsg]
                   @nMobile      = @nMobile      
                  ,@nFunc        = @nFunc        
                  ,@cLangCode    = @cLangCode    
                  ,@nStep        = @nStep        
                  ,@nInputKey    = @nInputKey    
                  ,@cFacility    = @cFacility    
                  ,@cStorerKey   = @cStorerKey   
                  ,@cType        = @cType       
                  ,@cDeviceID    = @cDeviceID
                  ,@cMessage     = @cVNAMessage     
                  ,@nErrNo       = @nErrNo       OUTPUT
                  ,@cErrMsg      = @cErrMsg      OUTPUT  
               
            END
                  
         END
      END
   END
QUIT:  
END
 

GO