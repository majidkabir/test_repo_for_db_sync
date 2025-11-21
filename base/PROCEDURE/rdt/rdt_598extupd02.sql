SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_598ExtUpd02                                           */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Extended putaway                                                  */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 24-Nov-2017  ChewKP    1.0   WMS-3492 Created                              */
/******************************************************************************/

CREATE PROC [RDT].[rdt_598ExtUpd02] (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @nStep        INT,
   @nInputKey    INT,
   @cFacility    NVARCHAR( 5),
   @cStorerKey   NVARCHAR( 15),
   @cRefNo       NVARCHAR( 20),
   @cColumnName  NVARCHAR( 20),
   @cLOC         NVARCHAR( 10),
   @cID          NVARCHAR( 18),
   @cSKU         NVARCHAR( 20),
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
   @nQTY         INT,
   @cReasonCode  NVARCHAR( 10),
   @cSuggToLOC   NVARCHAR( 10),
   @cFinalLOC    NVARCHAR( 10),
   @cReceiptKey  NVARCHAR( 10),
   @cReceiptLineNumber NVARCHAR( 10),
   @nErrNo       INT            OUTPUT,
   @cErrMsg      NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nNoOfCopy      INT 
          ,@nCaseCnt       INT
          ,@cPackKey       NVARCHAR(10) 
          ,@nPrintType     INT
          ,@nRemainQty     INT
          ,@cLabelPrinter  NVARCHAR( 10)  

   DECLARE @tOutBoundList AS VariableTable          


   IF @nFunc = 598 -- Container receive
   BEGIN
      IF @nStep = 6 -- QTY
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Get login info
            DECLARE @cPrinter  NVARCHAR( 10)     
            DECLARE @cUserName NVARCHAR( 18)
            
            
            SELECT
               @cLabelPrinter = Printer,
               @cUserName = UserName
            FROM rdt.rdtMobRec WITH (NOLOCK)
            WHERE Mobile = @nMobile

            IF @cPrinter <> '' AND @cID <> ''
            BEGIN
               
--               DECLARE C_EATRECLBL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
--               SELECT RD.SKU, SUM(RD.BeforeReceivedQty) 
--               FROM dbo.ReceiptDetail  RD WITH (NOLOCK) 
--               INNER JOIN dbo.Receipt R WITH (NOLOCK) ON R.ReceiptKey = RD.ReceiptKey AND R.StorerKey = RD.StorerKey
--               WHERE RD.StorerKey   = @cStorerKey
--               AND R.ContainerKey   = @cRefNo 
--               AND RD.ToID          = @cID
--               AND RD.SKU           = @cSKU 
--               GROUP BY RD.StorerKey, R.ContainerKey, RD.SKU, RD.Lottable02, RD.Lottable04, RD.ToID
--               ORDER BY RD.SKU
--               
--               OPEN C_EATRECLBL  
--               FETCH NEXT FROM C_EATRECLBL INTO  @cSKU, @nQty 
--               WHILE (@@FETCH_STATUS <> -1)  
--               BEGIN  
                  
                  SET @nNoOfCopy = 0 
                  SET @nCaseCnt = 0
                  SET @cPackKey = '' 
                  
                  IF NOT EXISTS ( SELECT 1 FROM rdt.rdtPrintJob WITH (NOLOCK) 
                                  WHERE ReportID = 'SKULABEL01' 
                                  AND Parm1 = @cReceiptKey 
                                  AND Parm2 = @cID
                                  AND Parm3 = @cSKU
                                  AND Parm5 = @cLottable02 ) 
                  BEGIN
                     SELECT @cPackKey = PacKKey 
                     FROM dbo.SKU WITH (NOLOCK) 
                     WHERE StorerKey = @cStorerKey
                     AND SKU = @cSKU 
                     
                     SELECT @nCaseCnt = CaseCnt
                     FROM dbo.Pack WITH (NOLOCK) 
                     WHERE PackKey = @cPackKey 
                     
                     IF @nCaseCnt > 0 
                     BEGIN
                        IF (@nQty % @nCaseCnt) = 0 
                        BEGIN
                          SET @nNoOfCopy = @nQty/@nCaseCnt
                          SET @nPrintType = 1 
                        END 
                        ELSE
                        BEGIN
                          
                          
                          IF CEILING(@nQty/@nCaseCnt) = 0 
                          BEGIN
                             SET @nNoOfCopy = 1 
                             SET @nPrintType = 2
                             SET @nRemainQty = @nQty
                          END
                          ELSE
                          BEGIN
                             SET @nNoOfCopy = @nQty / @nCaseCnt
                             
                             SET @nRemainQty = @nQty % @nCaseCnt

                             --SELECT @nQty '@nQty' , @nCaseCnt '@nCaseCnt'  ,@nRemainQty '@nRemainQty' 

                             IF @nRemainQty > 0
                             BEGIN
                               SET @nNoOfCopy =  @nNoOfCopy + 1 
                             END
                             
                             --SELECT @nQty '@nQty' , @nCaseCnt '@nCaseCnt'  ,@nRemainQty '@nRemainQty' , @nNoOfCopy '@nNoOfCopy' 

                             SET @nPrintType = 2
                             
                          END
                        END
                     END
                     ELSE 
                     BEGIN
                        SET @nNoOfCopy = 1 
                        SET @nPrintType = 2
                        SET @nRemainQty = @nQty
                     END
                     
                     
                     WHILE @nNoOfCopy > 0 
                     BEGIN
                        
                        DELETE FROM @tOutBoundList
                        
                        INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cReceiptKey',  @cReceiptKey)
                        INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cID', @cID)
                        INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cSKU', @cSKU)
                        
                        IF @nPrintType = 1 
                        BEGIN
                           INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@nQty', @nCaseCnt)
                        END
                        ELSE
                        BEGIN
                           IF @nNoOfCopy = 1 
                           BEGIN
                              INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@nQty', @nRemainQty)
                           END
                           ELSE 
                           BEGIN
                              INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@nQty', @nCaseCnt)
                           END
                        END
                        
                        INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cLottable02', @cLottable02)
                        
                        
                        -- Print label
                        EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '', 
                           'SKULABEL01', -- Report type
                           @tOutBoundList, -- Report params
                           'rdt_598ExtUpd02', 
                           @nErrNo  OUTPUT,
                           @cErrMsg OUTPUT
                        
                        
                        IF @nErrNo <> 0
                           GOTO Quit
                        
                        SET @nNoOfCopy  = @nNoOfCopy - 1 
                        
                     END  
                  
                  END
                  
--                  FETCH NEXT FROM C_EATRECLBL INTO  @cSKU, @nQty 
--                  
--               END
--               CLOSE C_EATRECLBL  
--               DEALLOCATE C_EATRECLBL
            END
         END
      END
   END

Quit:

END

GO