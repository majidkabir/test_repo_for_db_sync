SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/***************************************************************************/  
/* Store procedure: rdt_1841DecodeSP01                                     */  
/*                                                                         */  
/* Purpose: Get UCC stat                                                   */  
/*                                                                         */  
/* Called from: rdtfnc_PrePalletizeSort                                    */  
/*                                                                         */  
/* Modifications log:                                                      */  
/*                                                                         */  
/* Date        Rev  Author     Purposes                                    */  
/* 2021-10-27  1.0  Chermaine  WMS-18096. Created                          */  
/***************************************************************************/  
  
CREATE PROC [RDT].[rdt_1841DecodeSP01] (  
   @nMobile      INT,       
   @nFunc        INT,       
   @cLangCode    NVARCHAR( 3),      
   @nStep        INT,     
   @nAfterStep   INT,     
   @nInputKey    INT,    
   @cFacility    NVARCHAR( 5),     
   @cStorerKey   NVARCHAR( 15),  
   @cSKUBarcode  NVARCHAR( 60), 
   @cReceiptKey  NVARCHAR( 10), 
   @cLane        NVARCHAR( 10), 
   @cUCC         NVARCHAR( 20),   
   @cLottable01  NVARCHAR( 18),  
   @cLottable02  NVARCHAR( 18),  
   @cLottable03  NVARCHAR( 18),  
   @dLottable04  DATETIME,  
   @dLottable05  DATETIME,  
   @cLottable06  NVARCHAR( 30),  
   @cLottable07  NVARCHAR( 30),  
   @cLottable08  NVARCHAR( 30),  
   @cLottable09  NVARCHAR( 30),  
   @cLottable10  NVARCHAR( 30),  
   @cLottable11  NVARCHAR( 30),  
   @cLottable12  NVARCHAR( 30),  
   @dLottable13  DATETIME,  
   @dLottable14  DATETIME,  
   @dLottable15  DATETIME,   
   @cSkipQtyScn  Nvarchar( 1)   OUTPUT,
   @cID          NVARCHAR( 18)  OUTPUT,   
   @cSKU         NVARCHAR( 20)  OUTPUT,   
   @nQTY         INT            OUTPUT,        
   @nErrNo       INT            OUTPUT,    
   @cErrMsg      NVARCHAR( 20)  OUTPUT
)  
AS  
BEGIN    
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE 
   	@cSkuCode    NVARCHAR(20),
      @cSKUStyle   NVARCHAR(20),
      @cSKUGroup   NVARCHAR(10),
      @nRowRef     INT, 
      @cUCCNo      NVARCHAR(20), 
      @cUCCSKU     NVARCHAR(20), 
      @cSUSR2      NVARCHAR(18),
      @cPosition   NVARCHAR( 20),
      @nUCCQty     INT
  
   IF @nFunc = 1841 --PrePalletizeSort  
   BEGIN  
      IF @nStep = 7 -- SKU  
      BEGIN  
         IF @nInputKey = 1 -- ENTER  
         BEGIN  
         	--from others screen, 1st time to SKU screen
         	--Clear Prev SKU key in of this UCC
         	IF @nAfterStep <> 7 
         	BEGIN
         		IF EXISTS (SELECT 1 
            		            FROM rdt.rdtPreReceiveSort WITH (NOLOCK) 
            		            WHERE storerKey = @cStorerKey 
            		            AND ReceiptKey = @cReceiptKey
            		            AND uccNo = @cUCC
                              AND status = 1)
               BEGIN
                  DELETE rdt.rdtPreReceiveSort 
            		WHERE storerKey = @cStorerKey 
            		AND ReceiptKey = @cReceiptKey
            		AND uccNo = @cUCC
                  AND status = 1
            		   
            		IF @@ERROR <> 0
            		BEGIN
            		   SET @nErrNo = 177651  
                     SET @cErrMsg = rdt.rdtgetmessage(63143, @cLangCode, 'DSP') --Del Log Fail
                     GOTO QUIT
            		END
               END
         	END
         	
         	--OSD2 label--go to QTY Screen and Key in Qty
            IF LEN (@cSKUBarcode) = 32
            BEGIN
            	SET @cSkuCode = SUBSTRING(@cSKUBarcode,5,13)
            	
            	IF NOT EXISTS (SELECT 1 FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND MANUFACTURERSKU = @cSkuCode)
            	BEGIN
            		SET @nErrNo = 177652  
                  SET @cErrMsg = rdt.rdtgetmessage(63143, @cLangCode, 'DSP') --Invalid SKU
                  GOTO QUIT
            	END
            	ELSE
            	BEGIN
            		SELECT @cSKU = SKU FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND MANUFACTURERSKU = @cSkuCode
            		SET @cSkipQtyScn = '0'
            		SET @nQty = 0
            		GOTO QUIT
            	END
            END
            
            --End scanning sku for this UCC and start insert to ucc table
            --Go to Qty Scn to call rdt_PrePalletizeSort
            IF @cSKUBarcode = @cUCC
            BEGIN
            	--DECLARE @curPRL CURSOR  
             --  SET @curPRL = CURSOR FOR  
             --  SELECT RowRef, UCCNo, SKU, Qty 
             --  FROM RDT.rdtPreReceiveSort WITH (NOLOCK)  
             --  WHERE ReceiptKey = @cReceiptKey   
             --  AND UCCNo = @cUCC
             --  AND   [Status] = '1'  
             --  ORDER BY RowRef
         
             --  OPEN @curPRL  
             --  FETCH NEXT FROM @curPRL INTO @nRowRef, @cUCCNo, @cUCCSKU, @nUCCQty  
             --  WHILE @@FETCH_STATUS = 0  
             --  BEGIN  
         	   --   INSERT INTO dbo.UCC (StorerKey, UCCNo, Status, SKU, QTY, LOC, ID, ReceiptKey, ReceiptLineNumber, ExternKey)  
             --     VALUES (@cStorerKey, @cUCCNo, '0', @cUCCSKU, @nUCCQty, '', '', @cReceiptKey, '', '')  
            
             --     IF @@ERROR <> 0  
             --     BEGIN  
             --        SET @nErrNo = 177656  
             --        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INS UCC fail'   
             --        GOTO Quit  
             --     END  
         	
         	   --   FETCH NEXT FROM @curPRL INTO @nRowRef, @cUCC, @cUCCSKU, @nUCCQty  
             --  END
         
            	SET @cSkipQtyScn = '0'
            	SET @nQty = 1
            	GOTO QUIT
            END
            
            --Open Carton and scan SKU (loop)
            --no need go to Qty screen           	
            IF NOT EXISTS (SELECT 1 FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND (MANUFACTURERSKU = @cSKUBarcode OR SKU = @cSKUBarcode) )
            BEGIN
            	SET @nErrNo = 177653  
               SET @cErrMsg = rdt.rdtgetmessage(63143, @cLangCode, 'DSP') --Invalid SKU
               GOTO QUIT
            END
            ELSE
            BEGIN
            	SELECT 
            		@cSKU = SKU,
            		@cSKUStyle = Style,
            		@cSKUGroup = SKUGroup,
            		@cSUSR2 = SUSR2  
            	FROM SKU WITH (NOLOCK) 
            	WHERE StorerKey = @cStorerKey 
            	AND (MANUFACTURERSKU = @cSKUBarcode OR SKU = @cSKUBarcode)
            	
            	IF @cSUSR2 = '1'
            	BEGIN
            		SELECT @cPosition = Code FROM codelkup (NOLOCK) WHERE listName = 'PreRcvLane' and storerKey = @cStorerKey AND DESCRIPTION = 'HV'
            	END
            	ELSE
            	BEGIN
            		SET @cPosition = ''
            	END
            		
               --INSERT INTO traceInfo (TraceName,timein, col1,col2,col3,col4,col5,step1)
               --VALUES ('cc',GETDATE(),@cSKU,@cSKUBarcode,@cUCC,@cReceiptKey,@cStorerKey,@nAfterStep)
            	IF NOT EXISTS (SELECT 1 
            		         FROM rdt.rdtPreReceiveSort WITH (NOLOCK) 
            		         WHERE storerKey = @cStorerKey 
            		         AND ReceiptKey = @cReceiptKey
            		         AND uccNo = @cUCC
            		         AND SKU = @cSKU)
            	BEGIN
            		INSERT INTO rdt.rdtPreReceiveSort
                  (Mobile, Func, Facility, StorerKey, ReceiptKey, UCCNo, SKU, Qty, 
                  LOC, ID, Position, SourceType, UDF01, UDF02, [Status],
                  Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, 
                  Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, 
                  Lottable11, Lottable12, Lottable13, Lottable14, Lottable15 ) VALUES 
                  (@nMobile, @nFunc, @cFacility, @cStorerKey, @cReceiptKey, @cUCC, @cSKU, '1', 
                  @cLane, '', @cPosition, 'rdt_1841DecodeSP01', @cSKUStyle, @cSKUGroup, '1',
                  @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
                  @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
                  @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15)
                     
                  IF @@ERROR <> 0
            		BEGIN
            		   SET @nErrNo = 177654  
                     SET @cErrMsg = rdt.rdtgetmessage(63143, @cLangCode, 'DSP') --Ins Log Fail
                     GOTO QUIT
            		END
            	END
            	ELSE
            	BEGIN
            		UPDATE rdt.rdtPreReceiveSort WITH (ROWLOCK) SET
            			QTY = QTY + 1
            		WHERE storerKey = @cStorerKey 
            		AND ReceiptKey = @cReceiptKey
            		AND uccNo = @cUCC
            		AND SKU = @cSKU 
            		   
            		IF @@ERROR <> 0
            		BEGIN
            		   SET @nErrNo = 177655  
                     SET @cErrMsg = rdt.rdtgetmessage(63143, @cLangCode, 'DSP') --Upd Log Fail
                     GOTO QUIT
            		END
            	END

             --  SELECT 
             --     @nQty = SUM(Qty) 
             --  FROM rdt.rdtPreReceiveSort WITH (NOLOCK) 
            	--WHERE storerKey = @cStorerKey 
            	--AND ReceiptKey = @cReceiptKey
            	--AND uccNo = @cUCC
            		
            	SET @cSkipQtyScn = '1'
            END
         END
      END
   END
  
Quit:  
  
END 

GO