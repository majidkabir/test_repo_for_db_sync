SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_1765DecodeLBL01                                 */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Decode Label No Scanned                                     */  
/*                                                                      */  
/* Called from:                                                         */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author      Purposes                                */  
/* 26-06-2014  1.0  ChewKP      Created                                 */  
/************************************************************************/  
  
CREATE PROCEDURE [dbo].[rdt_1765DecodeLBL01]  
   @c_LabelNo          NVARCHAR(40),  
   @c_Storerkey        NVARCHAR(15),  
   @c_ReceiptKey       NVARCHAR(10),  
   @c_POKey            NVARCHAR(10),  
   @c_LangCode         NVARCHAR(3),  
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
  
   DECLARE @cUCCNo         NVARCHAR( 20)  
   DECLARE @cUCCSKU        NVARCHAR( 20)  
   DECLARE @cUCCLOT        NVARCHAR( 10)  
   DECLARE @cUCCLOC        NVARCHAR( 10)  
   DECLARE @cUCCID         NVARCHAR( 18)  
   DECLARE @cUCCStatus     NVARCHAR( 1)  
   DECLARE @nUCCQTY        INT  
  
   DECLARE @cTaskDetailKey NVARCHAR( 10)  
   DECLARE @cLOT           NVARCHAR( 10)  
   DECLARE @cLOC           NVARCHAR( 10)  
   DECLARE @cID            NVARCHAR( 18)  
   DECLARE @cDropID        NVARCHAR( 20)  
   DECLARE @cCaseID        NVARCHAR( 20)  
          ,@cListKey       NVARCHAR( 10)
          ,@cSourceKey     NVARCHAR( 30)
          ,@cTransferKey   NVARCHAR( 10)
          ,@cTrasferLineNumber NVARCHAR(5)
          ,@cRefSourceKey  NVARCHAR( 30)
  
   SET @n_ErrNo = 0  
   SET @c_ErrMsg = 0  
  
   SET @cDropID = @c_oFieled09  
   SET @cTaskDetailKey = @c_oFieled10  
   
   -- Get TransferKey
   SELECT @cRefSourceKey = SourceKey
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE TaskDetailKey = @cTaskDetailKey

   SELECT @cSourceKey = SourceKey
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE TaskDetailKey = @cRefSourceKey
   AND TaskType        = 'RPF'
   AND CaseID          = @c_LabelNo

   SET @cTransferKey       = Substring(@cSourceKey , 1 , 10) 
   SET @cTrasferLineNumber = Substring(@cSourceKey , 11 , 15 ) 

  
   -- Get UCC record  
   SELECT @nRowCount = COUNT( 1)  
   FROM dbo.UCC WITH (NOLOCK)  
   WHERE UCCNo = @c_LabelNo  
      AND StorerKey = @c_Storerkey  
  
   -- Check label scanned is UCC  
   IF @nRowCount = 0  
   BEGIN  
      SET @c_oFieled01 = '' -- SKU  
      SET @c_oFieled05 = 0  -- UCC QTY  
      SET @c_oFieled08 = '' -- UCC QTY  
  
      SET @n_ErrNo = 90601  
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --Not an UCC  
      RETURN  
   END  
  
   -- Check multi SKU UCC  
   IF @nRowCount > 1  
   BEGIN  
      SET @n_ErrNo = 90602  
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --Multi SKU UCC  
      RETURN  
   END  
  
   -- Get scanned UCC info  
   SELECT  
      @cUCCNo = UCCNo,  
      @cUCCSKU = SKU,  
      @nUCCQTY = QTY,  
      @cUCCLOT = LOT,  
      @cUCCLOC = LOC,  
      @cUCCID = ID,   
      @cUCCStatus = Status  
   FROM dbo.UCC WITH (NOLOCK)  
   WHERE UCCNo = @c_LabelNo  
      AND StorerKey = @c_Storerkey  
  
   -- Get task info  
   SELECT  
      @cCaseID = CaseID,   
      @cLOT = LOT,  
      @cLOC = FromLOC,  
      @cID = FromID  
   FROM dbo.TaskDetail WITH (NOLOCK)  
   WHERE TaskDetailKey = @cTaskDetailKey  
   IF @@ROWCOUNT = 0  
   BEGIN  
      SET @n_ErrNo = 90609  
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --BadTaskDtlKey  
      RETURN  
   END  
   
  
   -- Check UCC status  
   IF @cUCCStatus NOT IN ('1', '3')  
   BEGIN  
      SET @n_ErrNo = 90603  
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --Bad UCC Status  
      RETURN  
   END  
  
   -- Check UCC LOC match  
   IF @cLOC <> @cUCCLOC  
   BEGIN  
      SET @n_ErrNo = 90604  
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UCCLOCNotMatch  
      RETURN  
   END  
  
   -- Check UCC ID match  
   IF @cID <> @cUCCID  
   BEGIN  
      SET @n_ErrNo = 90605  
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UCCIDNotMatch  
      RETURN  
   END  
  
   -- Check UCC LOT match  
   IF @cLOT <> @cUCCLOT  
   BEGIN  
      SET @n_ErrNo = 90606  
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UCCLOTNotMatch  
      RETURN  
   END  
   
   IF @c_LabelNo <> @cCaseID
   BEGIN
      SET @n_ErrNo = 90610  
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UCCNotMatch  
      RETURN  
   END
  
   -- Get UCC hold by ID  
