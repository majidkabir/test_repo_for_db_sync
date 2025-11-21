SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_511ExtUpd03                                     */  
/* Purpose:                                                             */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2018-06-28 1.0  ChewKP     WMS-5222 Created                          */ 
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_511ExtUpd03] (  
   @nMobile        INT, 
   @nFunc          INT, 
   @cLangCode      NVARCHAR( 3),  
   @nStep          INT, 
   @nInputKey      INT, 
   @cFacility      NVARCHAR( 5), 
   @cStorerKey     NVARCHAR( 15), 
   @cFromID        NVARCHAR( 18), 
   @cFromLOC       NVARCHAR( 10), 
   @cToLOC         NVARCHAR( 10), 
   @nErrNo         INT           OUTPUT, 
   @cErrMsg        NVARCHAR( 20) OUTPUT
)  
AS  
BEGIN
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  

   DECLARE @bDebug INT
         , @bSuccess INT
  
   IF @nFunc = 511 -- Move by ID
   BEGIN  
      IF @nStep = 3 -- ToLOC
      BEGIN
             IF @nInputKey = 1 
             BEGIN
                -- Call to Sent Web Services
                IF EXISTS ( SELECT 1 FROM dbo.Loc WITH (NOLOCK) 
                            WHERE Loc = @cToLoc
                            AND LocationType = 'ROBOTSTG')
                BEGIN
                   EXEC  [dbo].[isp_WSITF_GeekPlusRBT_RECEIVING_Outbound]
                        @cStorerKey  
                      , @cFromID 
                      , @cFacility
                      , @bDebug                 
                      , @bSuccess               OUTPUT  
                      , @nErrNo                 OUTPUT  
                      , @cErrMsg                OUTPUT  
                    
                    IF @bSuccess = 0 
                    BEGIN
                        SET @nErrNo = 125651
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- WSSendingFail 
                        GOTO Quit
                    END
                END
             END
         
      END
   END  
  
Quit:  

END

GO