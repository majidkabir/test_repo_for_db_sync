SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: isp_1764LblDecode03                                 */
/* Copyright      : LF                                                  */
/*                                                                      */
/* Purpose: Decode UCC No Scanned in VNA                                */
/*                                                                      */
/* Called from:                                                         */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 04-07-2018  1.0  Chew        WMS-5568 Created                        */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_1764LblDecode03]
   @c_LabelNo          NVARCHAR(40),
   @c_Storerkey        NVARCHAR(15),
   @c_ReceiptKey       NVARCHAR(10),
   @c_POKey            NVARCHAR(10),
   @c_LangCode	        NVARCHAR(3),
   @c_oFieled01        NVARCHAR(20) OUTPUT,
   @c_oFieled02        NVARCHAR(20) OUTPUT,
   @c_oFieled03        NVARCHAR(20) OUTPUT,
   @c_oFieled04        NVARCHAR(20) OUTPUT,
   @c_oFieled05        NVARCHAR(20) OUTPUT,
   @c_oFieled06        NVARCHAR(20) OUTPUT,
   @c_oFieled07        NVARCHAR(20) OUTPUT,
   @c_oFieled08        NVARCHAR(20) OUTPUT,
   @c_oFieled09        NVARCHAR(20) OUTPUT,
   @c_oFieled10        NVARCHAR(20) OUTPUT,
   @b_Success          INT = 1  OUTPUT,
   @n_ErrNo            INT      OUTPUT,
   @c_ErrMsg           NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nRowCount      INT

   DECLARE @cActSKU        NVARCHAR( 20)
 
   
   DECLARE @cTaskDetailKey NVARCHAR( 10)
   DECLARE @cTaskUOM       NVARCHAR( 5)
   DECLARE @cTaskLOT       NVARCHAR( 10)
   DECLARE @cTaskLOC       NVARCHAR( 10)
   DECLARE @cTaskID        NVARCHAR( 18)
   DECLARE @cTaskSKU       NVARCHAR( 20)
   DECLARE @nTaskQTY       INT
   DECLARE @nTaskSystemQTY INT
   DECLARE @cDropID        NVARCHAR(20)
   DECLARE @cQty           NVARCHAR(5)
         , @nCaseCnt       INT
         , @cPackKey       NVARCHAR(10)
         , @cTaskUCCNo     NVARCHAR(20)
         , @cUserName      NVARCHAR(18)
         , @cMQty          NVARCHAR(10)
         
   

   SET @n_ErrNo = 0
   SET @c_ErrMsg = 0

   SET @cActSKU = @c_LabelNo
   SET @cTaskDetailKey = @c_oFieled10

   
   -- Get task info
   SELECT
      @cTaskUCCNo = CaseID,
      @cTaskUOM = UOM, 
      @cTaskLOT = LOT,
      @cTaskLOC = FromLOC,
      @cTaskID = FromID, 
      @cTaskSKU = SKU, 
      @nTaskQTY = QTY, 
      @nTaskSystemQTY = SystemQTY,
      @cUserName  = UserKey 
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE TaskDetailKey = @cTaskDetailKey

   IF @@ROWCOUNT = 0
   BEGIN
      SET @n_ErrNo = 110402
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --BadTaskDtlKey
      RETURN
   END
   
   SELECT @cMQty = V_String17 
   FROM rdt.rdtMobRec WITH (NOLOCK) 
   WHERE UserName = @cUserName 
   AND StorerKey = @c_Storerkey 

   -- Get SKU barcode count  
   -- Get SKU barcode count  
   DECLARE @nSKUCnt INT  
   EXEC rdt.rdt_GETSKUCNT  
       @cStorerkey  = @c_Storerkey  
      ,@cSKU        = @cActSKU  
      ,@nSKUCnt     = @nSKUCnt       OUTPUT  
      ,@bSuccess    = @b_Success     OUTPUT  
      ,@nErr        = @n_ErrNo        OUTPUT  
      ,@cErrMsg     = @c_ErrMsg       OUTPUT  
   
   -- Check SKU/UPC  
   IF @nSKUCnt = 0  
   BEGIN  
      SET @n_ErrNo = 72277  
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') -- Invalid SKU  
      RETURN 
   END  
   
   -- Check multi SKU barcode  
   IF @nSKUCnt > 1  
   BEGIN  
      SET @n_ErrNo = 72278  
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') -- MultiSKUBarCod  
      RETURN 
   END  
   
   -- Get SKU code  
   EXEC rdt.rdt_GETSKU  
       @cStorerkey  = @c_Storerkey  
      ,@cSKU        = @cActSKU       OUTPUT  
      ,@bSuccess    = @b_Success     OUTPUT  
      ,@nErr        = @n_ErrNo        OUTPUT  
      ,@cErrMsg     = @c_ErrMsg       OUTPUT  
   
   -- Check SKU same as suggested  
   IF @cActSKU <> @cTaskSKU  
   BEGIN  
      SET @n_ErrNo = 72279  
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') -- Different SKU  
      RETURN
   END  
   
   SELECT @cPackKey = PackKey 
   FROM dbo.SKU WITH (NOLOCK) 
   WHERE StorerKey = @c_Storerkey 
   AND SKU = @cActSKU
   
   SELECT @nCaseCnt = CaseCnt
   FROM dbo.Pack WITH (NOLOCK) 
   WHERE PackKey = @cPackKey
   
   
   IF @nTaskQTY % @nCaseCnt = 0 
      SET @cQty = @nTaskQty 
   ELSE
      SET @cQty = '' 
   
   
   INSERT INTO TRACEINFO ( TraceName , TimeIn , Step1, Col1, Col2, Col3, Col4, Col5, Step2   )
   VALUES ( 'UARPF' , GETDATE() , 'Decode' , @cTaskDetailKey, @cActSKU, @nTaskQty , @nCaseCnt, @cQty, @cMQty )
            
   SET @c_oFieled01 = @cActSKU
   SET @c_oFieled05 = @cQty
   SET @c_oFieled08 = ''--@cActUCCNo

   -- Get actual PickDetail info
   --SET @nRowCount = @@ROWCOUNT

--CommitTran:
--   COMMIT TRAN isp_1764LblDecode03
--   GOTO Quit

--RollBackTran:
--   ROLLBACK TRAN isp_1764LblDecode03
--Quit:
--   WHILE @@TRANCOUNT > @nTranCount
--      COMMIT TRAN
END -- End Procedure



GO