--   IF EXISTS( SELECT TOP 1 1 FROM InventoryHold WITH (NOLOCK) WHERE ID = @cUCCID AND Status = '1')  
--   BEGIN  
--      IF @cCaseID = @c_LabelNo  
--      BEGIN  
--         SET @c_oFieled01 = @cUCCSKU  
--         SET @c_oFieled05 = @nUCCQTY  
--         SET @c_oFieled08 = @cUCCNo  
--      END  
--      BEGIN  
--         SET @n_ErrNo = 84570  
--         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UCC not match  
--      END  
--      RETURN  
--   END  
--  
   -- Get suggested UCC QTY  
   DECLARE @nSuggQTY INT  
   SELECT TOP 1   
      @nSuggQTY = UCC.QTY  
   FROM TransferDetail TD WITH (NOLOCK)  
      JOIN UCC WITH (NOLOCK) ON (TD.UserDefine01 = UCC.UCCNo)  
   WHERE TD.TransferKey = @cTransferKey
     AND TD.TransferLineNumber = @cTrasferLineNumber
     AND TD.UserDefine01 = @c_LabelNo
--      AND T.Status = '0'  
--      AND T.QTY > 0  
   ORDER BY TD.TransferKey

--   SET @n_Errno = 1
--   SET @c_ErrMsg = @cSourceKey
--   RETURN


   -- Check UCC on task  
   IF @@ROWCOUNT = 0  
   BEGIN  
      SET @n_ErrNo = 90607  
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --Over replenish  
      RETURN  
   END  
  
   -- Check UCC QTY match  
   IF @nSuggQTY <> @nUCCQTY  
   BEGIN  
      SET @n_ErrNo = 90608  
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UCCQTYNotMatch  
      RETURN  
   END  
  
   -- Check UCC taken by other task  
--   IF EXISTS( SELECT TOP 1 1  
--      FROM UCC WITH (NOLOCK)  
--         JOIN PickDetail PD WITH (NOLOCK) ON (UCC.UCCNo = PD.DropID)  
--      WHERE UCC.StorerKey = @c_StorerKey  
--         AND PD.StorerKey = @c_StorerKey  
--         AND UCC.UCCNo = @cUCCNo  
--         AND PD.Status > '0'  
--         AND PD.QTY > 0)  
--   BEGIN  
--      SET @n_ErrNo = 84560  
--      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --UCCTookByOther  
--      RETURN  
--   END  
  
  
--CommitTran:  
   -- Log UCC swap  
  
  
   SET @c_oFieled01 = @cUCCSKU  
   SET @c_oFieled05 = @nUCCQTY  
   SET @c_oFieled08 = @cUCCNo  
  
   --COMMIT TRAN rdt_1765DecodeLBL01  
   --GOTO Quit  
  
--RollBackTran:  
--   ROLLBACK TRAN rdt_1765DecodeLBL01  
--Quit:  
--   WHILE @@TRANCOUNT > @nTranCount  
--      COMMIT TRAN  
END -- End Procedure  

GO