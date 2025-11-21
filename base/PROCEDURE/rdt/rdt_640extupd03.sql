SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_640ExtUpd03                                     */  
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Display special instrution (orders.notes2)                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date         Author    Ver.  Purposes                                */  
/* 2023-04-19   James     1.0   WMS-22212 Created                       */  
/************************************************************************/  
  
CREATE   PROCEDURE [RDT].[rdt_640ExtUpd03]  
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
   
   DECLARE @nTranCount           INT
   DECLARE @cWaveKey             NVARCHAR( 10)
   DECLARE @cErrMsg1             NVARCHAR( 20)
   DECLARE @curUpdPick           CURSOR
   DECLARE @curUpdPack           CURSOR
   DECLARE @cPickDetailKey       NVARCHAR( 10)
   DECLARE @cDropID              NVARCHAR( 20)
   DECLARE @cPickConfirmStatus   NVARCHAR( 1)
   DECLARE @cPickSlipNo          NVARCHAR( 10)
   DECLARE @nCartonNo            INT
   DECLARE @cLabelLine           NVARCHAR( 5)
   DECLARE @curPackH             CURSOR
   DECLARE @cOrderKey            NVARCHAR( 10)
   DECLARE @cDeviceID            NVARCHAR( 20)
   
   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)    
   IF @cPickConfirmStatus = '0'    
      SET @cPickConfirmStatus = '5'    

   
   IF @nStep = 1
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SELECT TOP 1 @cDeviceID = DeviceID
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE Groupkey = @cGroupKey
         AND   [Status] < '9'
         ORDER BY 1

         IF EXISTS ( SELECT 1 
                     FROM dbo.DeviceProfile DP WITH (NOLOCK)
                     WHERE DeviceID = @cDeviceID
                     AND   DeviceType = 'CART'
      	            AND   StorerKey = @cStorerKey
                     AND   EXISTS ( SELECT 1 
                                    FROM dbo.PackDetail PD WITH (NOLOCK)
                                    JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickSlipNo = PH.PickSlipNo)
                                    WHERE PD.StorerKey = @cStorerKey
                                    AND   PD.DropID = DP.DevicePosition))
                                    --AND   PH.[Status] < '9'))
         BEGIN          
            SET @nErrNo = 200201          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Carton In Use          
            GOTO Quit          
         END
         
      	IF EXISTS ( SELECT 1 
      	            FROM dbo.TaskDetail TD WITH (NOLOCK)
      	            JOIN dbo.PICKDETAIL PD WITH (NOLOCK) ON ( TD.TaskDetailKey = PD.TaskDetailKey)
      	            JOIN dbo.ORDERS O WITH (NOLOCK) ON ( PD.OrderKey = O.OrderKey)
      	            WHERE TD.TaskDetailKey = @cTaskDetailKey)
         BEGIN
            SELECT @cWaveKey = WaveKey
            FROM dbo.TaskDetail WITH (NOLOCK)
            WHERE TaskDetailKey = @cTaskDetailKey

            SET @cErrMsg1 = @cWaveKey
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
            IF @nErrNo = 1  
            BEGIN  
               SET @cErrMsg1 = ''  
            END  
               
            SET @nErrNo = 0
            
            GOTO Quit
         END
      END
   END

   -- Handling transaction            
   SET @nTranCount = @@TRANCOUNT            
   BEGIN TRAN  -- Begin our own transaction            
   SAVE TRAN rdt_640ExtUpd03 -- For rollback or commit only our own transaction            
   
   SELECT 
      @nStep = Step, -- current step
      @cTaskDetailKey = V_TaskDetailKey -- current taskdetailkey
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile
   
   IF @nStep = 5  OR @nStep = 6
   BEGIN
   	IF @nInputKey = 1
   	BEGIN
   		-- Check everything picked for this carton
   		IF NOT EXISTS ( SELECT 1 
   		                FROM dbo.TaskDetail TD WITH (NOLOCK)
   		                JOIN dbo.PICKDETAIL PD WITH (NOLOCK) ON ( TD.TaskDetailKey = PD.TaskDetailKey)
   		                WHERE TD.Storerkey = @cStorerKey
   		                AND   TD.TaskType = 'CPK'
   		                AND   TD.Groupkey = @cGroupKey
   		                AND   TD.Caseid = @cCartonId
   		                AND   PD.Status <> '4' --Short Pick status
   		                AND   PD.Status < @cPickConfirmStatus)
         BEGIN
         	SELECT @cDropID = Dropid
         	FROM dbo.TaskDetail WITH (NOLOCK)
         	WHERE TaskDetailKey = @cTaskDetailKey

            SET @curUpdPack = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT PickSlipNo, CartonNo, LabelLine
            FROM dbo.PackDetail WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND   LabelNo = @cCartonId
            OPEN @curUpdPack
            FETCH NEXT FROM @curUpdPack INTO @cPickSlipNo, @nCartonNo, @cLabelLine
            WHILE @@FETCH_STATUS = 0
            BEGIN
            	UPDATE dbo.PackDetail SET 
            	   DropID = @cDropID, 
            	   EditWho = SUSER_NAME(), 
            	   EditDate = GETDATE()
            	WHERE PickSlipNo = @cPickSlipNo
            	AND   CartonNo = @nCartonNo
            	AND   LabelNo = @cCartonId
            	AND   LabelLine = @cLabelLine
            	
            	IF @@ERROR <> 0
               BEGIN          
                  SET @nErrNo = 200202          
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Upd DropId Err          
                  GOTO RollBackTran          
               END

            	FETCH NEXT FROM @curUpdPack INTO @cPickSlipNo, @nCartonNo, @cLabelLine
            END
         END
   	END
   END

   COMMIT TRAN rdt_640ExtUpd03

   GOTO Commit_Tran

   RollBackTran:
      ROLLBACK TRAN rdt_640ExtUpd03 -- Only rollback change made here
   Commit_Tran:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN
          
   Quit:               

END  
SET QUOTED_IDENTIFIER OFF 

GO