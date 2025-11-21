SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_1809ExtValidSP01                                */  
/* Purpose: Validate Reason Code, Call from TM Tote Picking             */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2015-01-15 1.0  ChewKP     SOS#330270 Created                        */  
/* 2016-06-07 1.1  ChewKP     SOS#358813 Add Parameter (ChewKP01)       */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_1809ExtValidSP01] (  
   @nMobile          INT,  
   @nFunc            INT,   
   @cLangCode        NVARCHAR(3),   
   @nStep            INT,   
   @cStorerKey       NVARCHAR(15),   
   @nFromStep        NVARCHAR(18),   
   @cReasonCode      NVARCHAR(10),   
   @cTaskDetailKey   NVARCHAR(10),
   @cDropID          NVARCHAR(20), -- (ChewKP01)
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
    
    SET @nErrNo          = 0
    SET @cErrMSG         = ''
    SET @cFromLoc        = ''
    SET @cToteNo         = ''
    


    IF @nStep = '1'
    BEGIN
         IF EXISTS ( SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cDropID And Status < '9' )
         BEGIN
            -- Check if every orders inside tote is canc. If exists 1 orders is open/in progress/picked then not allow
            IF EXISTS (SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK)
                       JOIN dbo.TaskDetail TD WITH (NOLOCK) ON PD.TaskDetailKey = TD.TaskDetailKey
                       JOIN dbo.Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey
                       WHERE TD.DropID = @cDropID
                       AND O.STATUS NOT IN ('9', 'CANC')
                       AND O.StorerKey = @cStorerKey)
            BEGIN
               SET @nErrNo = 92605
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote In Used
               GOTO QUIT
            END
            ELSE
            BEGIN
               -- If every orders in tote is shipped/canc then update them to '9' and release it
               
   
               UPDATE dbo.DropID WITH (ROWLOCK) SET
                  Status = '9'
               WHERE DropID = @cDropID
                  AND Status < '9'
   
               IF @@ERROR <> 0
               BEGIN
               
                  SET @nErrNo = 92606
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdateToteFail
                  GOTO QUIT
               END
               
            END
         END
    END
    
    IF @nStep = '9'
    BEGIN
       
       IF @nFromStep = 7 AND @cReasonCode <> 'NT'
       BEGIN
          SET @nErrNo = 92601
          SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'WrongRSNCode'
          GOTO QUIT   
       END
       
       
       IF @nFromStep = 2 AND @cReasonCode <> 'SP'
       BEGIN
          SET @nErrNo = 92602
          SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'WrongRSNCode'
          GOTO QUIT   
       END
       
       SELECT   @cFromLoc = V_Loc 
              , @cToteNo  = V_String1
       FROM rdt.rdtMobRec WITH (NOLOCK)
       WHERE Mobile = @nMobile 
       
       IF @cReasonCode = 'SP' AND @cFromLoc = ''
       BEGIN
          SET @nErrNo = 92603
          SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'FromLocReq'
          GOTO QUIT   
  END
       
       IF @cReasonCode = 'SP' AND @cToteNo = ''
       BEGIN
          SET @nErrNo = 92604
          SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ToteNoReq'
          GOTO QUIT   
       END 
       
       
    END
END  
  
QUIT:  

 
 

GO