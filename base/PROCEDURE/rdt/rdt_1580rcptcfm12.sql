SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_1580RcptCfm12                                      */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Date       Rev  Author  Purposes                                        */
/* 2019-01-30 1.0  ChewKP  WMS-7780 Created                                */
/***************************************************************************/
CREATE PROC [RDT].[rdt_1580RcptCfm12](
   @nFunc          INT,
   @nMobile        INT,
   @cLangCode      NVARCHAR( 3),
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT, 
   @cStorerKey     NVARCHAR( 15),
   @cFacility      NVARCHAR( 5),
   @cReceiptKey    NVARCHAR( 10),
   @cPOKey         NVARCHAR( 10),
   @cToLOC         NVARCHAR( 10),
   @cToID          NVARCHAR( 18),
   @cSKUCode       NVARCHAR( 20),
   @cSKUUOM        NVARCHAR( 10),
   @nSKUQTY        INT,
   @cUCC           NVARCHAR( 20),
   @cUCCSKU        NVARCHAR( 20),
   @nUCCQTY        INT,
   @cCreateUCC     NVARCHAR( 1),
   @cLottable01    NVARCHAR( 18),
   @cLottable02    NVARCHAR( 18),
   @cLottable03    NVARCHAR( 18),
   @dLottable04    DATETIME,
   @dLottable05    DATETIME,
   @nNOPOFlag      INT,
   @cConditionCode NVARCHAR( 10),
   @cSubreasonCode NVARCHAR( 10), 
   @cReceiptLineNumber NVARCHAR( 5) OUTPUT, 
   @cSerialNo      NVARCHAR( 30) = '', 
   @nSerialQTY     INT = 0,
   @nBulkSNO       INT = 0,
   @nBulkSNOQTY    INT = 0
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cLottable06    NVARCHAR( 30)
          ,@cLottable07    NVARCHAR( 30)
          ,@cLottable08    NVARCHAR( 30)
          ,@cLottable09    NVARCHAR( 30)
          ,@cLottable10    NVARCHAR( 30)
          ,@cLottable11    NVARCHAR( 30)
          ,@cLottable12    NVARCHAR( 30)
          ,@dLottable13    DATETIME
          ,@dLottable14    DATETIME
          ,@dLottable15    DATETIME
          ,@cLoadKey       NVARCHAR( 10)
          ,@cLastAssignConsignee NVARCHAR(30) 
          ,@cLastAssignOrderKey  NVARCHAR(10) 
          ,@cDocType       NVARCHAR(1) 
          ,@cShort         NVARCHAR(10)
          ,@cShort2        NVARCHAR(10)
          ,@cSUSR3         NVARCHAR(18)
          ,@cNewReceiptKEy NVARCHAR(10) 
          ,@nCounter       INT
          ,@cConsigneeKey  NVARCHAR(15)
          ,@cOrderKey      NVARCHAR(10) 
          ,@nCurrentRow    INT
          ,@cExternReceiptKey NVARCHAR(20) 
          ,@nSumReceived   INT
          ,@cLot08         NVARCHAR( 30)
          ,@cLot09         NVARCHAR( 30)
          
             
          
   DECLARE @cLabelPrinter NVARCHAR( 10)    
   DECLARE @tOutBoundList AS VariableTable    
   
   DECLARE @tConsigneeList TABLE (ConsigneeKey NVARCHAR(15)
                                  ,Priority    NVARCHAR(20)
                                  ,OrderKey    NVARCHAR(10)
                                  ,SKU         NVARCHAR(20)
                                  ,OpenQty     INT  
                                  ,Qty         INT
                                  ,QtyReceived INT 
                                  ,SKUGroup    NVARCHAR(20)
                                  ,RowRef      INT NULL)   

   DECLARE  @cTConsigneeKey NVARCHAR(15), 
            @cTOderKey      NVARCHAR(10),  
            @cTSKU          NVARCHAR(20), 
            @nTOpenQty      INT, 
            @nTQty          INT,
            @nTQtyReceived  INT                                

   DECLARE @tASNList TABLE (ReceiptKey NVARCHAR(10)
                           ,SKU         NVARCHAR(20)
                           ,QtyExpected INT
                           ,BeforeReceivedQty INT)                                                        
   
   SELECT @cLabelPrinter = Printer
         --,@cUserName     = UserName
         --,@cPaperPrinter = Printer_Paper
   FROM rdt.rdtMobrec WITH (NOLOCK)
   WHERE Mobile = @nMobile
   
   -- Storer Distribution Logic
   SELECT @cLoadKey = UserDefine03 
   FROM dbo.Receipt WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey
   AND ReceiptKey = @cReceiptKey
   
   IF EXISTS ( SELECT 1 FROM dbo.LoadPlan WITH (NOLOCK) WHERE LoadKey = @cLoadKey ) 
   BEGIN
      
                 
      INSERT INTO @tConsigneeList (ConsigneeKey, Priority, OrderKey, SKU, OpenQty, Qty, QtyReceived, SKUGroup)
      SELECT O.ConsigneeKey , ISNULL(D.UserDefine01,'99' ) , O.OrderKey, OD.SKU, SUM(OD.OpenQty), SUM(OD.OpenQty - OD.QtyAllocated - OD.QtyPicked) , 0, D.SKUGroup
      FROM dbo.DocLKup D WITH (NOLOCK) 
      INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.ConsigneeKey = D.ConsigneeGroup AND O.StorerKey = D.UserDefine02
      INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = O.OrderKey AND OD.StorerKey = O.StorerKey
      INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON SKU.BUSR1 = D.SKUGroup AND SKU.StorerKey = O.StorerKey AND OD.SKU = SKU.SKU
      WHERE O.StorerKey = @cStorerKey 
      AND O.LoadKey = @cLoadKey
      AND OD.SKU = @cSKUCode
      GROUP BY O.ConsigneeKey , ISNULL(D.UserDefine01,'99' ) , O.OrderKey, OD.SKU, D.SKUGroup
      ORDER BY O.ConsigneeKey , ISNULL(D.UserDefine01,'99' ) , O.OrderKey, OD.SKU, D.SKUGroup
      
      

      SET @nCounter = 1 

      DECLARE @curTemp CURSOR
      SET @curTemp = CURSOR FOR 
         SELECT ConsigneeKey, OrderKey 
         FROM @tConsigneeList 
         ORDER BY Priority, ConsigneeKey, OrderKey
      OPEN @curTemp
      FETCH NEXT FROM @curTemp INTO @cConsigneeKey, @cOrderKey
      WHILE @@FETCH_STATUS = 0
      BEGIN
         UPDATE @tConsigneeList
         SET RowRef = @nCounter 
         WHERE ConsigneeKey = @cConsigneeKey
         AND OrderKey = @cOrderKey 

         SET @nCounter = @nCounter + 1 

         FETCH NEXT FROM @curTemp INTO @cConsigneeKey, @cOrderKey
      END

     

      -- Update QtyReceived to Temp 
      DECLARE @curTempRec CURSOR
      SET @curTempRec = CURSOR FOR 
      SELECT  RD.Lottable09
             ,RD.Lottable08
             ,RD.BeforeReceivedQty
      FROM dbo.ReceiptDetail RD WITH (NOLOCK)
      INNER JOIN dbo.Receipt R WITH (NOLOCK) ON R.ReceiptKey = RD.ReceiptKey AND R.StorerKey = RD.StorerKey
      WHERE R.StorerKey = @cStorerKey
      AND R.UserDefine03 = @cLoadKey 
      AND RD.SKU = @cSKUCode
      AND RD.BeforeReceivedQty > 0 
      --Group By RD.Lottable09, RD.Lottable08
      
      --AND RD.FinalizeFlag <> 'Y' -- (ChewKPXX) 
      --AND RD.Lottable08 <> ''
      --AND RD.Lottable09 <> '' 
      
      OPEN @curTempRec
      FETCH NEXT FROM @curTempRec INTO @cLot09, @cLot08, @nSumReceived
      WHILE @@FETCH_STATUS = 0
      BEGIN
         UPDATE @tConsigneeList
         SET QtyReceived = QtyReceived + @nSumReceived 
         WHERE ConsigneeKey = @cLot08
         AND OrderKey = @cLot09 
         
         --SELECT @cLot08 '@cLot08' , @cLot09 '@cLot09' , @nSumReceived '@nSumReceived' 
         

         FETCH NEXT FROM @curTempRec INTO @cLot09, @cLot08, @nSumReceived
      END
         
      
      
      SELECT TOP 1  @cLastAssignOrderKey = ISNULL(RD.Lottable09,'' ) 
              ,@cLastAssignConsignee = ISNULL(RD.Lottable08,'' ) 
              --,@nSumReceived =  ISNULL(BeforeReceivedQty ,0) 
      FROM dbo.ReceiptDetail RD WITH (NOLOCK)
      INNER JOIN dbo.Receipt R WITH (NOLOCK) ON R.ReceiptKey = RD.ReceiptKey AND R.StorerKey = RD.StorerKey
      WHERE R.StorerKey = @cStorerKey
      AND R.UserDefine03 = @cLoadKey 
      AND RD.SKU = @cSKUCode
      AND RD.Lottable08 <> ''
      AND RD.Lottable09 <> '' 
      --GROUP BY RD.Lottable09 , RD.Lottable08
      ORDER BY RD.EditDate DESC
      
      -- Trace Error -- 
      DECLARE @curTrace1580 CURSOR
      SET @curTrace1580 = CURSOR FOR 
         SELECT ConsigneeKey ,OrderKey ,SKU ,OpenQty ,Qty ,QtyReceived   
         FROM @tConsigneeList 
      OPEN @curTrace1580
      FETCH NEXT FROM @curTrace1580 INTO @cTConsigneeKey, @cTOderKey, @cTSKU, @nTOpenQty, @nTQty, @nTQtyReceived
      WHILE @@FETCH_STATUS = 0
      BEGIN
         INSERT INTO TRACEINFO ( TraceName, TimeIn, Step1, Step2, Step3, Step4, Step5, Col1, Col2, Col3, Col4, Col5 )
         VALUES( 'rdt_1580RcptCfm12', GetDate() ,'D1', @cLoadKey, @cTConsigneeKey, @cTOderKey, @cTSKU, @nTOpenQty, @nTQty, @nTQtyReceived, '', '')
      
         FETCH NEXT FROM @curTrace1580 INTO @cTConsigneeKey, @cTOderKey, @cTSKU, @nTOpenQty, @nTQty, @nTQtyReceived   
      END
      
      SET @cLottable08 = ''
      SET @cLottable09 = '' 
      
      --SELECT * FROM @tConsigneeList 
      --SELECT @nSumReceived '@nSumReceived' , @cLastAssignConsignee '@cLastAssignConsignee'

      IF ISNULL(@cLastAssignConsignee,'')  = '' 
      BEGIN
         --SELECT * FROM @tConsigneeList where sku = @cSKUCode
         
         SELECT TOP 1 @cLottable08 = ConsigneeKey
               ,@cLottable09 = OrderKey 
         FROM @tConsigneeList 
         WHERE SKU = @cSKUCode 
         AND  OpenQty >= ISNULL(QtyReceived,0 )  + 1 
         AND  Qty - 1 >= 0 
         ORDER BY RowRef

         --SELECT @cLottable08 '@cLottable08'
         INSERT INTO TRACEINFO ( TraceName, TimeIn, Step1, Step2, Step3, Step4, Step5, Col1, Col2, Col3, Col4, Col5 )
         VALUES( 'rdt_1580RcptCfm12', GetDate() ,'D2', @cLoadKey, @cTConsigneeKey, @cTOderKey, @cTSKU, @nTOpenQty, @nTQty, @nTQtyReceived, @cLottable08, @cLottable09)
      
         
         
      END
      ELSE 
      BEGIN
         

         SELECT @nCurrentRow = RowRef 
         FROM @tConsigneeList 
         WHERE ConsigneeKey = RTRIM(@cLastAssignConsignee)
         AND OrderKey  = RTRIM(@cLastAssignOrderKey)

         --PRINT @nCurrentRow 
         --PRINT @nCounter

         --SELECT @nCurrentRow '@nCurrentRow' , @nCounter '@nCounter' 

         IF @nCurrentRow = ( @nCounter -1 )
         BEGIN
            

            SELECT TOP 1 @cLottable08 = ConsigneeKey
                  ,@cLottable09 = OrderKey 
            FROM @tConsigneeList 
            WHERE SKU = @cSKUCode 
            AND   OpenQty >= ISNULL(QtyReceived,0 )  + 1 
            AND  Qty - 1 >= 0 
            ORDER BY RowRef
            
            INSERT INTO TRACEINFO ( TraceName, TimeIn, Step1, Step2, Step3, Step4, Step5, Col1, Col2, Col3, Col4, Col5 )
            VALUES( 'rdt_1580RcptCfm12', GetDate() ,'D3', @cLoadKey, @nCurrentRow, @nCounter, @cSKUCode, @cLastAssignConsignee, @cLastAssignOrderKey, '', @cLottable08, @cLottable09)
      
         END
         ELSE
         BEGIN
            -- SELECT TOP 1 cLottable08 = ConsigneeKey
            --            ,cLottable09 = OrderKey      
            --            ,Qty 
            --FROM @tConsigneeList 
            --WHERE SKU = @cSKUCode 
            --AND RowRef > @nCurrentRow
            --AND   Qty >= ISNULL(QtyReceived,0 )  + 1 
            --ORDER BY RowRef

            SELECT TOP 1 @cLottable08 = ConsigneeKey
                        ,@cLottable09 = OrderKey      
            FROM @tConsigneeList 
            WHERE SKU = @cSKUCode 
            AND RowRef > @nCurrentRow
            AND  OpenQty >= ISNULL(QtyReceived,0 )  + 1 
            AND  Qty - 1 >= 0 
            ORDER BY RowRef
            
            INSERT INTO TRACEINFO ( TraceName, TimeIn, Step1, Step2, Step3, Step4, Step5, Col1, Col2, Col3, Col4, Col5 )
            VALUES( 'rdt_1580RcptCfm12', GetDate() ,'D4', @cLoadKey, @nCurrentRow, @nCounter, @cSKUCode, @cLastAssignConsignee, @cLastAssignOrderKey, '', @cLottable08, @cLottable09)
      
            -- Search again in the list to make sure really no more match 
            IF @cLottable08 = '' AND @cLottable09 = '' 
            BEGIN
               SELECT TOP 1 @cLottable08 = ConsigneeKey
                           ,@cLottable09 = OrderKey 
               FROM @tConsigneeList 
               WHERE SKU = @cSKUCode 
               AND  OpenQty >= ISNULL(QtyReceived,0 )  + 1 
               AND  Qty - 1 >= 0 
               ORDER BY RowRef
               
               INSERT INTO TRACEINFO ( TraceName, TimeIn, Step1, Step2, Step3, Step4, Step5, Col1, Col2, Col3, Col4, Col5 )
               VALUES( 'rdt_1580RcptCfm12', GetDate() ,'D5', @cLoadKey, @nCurrentRow, @nCounter, @cSKUCode, @cLastAssignConsignee, @cLastAssignOrderKey, '', @cLottable08, @cLottable09)
      
            END
         END

      END   
      
      

      --SELECT @cLottable08 '@cLottable08' , @cLottable09 '@cLottable09' 

      -- GET ASN that have the QTY to Received.
      INSERT INTO @tASNList  ( ReceiptKey, SKU, QtyExpected, BeforeReceivedQty)
      SELECT RD.ReceiptKey, RD.SKU, SUM(RD.QtyExpected), SUM(RD.BeforeReceivedQty)
      FROM dbo.ReceiptDetail RD WITH (NOLOCK) 
      INNER JOIN dbo.Receipt R WITH (NOLOCK) ON ( R.ReceiptKey = RD.ReceiptKey and R.StorerKey = RD.StorerKey ) 
      WHERE R.StorerKey = @cStorerKey
      AND R.UserDefine03 = @cLoadKey
      AND RD.SKU = @cSKUCode
      GROUP BY RD.ReceiptKey, RD.SKU 

      

      --UPDATE @tASNList 
      --SET BeforeReceivedQty = 100 
      --WHERE Receiptkey = '0001766324' 

      --SELECT * FROM @tConsigneeList  

      SELECT TOP 1 @cNewReceiptKey = ReceiptKey
      FROM @tASNList 
      WHERE SKU = @cSKUCode
      AND QtyExpected >= ( BeforeReceivedQty + 1 ) 
      ORDER By ReceiptKey

      IF ISNULL(@cNewREceiptKey ,'' ) = '' 
         SET @cNewReceiptKey = @cReceiptKey

   --   SELECT TOP 1  @cExternReceiptKey  = ISNULL(RD.ExternReceiptKey,'')
   --               , @cLottable06        = Lottable06 
   --   FROM dbo.ReceiptDetail RD WITH (NOLOCK)
   --   WHERE RD.StorerKey = @cStorerKey
   --   AND RD.ReceiptKey = @cReceiptKey
   --   AND RD.SKU        = @cSKUCode
   --   AND RD.Lottable06 <> '' 
      
      
      
      SELECT TOP 1 
         --@cUCCPOKey = RD.POKey
          @cExternReceiptKey  = RD.ExternReceiptKey
      FROM Receipt R WITH (NOLOCK)
         JOIN ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey)
      WHERE R.StorerKey = @cStorerKey
         AND R.Facility = @cFacility
         AND RD.ReceiptKey = @cReceiptKey
         AND RD.SKU     = @cSKUCode 
      ORDER BY RD.ExternReceiptKey, RD.ExternLineNo    
      
   --   -- Get ASN
      SELECT TOP 1 
         --@cUCCPOKey = RD.POKey
          @cExternReceiptKey  = RD.ExternReceiptKey
         ,@cLottable01 = RD.Lottable01
         ,@cLottable02 = RD.Lottable02
         ,@cLottable03 = RD.Lottable03
         ,@dLottable04 = RD.Lottable04
         --,@dLottable05 = RD.Lottable05
         ,@cLottable06 = RD.Lottable06
         ,@cLottable07 = RD.Lottable07
         --,@cLottable08 = RD.Lottable08
         --,@cLottable09 = RD.Lottable09
         ,@cLottable10 = RD.Lottable10
         ,@cLottable11 = RD.Lottable11
         ,@cLottable12 = RD.Lottable12
         ,@dLottable13 = RD.Lottable13
         ,@dLottable14 = RD.Lottable14
         ,@dLottable15 = RD.Lottable15
      FROM Receipt R WITH (NOLOCK)
         JOIN ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey)
      WHERE R.StorerKey = @cStorerKey
         AND R.Facility = @cFacility
         AND RD.ReceiptKey = @cReceiptKey
         AND RD.SKU     = @cSKUCode 
         AND RD.Lottable06 <> '' 
      ORDER BY RD.ExternReceiptKey, RD.ExternLineNo      
   --      --AND RD.ReceiptLineNumber = @cUCCLineNumber
   --      --AND RD.POKey = @cUCCPOKey
   --      --AND RD.POLineNumber = @cUCCPOLineNumber

      -- Counter Check Once again with Orders Records before proceed with stamping Lottable08, Lottable09
