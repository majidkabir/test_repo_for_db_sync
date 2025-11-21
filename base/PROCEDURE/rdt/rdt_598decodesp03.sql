SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/  
/* Store procedure: rdt_598DecodeSP03                                         */  
/* Copyright      : LF Logistics                                              */  
/*                                                                            */  
/* Purpose: Decode UCC                                                        */
/*                                                                            */  
/* Date         Author    Ver.  Purposes                                      */  
/* 2021-06-18   Chermaine 1.0   WMS-17244 Created                             */  
/******************************************************************************/  
  
CREATE PROCEDURE [RDT].[rdt_598DecodeSP03]  
   @nMobile      INT,            
   @nFunc        INT,            
   @cLangCode    NVARCHAR( 3),   
   @nStep        INT,            
   @nInputKey    INT,            
   @cStorerKey   NVARCHAR( 15),  
   @cRefNo       NVARCHAR( 20),  
   @cColumnName  NVARCHAR( 20),  
   @cLOC         NVARCHAR( 10),  
   @cBarcode     NVARCHAR( 60),  
   @cFieldName   NVARCHAR( 10),  
   @cID          NVARCHAR( 18)  OUTPUT,  
   @cSKU         NVARCHAR( 20)  OUTPUT,  
   @nQTY         INT            OUTPUT,  
   @cLottable01  NVARCHAR( 18)  OUTPUT,  
   @cLottable02  NVARCHAR( 18)  OUTPUT,  
   @cLottable03  NVARCHAR( 18)  OUTPUT,  
   @dLottable04  DATETIME       OUTPUT,  
   @dLottable05  DATETIME       OUTPUT,  
   @cLottable06  NVARCHAR( 30)  OUTPUT,  
   @cLottable07  NVARCHAR( 30)  OUTPUT,  
   @cLottable08  NVARCHAR( 30)  OUTPUT,  
   @cLottable09  NVARCHAR( 30)  OUTPUT,  
   @cLottable10  NVARCHAR( 30)  OUTPUT,  
   @cLottable11  NVARCHAR( 30)  OUTPUT,  
   @cLottable12  NVARCHAR( 30)  OUTPUT,  
   @dLottable13  DATETIME       OUTPUT,  
   @dLottable14  DATETIME       OUTPUT,  
   @dLottable15  DATETIME       OUTPUT,  
   @nErrNo       INT            OUTPUT,  
   @cErrMsg      NVARCHAR( 20)  OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @cSSCC          NVARCHAR( 60)
   DECLARE @nTranCount     INT
   DECLARE @nQTYExpected   INT
   DECLARE @bSuccess       INT
   DECLARE @cFinalizeRD    NVARCHAR(1)
   DECLARE @cReceiptKey    NVARCHAR( 10)
   DECLARE @cReceiptLineNumber   NVARCHAR( 5)
   DECLARE @cFacility      NVARCHAR( 5)
   DECLARE @cUserName      NVARCHAR( 18)
   
   DECLARE @cUCC           NVARCHAR(20)
   DECLARE @cBusr7         NVARCHAR(30)
   DECLARE @cItemClass     NVARCHAR(10)
   DECLARE @cToID          NVARCHAR(18)
   DECLARE @cDupFrom       NVARCHAR(18)
   DECLARE @dEditDate      DATETIME 
   DECLARE @nIDUccCount    INT
   DECLARE @nLookupCount   INT
   DECLARE @nCount         INT
   DECLARE @curToID        CURSOR

   SET @nErrNo = 0

   SELECT @cUserName = UserName,
          @cFacility = Facility
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   IF @nStep = 4 -- SKU    
   BEGIN  
      IF @nInputKey = 1 -- ENTER
      BEGIN  
         SET @cUCC = @cBarcode
            
         IF NOT EXISTS (SELECT 1 FROM UCC WITH (NOLOCK) WHERE UCCNo = @cUCC AND Storerkey = @cStorerKey)
         BEGIN
            SET @nErrNo = 169601
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Invalid UCC
            GOTO Fail
         END
         
            
         IF NOT EXISTS (SELECT 1 
                        FROM UCC u WITH (NOLOCK)
                        JOIN Receipt R WITH (NOLOCK) ON (R.externreceiptkey = U.ExternKey AND R.StorerKey = U.Storerkey)
                        WHERE U.UCCNo =  @cUCC
                        AND R.UserDefine04 = @cRefNo
                        AND R.StorerKey = @cStorerKey
                        AND R.ASNStatus <> 'CANC'
                        AND U.Status ='0')
                           
         BEGIN
            SET @nErrNo = 169602
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Invalid UCC
            GOTO Fail
         END
         
         --UCC with multi SKU
         SELECT DISTINCT U.SKU 
         FROM UCC U WITH (NOLOCK) 
         JOIN Receipt R WITH (NOLOCK) ON (R.externreceiptkey = U.ExternKey AND R.StorerKey = U.Storerkey)
         WHERE R.UserDefine04 = @cRefNo
         AND R.StorerKey = @cStorerKey
         AND U.UccNo = @cUCC
         AND R.ASNStatus <> 'CANC'
         AND U.Status ='0'
         
         IF @@ROWCOUNT > 1
         BEGIN
         	SET @cID = ''
         	
         	SELECT TOP 1 
         	 @cSKU = U.SKU,
         	 @nQty = U.Qty
            FROM UCC U WITH (NOLOCK) 
            JOIN Receipt R WITH (NOLOCK) ON (R.externreceiptkey = U.ExternKey AND R.StorerKey = U.Storerkey)
            WHERE R.UserDefine04 = @cRefNo
            AND R.StorerKey = @cStorerKey
            AND U.UccNo = @cUCC
            AND R.ASNStatus <> 'CANC'
            AND U.Status ='0'
         
         	GOTO Fail
         END

         SELECT top 1 
            @cSKU = U.SKU,
            @cItemClass = s.ItemClass,
            @cBusr7 = S.Busr7,
            @nQty = U.Qty
         FROM UCC u WITH (NOLOCK)
         JOIN Receipt R WITH (NOLOCK) ON (R.externreceiptkey = U.ExternKey AND R.StorerKey = U.Storerkey)
         Join ReceiptDetail RD WITH (nolock) on (R.ReceiptKey = RD.ReceiptKey and R.StorerKey = RD.StorerKey and RD.SKU = U.SKU)
         JOIN SKU S WITH (nolock) on (S.SKU = U.SKU and S.StorerKey = U.StorerKey)
         WHERE R.UserDefine04 = @cRefNo
         AND R.StorerKey = @cStorerKey
         AND U.UccNo = @cUCC
         AND R.ASNStatus <> 'CANC'
         AND U.Status ='0'
                 
         SELECT 
            @nLookupCount = UDF02
         FROM Codelkup WITH (NOLOCK)
         WHERE storerKey = @cStorerKey
         AND Code = @cBusr7 
         AND LISTNAME = 'SKUGROUP'
         
         IF EXISTS ( SELECT 1 
            FROM RECEIPT R WITH (NOLOCK)
            JOIN RECEIPTDETAIL RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey AND R.StorerKey = RD.StorerKey)
            JOIN SKU S WITH (NOLOCK) ON (RD.SKU = S.SKU AND S.StorerKey = RD.StorerKey)
            WHERE R.UserDefine04 = @cRefNo
            AND S.Busr7 = @cBusr7
            AND S.ItemClass = @cItemClass
            AND R.StorerKey = @cStorerKey
            AND RD.toID <> '')
         BEGIN
            SET @curToID = CURSOR FOR  
            SELECT DISTINCT RD.toID,RD.editDate,DuplicateFrom
	         FROM RECEIPT R WITH (NOLOCK)
            JOIN RECEIPTDETAIL RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey AND R.StorerKey = RD.StorerKey)
            JOIN SKU S WITH (NOLOCK) ON (RD.SKU = S.SKU AND S.StorerKey = RD.StorerKey)
            WHERE R.UserDefine04 = @cRefNo
            AND toID <> ''
            AND S.Busr7 = @cBusr7
            AND S.ItemClass = @cItemClass
            AND R.storerKey = @cStorerKey
	         ORDER BY RD.editDate DESC, DuplicateFrom desc
	         
            OPEN @curToID
            FETCH NEXT FROM @curToID INTO @cToID,@dEditDate,@cDupFrom
            WHILE @@FETCH_STATUS = 0
            BEGIN

               SELECT --TOP 1 
                  @cID = U.ID,
                  @nCount = COUNT(DISTINCT U.UCCNo)
               FROM Receipt R WITH (NOLOCK) 
               JOIN PO P WITH (NOLOCK) ON (R.ExternReceiptKey = P.ExternPOKey AND R.StorerKey = P.StorerKey)
               JOIN UCC U WITH (NOLOCK) ON  (U.ExternKey = p.ExternPOKey AND U.Storerkey = P.StorerKey AND LEFT(U.Sourcekey,10) = P.POKey)
               --JOIN SKU S WITH (nolock) on (S.SKU = U.SKU and S.StorerKey = R.StorerKey)
               WHERE R.UserDefine04 = @cRefNo
               AND R.StorerKey = @cStorerKey
               AND R.ASNStatus <> 'CANC'
               --AND S.Busr7 = @cBusr7
               --AND S.ItemClass = @cItemClass
               AND U.ID = @cToID
               GROUP BY U.ID            
               --HAVING COUNT(U.UCCNo) < 5
         	
         	   IF @@ROWCOUNT = 0 OR @nCount <= @nLookupCount
         	   BEGIN
         		   SET @cID = @cToID
         		   BREAK 
         	   END
         	   ELSE
         	   BEGIN
         	   	SET @cID = ''
         	   END
         	
         	   FETCH NEXT FROM @curToID INTO  @cToID,@dEditDate,@cDupFrom
            END
            CLOSE @curToID  
            DEALLOCATE @curToID 
         END
         ELSE
         BEGIN
         	SET @cID = ''
         END
         
         SELECT 
            @cLottable02 = UDF03 
         FROM Codelkup 
         WHERE ListName = 'SKUGROUP'
         AND Storerkey = @cStorerKey
         AND Code = @cBusr7
         

       END  
   END  

   FAIL:
END  
 

GO