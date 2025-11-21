SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: ispANFPADecode                                      */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Purpose: Decode Label No Scanned - rdtfnc_Putaway                    */    
/*                                                                      */    
/* Called from:                                                         */    
/*                                                                      */    
/* Exceed version: 5.4                                                  */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date        Rev  Author      Purposes                                */    
/* 14-05-2014  1.0  Shong       Created                                 */   
/* 22-05-2014  1.1  Chee        UCC Status already 6 after ReplenFrom / */   
/*                              Sort&Pack (Chee01)                      */
/************************************************************************/    
    
CREATE PROCEDURE [dbo].[ispANFPADecode]    
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
    
   SET @n_ErrNo = 0    
   SET @c_ErrMsg = 0    
    
   IF EXISTS(SELECT 1 FROM SKU WITH (NOLOCK) WHERE StorerKey = @c_Storerkey AND SKU = @c_LabelNo)  
   BEGIN  
      SET @c_oFieled01 = @c_LabelNo  
      SET @c_oFieled07 = ''  
      RETURN   
   END  
     
   -- Get UCC record    
   SELECT @nRowCount = COUNT( 1)    
   FROM dbo.UCC WITH (NOLOCK)    
   WHERE UCCNo = @c_LabelNo    
     AND StorerKey = @c_Storerkey    
    
   -- Check label scanned is UCC    
   IF @nRowCount = 0    
   BEGIN    
      SET @c_oFieled01 = @c_LabelNo -- SKU    
      SET @c_oFieled05 = 0          -- UCC QTY    
      SET @c_oFieled08 = ''         -- UCC QTY    
      RETURN    
   END    
    
   -- Check multi SKU UCC    
   IF @nRowCount > 1    
   BEGIN    
      SET @n_ErrNo = 84552    
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --Multi SKU UCC    
      RETURN    
   END    
    
   -- Get scanned UCC info    
   SELECT    
      @cUCCNo = UCCNo,    
      @cUCCSKU = SKU,    
      @cUCCLOC = LOC,    
      @cUCCStatus = Status    
   FROM dbo.UCC WITH (NOLOCK)    
   WHERE UCCNo = @c_LabelNo    
     AND StorerKey = @c_Storerkey    
    
   -- Check UCC status    
   IF @cUCCStatus NOT IN ('6') --('1', '3')  (Chee01) 
   BEGIN    
      SET @n_ErrNo = 84554    
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --Bad UCC Status    
      RETURN    
   END    
    
   SET @c_oFieled07 = @cUCCLOC   
   SET @c_oFieled01 = @cUCCSKU   
     
END -- End Procedure    

GO