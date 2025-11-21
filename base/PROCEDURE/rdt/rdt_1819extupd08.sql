SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1819ExtUpd08                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Generate PA1 task                                           */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2018-06-20   ChewKP    1.0   WMS-5200 Created                        */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1819ExtUpd08]
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nInputKey       INT,
   @cFromID         NVARCHAR( 18),
   @cSuggLOC        NVARCHAR( 10),
   @cPickAndDropLOC NVARCHAR( 10),
   @cToLOC          NVARCHAR( 10),
   @nErrNo          INT           OUTPUT,
   @cErrMsg         NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount  INT
   DECLARE @cLoseID     NVARCHAR( 1)
   DECLARE @cStorerKey  NVARCHAR( 15)
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
          ,@cDeviceID    NVARCHAR(10)
   
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

   -- Putaway By ID
   IF @nFunc = 1819
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
                   SET @cVNAMessage = 'STXPUTPL;'  + @cSuggLOC + 'ETX'
               END
               ELSE IF ISNULL(@cTruckType,'') = 'CT'
               BEGIN
                   SET @cVNAMessage = 'STXPUTCT;'  + @cSuggLOC + 'ETX'  
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
   
   GOTO Quit

--RollBackTran:
--   ROLLBACK TRAN rdt_1819ExtUpd08 -- Only rollback change made here
--Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO