SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_859ExtValidSP01                                 */  
/* Purpose:                                                             */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2017-06-16 1.0  ChewKP     WMS-2162 Created                          */  
/* 2020-09-24 1.1  Chermaine  WMS-15283 remove error 111202 (cc01)      */
/* 2021-12-14 1.2  Chermaine  WMS-18535 AllowEventCodeBlank Config(cc02)*/
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_859ExtValidSP01] (  
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
   @nCursor        INT OUTPUT,     
   @nErrNo         INT           OUTPUT, 
   @cErrMsg        NVARCHAR( 20) OUTPUT
)  
AS  
  
SET NOCOUNT ON    
SET QUOTED_IDENTIFIER OFF    
SET ANSI_NULLS OFF    
SET CONCAT_NULL_YIELDS_NULL OFF    
  
IF @nFunc = 859  
BEGIN  
   
	 DECLARE @nNewType  		   INT 
	        ,@nType            INT
	        ,@cIDtype          NVARCHAR(1)
	        ,@cNewIDType       NVARCHAR(1) 
           ,@nEventSequence   NVARCHAR(1)
           ,@cAllowEventCodeBlank   NVARCHAR(1) --(cc02)
    
    SET @nErrNo          = 0
    SET @cErrMSG         = ''
    SET @cAllowEventCodeBlank = rdt.RDTGetConfig( @nFunc, 'AllowEventCodeBlank', @cStorerKey)   --(cc02)
       
    IF @nStep = '1'
    BEGIN
			 
			 IF NOT EXISTS ( SELECT 1 FROM dbo.Codelkup WITH (NOLOCK) 
			                 WHERE ListName = 'EVENTCODE'
			                 AND StorerKey = @cStorerKey 
			                 AND Long = @cSourceKey )
			 BEGIN
			   SET @nErrNo = 111201
	         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidEventcode'
            SET @nCursor = 2
	         GOTO QUIT 
	            
			 END
			 
			 
			 IF @cAllowEventCodeBlank <> '1' --(cc02)
			 BEGIN
			 	IF NOT EXISTS ( SELECT 1 FROM dbo.Codelkup WITH (NOLOCK) 
			                    WHERE ListName = 'CARRIERCHK'
			                    AND Code = @cEventCode
			                    AND StorerKey = @cStorerKey ) 
			    BEGIN
			      SET @nErrNo = 111203
   	         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidCarrier'
               SET @nCursor = 4
   	         GOTO QUIT 
			    END
			 END
			 
			 
			 IF EXISTS ( SELECT 1
                      FROM rdt.rdtSTDEventLog WITH (NOLOCK) 
                      WHERE FunctionID = @nFunc
                      AND MobileNo  = @nMobile
                      AND StorerKey = @cStorerKey 
                      AND Facility  = @cFacility
                      AND ActionType = 14
                      AND RefNo1    = @cSourceKey
                      AND RefNo2    = @cEventCode
                      AND RefNo3    = @cEventCode2 ) 
			 BEGIN
			   SET @nErrNo = 111204
	         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'EventExists'
            SET @nCursor = 6
	         GOTO QUIT 
			 END
			 
			 --SELECT @nEventSequence = UDF01 
			 --FROM dbo.Codelkup WITH (NOLOCK) 
			 --WHERE ListNAme = 'EventCode'
			 --AND StorerKey = @cStorerKey
			 --AND Long = @cSourceKey


		    		 
			 --IF @nEventSequence <> 0 
			 --BEGIN  
   	--		 IF NOT EXISTS ( SELECT 1 FROM rdt.rdtStdEventLog WITH (NOLOCK) 
   	--		                 WHERE FunctionID = @nFunc
    --                         AND StorerKey = @cStorerKey 
    --                         AND Facility  = @cFacility
    --                         AND ActionType = 14
    --                         AND RefNo2    = @cEventCode
    --                         AND RefNo3    = @cEventCode2
    --                         AND RefNo4    = (@nEventSequence - 1) ) 
    --         BEGIN
    --            SET @nErrNo = 111202
    --  	       SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'PreEventNotDone'
    --            SET @nCursor = 6
    --  	       GOTO QUIT 
    --         END
    --      END
		
   END
       
       
    
    
    

   
END  
  
QUIT:  

 

GO