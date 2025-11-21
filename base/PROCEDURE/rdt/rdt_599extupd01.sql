SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_599ExtUpd01                                     */    
/* Copyright      : LF Logistics                                        */  
/*                                                                      */  
/* Purpose: Send picked interface to WCS                                */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date         Author    Ver.  Purposes                                */    
/* 2021-10-18   James     1.0   WMS-18084 Created                       */    
/* 2022-03-11   James     1.1   WMS-19126 Add option to decide whether  */
/*                              reverse by id or sku (james01)          */
/* 2022-04-05   James     1.2   Addhoc bug fix (james02)                */
/************************************************************************/    
    
CREATE   PROCEDURE [RDT].[rdt_599ExtUpd01]    
   @nMobile        INT,  
   @nFunc          INT,  
   @cLangCode      NVARCHAR( 3),  
   @nStep          INT,  
   @nInputKey      INT,  
   @cFacility      NVARCHAR( 5),  
   @cStorerKey     NVARCHAR( 15),  
   @cReceiptKey    NVARCHAR( 10),  
   @cID            NVARCHAR( 18),  
   @cSKU           NVARCHAR( 20),  
   @nQty           INT,  
   @cLottable01    NVARCHAR( 18),  
   @cLottable02    NVARCHAR( 18),  
   @cLottable03    NVARCHAR( 18),  
   @dLottable04    DATETIME,       
   @dLottable05    DATETIME,       
   @cLottable06    NVARCHAR( 30),  
   @cLottable07    NVARCHAR( 30),  
   @cLottable08    NVARCHAR( 30),  
   @cLottable09    NVARCHAR( 30),  
   @cLottable10    NVARCHAR( 30),  
   @cLottable11    NVARCHAR( 30),  
   @cLottable12    NVARCHAR( 30),  
   @dLottable13    DATETIME,       
   @dLottable14    DATETIME,       
   @dLottable15    DATETIME,       
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
   DECLARE @nRowRef        INT  
   DECLARE @nUCC_RowRef    INT  
   DECLARE @cUCCNo         NVARCHAR( 20)  
   DECLARE @cur_PreSort    CURSOR  
   DECLARE @cur_UCC        CURSOR  
   DECLARE @cur_RD         CURSOR
   DECLARE @nReverve_ByID  INT
   DECLARE @cRD_Line       NVARCHAR( 5)
   
   SET @nErrNo = 0  
     
   -- Handling transaction              
   SET @nTranCount = @@TRANCOUNT              
   BEGIN TRAN  -- Begin our own transaction              
   SAVE TRAN rdt_599ExtUpd01 -- For rollback or commit only our own transaction              
              
   IF @nStep = 4  
   BEGIN  
      IF @nInputKey = 1  
      BEGIN  
      	IF @cOption = '1'
      	BEGIN
            IF ISNULL( @cID, '') = ''  
            BEGIN  
               SET @nErrNo = 178901    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Pallet req'    
               GOTO RollBackTran      
            END  
            
            SET @nReverve_ByID = 1
      	END
         ELSE
      	BEGIN
            IF ISNULL( @cSKU, '') = ''  
            BEGIN  
               SET @nErrNo = 178904    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SKU req'    
               GOTO RollBackTran      
            END  
            
            SET @nReverve_ByID = 0
      	END
         	
         DECLARE @tUCC TABLE  
         (  
            Seq       INT IDENTITY(1,1) NOT NULL,  
            UCCNo     NVARCHAR( 20)  
         )  
           
         SET @cur_PreSort = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR  
         SELECT RowRef, UCCNo  
         FROM rdt.rdtPreReceiveSort WITH (NOLOCK)  
         WHERE Storerkey = @cStorerKey  
         AND   ReceiptKey = @cReceiptKey  
         AND   (( @nReverve_ByID = 1 AND ID = @cID) OR ( @nReverve_ByID = 0 AND SKU = @cSKU AND ID = @cID)) -- (james02) 
         AND   [STATUS] = '9'  
         ORDER BY 1  
         OPEN @cur_PreSort  
         FETCH NEXT FROM @cur_PreSort INTO @nRowRef, @cUCCNo  
         WHILE @@FETCH_STATUS = 0  
         BEGIN  
            DELETE FROM rdt.rdtPreReceiveSort WHERE Rowref = @nRowRef  
      
            IF @@ERROR <> 0      
            BEGIN  
               SET @nErrNo = 178902    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DelPreSortErr'    
               GOTO RollBackTran      
            END  
  
            IF NOT EXISTS ( SELECT 1 FROM @tUCC WHERE UCCNo = @cUCCNo)  
               INSERT INTO @tUCC (UCCNo) VALUES (@cUCCNo)  
                          
            FETCH NEXT FROM @cur_PreSort INTO @nRowRef, @cUCCNo  
         END  
  
         SET @cur_UCC = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR  
         SELECT UCC_RowRef FROM dbo.UCC UCC WITH (NOLOCK)  
         WHERE EXISTS ( SELECT 1 FROM @tUCC t WHERE UCC.UCCNo = t.UCCNo)  
         AND   UCC.Storerkey = @cStorerKey  
         OPEN @cur_UCC  
         FETCH NEXT FROM @cur_UCC INTO @nUCC_RowRef  
         WHILE @@FETCH_STATUS = 0  
         BEGIN  
            UPDATE dbo.UCC SET   
               [Status] = '0',   
               Lot = '',   
               Loc = '',   
               Id = '',   
               Receiptkey = '',   
               ReceiptLineNumber = '',   
               EditWho = SUSER_SNAME(),   
               EditDate = GETDATE()  
            WHERE UCC_RowRef = @nUCC_RowRef  
              
            IF @@ERROR <> 0      
            BEGIN  
               SET @nErrNo = 178903    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ReverseUCCErr'    
               GOTO RollBackTran      
            END  
  
            FETCH NEXT FROM @cur_UCC INTO @nUCC_RowRef  
         END  
         
         SET @cur_RD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT ReceiptLineNumber 
         FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
         AND   StorerKey = @cStorerKey
         AND   (( @nReverve_ByID = 1 AND ToId = @cID) OR ( @nReverve_ByID = 0 AND SKU = @cSKU AND ToId = @cID))   -- (james02) 
         AND   BeforeReceivedQty = 0
         OPEN @cur_RD
         FETCH NEXT FROM @cur_RD INTO @cRD_Line
         WHILE @@FETCH_STATUS = 0
         BEGIN
         	UPDATE dbo.ReceiptDetail SET 
         	   ToId = '',
         	   EditWho = SUSER_SNAME(),
         	   EditDate = GETDATE()
         	WHERE ReceiptKey = @cReceiptKey
         	AND   ReceiptLineNumber = @cRD_Line
         	
            IF @@ERROR <> 0      
            BEGIN  
               SET @nErrNo = 178905    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ReverseToIDEr'    
               GOTO RollBackTran      
            END  
            
         	FETCH NEXT FROM @cur_RD INTO @cRD_Line
         END
      END  
   END  
        
   COMMIT TRAN rdt_599ExtUpd01  
  
   GOTO Commit_Tran  
  
   RollBackTran:  
      ROLLBACK TRAN rdt_599ExtUpd01 -- Only rollback change made here  
   Commit_Tran:  
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
         COMMIT TRAN  
END    

GO