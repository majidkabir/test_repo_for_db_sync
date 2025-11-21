SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
      
/************************************************************************/      
/* Store procedure: rdt_1867ExtUpd01                                    */      
/* Copyright      : MAERSK                                              */    
/*                                                                      */    
/* Purpose: Send picked interface to WCS                                */      
/*                 For HUSQ                                             */      
/* Modifications log:                                                   */      
/*                                                                      */      
/* Date         Author    Ver.  Purposes                                */ 
/* 2024-10-10   1.0  JHU151    FCR-777 Created                          */ 
/************************************************************************/      
      
CREATE   PROCEDURE [rdt].[rdt_1867ExtUpd01]      
   @nMobile        INT,    
   @nFunc          INT,    
   @cLangCode      NVARCHAR( 3),    
   @nStep          INT,             
   @nInputKey      INT,             
   @cFacility      NVARCHAR( 5),    
   @cStorerKey     NVARCHAR( 15),    
   @cGroupKey      NVARCHAR( 10),    
   @cTaskDetailKey NVARCHAR( 10),    
   @cCartId        NVARCHAR( 10),    
   @cFromLoc       NVARCHAR( 10),    
   @cCartonId      NVARCHAR( 20),    
   @cSKU           NVARCHAR( 20),    
   @nQty           INT,             
   @cOption        NVARCHAR( 1),    
   @tExtUpdate     VariableTable READONLY,     
   @nErrNo         INT           OUTPUT,    
   @cErrMsg        NVARCHAR( 20) OUTPUT      
