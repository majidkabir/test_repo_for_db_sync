SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: rdt_1765ExtValidSP01                                */    
/* Copyright      : LF                                                  */    
/*                                                                      */    
/* Purpose: VICTORIA SECRET Replen To Logic                             */    
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author   Purposes                                   */    
/* 28-06-2017  1.0  ChewKP   Created. WMS-1580                          */ 
/* 04-04-2019  1.1  ChewKP   WMS-8496 (ChewKP01)                        */ 
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_1765ExtValidSP01] (    
   @nMobile        INT,    
   @nFunc          INT,    
   @cLangCode      NVARCHAR( 3),    
   @cUserName      NVARCHAR( 15),    
   @cFacility      NVARCHAR( 5),    
   @cStorerKey     NVARCHAR( 15),    
   @cDROPID        NVARCHAR( 20),    
   @nStep          INT,  
   @cTaskDetailKey NVARCHAR(10),  
   @nQty           INT,  
   @nErrNo         INT           OUTPUT,    
   @cErrMsg        NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max    
) AS
BEGIN
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
     
   DECLARE  @cUCC               NVARCHAR(20)   
          , @cSourceKey         NVARCHAR(30)  
          , @nTrancount         INT  
        
          , @cFromLoc           NVARCHAR(10)  
          , @cToLoc             NVARCHAR(10)  
          , @b_Success          INT  
          , @cListKey           NVARCHAR(10)  
          , @cRefSourceKey      NVARCHAR(30)   
          , @cFromID            NVARCHAR(18)  
          , @cLot               NVARCHAR(10)  
          , @cSKU               NVARCHAR(20)   
          , @cModuleName        NVARCHAR(30)  
          , @cAlertMessage      NVARCHAR(255)  
          , @cLoseUCC           NVARCHAR(1)
          , @cTDTaskDetailKey   NVARCHAR(10)

   SET @nErrNo   = 0    
   SET @cErrMsg  = ''   
   SET @cSKU     = ''  
   SET @cLot     = ''  
   SET @cFromLoc = ''  
   SET @cToLoc   = ''  
   SET @cFromID  = ''  
   SET @cLoseUCC = ''

   SET @nTranCount = @@TRANCOUNT  
   
   IF @nFunc = 1765 
   BEGIN
      
      SELECT 
               @cFromLoc = FromLoc
             , @cToLoc   = ToLoc
             , @cFromID  = FromID
             , @cSKU     = SKU
             , @cLot     = Lot   
      FROM dbo.TaskDetail WITH (NOLOCK)
      WHERE TaskDetailKey = @cTaskDetailKey 
      
      IF @nStep = 3 
      BEGIN 
   		
           
         IF EXISTS ( SELECT 1 FROM dbo.LotxLocxID WITH (NOLOCK) 
                     WHERE StorerKey = @cStorerKey 
                     AND Loc = @cToLoc
                     AND SKU = @cSKU 
                     AND Lot = @cLot
                     AND PendingMoveIn > 0 ) 
         BEGIN  
            SET @nErrNo = 111551  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LocReserved'  
            GOTO QUIT 
         END  
         
         -- (ChewKP01) 
         IF NOT EXISTS ( SELECT 1 FROM dbo.Loc WITH (NOLOCK) 
                         WHERE Facility = @cFacility
                         AND LocationCategory = 'MEZZANINE'
                         AND Loc = @cToLoc)
         BEGIN
            SET @nErrNo = 111552 
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidLoc'  
            GOTO QUIT 
         END
         
         
         IF @cToLoc = 'MASTDPP'
         BEGIN
            SET @nErrNo = 111553
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidLoc'  
            GOTO QUIT
         END
         
         
         
      END
      
  
       
  END
END   

QUIT:
 

GO