SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_859ExtUpd01                                     */  
/* Purpose: Validate  Input                                             */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2017-06-14 1.0  ChewKP	    WMS-2162 Created                         */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_859ExtUpd01] (  
   @nMobile        INT, 
   @nFunc          INT, 
   @cLangCode      NVARCHAR( 3),  
   @cUserName      NVARCHAR( 18), 
   @cFacility      NVARCHAR( 5),  
   @cStorerKey     NVARCHAR( 15), 
   @nStep          INT,           
   @cSourceKey     NVARCHAR( 20), 
   @cEventCode     NVARCHAR( 20), 
   @cEventCode2    NVARCHAR( 20),           
   @nErrNo         INT           OUTPUT, 
   @cErrMsg        NVARCHAR( 20) OUTPUT
)  
AS  
  
SET NOCOUNT ON  
SET QUOTED_IDENTIFIER OFF  
SET ANSI_NULLS OFF  

DECLARE @nTranCount 			INT
       ,@b_success         INT
       ,@nEventNum         INT
       ,@nEventType        INT        
       ,@cTransmitlogCode  NVARCHAR(1)
       ,@cEventSequence    NVARCHAR(1) 
       ,@cTableName        NVARCHAR(10) 

SET @nTranCount = @@TRANCOUNT


  
IF @nFunc = 859  
BEGIN  
    BEGIN TRAN
    SAVE TRAN rdt_859ExtUpd01  
    
    SET @nErrNo          = 0
    SET @cErrMSG         = ''
    
    IF @nStep = 1
    BEGIN
      
       SELECT @cEventSequence = UDF01 
		 FROM dbo.Codelkup WITH (NOLOCK) 
		 WHERE ListNAme = 'EventCode'
		 AND StorerKey = @cStorerKey
		 AND Long = @cSourceKey
		 
       EXEC RDT.rdt_STD_EventLog
         @cActionType   = '14',
         @cUserID       = @cUserName,
         @nMobileNo     = @nMobile,
         @nFunctionID   = @nFunc,
         @cFacility     = @cFacility,
         @cStorerKey    = @cStorerKey,
         @cRefNo1       = @cSourceKey, 
    	   @cRefNo2       = @cEventCode, 
    		@cRefNo3       = @cEventCode2,
    		@cRefNo4       = @cEventSequence
    		
       SELECT @nEventNum = EventNum
             ,@nEventType = EventType
       FROM rdt.rdtSTDEventLog WITH (NOLOCK) 
       WHERE FunctionID = @nFunc
       AND MobileNo  = @nMobile
       AND StorerKey = @cStorerKey 
       AND Facility  = @cFacility
       AND UserID    = @cUserName
       AND ActionType = 14
       AND RefNo1    = @cSourceKey
       AND RefNo2    = @cEventCode
       AND RefNo3    = @cEventCode2
       AND RefNo4    = @cEventSequence
       
		 SELECT @cTableName = Short 
             ,@cTransmitlogCode= Code
       FROM dbo.CodeLkup WITH (NOLOCK) 
       WHERE ListName = 'RDT859' 
       AND StorerKey = @cStorerKey
       
              
       IF @cTransmitlogCode = '2' 
       BEGIN
         --SELECT @cEventCode '@cEventCode' , @nEventNum '@nEventNum' , @nEventType '@nEventType' 

         EXEC ispGenTransmitLog2 @cTableName, @nEventNum, @nEventType, @cStorerKey, ''  
                                       , @b_success OUTPUT
                                       , @nErrNo OUTPUT
                                       , @cErrMsg OUTPUT 
         
         
       END
       ELSE IF @cTransmitlogCode = '3'
       BEGIN
         EXEC ispGenTransmitLog3 @cTableName, @nEventNum, @nEventType, @cStorerKey, ''  
                                       , @b_success OUTPUT
                                       , @nErrNo OUTPUT
                                       , @cErrMsg OUTPUT 

       END
       
       GOTO QUIT 

    END
    

RollBackTran:
   ROLLBACK TRAN rdt_859ExtUpd01 -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
   
END  
  


 

GO