AS      
BEGIN      
   SET NOCOUNT ON      
   SET QUOTED_IDENTIFIER OFF      
   SET ANSI_NULLS OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF      
       
   DECLARE @nTranCount     INT    
   DECLARE @bSuccess       INT    
   DECLARE @nSerialNo      BIGINT    
   DECLARE @cUserName      NVARCHAR( 18)    
   DECLARE @cCommand       NVARCHAR( MAX) = ''    
   DECLARE @cIPAddress     NVARCHAR( 20) = ''      
   DECLARE @cPortNo        NVARCHAR( 5)  = ''      
   DECLARE @cMessageID     NVARCHAR( 10)    
   DECLARE @cWaveKey       NVARCHAR( 10)    
   DECLARE @cTaskKey       NVARCHAR( 10)    
   DECLARE @cCaseID        NVARCHAR( 20)    
   DECLARE @cDropID        NVARCHAR( 20)    
   DECLARE @cAreaKey       NVARCHAR( 10)    
   DECLARE @cLoc           NVARCHAR( 10)    
   DECLARE @cToloc         NVARCHAR( 10)    
   DECLARE @cPickerID      NVARCHAR( 18)    
   DECLARE @cPickedDate    NVARCHAR( 20)    
   DECLARE @cIniFilePath   NVARCHAR( 200)      
   DECLARE @cResult        NVARCHAR( 10)    
   DECLARE @cLocalEndPoint    NVARCHAR( 50)     
   DECLARE @cRemoteEndPoint   NVARCHAR( 50)    
   DECLARE @cApplication      NVARCHAR( 50) = 'GenericTCPSocketClient_WCS'    
   DECLARE @cSendMessage      NVARCHAR( MAX)    
   DECLARE @cReceiveMessage   NVARCHAR( MAX)    
   DECLARE @cStatus           NVARCHAR( 1) = '9'    
   DECLARE @nNoOfTry          INT = 0    
   DECLARE @cvbErrMsg         NVARCHAR( MAX)    
   DECLARE @cRecipient        NVARCHAR( MAX)    
   DECLARE @cPickConfirmStatus   NVARCHAR( 1)    
   DECLARE @cOrderKey         NVARCHAR( 10) = ''    
   DECLARE @cOrderLineNumber  NVARCHAR( 5) = ''    
   DECLARE @curUpdOrd         CURSOR    
   DECLARE @curUpdOrdDtl      CURSOR    
   DECLARE @cErrMsg1          NVARCHAR( 20) = ''
   DECLARE @nPENDCANC         INT = 0
   DECLARE @cCartonId2Confirm NVARCHAR( 20)
   DECLARE @cMethod           NVARCHAR( 1)

   SET @nErrNo = 0    
       
   SELECT @cUserName = UserName,
          @cMethod = V_String25  
   FROM RDT.RDTMOBREC WITH (NOLOCK)    
   WHERE Mobile = @nMobile    
    
    /**
   IF @nStep = 4    
   BEGIN    
      IF @nInputKey = 1    
      BEGIN    
         -- Handling transaction                
         SET @nTranCount = @@TRANCOUNT                
         BEGIN TRAN  -- Begin our own transaction                
         SAVE TRAN rdt_1855ExtUpd02 -- For rollback or commit only our own transaction                
    
         SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)      
         IF @cPickConfirmStatus = '0'      
            SET @cPickConfirmStatus = '5'      

         IF OBJECT_ID('tempdb..#OrderKey') IS NOT NULL
            DROP TABLE #OrderKey

         CREATE TABLE #OrderKey  (
            RowRef            BIGINT IDENTITY(1,1)  Primary Key,
            OrderKey          NVARCHAR( 10))
   
         SET @nErrNo = 0    
    
         SET @curUpdOrd = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR    
         SELECT DISTINCT O.OrderKey    
         FROM dbo.PICKDETAIL PD WITH (NOLOCK)    
         JOIN dbo.TaskDetail TD WITH (NOLOCK) ON ( PD.TaskDetailKey = TD.TaskDetailKey)    
         JOIN dbo.ORDERS O WITH (NOLOCK) ON ( PD.OrderKey = O.OrderKey)    
         WHERE TD.Storerkey = @cStorerKey    
         AND   TD.[Status] = '5'    
         AND   TD.Groupkey = @cGroupKey     
         AND   TD.DeviceID = @cCartID     
         AND   PD.[Status] = @cPickConfirmStatus    
         AND   O.Ecom_Single_flag = 'S'    
         AND   O.[Status] < '3'    
         ORDER BY 1    
         OPEN @curUpdOrd    
         FETCH NEXT FROM @curUpdOrd INTO @cOrderKey    
         WHILE @@FETCH_STATUS = 0    
         BEGIN    
         	IF EXISTS ( SELECT 1 
         	            FROM dbo.ORDERS WITH (NOLOCK)
         	            WHERE OrderKey = @cOrderKey
         	            AND   SOStatus = 'PENDCANC')
            BEGIN  
            	IF @nPENDCANC = 0
            	BEGIN
                  SET @nErrNo = 0  
                  SET @cErrMsg1 = 'ORDERS PENDCANC'  
                  EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1  
                  IF @nErrNo = 1  
                  BEGIN  
                     SET @nErrNo = 0
                     SET @cErrMsg = ''
                     SET @cErrMsg1 = ''  
                     SET @nPENDCANC = 1
                  END  
               END
            END  
      
            UPDATE dbo.ORDERS SET     
               [Status] = '3',     
               EditWho = SUSER_SNAME(),     
               EditDate = GETDATE()    
            WHERE OrderKey = @cOrderKey    
              
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 177302      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD ORDHd Fail'      
               GOTO RollBackTran     
            END    
            
            IF NOT EXISTS ( SELECT 1 FROM #OrderKey WHERE OrderKey = @cOrderKey)
               INSERT INTO #OrderKey(OrderKey) VALUES (@cOrderKey)
            
            FETCH NEXT FROM @curUpdOrd INTO @cOrderKey    
         END    

         SET @curUpdOrdDtl = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR    
         SELECT OD.OrderLineNumber    
         FROM dbo.ORDERDETAIL OD WITH (NOLOCK)    
         JOIN #OrderKey O WITH (NOLOCK) ON ( OD.OrderKey = O.OrderKey)    
         OPEN @curUpdOrdDtl    
         FETCH NEXT FROM @curUpdOrdDtl INTO @cOrderLineNumber    
         WHILE @@FETCH_STATUS = 0    
         BEGIN    
            UPDATE dbo.ORDERDETAIL SET     
               [Status] = '3',     
               EditWho = SUSER_SNAME(),     
               EditDate = GETDATE()    
            WHERE OrderKey = @cOrderKey    
            AND   OrderLineNumber = @cOrderLineNumber    
                 
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 177303      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD ORDDt Fail'      
               GOTO RollBackTran     
            END    
    
            FETCH NEXT FROM @curUpdOrdDtl INTO @cOrderLineNumber    
         END    
            
         COMMIT TRAN rdt_1855ExtUpd02    
    
         GOTO Commit_Tran    
    
         RollBackTran:    
            ROLLBACK TRAN rdt_1855ExtUpd02 -- Only rollback change made here    
         Commit_Tran:    
            WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
               COMMIT TRAN    
             
         GOTO Quit    
      END    
   END    
    **/
   IF @nStep = 5
   BEGIN
      IF @nInputKey = 1    
      BEGIN
         SELECT @cCartonId2Confirm = value FROM @tExtUpdate WHERE Variable = '@cCartonId2Confirm'
         -- overwrite original dropid
         IF @cCartonId <> @cCartonId2Confirm
         Begin
            UPDATE PICKDETAIL
            SET DropID = @cCartonId2Confirm               
            WHERE Storerkey = @cStorerKey
            AND TaskDetailKey = @cTaskdetailKey
            AND DropID = @cCartonId

            UPDATE TaskDetail
            SET DropID = @cCartonId2Confirm
            WHERE Storerkey = @cStorerKey
            AND TaskDetailKey = @cTaskdetailKey
            AND DropID = @cCartonId

         END
      End
   END

   IF @nStep = 7
   BEGIN
      IF @nInputKey = 1    
      BEGIN
         IF @cMethod = '3'
         BEGIN
            SELECT 
               @cOrderKey = TD.OrderKey,
               @cWaveKey = TD.WaveKey
            FROM Taskdetail TD WITH(NOLOCK)
            WHERE storerkey = @cStorerkey
            AND TD.taskdetailkey = @cTaskdetailKey

            IF NOT EXISTS(SELECT 1
                        FROM PickDetail PD WITH(NOLOCK)
                        INNER JOIN Orders ORD WITH(NOLOCK) ON PD.storerkey = ORD.storerkey AND PD.OrderKey = ORD.OrderKey
                        INNER JOIN MBOL MBL WITH(NOLOCK) ON  MBL.MBOLKey = ORD.MBOLKey
                        WHERE Pd.loc <> MBL.OtherReference
                        AND PD.OrderKey = @cOrderKey
                        AND PD.storerkey = @cStorerKey
                        )
            Begin
               SELECT TOP 1
                     @cOrderKey = TD.OrderKey
               FROM taskdetail TD WITH(NOLOCK)
               INNER JOIN Orders ORD WITH(NOLOCK) ON TD.storerkey = ORD.storerkey AND TD.OrderKey = ORD.OrderKey
               WHERE TD.WaveKey = @cWaveKey
               AND TD.storerkey = @cStorerkey
               AND TD.Status = 'S'
               AND TD.TaskType IN ('ASTCPK','FPK')
               -- only method 3
               AND Ord.UserDefine10 IN 
                  (SELECT  short  
                     FROM CodeLKUP WITH(NOLOCK) WHERE LISTNAME = 'HUSQPKTYPE' AND ISNULL(Code2,'') = '' AND StorerKey = @cStorerKey)
               ORDER BY ORD.DeliveryDate ASC

               IF ISNULL(@cOrderKey,'') <> ''
               BEGIN
                  UPDATE Taskdetail
                  SET status = '0'
                  WHERE storerkey = @cStorerkey
                  AND OrderKey = @cOrderKey
                  AND status = 'S'
                  AND TaskType IN ('ASTCPK','FPK')
               END
            END
         END
      END
      GOTO QUIT
   END
   
   Quit:                   
   IF @nErrNo <> 0    
      SET @nErrNo = -1    
END      
SET QUOTED_IDENTIFIER OFF 

GO