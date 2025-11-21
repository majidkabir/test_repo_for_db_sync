SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_1765DecodeLBL02                                 */  
/* Copyright      : LF                                                  */  
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
/* 23-03-2016  1.0  ChewKP      Created. SOS#366906                     */  
/************************************************************************/  
  
CREATE PROCEDURE [dbo].[rdt_1765DecodeLBL02]  
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
  
   SET @c_oFieled01 = @cUCCSKU  
   SET @c_oFieled05 = @nUCCQTY  
   SET @c_oFieled08 = @cUCCNo  
  
   --COMMIT TRAN rdt_1765DecodeLBL02  
   --GOTO Quit  
  
--RollBackTran:  
--   ROLLBACK TRAN rdt_1765DecodeLBL02  
--Quit:  
--   WHILE @@TRANCOUNT > @nTranCount  
--      COMMIT TRAN  
END -- End Procedure  

GO