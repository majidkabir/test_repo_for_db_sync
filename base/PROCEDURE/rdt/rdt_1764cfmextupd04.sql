SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  

/************************************************************************/
/* Store procedure: rdt_1764CfmExtUpd04                                 */
/* Purpose: 1. Stamp TaskDetail.CaseID as UCCNo                         */
/*          2. Stamp PickDetail.DropID as UCCNo                         */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2021-09-22   yeekung   1.0   WMS-17488 Created                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1764CfmExtUpd04]
    @nMobile            INT 
   ,@nFunc              INT 
   ,@cLangCode          NVARCHAR( 3) 
   ,@cTaskdetailKey     NVARCHAR( 10) 
   ,@cNewTaskdetailKey  NVARCHAR( 10) 
   ,@nErrNo             INT           OUTPUT 
   ,@cErrMsg            NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cPickDetailKey NVARCHAR(10)
   DECLARE @cPickMethod    NVARCHAR(10)
   DECLARE @cUCCNo         NVARCHAR(20)
          ,@cStorerKey     NVARCHAR(15) 
   DECLARE @cWebServicePTS NVARCHAR(1),
           @cWavekey       NVARCHAR(20),
           @bSuccess       INT,
           @cShort         NVARCHAR(20),
           @cFacility      NVARCHAR(20)

   -- Get orginal task info
   SELECT 
       @cPickMethod = PickMethod
      ,@cStorerKey  = StorerKey 
   FROM TaskDetail WITH (NOLOCK) 
   WHERE TaskDetailKey = @cTaskdetailKey

   SELECT @cFacility=FACILITY
   FROM rdt.RDTMOBREC
   WHERE mobile=@nMobile

   -- FP, does not close pallet or short
   IF @cPickMethod = 'FP'
      RETURN

   -- Get UCC
   SELECT @cUCCNo = UCCNo FROM rdt.rdtRPFLog WITH (NOLOCK) WHERE TaskDetailKey = @cTaskDetailKey
   
   
   DECLARE @nTranCount  INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_1764CfmExtUpd04

   -- Loop PickDetail for original task
   IF ISNULL(@cUCCNo, '' ) <> '' 
   BEGIN
   
      -- Update task
      UPDATE TaskDetail WITH (ROWLOCK)  SET
         finalloc= toloc,
         CaseID = ISNULL(@cUCCNo,''), 
         EditWho  = SUSER_SNAME(), 
         EditDate = GETDATE(),
         Trafficcop = NULL
      WHERE TaskDetailKey = @cTaskDetailKey
      
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 175851
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Task Fail
         GOTO RollBackTran
      END
      

   END

   -- Get storer config      
   EXEC nspGetRight    
      @c_Facility   = @cFacility      
   ,  @c_StorerKey  = @cStorerKey     
   ,  @c_sku        = ''           
   ,  @c_ConfigKey  = 'WSPTS'     
   ,  @b_Success    = @bSuccess  OUTPUT    
   ,  @c_authority  = @cWebServicePTS   OUTPUT     
   ,  @n_err        = @nErrNo    OUTPUT    
   ,  @c_errmsg     = @cErrMsg   OUTPUT  

   IF @cWebServicePTS='1'
   BEGIN
      SELECT @cwavekey = w.wavekey 
      FROM dbo.TaskDetail TD (NOLOCK) JOIN wave W (NOLOCK)
      ON TD.WaveKey=W.WaveKey
      WHERE taskdetailkey = @cTaskdetailKey
      AND td.Message03='PTS'
      AND w.UserDefine01 IN('PTS-sent','PTS')

      SELECT 
         @cShort = short 
      FROM codelkup WITH (NOLOCK) 
      WHERE storerKey = @cStorerKey 
      AND listName = 'WSPTSITF'
      AND code = @nFunc

      IF ISNULL(@cwavekey,'')<>''
      BEGIN
         SET @bSuccess = 1    
         EXEC ispGenTransmitLog2     
            @c_TableName         = @cShort   
            ,@c_Key1             = @cwavekey    
            ,@c_Key2             = @cTaskDetailKey    
            ,@c_Key3             = @cStorerkey    
            ,@c_TransmitBatch    = ''    
            ,@b_Success          = @bSuccess    OUTPUT    
            ,@n_err              = @nErrNo      OUTPUT    
            ,@c_errmsg           = @cErrMsg     OUTPUT  
      END
   END   
   COMMIT TRAN rdt_1764CfmExtUpd04 -- Only commit change made here
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1764CfmExtUpd04 -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO