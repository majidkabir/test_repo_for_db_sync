SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_1765DecodeLBL03                                 */  
/* Copyright      : LF                                                  */  
/*                                                                      */  
/* Date        Rev  Author      Purposes                                */  
/* 16-03-2018  1.0  Ung         WMS-3935 Created                        */
/************************************************************************/  
  
CREATE PROCEDURE [dbo].[rdt_1765DecodeLBL03]  
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
   DECLARE @cUCCLOC        NVARCHAR( 10)  
   DECLARE @cUCCID         NVARCHAR( 18)  
   DECLARE @nUCCQTY        INT  
  
   DECLARE @cTaskDetailKey NVARCHAR( 10)  
   DECLARE @cTaskLOC       NVARCHAR( 10)  
   DECLARE @cTaskID        NVARCHAR( 18)  
   DECLARE @cCaseID        NVARCHAR( 20)  

   DECLARE @nFunc          INT
   DECLARE @cLangCode      NVARCHAR( 3)
   DECLARE @cSwapUCC       NVARCHAR( 1)
   DECLARE @cNewTaskDetailKey NVARCHAR( 10)  

   SET @n_ErrNo = 0  
   SET @c_ErrMsg = 0  
  
   -- Parameter mapping
   SET @cTaskDetailKey = @c_oFieled10  
   
   -- Get original task info
   SELECT
      @cTaskLOC = FromLOC, 
      @cTaskID = FromID, 
      @cCaseID = CaseID
   FROM TaskDetail WITH (NOLOCK)
   WHERE TaskDetailKey = @cTaskDetailKey

   -- Get UCC info
   SELECT  
      @cUCCNo = UCCNo,  
      @cUCCSKU = SKU,  
      @nUCCQTY = QTY,  
      @cUCCLOC = LOC,  
      @cUCCID = ID
   FROM dbo.UCC WITH (NOLOCK)  
   WHERE UCCNo = @c_LabelNo  
      AND StorerKey = @c_Storerkey  

   -- Different UCC
   IF @cCaseID <> @c_LabelNo
   BEGIN
      -- Get session info
      SELECT 
         @nFunc = Func, 
         @cLangCode = Lang_Code
      FROM rdt.rdtMobRec WITH (NOLOCK) 
      WHERE UserName = SUSER_SNAME()

      -- Storer configure
      SET @cSwapUCC = rdt.RDTGetConfig( @nFunc, 'SwapUCC', @c_StorerKey)
   
      -- Swap UCC
      IF @cSwapUCC <> '1'
      BEGIN
         SET @n_ErrNo = 121301     
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @cLangCode, 'DSP') --Diff UCC
         GOTO Quit
      END  
      
      -- Check LOC
      IF @cTaskLOC <> @cUCCLOC
      BEGIN
         SET @n_ErrNo = 121302     
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @cLangCode, 'DSP') --UCC Diff LOC
         GOTO Quit
      END 

      -- Check ID
      IF @cTaskID <> @cUCCID
      BEGIN
         SET @n_ErrNo = 121303     
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @cLangCode, 'DSP') --UCC Diff ID
         GOTO Quit
      END 

      -- Check UCC on ID
      SELECT @cNewTaskDetailKey = TaskDetailKey
      FROM TaskDetail WITH (NOLOCK)
      WHERE StorerKey = @c_StorerKey
         AND TaskType = 'RPT'
         AND FromLOC = @cTaskLOC
         AND FromID = @cTaskID
         AND CaseID = @c_LabelNo
         AND Status = '3'

      -- Check UCC have task
      IF @@ROWCOUNT = 0
      BEGIN
         SET @n_ErrNo = 121304     
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @cLangCode, 'DSP') --UCC no task
         GOTO Quit
      END
      
      SET @c_oFieled10 = @cNewTaskDetailKey
   END

   SET @c_oFieled01 = @cUCCSKU  
   SET @c_oFieled05 = @nUCCQTY  
   SET @c_oFieled08 = @cUCCNo  

Quit:

END

GO