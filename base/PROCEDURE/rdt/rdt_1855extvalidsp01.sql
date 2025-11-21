SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_1855ExtValidSP01                                */    
/* Purpose: Validate cart id prefix value                               */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author     Purposes                                  */    
/* 2021-08-13 1.0  James      WMS-17335. Created                        */    
/* 2023-07-04 1.1  James      WMS-22863 Add short pick validate(james01)*/
/************************************************************************/    
    
CREATE   PROC [RDT].[rdt_1855ExtValidSP01] (    
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
    
   DECLARE @cPickMethod    NVARCHAR( 10)  
   DECLARE @cCartonType    NVARCHAR( 10)  
   DECLARE @cUserName      NVARCHAR( 18)  
   DECLARE @cCode          NVARCHAR( 10)
   DECLARE @cOrderKey      NVARCHAR( 10)
   DECLARE @cSalesMan      NVARCHAR( 30)  
   DECLARE @cInField06     NVARCHAR( 60)
   DECLARE @cErrMsg1       NVARCHAR( 20)
   DECLARE @cErrMsg2       NVARCHAR( 20)
   DECLARE @nSuggQty       INT = 0
   DECLARE @nActQTY        INT = 0
   
   SELECT @cUserName = UserName  
   FROM rdt.RDTMOBREC WITH (NOLOCK)  
   WHERE Mobile = @nMobile  
     
   IF @nStep = 2  
   BEGIN  
      IF @nInputKey = 1  
      BEGIN  
         SELECT TOP 1 @cPickMethod = PickMethod, @cCode = CL.Code  
         FROM dbo.TaskDetail TD WITH (NOLOCK)  
         JOIN dbo.CODELKUP CL WITH (NOLOCK) ON ( TD.PickMethod = CL.Long)  
         WHERE TD.Storerkey = @cStorerKey  
         AND   TD.TaskType = 'ASTCPK'  
         AND   TD.Status = '3'  
         AND   TD.Groupkey = @cGroupKey  
         AND   TD.UserKey = @cUserName  
         AND   TD.DeviceID = @cCartID  
         AND   TD.DropID = ''  
         ORDER BY CL.Code, TD.TaskDetailKey  
  
         SELECT @cCartonType = UDF01  
         FROM dbo.CODELKUP WITH (NOLOCK)  
         WHERE LISTNAME = 'TMPICKMTD'  
         AND   Storerkey = @cStorerKey  
         AND   Long = @cPickMethod  
  
         IF CHARINDEX( LEFT( @cCartonId, 1), @cCartonType) = 0  
         BEGIN  
            SET @nErrNo = 173301              
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvCartPrefix      
            GOTO Quit  
         END           
      END  
   END  
   
   IF @nStep = 4
   BEGIN
   	IF @nInputKey = 1
   	BEGIN
   		SELECT
   		   @cInField06 = I_Field06,
   		   @nSuggQty =  V_Integer1,
   		   @nActQTY = V_Integer3
   		FROM rdt.RDTMOBREC WITH (NOLOCK)
   		WHERE Mobile = @nMobile

   		-- User try to do Short pick   		   
   		IF (( @nActQTY + @nQty) < @nSuggQTY) AND 
   		   ( @cInField06 = '' OR @cInField06 = '99')
   		BEGIN
   			SELECT @cOrderKey = OrderKey
   			FROM dbo.PICKDETAIL WITH (NOLOCK)
   			WHERE TaskDetailKey = @cTaskDetailKey
   			
   			SELECT @cSalesMan = Salesman
   			FROM dbo.ORDERS WITH (NOLOCK)
   			WHERE OrderKey = @cOrderKey
   			
   			-- Not allowed to short pick if below condition exists 
            IF EXISTS( SELECT 1 
                       FROM dbo.CODELKUP WITH (NOLOCK)
                       WHERE LISTNAME = 'COURIERLBL'
                       AND   Code = @cSalesMan
                       AND   Short = 'Y'
                       AND   Storerkey = @cStorerKey)
            BEGIN  
               SET @nErrNo = 0  
               SET @cErrMsg1 = rdt.rdtgetmessage( 173302, @cLangCode, 'DSP') -- Short Pick Not   
               SET @cErrMsg2 = rdt.rdtgetmessage( 173303, @cLangCode, 'DSP') -- Allowed     
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2  
               IF @nErrNo = 1  
               BEGIN  
                  SET @cErrMsg1 = ''  
                  SET @cErrMsg2 = ''  
                  SET @nErrNo = 173304              
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --X Short Pick      
                  GOTO Quit
               END  
            END  
   		END
   	END
   END
    
Quit:    

GO