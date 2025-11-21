SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_ActionByReason                                  */  
/*                                                                      */  
/* Purpose: Puma                                                        */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2024-07-14 1.0    JHU151   FCR-428. Created                          */  
/* 2024-11-08 1.1    YYS027   FCR-989 use @cFunc instead of @nFunc      */
/************************************************************************/  
CREATE   PROC [RDT].[rdt_ActionByReason] (
   @nMobile          INT,           
   @nFunc            INT,
   @cStorerKey       NVARCHAR(15), 
   @cSKU             NVARCHAR(20),
   @cLoc             NVARCHAR(10),
   @cLot             NVARCHAR(10),
   @cID              NVARCHAR(20),
   @cReasonCode      NVARCHAR(20),
   @nErrNo           INT            OUTPUT, 
   @cErrMsg          NVARCHAR(20)   OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
      @b_Success         INT,
      @n_continue        INT     

   DECLARE
      @cTaskDetailKeyCC  NVARCHAR(10),
      @cCCKey            NVARCHAR(10),
      @cCCTaskType       NVARCHAR(60),
      @cHoldCheckFlg     NVARCHAR(60),
      @cHoldType         NVARCHAR(60),
      @cPickDetailKey    NVARCHAR(50) = '',
      @cOrderKey         NVARCHAR(10) = '',
      @cLoadKey          NVARCHAR(10) = '',
      @cZone             NVARCHAR(18) = ''
   DECLARE 
      @cFunc             NVARCHAR(20)      
         
   SELECT @cFunc = CONVERT(NVARCHAR(20),@nFunc)
   SELECT 
      @cCCTaskType = UDF01,-- CC task type
      @cHoldType = UDF02, -- Hold type
      @cHoldCheckFlg = CASE WHEN ISNULL(UDF03,'') = 'X' THEN '1' ELSE '0' END
   FROM codelkup 
   WHERE listname = 'RDTREASON'
   AND code = @cFunc
   AND code2 = @cReasonCode
   AND storerkey = @cStorerKey

   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 219554
      SET @cErrMsg = CONVERT(NVARCHAR(6),@nErrNo)+ ' InvReasonCode' -- InvReasonCode
   END

   -- Generate CC task
   IF ISNULL(@cCCTaskType,'') <> ''
   BEGIN
      IF (ISNULL(RTRIM(@cCCTaskType),'')  IN ( 'CC' , 'CCSV', 'CCSUP'))
      BEGIN
         INSERT INTO TRACEINFO (Tracename , TimeIn, Step1 , Col1 )
         Values ( 'TMRSN', GETDATE(), 'TsKTYPE' , @cCCTaskType )


         EXECUTE dbo.nspg_getkey
         'TaskDetailKey'
         , 10
         , @cTaskDetailKeyCC OUTPUT
         , @b_success OUTPUT
         , @nErrNo     
         , @cErrMsg OUTPUT

         IF NOT @b_success = 1
         BEGIN
            SELECT @n_continue = 3
            SELECT @nErrNo = 219552
            SELECT @cErrMsg= CONVERT(NVARCHAR(6),@nErrNo)+ ' GetKeyFailed(rdt_ActionByReason)'
         END

         EXECUTE nspg_getkey
         'CCKey'
         , 10
         , @cCCKey OUTPUT
         , @b_success OUTPUT
         , @nErrNo    --OUTPUT Commented by NLT013, it overrides the old error no, if the error was not 0, but no error happens while executing this SP, error no will be updated as 0
         , @cErrMsg OUTPUT

         IF NOT @b_success = 1
         BEGIN
            SELECT @n_continue = 3
            SELECT @nErrNo = 219553
            SELECT @cErrMsg= CONVERT(NVARCHAR(6),@nErrNo)+ ' GetKeyFailed(rdt_ActionByReason)'
         END

         INSERT INTO dbo.TaskDetail
         (TaskDetailKey,TaskType,Storerkey,Sku,Lot,UOM,UOMQty,Qty,FromLoc,LogicalFromLoc,FromID,ToLoc,LogicalToLoc
         ,ToID,Caseid,PickMethod,Status,StatusMsg,Priority,SourcePriority,Holdkey,UserKey,UserPosition,UserKeyOverRide
         ,StartTime,EndTime,SourceType,SourceKey,PickDetailKey,OrderKey,OrderLineNumber,ListKey,WaveKey,ReasonKey
         ,Message01,Message02,Message03,RefTaskKey,LoadKey,AreaKey,DropID, SystemQty)
         SELECT 
         @cTaskDetailKeyCC,@cCCTaskType,@cStorerKey,@cSKU,'','',0,0,@cLoc,'','','',''
         ,'','','SKU','0','','1','1','','','',''
         ,GetDATE(),GetDATE(),'rdt_ActionByReason',@cCCKey,'','','','','',''
         ,'','','','','','', '', 0
         

         IF @@ERROR <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @nErrNo = 219551   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @cErrMsg= CONVERT(NVARCHAR(6),@nErrNo)+ 'InsTaskFailed'
         END
               
      END
   END

      -- Hold Type(LOC/ID/LOT)
   IF ISNULL(@cHoldType,'') IN ('LOC','LOT','ID')
   BEGIN

      IF @cHoldType = 'LOC'
      BEGIN
         SET @cLot = ''
         SET @cID = ''
      END
      ELSE IF @cHoldType = 'ID'
      BEGIN
         SET @cLoc = ''
         SET @cLot = ''
      END
      ELSE IF @cHoldType = 'LOT'
      BEGIN
         SET @cLoc = ''
         SET @cID = ''
      END
      
      EXEC dbo.nspInventoryHoldWrapper    
         @c_lot = @cLot   
         ,@c_Loc = @cLoc
         ,@c_ID  = @cID     
         ,@c_StorerKey    = @cStorerKey    
         ,@c_SKU          = ''    
         ,@c_Lottable01   = ''    
         ,@c_Lottable02   = ''    
         ,@c_Lottable03   = ''    
         ,@dt_Lottable04  = NULL    
         ,@dt_Lottable05  = NULL    
         ,@c_Lottable06   = ''    
         ,@c_Lottable07   = ''    
         ,@c_Lottable08   = ''    
         ,@c_Lottable09   = ''    
         ,@c_Lottable10   = ''    
         ,@c_Lottable11   = ''    
         ,@c_Lottable12   = ''    
         ,@dt_Lottable13  = NULL    
         ,@dt_Lottable14  = NULL    
         ,@dt_Lottable15  = NULL    
         ,@c_Status = @cReasonCode   
         ,@c_Hold = @cHoldCheckFlg   
         ,@b_success = @b_Success OUTPUT    
         ,@n_Err = @nErrNo OUTPUT    
         ,@c_Errmsg = @cErrMsg OUTPUT    
         ,@c_Remark  = ''
   END
Quit:
END


SET QUOTED_IDENTIFIER OFF

GO