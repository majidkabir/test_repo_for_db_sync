SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: rdt_1809ExtInfo01                                   */    
/* Copyright      : LF                                                  */    
/*                                                                      */    
/* Purpose: Call From rdtfnc_TM_TotePicking                             */    
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author   Purposes                                   */    
/* 2015-12-29  1.0  ChewKP   SOS#358813 Created                         */   
/* 2021-03-12  1.1  James    WMS-15657 Bug fix (james01)                */
/************************************************************************/    

CREATE PROC [RDT].[rdt_1809ExtInfo01] (    
    @nMobile      INT,           
    @nFunc        INT,           
    @cLangCode    NVARCHAR( 3),  
    @nStep        INT,           
    @nInputKey    INT,           
    @cStorerKey   NVARCHAR( 15), 
    @cTaskDetailKey  NVARCHAR( 10), 
    @cOutInfo01         NVARCHAR( 60)  OUTPUT,
    @cOutInfo02         NVARCHAR( 60)  OUTPUT,
    @nErrNo             INT            OUTPUT, 
    @cErrMsg            NVARCHAR( 20)  OUTPUT
) AS    
BEGIN    
   SET NOCOUNT ON            
   SET ANSI_NULLS OFF            
   SET QUOTED_IDENTIFIER OFF            
   SET CONCAT_NULL_YIELDS_NULL OFF            
   
   DECLARE @cOrderKey NVARCHAR(10)
         , @cPutawayZone NVARCHAR(10) 
         , @cFromLoc     NVARCHAR(10)
            
   SET @nErrNo   = 0            
   SET @cErrMsg  = ''     
         
   SET @cOrderKey = ''
   SET @cPutawayZone = ''
   SET @cFromLoc = ''
   
   
   IF @nFunc = 1809          
   BEGIN     

         
         IF @nStep = 3
         BEGIN       
                        
            SELECT @cOrderKey = OrderKey
            FROM dbo.TaskDetail WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
            AND TaskDetailKey = @cTaskDetailKey 
             
            SELECT TOP 1 @cFromLoc = FromLoc
            FROM dbo.TaskDetail WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND OrderKey = @cOrderKey
            AND TaskDetailKey <> @cTaskDetailKey
            AND Status = '0' 
            Order by AreaKey
            
            SELECT @cPutawayZone = PutawayZone 
            FROM dbo.Loc WITH (NOLOCK)
            WHERE Loc = @cFromLoc 
            
            SET @cOutInfo01 = 'NEXT ZONE:' 
            SET @cOutInfo02 = @cPutawayZone
            
                      
         END      
                
   END          
          

            
       
END     

GO