--      IF NOT EXISTS ( SELECT 1 FROM dbo.OrderDetail WITH (NOLOCK) 
--                      WHERE StorerKey = @cStorerKey
--                      AND OrderKey = @cLottable09
--                      AND SKU = @cSKUCode
--                      AND OpenQty - QtyAllocated - QtyPicked > 0 )
--      BEGIN
--         SET @cLottable08 = ''
--         SET @cLottable09 = ''
--      END
      
      --SELECT @cNewReceiptKey '@cNewReceiptKey' , @cLottable08 '@cLottable08' , @cLottable09 '@cLottable09' 
      IF @cLottable08 = '' AND @cLottable09 = ''
      BEGIN
         SET @cLottable08 = 'STOCK'
         SET @cLottable09 = 'STOCK'
      END
      --SELECT @cNewReceiptKey '@cNewReceiptKey' , @cLottable08 '@cLottable08' , @cLottable09 '@cLottable09' 
      --GOTO QUIT

      EXEC rdt.rdt_Receive_v7  
         @nFunc          = @nFunc,
         @nMobile        = @nMobile,
         @cLangCode      = @cLangCode,
         @nErrNo         = @nErrNo  OUTPUT,
         @cErrMsg        = @cErrMsg OUTPUT,
         @cStorerKey     = @cStorerKey,
         @cFacility      = @cFacility,
         @cReceiptKey    = @cNewReceiptKey,
         @cPOKey         = @cPOKey,
         @cToLOC         = @cToLOC,
         @cToID          = @cToID,
         @cSKUCode       = @cSKUCode,
         @cSKUUOM        = @cSKUUOM,
         @nSKUQTY        = @nSKUQTY,
         @cUCC           = @cUCC,
         @cUCCSKU        = @cUCCSKU,
         @nUCCQTY        = @nUCCQTY,
         @cCreateUCC     = @cCreateUCC,
         @cLottable01    = @cLottable01,
         @cLottable02    = @cLottable02,   
         @cLottable03    = @cLottable03,
         @dLottable04    = @dLottable04,
         @dLottable05    = @dLottable05,
         @cLottable06    = @cLottable06,
         @cLottable07    = @cExternReceiptKey, --@cLottable07,
         @cLottable08    = @cLottable08,
         @cLottable09    = @cLottable09,
         @cLottable10    = @cLottable10,
         @cLottable11    = @cLottable11,
         @cLottable12    = @cLottable12,
         @dLottable13    = @dLottable13,
         @dLottable14    = @dLottable14,
         @dLottable15    = @dLottable15,
         @nNOPOFlag      = @nNOPOFlag,
         @cConditionCode = @cConditionCode,
         @cSubreasonCode = @cSubreasonCode

        IF @nErrNo > 0 
            GOTO QUIT
        
        -- PRINT LABEL
        SELECT @cDocType = ISNULL(DocType ,'') 
        FROM dbo.Receipt WITH (NOLOCK)
        WHERE StorerKey = @cStorerKey
        AND ReceiptKey = @cNewReceiptKey
        
        SET @cShort  = ''
        SET @cShort2 = ''
               
        SELECT @cShort = ISNULL(Short,'')
        FROM dbo.Codelkup WITH (NOLOCK) 
        WHERE ListName = 'RDT608PRNT'
        AND StorerKey = @cStorerKey
        AND Code = @cDocType
        
        IF @cShort = 'R'
           GOTO Quit
        
        SELECT @cSUSR3 = SUSR3 
        FROM dbo.SKU WITH (NOLOCK)
        WHERE StorerKey = @cStorerKey
        AND SKU = @cSKUCode 
        
        SELECT @cShort2 = ISNULL(Short,'')
        FROM dbo.Codelkup WITH (NOLOCK) 
        WHERE ListName = 'NOSKULABEL'
        AND StorerKey = @cStorerKey
        AND Code = @cSUSR3
        
        IF @cShort2 = ''
        BEGIN
              
           DELETE @tOutBoundList
           INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cReceiptKey',  @cNewReceiptKey)
           INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cCartonID', @cExternReceiptKey)
           INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cSKU', @cSKUCode)
           
           -- Print Carton label
           EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '', 
              'PALLETLBL4', -- Report type
              @tOutBoundList, -- Report params
              'rdt_1580RcptCfm12', 
              @nErrNo  OUTPUT,
              @cErrMsg OUTPUT
              
           IF @nErrNo <> 0
              GOTO Quit
              
           -- Store Label 
           DELETE @tOutBoundList
                   
           INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cReceiptKey',  @cNewReceiptKey)
           INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cSKU', @cSKUCode)
           INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cLottable08', @cLottable08)
           INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cLottable09', @cLottable09)
           INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cToID', @cToID)
           
           -- Print label
           EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '', 
              'STORERLBL', -- Report type
              @tOutBoundList, -- Report params
              'rdt_1580RcptCfm12', 
              @nErrNo  OUTPUT,
              @cErrMsg OUTPUT
              
           IF @nErrNo <> 0
              GOTO Quit   
        END
     
   END
   ELSE
   BEGIN
     
      SELECT TOP 1 
         --@cUCCPOKey = RD.POKey
          @cExternReceiptKey  = RD.ExternReceiptKey
         ,@cLottable01 = RD.Lottable01
         ,@cLottable02 = RD.Lottable02
         ,@cLottable03 = RD.Lottable03
         ,@dLottable04 = RD.Lottable04
         --,@dLottable05 = RD.Lottable05
         ,@cLottable06 = RD.Lottable06
         ,@cLottable07 = RD.Lottable07
         ,@cLottable08 = RD.Lottable08
         ,@cLottable09 = RD.Lottable09
         ,@cLottable10 = RD.Lottable10
         ,@cLottable11 = RD.Lottable11
         ,@cLottable12 = RD.Lottable12
         ,@dLottable13 = RD.Lottable13
         ,@dLottable14 = RD.Lottable14
         ,@dLottable15 = RD.Lottable15
      FROM Receipt R WITH (NOLOCK)
         JOIN ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey)
      WHERE R.StorerKey = @cStorerKey
         AND R.Facility = @cFacility
         AND RD.ReceiptKey = @cReceiptKey
         AND RD.SKU     = @cSKUCode 
         --AND RD.Lottable06 <> '' 
      ORDER BY RD.ExternReceiptKey, RD.ExternLineNo   
       
     EXEC rdt.rdt_Receive_v7  
         @nFunc          = @nFunc,
         @nMobile        = @nMobile,
         @cLangCode      = @cLangCode,
         @nErrNo         = @nErrNo  OUTPUT,
         @cErrMsg        = @cErrMsg OUTPUT,
         @cStorerKey     = @cStorerKey,
         @cFacility      = @cFacility,
         @cReceiptKey    = @cNewReceiptKey,
         @cPOKey         = @cPOKey,
         @cToLOC         = @cToLOC,
         @cToID          = @cToID,
         @cSKUCode       = @cSKUCode,
         @cSKUUOM        = @cSKUUOM,
         @nSKUQTY        = @nSKUQTY,
         @cUCC           = @cUCC,
         @cUCCSKU        = @cUCCSKU,
         @nUCCQTY        = @nUCCQTY,
         @cCreateUCC     = @cCreateUCC,
         @cLottable01    = @cLottable01,
         @cLottable02    = @cLottable02,   
         @cLottable03    = @cLottable03,
         @dLottable04    = @dLottable04,
         @dLottable05    = @dLottable05,
         @cLottable06    = @cLottable06,
         @cLottable07    = @cLottable07,
         @cLottable08    = @cLottable08,
         @cLottable09    = @cLottable09,
         @cLottable10    = @cLottable10,
         @cLottable11    = @cLottable11,
         @cLottable12    = @cLottable12,
         @dLottable13    = @dLottable13,
         @dLottable14    = @dLottable14,
         @dLottable15    = @dLottable15,
         @nNOPOFlag      = @nNOPOFlag,
         @cConditionCode = @cConditionCode,
         @cSubreasonCode = @cSubreasonCode
         
         
