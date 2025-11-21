SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_SKUInquiry_Update                               */
/*                                                                      */
/* Purpose: Update sku info                                             */
/*                                                                      */
/* Called from: rdtfnc_SKUInquiry                                       */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2022-06-22 1.0  James      WMS20022. Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_SKUInquiry_Update] (
   @nMobile       INT,
   @nFunc         INT, 
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nInputKey     INT,
   @cStorerKey    NVARCHAR( 15), 
   @cFacility     NVARCHAR( 5), 
   @cInquiry_SKU  NVARCHAR( 20), 
   @cCaseUOM      NVARCHAR( 5), 
   @cEAUOM        NVARCHAR( 5), 
   @cCS_PL        NVARCHAR( 5),  
   @cEA_CS        NVARCHAR( 5), 
   @cPickLOC      NVARCHAR( 10),   
   @cMin          NVARCHAR( 5), 
   @cMax          NVARCHAR( 5), 
   @tSKUInqUpdate VARIABLETABLE READONLY,
   @nErrNo        INT           OUTPUT,  
   @cErrMsg       NVARCHAR(250) OUTPUT    
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @cSKUInquiryUpdate NVARCHAR( 10)
   DECLARE @cPackKey          NVARCHAR( 10)
   DECLARE @nCaseCnt          INT = 0
   DECLARE @nQtyOnHold        INT = 0
   DECLARE @nQtyAllocated     INT = 0
   DECLARE @nQtyAvailable     INT = 0
   DECLARE @nQtyOnHand        INT = 0
   DECLARE @nAllowUpdate      INT = 0
   DECLARE @cErrMsg1          NVARCHAR( 20) = ''
   
   SET @nErrNo = 0
   
   -- Handling transaction
   DECLARE @nTranCount  INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_SKUInquiry_Update -- For rollback or commit only our own transaction
                                        --    
   SET @cSKUInquiryUpdate = rdt.RDTGetConfig( @nFunc, 'SKUInquiryUpdate', @cStorerKey)  

   -- Case Cnt
   IF CHARINDEX( 'C', @cSKUInquiryUpdate) > 0
   BEGIN
   	SELECT
   	   @cPackKey = PACK.PackKey, 
   	   @nCaseCnt = PACK.CaseCnt
   	FROM dbo.PACK PACK WITH (NOLOCK)
   	JOIN dbo.SKU SKU WITH (NOLOCK) ON PACK.PackKey = SKU.PACKKey
   	WHERE  SKU.StorerKey = @cStorerKey
   	AND    SKU.Sku = @cInquiry_SKU
   	   
   	IF @nCaseCnt IN ( 0, 1)
   	BEGIN
   		-- no inventory exists, allow modify casecnt
   		IF EXISTS ( SELECT 1 FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
   		            JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.Loc = LOC.Loc)
   		            WHERE LLI.StorerKey = @cStorerKey
                     AND   LLI.SKU = @cInquiry_SKU
                     AND  (LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - ABS( LLI.QTYReplen)) = 0
                     AND   LOC.Facility = @cFacility)
   	      SET @nAllowUpdate = 1
 		   -- inventory exists in stage and pick, allow modify casecnt
   	   ELSE IF EXISTS ( SELECT 1 FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
   		                 JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.Loc = LOC.Loc)
   		                 JOIN dbo.SKUxLOC SL WITH (NOLOCK) ON ( LOC.LOC = SL.Loc)
   		                 WHERE LLI.StorerKey = @cStorerKey
                          AND   LLI.SKU = @cInquiry_SKU
                          AND  (LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - ABS( LLI.QTYReplen)) > 0
                          AND   LOC.Facility = @cFacility
   		                 AND   (( SL.LocationType = 'PICK') OR ( LOC.LocationType IN ( 'PICK', 'STAGING'))))
   	      SET @nAllowUpdate = 1
   	   ELSE
   	   	SET @nAllowUpdate = 0
   	   	

         IF @nAllowUpdate = 1
         BEGIN
            UPDATE dbo.Pack SET
               CaseCnt = @cEA_CS,
               EditWho = SUSER_SNAME(),
               EditDate = GETDATE()
            WHERE PackKey = @cPackKey
            
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 187551
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD CASECNT ER
               GOTO RollbackTran
            END

            SET @cErrMsg1 = rdt.rdtgetmessage( 187552, @cLangCode, 'DSP') -- SKU CASECNT UPDATED 
            SET @nErrNo = 0  
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1  
            IF @nErrNo = 1  
            BEGIN  
               SET @cErrMsg1 = ''  
               SET @cErrMsg = ''
               SET @nErrNo = -1  -- set -1 here to make the sku alert screen not appear  
            END           
         END
      END
   END
   
   COMMIT TRAN rdt_SKUInquiry_Update
   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN rdt_SKUInquiry_Update -- Only rollback change made here
   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN


GO