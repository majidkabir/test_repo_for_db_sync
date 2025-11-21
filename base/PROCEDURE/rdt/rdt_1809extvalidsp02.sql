SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_1809ExtValidSP02                                */  
/* Purpose: Validate Reason Code, Call from TM Tote Picking             */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2016-06-07 1.0  ChewKP     SOS#358813 Created                        */ 
/* 2018-06-22 1.1  CheeMun    INC0233348 - 1 Tote 1 Orderkey            */
/* 2018-10-02 1.2  CheeMun    INC0412673 - Fix DropIDType Typo          */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_1809ExtValidSP02] (  
   @nMobile          INT,  
   @nFunc            INT,   
   @cLangCode        NVARCHAR(3),   
   @nStep            INT,   
   @cStorerKey       NVARCHAR(15),   
   @nFromStep        NVARCHAR(18),   
   @cReasonCode      NVARCHAR(10),   
   @cTaskDetailKey   NVARCHAR(10),
   @cDropID          NVARCHAR(20),
   @nErrNo           INT       OUTPUT,   
   @cErrMsg          CHAR( 20) OUTPUT
)  
AS  
  
SET NOCOUNT ON  
SET QUOTED_IDENTIFIER OFF  
SET ANSI_NULLS OFF  
  
IF @nFunc = 1809  
BEGIN  
   
    
    DECLARE    @cID            NVARCHAR(18)
            ,  @cLoseID        NVARCHAR(1)
            ,  @cFromLoc       NVARCHAR(10) 
            ,  @cToteNo        NVARCHAR(18) 
            ,  @cDropIDType    NVARCHAR(10)
            ,  @cOrderKey      NVARCHAR(10) 
            ,  @cWaveKey       NVARCHAR(10) 
            ,  @cMessage03     NVARCHAR(20)
            ,  @cPickMethod    NVARCHAR(10)
            ,  @cUserName      NVARCHAR(18) 
				,  @cCount         INT           --INC0233348        
            ,  @cPOrderKey     NVARCHAR(10)  --INC0233348 

    SET @nErrNo          = 0
    SET @cErrMSG         = ''
    SET @cFromLoc        = ''
    SET @cToteNo         = ''
    
    --SELECT @cDropID = V_String1 
    --FROM rdt.rdtMobRec WITH (NOLOCK)
    --WHERE Mobile = @nMobile
    
--    IF @nStep = 1
--    BEGIN
--      
--      IF EXISTS (SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK)
--                       JOIN dbo.TaskDetail TD WITH (NOLOCK) ON PD.TaskDetailKey = TD.TaskDetailKey
--                       JOIN dbo.Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey
--                       WHERE TD.DropID = @cDropID
--                       AND O.STATUS NOT IN ('9', 'CANC')
--                       AND O.StorerKey = @cStorerKey)
--      BEGIN
--         SET @nErrNo = 101105
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote In Used
--         GOTO QUIT
--      END
--      
--    END
    IF @nStep = 1 
    BEGIN
      
      IF EXISTS ( SELECT 1 FROM dbo.DropID WITH (NOLOCK) 
                  WHERE DropID = @cDropID 
                  AND Status = '5' ) 
      BEGIN
         
         SELECT @cDropIDType = DropIDType 
         FROM dbo.DropID WITH (NOLOCK)
         WHERE DropID = @cDropID 
         
         SELECT @cMessage03 = Message03 
               ,@cPickMethod = PickMethod
               ,@cUserName  = UserKey
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE TaskDetailKey = @cTaskDetailKey
         
         SELECT Top 1 @cOrderKey = PD.OrderKey 
                     ,@cWaveKey  = O.UserDefine09
         FROM dbo.PickDetail PD WITH (NOLOCK) 
         INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
         WHERE PD.StorerKey = @cStorerKey
         AND PD.DropID = @cDropID
         AND PD.Status = '5' 
         ORDER BY PD.EditDate Desc
		 
		 --INC0233348 (START)      
         SELECT @cCount = COUNT(DISTINCT PD.OrderKey)    
         FROM dbo.PickDetail PD WITH (NOLOCK)         
         INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey        
         WHERE PD.StorerKey = @cStorerKey        
         AND PD.DropID = @cDropID        
         AND PD.Status = '5'       
             
         IF @cCount = 1     
         BEGIN    
            SELECT DISTINCT  @cPOrderKey = PD.OrderKey     
            FROM dbo.PickDetail PD WITH (NOLOCK)         
            INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey        
            WHERE PD.StorerKey = @cStorerKey        
            AND PD.DropID = @cDropID     
            AND PD.Status = '5'    
       
            IF ISNULL(@cPOrderKey, '') <> ISNULL(@cOrderKey ,'') OR ISNULL(@cPOrderKey, '') <> ISNULL(@cMessage03 ,'')   
            BEGIN    
               SET @cCount = @cCount + 1    
            END    
         END    
         --INC0233348 (END)

         IF @cDropIDType NOT IN ( 'PP' , 'MULTIS' , 'SINGLES' )    --INC0412673 
         BEGIN
               SET @nErrNo = 101107
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidTote'
               GOTO QUIT  
         END
         
         IF @cDropIDType IN (  'PP' , 'MULTIS' )       
         BEGIN      
      
            IF ISNULL(@cMessage03,'')  <> ISNULL(@cOrderKey ,'') AND @cCount > 1 --INC0233348      
            BEGIN      
               SET @nErrNo = 101105      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ToteInUsed'      
               GOTO QUIT         
            END      
         END 
         
         IF @cDropIDType = 'SINGLES'
         BEGIN
            IF ISNULL(@cMessage03,'')  <> ISNULL(@cWaveKey ,'') 
            BEGIN
               SET @nErrNo = 101106
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ToteInUsed'
               GOTO QUIT   
            END
         END
         
         IF EXISTS ( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK) 
                               WHERE DropID = @cDropID
                               AND UserKey <> @cUserName 
                               AND Status IN ( '0' , '3' ) )
         BEGIN         
               SET @nErrNo = 101108
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ToteInUsed'
               GOTO QUIT   
         END
         
      END
      
    END
    
    IF @nStep = 9
    BEGIN
       
       IF @nFromStep = 7 AND @cReasonCode <> 'NT'
       BEGIN
          SET @nErrNo = 101101
          SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'WrongRSNCode'
          GOTO QUIT   
       END
       
       
       IF @nFromStep = 2 AND @cReasonCode <> 'SP'
       BEGIN
          SET @nErrNo = 101102
          SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'WrongRSNCode'
          GOTO QUIT   
       END
       
       SELECT   @cFromLoc = V_Loc 
              , @cToteNo  = V_String1
       FROM rdt.rdtMobRec WITH (NOLOCK)
       WHERE Mobile = @nMobile 
       
       IF @cReasonCode = 'SP' AND @cFromLoc = ''
       BEGIN
          SET @nErrNo = 101103
          SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'FromLocReq'
          GOTO QUIT   
       END
       
       IF @cReasonCode = 'SP' AND @cToteNo = ''
       BEGIN
          SET @nErrNo = 101104
          SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ToteNoReq'
          GOTO QUIT   
       END 
       
       
    END
END  
  
QUIT:  

 

GO