--      EXEC rdt.rdt_Receive    
--         @nFunc          = @nFunc,
--         @nMobile        = @nMobile,
--         @cLangCode      = @cLangCode,
--         @nErrNo         = @nErrNo  OUTPUT,
--         @cErrMsg        = @cErrMsg OUTPUT,
--         @cStorerKey     = @cStorerKey,
--         @cFacility      = @cFacility,
--         @cReceiptKey    = @cReceiptKey,
--         @cPOKey         = @cPOKey,
--         @cToLOC         = @cToLOC,
--         @cToID          = @cTOID,
--         @cSKUCode       = @cSKUCode,
--         @cSKUUOM        = @cSKUUOM,
--         @nSKUQTY        = @nSKUQTY,
--         @cUCC           = @cUCC,
--         @cUCCSKU        = @cUCCSKU,
--         @nUCCQTY        = @nUCCQTY,
--         @cCreateUCC     = @cCreateUCC,
--         @cLottable01    = @cLottable01,
--         @cLottable02    = @cLottable02,   
--         @cLottable03    = @cLottable03,
--         @dLottable04    = @dLottable04,
--         @dLottable05    = @dLottable05,
--         @nNOPOFlag      = @nNOPOFlag,
--         @cConditionCode = @cConditionCode,
--         @cSubreasonCode = @cSubreasonCode, 
--         @cReceiptLineNumberOutput = @cReceiptLineNumber OUTPUT
--
--   IF @nErrNo <> 0
--   BEGIN
--      IF @cTOID <> '' AND @cReceiptLineNumber <> ''
--      BEGIN
--         IF EXISTS( SELECT 1 
--            FROM ReceiptDetail WITH (NOLOCK) 
--            WHERE ReceiptKey = @cReceiptKey 
--               AND ReceiptLineNumber = @cReceiptLineNumber
--               AND ISNULL( UserDefine10, '') = '')
--         BEGIN
--            -- Get ExtendedInfo (PutawayZone)
--            DECLARE @cPutawayZone NVARCHAR( 20)
--            SELECT @cPutawayZone = O_Field15 FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile
--            
--            -- Update PutawayZone to UDF10
--            UPDATE ReceiptDetail SET 
--               UserDefine10 = @cPutawayZone, 
--               EditDate = GETDATE(), 
--               EditWho = SUSER_SNAME(), 
--               TrafficCop = NULL
--            WHERE ReceiptKey = @cReceiptKey 
--               AND ReceiptLineNumber = @cReceiptLineNumber
--         END
--      END
   END
   
Quit:

END

GO