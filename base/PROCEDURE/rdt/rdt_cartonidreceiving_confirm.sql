SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_CartonIDReceiving_Confirm                       */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Confirm Receiving                                           */
/*                                                                      */
/* Called from: rdtfnc_CartonIDReceiving                                */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 11-05-2012 1.0  ChewKP   Created                                     */
/* 10-15-2012 1.1  ChewKP   SOS#258706 Change Screen design on Screen 5,*/
/*                         New StorerConfig, Label Validation (ChewKP01)*/ 
/* 01-16-2013 1.2  James    SOS265346 - Add split line (james01)        */
/* 02-10-2023 1.3  James    WMS-21643 Add Lot06-Lot15 (james02)         */
/************************************************************************/

CREATE   PROC [RDT].[rdt_CartonIDReceiving_Confirm] (
       @nFunc          INT   
      ,@nMobile        INT   
      ,@cLangCode      NVARCHAR(3)
      ,@cFacility      NVARCHAR(5)
      ,@cReceiptKey    NVARCHAR(10)
      ,@cStorerKey     NVARCHAR(15) 
      ,@cSKU           NVARCHAR(20)
      ,@cExternPOKey   NVARCHAR(30)
      ,@cToLoc         NVARCHAR(10)
      ,@cToID          NVARCHAR(18)
      ,@cCartonId      NVARCHAR(20)
      ,@nQtyReceived   INT
      ,@cConditionCode NVARCHAR(1)
      ,@nErrNo         INT         OUTPUT
      ,@cErrMsg        NVARCHAR(20) OUTPUT
    
    
 )
AS
BEGIN
    SET NOCOUNT ON
    SET QUOTED_IDENTIFIER OFF
    SET ANSI_NULLS OFF
    SET CONCAT_NULL_YIELDS_NULL OFF

    DECLARE @nTranCount            INT

    DECLARE   @cExternReceiptKey      NVARCHAR( 20),  
		        @cExternLineNo          NVARCHAR( 20),  
		        @cAltSku                NVARCHAR( 20),  
		        @cVesselKey             NVARCHAR( 18),  
		        @cVoyageKey             NVARCHAR( 18),  
		        @cXdockKey              NVARCHAR( 18),  
		        @cContainerKey          NVARCHAR( 18),  
		        @nUnitPrice             FLOAT,      
		        @nExtendedPrice         FLOAT,      
		        @nFreeGoodQtyExpected   INT,        
		        @nFreeGoodQtyReceived   INT,        
		        @cExportStatus          NVARCHAR(  1),  
		        @cLoadKey               NVARCHAR( 10),  
		        @cUserDefine01          NVARCHAR( 30),
		        @cUserDefine02          NVARCHAR( 30),
		        @cUserDefine03          NVARCHAR( 30),
		        @cUserDefine04          NVARCHAR( 30),
		        @cUserDefine05          NVARCHAR( 30),
		        @dtUserDefine06         DATETIME,   
		        @dtUserDefine07         DATETIME,   
		        @cUserDefine08          NVARCHAR( 30),
		        @cUserDefine09          NVARCHAR( 30),
		        @cUserDefine10          NVARCHAR( 30),
              @cPoLineNo              NVARCHAR(  5),
              @cOrgPOKey              NVARCHAR( 10),
              @cPOKey                 NVARCHAR( 10),
              @cUOM                   NVARCHAR( 10),
              @cNewReceiptLineNumber  NVARCHAR( 5),
              @cPackKey               NVARCHAR( 10),
              @cTariffkey             NVARCHAR( 10),
              @cSubreasonCode         NVARCHAR( 10),
              @cReceiptLineNo_Borrowed NVARCHAR( 5),
              @cLottable01            NVARCHAR( 18),    
              @cLottable02            NVARCHAR( 18),    
              @cLottable03            NVARCHAR( 18),    
              @dLottable04            DATETIME,
              @cExterPOKeyRD          NVARCHAR( 20),
              @cReceiptLineNumber     NVARCHAR( 5),
              @cItemClass             NVARCHAR( 10),
              @cExecStatements		  nvarchar(4000),
              @cExecArguments         nvarchar(4000),
              @cExtraID               NVARCHAR( 1),
              @cExtraSKU              NVARCHAR( 1),
              @cUserDefine            NVARCHAR( 2),
              @cConditionSQL          nvarchar(4000),
              @cExecStatements_2		  nvarchar(4000),
              @cExecStatements_3		  nvarchar(4000),
              @nDistributeReceivedQty INT,
              @nTotalRecordCount      INT,
              @nRecordCount           INT,
              @nQtyExpected           INT,
              @nBeforeReceivedQty     INT,
              @cDisAllowRDTOverReceipt NVARCHAR(1), -- (ChewKP01)
              @cLottable06            NVARCHAR( 30),    
              @cLottable07            NVARCHAR( 30),
              @cLottable08            NVARCHAR( 30),
              @cLottable09            NVARCHAR( 30),
              @cLottable10            NVARCHAR( 30),
              @cLottable11            NVARCHAR( 30),
              @cLottable12            NVARCHAR( 30),
              @dLottable13            DATETIME,
              @dLottable14            DATETIME,
              @dLottable15            DATETIME
              

   -- (james01)
   DECLARE   @cNewLoc                 NVARCHAR( 10), 
             @cNewID                  NVARCHAR( 18) 

    SET @nTranCount = @@TRANCOUNT
    SET @cReceiptLineNumber = ''
    
    -- (ChewKP01)
    SET @cDisAllowRDTOverReceipt = ''
    SET @cDisAllowRDTOverReceipt = rdt.RDTGetConfig( @nFunc, 'DisAllowRDTOverReceipt', @cStorerKey) -- Parse in Function
    

    BEGIN TRAN
    SAVE TRAN TM_CartonIDReceive_Confirm
    
    SET @cExtraID = 'N'
    SET @cExtraSKU = 'N'
    SET @cUserDefine = ''
    SET @cConditionSQL = ''
       
    -- Condition Checking 
    -- If Carton ID exist in ReceiptDetail
    IF EXISTS ( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK)
                WHERE StorerKey = @cStorerKey
                AND ReceiptKey = @cReceiptKey
                AND UserDefine02 = @cExternPOKey
                --AND SKU = @cSKU
                AND UserDefine01 = @cCartonID )
    BEGIN
      -- If SKU with Same Carton ID exist in ReceiptDetail
      IF EXISTS ( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                  AND ReceiptKey = @cReceiptKey
                  AND UserDefine02 = @cExternPOKey
                  AND UserDefine01 = @cCartonID
                  AND SKU = @cSKU )
      BEGIN
         SET @cExtraID = 'N'
         SET @cExtraSKU = 'N'
         SET @cUserDefine = '01'
      END
      ELSE
      BEGIN
         SET @cExtraID = 'N'
         SET @cExtraSKU = 'Y'
         SET @cUserDefine = '01'
      END
   END
   ELSE 
   BEGIN
      -- Extra CartonID / Extra SKU
      IF EXISTS ( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                  AND ReceiptKey = @cReceiptKey
                  AND UserDefine02 = @cExternPOKey
                  --AND SKU = @cSKU
                  AND UserDefine08 = @cCartonID )
      BEGIN
         -- If SKU with Same Carton ID exist in ReceiptDetail
         IF EXISTS ( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                     AND ReceiptKey = @cReceiptKey
                     AND UserDefine02 = @cExternPOKey
                     AND UserDefine08 = @cCartonID
                     AND SKU = @cSKU )
         BEGIN
            SET @cExtraID = 'N'
            SET @cExtraSKU = 'N'
            SET @cUserDefine = '08'
         END
         ELSE
         BEGIN
            SET @cExtraID = 'N'
            SET @cExtraSKU = 'Y'
            SET @cUserDefine = '08'
         END
      END  
      ELSE
      BEGIN
         IF EXISTS ( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                     AND ReceiptKey = @cReceiptKey
                     AND UserDefine02 = @cExternPOKey
                     AND SKU = @cSKU )
         BEGIN
            SET @cExtraID = 'Y'
            SET @cExtraSKU = 'N'
            SET @cUserDefine = '08'
         END
         ELSE
         BEGIN 
            SET @cExtraID = 'Y'
            SET @cExtraSKU = 'Y'
            SET @cUserDefine = '08'
                  
            -- GET ItemClass
            SET @cItemClass = ''
            SELECT @cItemClass = ItemClass FROM dbo.SKU WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND SKU = @cSKU
         END
      END                 
   END     
            
   -- PROCESS_RECEIVING
       
   SET @cExecStatements = 'SELECT	TOP 1 ' +
                        '  @cReceiptLineNumber   = RD.ReceiptLineNumber  , ' +
                        '  @cExternReceiptKey    = RD.ExternReceiptKey   , ' + 
   						   '  @cExternLineNo        = RD.ExternLineNo       , ' +
   						   '  @cAltSku              = RD.AltSku             , ' +
   						   '  @cVesselKey           = RD.VesselKey          , ' +
   						   '  @cVoyageKey           = RD.VoyageKey          , ' +
   						   '  @cXdockKey            = RD.XdockKey           , ' +
   						   '  @cContainerKey        = RD.ContainerKey       , ' +
   						   '  @nUnitPrice           = RD.UnitPrice          , ' +
   						   '  @nExtendedPrice       = RD.ExtendedPrice      , ' +
   						   '  @nFreeGoodQtyExpected = RD.FreeGoodQtyExpected, ' +
   						   '  @nFreeGoodQtyReceived = RD.FreeGoodQtyReceived, ' +
   						   '  @cExportStatus        = RD.ExportStatus       , ' +
   						   '  @cLoadKey             = RD.LoadKey            , ' +
   						   '  @cExterPOKeyRD        = RD.ExternPoKey        , ' +
                        '  @cPOKey               = RD.POKey              , ' +					
   						   '  @cUserDefine01        = RD.UserDefine01       , ' +
   						   '  @cUserDefine02        = RD.UserDefine02       , ' +
   						   '  @cUserDefine03        = RD.UserDefine03       , ' +
   						   '  @cUserDefine04        = RD.UserDefine04       , ' +
   						   '  @cUserDefine05        = RD.UserDefine05       , ' +
   						   '  @dtUserDefine06       = RD.UserDefine06       , ' +
   						   '  @dtUserDefine07       = RD.UserDefine07       , ' +
   						   '  @cUserDefine08        = RD.UserDefine08       , ' +
   						   '  @cUserDefine09        = RD.UserDefine09       , ' +
   						   '  @cUserDefine10        = RD.UserDefine10       , ' +
                        '  @cPoLineNo            = RD.POLineNumber       , ' +
                        '  @cUOM                 = RD.UOM                , ' +
                        '  @cPackkey             = RD.PackKey            , ' +
                        '  @cLottable01          = RD.Lottable01         , ' + 
                        '  @cLottable02          = RD.Lottable02         , ' +
                        '  @cLottable03          = RD.Lottable03         , ' +
                        '  @dLottable04          = RD.Lottable04         , ' +
                        '  @cLottable06          = RD.Lottable06         , ' +
                        '  @cLottable07          = RD.Lottable07         , ' +
                        '  @cLottable08          = RD.Lottable08         , ' +
                        '  @cLottable09          = RD.Lottable09         , ' +
                        '  @cLottable10          = RD.Lottable10         , ' +
                        '  @cLottable11          = RD.Lottable11         , ' +
                        '  @cLottable12          = RD.Lottable12         , ' +
                        '  @dLottable13          = RD.Lottable13         , ' +
                        '  @dLottable14          = RD.Lottable14         , ' +
                        '  @dLottable15          = RD.Lottable15           ' +
      	               ' FROM dbo.ReceiptDetail RD WITH (NOLOCK)          ' 
               	         
   SET @cExecStatements_2 =  ' WHERE RD.StorerKey = ''' + RTRIM(@cStorerKey)  + ''' ' + 
                            ' AND RD.ReceiptKey = ''' + RTRIM(@cReceiptKey) + ''' ' + 
                            ' AND RD.UserDefine02 = ''' + RTRIM(@cExternPOKey) + ''' '
/*
   IF NOT EXISTS (SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK) 
              WHERE StorerKey = @cStorerKey
              AND   ReceiptKey = @cReceiptKey
              AND   UserDefine02 = @cExternPOKey
              AND   ToLOC =  @cToLoc )
      SET @cNewLoc = 'Y'
   ELSE
      SET @cNewLoc = 'N'
      
   IF NOT EXISTS (SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK) 
              WHERE StorerKey = @cStorerKey
              AND   ReceiptKey = @cReceiptKey
              AND   UserDefine02 = @cExternPOKey
              AND   ToID =  @cToID )
      SET @cNewID = 'Y'
   ELSE
      SET @cNewID = 'N'

   IF @cNewLoc = 'Y' OR @cNewID = 'Y'
      GOTO Continue_AddLine
      */
   DECLARE @nb4ReceivedQty INT, @cb4ToLoc NVARCHAR(10), @cb4ToID NVARCHAR(18)
   IF @cExtraID = 'N' AND @cExtraSKU = 'N'
   BEGIN
      IF NOT EXISTS ( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK) 
                  WHERE StorerKey = @cStorerKey
                  AND   ReceiptKey = @cReceiptKey
                  AND   UserDefine02 = @cExternPOKey
                  AND   @cCartonID = CASE WHEN @cUserDefine = '01' THEN USERDEFINE01 ELSE USERDEFINE08 END
                  AND   ToLOC = @cToLOC
                  AND   ToID = @cToID
                  AND   SKU = @cSKU )
      BEGIN
         SELECT @nb4ReceivedQty = BeforeReceivedQty,  @cb4ToLoc = ToLoc, @cb4ToID = ToID 
         FROM dbo.ReceiptDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND   ReceiptKey = @cReceiptKey
         AND   UserDefine02 = @cExternPOKey
         AND   @cCartonID = CASE WHEN @cUserDefine = '01' THEN USERDEFINE01 ELSE USERDEFINE08 END
         AND   SKU = @cSKU
         ORDER BY BeforeReceivedQty 
      END
      ELSE
      BEGIN
      insert into traceinfo (tracename, timein, step1, step2, step3, step4, step5, col1, col2, col3, col4, col5)
      values ('cartonidb4', getdate(), @cStorerKey, @cb4ToLoc, @cToLOC, @cb4ToID, @cToID, @cReceiptKey, substring(@cExternPOKey, 1, 20), substring(@cExternPOKey, 21, 20), @cCartonID, @nb4ReceivedQty )
      
         SELECT @nb4ReceivedQty = BeforeReceivedQty,  @cb4ToLoc = ToLoc, @cb4ToID = ToID 
         FROM dbo.ReceiptDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND   ReceiptKey = @cReceiptKey
         AND   UserDefine02 = @cExternPOKey
         AND   @cCartonID = CASE WHEN @cUserDefine = '01' THEN USERDEFINE01 ELSE USERDEFINE08 END
         AND   ToLOC = @cToLOC
         AND   ToID = @cToID
         AND   SKU = @cSKU 
      END
      
      insert into traceinfo (tracename, timein, step1, step2, step3, step4, step5, col1, col2, col3, col4, col5)
      values ('cartonidaf', getdate(), @cStorerKey, @cb4ToLoc, @cToLOC, @cb4ToID, @cToID, @cReceiptKey, substring(@cExternPOKey, 1, 20), substring(@cExternPOKey, 21, 20), @cCartonID, @nb4ReceivedQty )

      IF @nb4ReceivedQty > 0 AND (@cb4ToLoc <> @cToLOC OR @cb4ToID <> @cToID)
         GOTO Continue_AddLine
         
      IF @cUserDefine = '01'
      BEGIN
         SET @nTotalRecordCount = 0
         SET @nRecordCount = 1
             
         SELECT @nTotalRecordcount = COUNT(ReceiptKey) 
         FROM dbo.ReceiptDetail WITH (NOLOCK)
         WHERE StorerKey  = @cStorerKey
             AND ReceiptKey   = @cReceiptKey
             AND UserDefine02 = @cExternPOKey
             AND SKU          = @cSKU
             AND UserDefine01 = @cCartonID

         IF @nb4ReceivedQty > 0
         BEGIN
            SELECT @nTotalRecordcount = COUNT(ReceiptKey) 
            FROM dbo.ReceiptDetail WITH (NOLOCK)
            WHERE StorerKey  = @cStorerKey
                AND ReceiptKey   = @cReceiptKey
                AND UserDefine02 = @cExternPOKey
                AND SKU          = @cSKU
                AND UserDefine01 = @cCartonID
                AND ToLOC        = @cToLOC
                AND ToID         = @cToID
             
            DECLARE CursorRDUpdate CURSOR LOCAL FAST_FORWARD READ_ONLY FOR            
            SELECT QtyExpected , BeforeReceivedQty, ReceiptLineNumber
            FROM dbo.ReceiptDetail WITH (NOLOCK)
            WHERE StorerKey  = @cStorerKey
                AND ReceiptKey   = @cReceiptKey
                AND UserDefine02 = @cExternPOKey
                AND SKU          = @cSKU
                AND UserDefine01 = @cCartonID
                AND ToLOC        = @cToLOC
                AND ToID         = @cToID
         END
         ELSE
         BEGIN
         SELECT @nTotalRecordcount = COUNT(ReceiptKey) 
         FROM dbo.ReceiptDetail WITH (NOLOCK)
         WHERE StorerKey  = @cStorerKey
             AND ReceiptKey   = @cReceiptKey
             AND UserDefine02 = @cExternPOKey
             AND SKU          = @cSKU
             AND UserDefine01 = @cCartonID
             
            DECLARE CursorRDUpdate CURSOR LOCAL FAST_FORWARD READ_ONLY FOR            
            SELECT QtyExpected , BeforeReceivedQty, ReceiptLineNumber
            FROM dbo.ReceiptDetail WITH (NOLOCK)
            WHERE StorerKey  = @cStorerKey
                AND ReceiptKey   = @cReceiptKey
                AND UserDefine02 = @cExternPOKey
                AND SKU          = @cSKU
                AND UserDefine01 = @cCartonID
         END
             
         OPEN CursorRDUpdate            

         FETCH NEXT FROM CursorRDUpdate INTO @nQtyExpected, @nBeforeReceivedQty, @cReceiptLineNumber

         WHILE @@FETCH_STATUS <> -1            
         BEGIN   
                   
            IF @nQtyExpected = @nBeforeReceivedQty + @nQtyReceived
            BEGIN
               SET @nDistributeReceivedQty = @nQtyReceived
            END
            ELSE IF @nQtyExpected > @nBeforeReceivedQty + @nQtyReceived
            BEGIN
               SET @nDistributeReceivedQty = @nQtyReceived
            END
            ELSE IF @nQtyExpected < @nBeforeReceivedQty + @nQtyReceived
            BEGIN
               IF @cDisAllowRDTOverReceipt <> '1' 
               BEGIN
                  IF @nQtyExpected > @nBeforeReceivedQty 
                  BEGIN
                     SET @nDistributeReceivedQty = @nQtyExpected - @nBeforeReceivedQty
                  END
                  ELSE
                  BEGIN
                     SET @nDistributeReceivedQty = @nQtyReceived
                  END
               END
               ELSE
               BEGIN
                  SET @nErrNo = 76307
                  SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'NotAllowOverReceipt'
                  GOTO RollBackTran
               END                           
            END
            
            -- IF Last Record BeforeReceivedQty = QtyReceived
            IF @nRecordCount = @nTotalRecordcount
            BEGIN
               SET @nDistributeReceivedQty = @nQtyReceived
            END
            ELSE 
            BEGIN
               IF ( @nTotalRecordcount > 1 ) AND (@nBeforeReceivedQty = @nQtyExpected)
               BEGIN
                  SET @nRecordCount = @nRecordCount + 1
                  FETCH NEXT FROM CursorRDUpdate INTO @nQtyExpected, @nBeforeReceivedQty, @cReceiptLineNumber
                  CONTINUE
               END
            END
                                                                         
            UPDATE dbo.ReceiptDetail WITH (ROWLOCK)
               SET BeforeReceivedQty = BeforeReceivedQty + @nDistributeReceivedQty
               ,UserDefine05 = @cConditionCode
               ,ToLoc = @cToLoc
               ,ToID = @cToID
            WHERE StorerKey  = @cStorerKey
            AND ReceiptKey   = @cReceiptKey
            AND UserDefine02 = @cExternPOKey
            AND SKU          = @cSKU
            AND UserDefine01 = @cCartonID
            AND ReceiptLineNumber = @cReceiptLineNumber
                   
            IF @@ERROR <> 0 
            BEGIN
               SET @nErrNo = 76301
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdReceiptDetFail'
               GOTO RollBackTran
            END

            SET @nQtyReceived = @nQtyReceived - @nDistributeReceivedQty
            SET @nRecordCount = @nRecordCount + 1
            SET @nDistributeReceivedQty = 0

            FETCH NEXT FROM CursorRDUpdate INTO @nQtyExpected, @nBeforeReceivedQty, @cReceiptLineNumber
         END
         CLOSE CursorRDUpdate            
         DEALLOCATE CursorRDUpdate  

         GOTO QUIT
      END
      ELSE IF @cUserDefine = '08'
      BEGIN
         SET @nTotalRecordCount = 0
         SET @nRecordCount = 1
             
         SELECT @nTotalRecordcount = COUNT(ReceiptKey) 
         FROM dbo.ReceiptDetail WITH (NOLOCK)
         WHERE StorerKey  = @cStorerKey
             AND ReceiptKey   = @cReceiptKey
             AND UserDefine02 = @cExternPOKey
             AND SKU          = @cSKU
             AND UserDefine08 = @cCartonID
             
         DECLARE CursorRDUpdate CURSOR LOCAL FAST_FORWARD READ_ONLY FOR            
             
         SELECT QtyExpected , BeforeReceivedQty, ReceiptLineNumber
         FROM dbo.ReceiptDetail WITH (NOLOCK)
         WHERE StorerKey  = @cStorerKey
             AND ReceiptKey   = @cReceiptKey
             AND UserDefine02 = @cExternPOKey
             AND SKU          = @cSKU
             AND UserDefine08 = @cCartonID

         OPEN CursorRDUpdate            
             
         FETCH NEXT FROM CursorRDUpdate INTO @nQtyExpected, @nBeforeReceivedQty, @cReceiptLineNumber

         WHILE @@FETCH_STATUS <> -1            
         BEGIN  
               
            IF @nQtyExpected = @nBeforeReceivedQty + @nQtyReceived
            BEGIN
               SET @nDistributeReceivedQty = @nQtyReceived
            END
            ELSE IF @nQtyExpected > @nBeforeReceivedQty + @nQtyReceived
            BEGIN
               SET @nDistributeReceivedQty = @nQtyReceived
            END
            ELSE IF @nQtyExpected < @nBeforeReceivedQty + @nQtyReceived
            BEGIN
               -- (ChewKP01)
               IF @cDisAllowRDTOverReceipt <> '1' 
               BEGIN
                  IF @nQtyExpected > @nBeforeReceivedQty 
                  BEGIN
                     SET @nDistributeReceivedQty = @nQtyExpected - @nBeforeReceivedQty
                  END
                  ELSE
                  BEGIN
                     SET @nDistributeReceivedQty = @nQtyReceived
                  END
               END   
               ELSE
               BEGIN
                  SET @nErrNo = 76308
                  SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'NotAllowOverReceipt'
                  GOTO RollBackTran
               END 
            END

            -- IF Last Record BeforeReceivedQty = QtyReceived
            IF @nRecordCount = @nTotalRecordcount
            BEGIN
               SET @nDistributeReceivedQty = @nQtyReceived
            END
            ELSE 
            BEGIN
               IF ( @nTotalRecordcount > 1 ) AND (@nBeforeReceivedQty = @nQtyExpected)
               BEGIN
                  SET @nRecordCount = @nRecordCount + 1
                  FETCH NEXT FROM CursorRDUpdate INTO @nQtyExpected, @nBeforeReceivedQty, @cReceiptLineNumber
                  CONTINUE
               END
            END

            UPDATE dbo.ReceiptDetail WITH (ROWLOCK)
               SET BeforeReceivedQty = BeforeReceivedQty + @nDistributeReceivedQty
               ,UserDefine05 = @cConditionCode
               ,ToLoc = @cToLoc
               ,ToID = @cToID
            WHERE StorerKey  = @cStorerKey
            AND ReceiptKey   = @cReceiptKey
            AND UserDefine02 = @cExternPOKey
            AND SKU          = @cSKU
            AND UserDefine08 = @cCartonID
            AND ReceiptLineNumber = @cReceiptLineNumber
                   
            IF @@ERROR <> 0 
            BEGIN
               SET @nErrNo = 76305
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdReceiptDetFail'
               GOTO RollBackTran
            END

            SET @nQtyReceived = @nQtyReceived - @nDistributeReceivedQty
            SET @nRecordCount = @nRecordCount + 1

            FETCH NEXT FROM CursorRDUpdate INTO @nQtyExpected, @nBeforeReceivedQty, @cReceiptLineNumber
         END
         CLOSE CursorRDUpdate            
         DEALLOCATE CursorRDUpdate  

         GOTO QUIT
      END
         
   END

   Continue_Addline:
   IF @cDisAllowRDTOverReceipt <> '1' -- (ChewKP01)
   BEGIN
      IF @cExtraID = 'N' AND @cExtraSKU = 'N'
      BEGIN
         IF @cUserDefine = '01'
         BEGIN
            SET @cConditionSQL = ' AND UserDefine01 = ''' + RTRIM(@cCartonID) + ''' '
         END
      
         IF @cUserDefine = '08'
         BEGIN
            SET @cConditionSQL = ' AND UserDefine08 = ''' + RTRIM(@cCartonID) + ''' '
         END
      END
      
      IF @cExtraID = 'N' AND @cExtraSKU = 'Y'
      BEGIN
         IF @cUserDefine = '01'
         BEGIN
            SET @cConditionSQL = ' AND UserDefine01 = ''' + RTRIM(@cCartonID) + ''' '
         END
      
         IF @cUserDefine = '08'
         BEGIN
            SET @cConditionSQL = ' AND UserDefine08 = ''' + RTRIM(@cCartonID) + ''' '
         END
      END
          
      IF @cExtraID = 'Y' AND @cExtraSKU = 'N'
      BEGIN
         IF @cUserDefine = '08'
         BEGIN
            SET @cConditionSQL = ' AND SKU = ''' + RTRIM(@cSKU) + ''''
         END
      END  
          
      IF @cExtraID = 'Y' AND @cExtraSKU = 'Y'
      BEGIN
         IF @cUserDefine = '08'
         BEGIN
         SET @cExecStatements_3 = ' LEFT OUTER JOIN SKU SKU WITH (NOLOCK) ON (SKU.SKU = ''' + RTRIM(ISNULL(@cSKU,'')) + '''  AND SKU.StorerKey = RD.StorerKey) ' 
         SET @cConditionSQL = ' AND SKU.ItemClass = ''' + RTRIM(@cItemClass) + ''' '
      END
      END
   END
   ELSE -- (ChewKP01)
   BEGIN 
      SET @nErrNo = 76306
      SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'DisAllowRDTOverReceipt'
      GOTO RollBackTran
   END
       
   IF @cExecStatements_3 = ''
   BEGIN
      SET @cExecStatements = RTRIM(@cExecStatements) + RTRIM(@cExecStatements_2) + RTRIM(@cConditionSQL)
   END
   ELSE
   BEGIN
      SET @cExecStatements = RTRIM(@cExecStatements) + RTRIM(@cExecStatements_3) + RTRIM(@cExecStatements_2) + RTRIM(@cConditionSQL)
   END
       
   SET @cExecArguments = N'  @cReceiptLineNumber     NVARCHAR( 5)       OUTPUT ,' + 
                        '  @cExternReceiptKey      NVARCHAR( 20)      OUTPUT ,' +   
         		         '  @cExternLineNo          NVARCHAR( 20)      OUTPUT ,' +   
         		         '  @cAltSku                NVARCHAR( 20)      OUTPUT ,' +   
         		         '  @cVesselKey             NVARCHAR( 18)      OUTPUT ,' +   
         		         '  @cVoyageKey             NVARCHAR( 18)      OUTPUT ,' +   
         		         '  @cXdockKey              NVARCHAR( 18)      OUTPUT ,' +   
         		         '  @cContainerKey          NVARCHAR( 18)      OUTPUT ,' +   
         		         '  @nUnitPrice             FLOAT          OUTPUT ,' +    
         		         '  @nExtendedPrice         FLOAT          OUTPUT ,' +   
         		         '  @nFreeGoodQtyExpected   INT            OUTPUT ,' +   
         		         '  @nFreeGoodQtyReceived   INT            OUTPUT ,' +   
         		         '  @cExportStatus          NVARCHAR(  1)      OUTPUT ,' +   
         		         '  @cLoadKey               NVARCHAR( 10)      OUTPUT ,' +  
         		         '  @cExterPOKeyRD          NVARCHAR( 20)      OUTPUT ,' +
         		         '  @cUserDefine01          NVARCHAR( 30)   OUTPUT ,' + 
         		         '  @cUserDefine02          NVARCHAR( 30)   OUTPUT ,' + 
         		         '  @cUserDefine03          NVARCHAR( 30)   OUTPUT ,' + 
         		         '  @cUserDefine04          NVARCHAR( 30)   OUTPUT ,' + 
         		         '  @cUserDefine05          NVARCHAR( 30)   OUTPUT ,' + 
         		         '  @dtUserDefine06         DATETIME       OUTPUT ,' + 
         		         '  @dtUserDefine07         DATETIME       OUTPUT ,' + 
         		         '  @cUserDefine08          NVARCHAR( 30)   OUTPUT ,' + 
         		         '  @cUserDefine09          NVARCHAR( 30)   OUTPUT ,' + 
         		         '  @cUserDefine10          NVARCHAR( 30)   OUTPUT ,' + 
                        '  @cPoLineNo              NVARCHAR(  5)   OUTPUT ,' + 
                        --'  @cOrgPOKey              NVARCHAR( 10),   ' + 
                        '  @cPOKey                 NVARCHAR( 10)      OUTPUT ,' + 
                        '  @cUOM                   NVARCHAR( 10)      OUTPUT ,' + 
                        --'  @cNewReceiptLineNumber  NVARCHAR( 5),    ' + 
                        '  @cPackKey               NVARCHAR( 10)      OUTPUT ,' + 
                        --'  @cTariffkey             NVARCHAR( 10),   ' + 
                        --'  @cSubreasonCode         NVARCHAR( 10),   ' + 
                        --'  @cReceiptLineNo_Borrowed NVARCHAR( 5),   ' + 
                        '  @cLottable01            NVARCHAR( 18)      OUTPUT ,' +   
                        '  @cLottable02            NVARCHAR( 18)      OUTPUT ,' +  
                        '  @cLottable03            NVARCHAR( 18)      OUTPUT ,' +  
                        '  @dLottable04            DATETIME           OUTPUT ,' + 
                        '  @cLottable06            NVARCHAR( 30)      OUTPUT ,' +
                        '  @cLottable07            NVARCHAR( 30)      OUTPUT ,' +
                        '  @cLottable08            NVARCHAR( 30)      OUTPUT ,' +
                        '  @cLottable09            NVARCHAR( 30)      OUTPUT ,' +
                        '  @cLottable10            NVARCHAR( 30)      OUTPUT ,' +
                        '  @cLottable11            NVARCHAR( 30)      OUTPUT ,' +
                        '  @cLottable12            NVARCHAR( 30)      OUTPUT ,' +
                        '  @dLottable13            DATETIME           OUTPUT ,' +
                        '  @dLottable14            DATETIME           OUTPUT ,' +
                        '  @dLottable15            DATETIME           OUTPUT ,' +                        
                        '  @cStorerKey             NVARCHAR( 15)  ,   ' +
                        '  @cReceiptKey            NVARCHAR( 10)      ' 
       
   EXEC sp_ExecuteSql @cExecStatements
                        , @cExecArguments 
                        , @cReceiptLineNumber      OUTPUT   
                        , @cExternReceiptKey       OUTPUT 
                        , @cExternLineNo           OUTPUT 
                        , @cAltSku                 OUTPUT 
                        , @cVesselKey              OUTPUT 
                        , @cVoyageKey              OUTPUT 
                        , @cXdockKey               OUTPUT 
                        , @cContainerKey           OUTPUT 
                        , @nUnitPrice              OUTPUT 
                        , @nExtendedPrice          OUTPUT 
                        , @nFreeGoodQtyExpected    OUTPUT 
                        , @nFreeGoodQtyReceived    OUTPUT 
                        , @cExportStatus           OUTPUT 
                        , @cLoadKey                OUTPUT 
                        , @cExterPOKeyRD           OUTPUT   
                        , @cUserDefine01           OUTPUT 
                        , @cUserDefine02           OUTPUT 
                        , @cUserDefine03           OUTPUT 
                        , @cUserDefine04           OUTPUT 
                        , @cUserDefine05           OUTPUT 
                        , @dtUserDefine06          OUTPUT 
                        , @dtUserDefine07          OUTPUT 
                        , @cUserDefine08           OUTPUT 
                        , @cUserDefine09           OUTPUT 
                        , @cUserDefine10           OUTPUT 
                        , @cPoLineNo               OUTPUT 
                        --, @cOrgPOKey               OUTPUT 
                        , @cPOKey                  OUTPUT 
                        , @cUOM                    OUTPUT 
                        --, @cNewReceiptLineNumber   OUTPUT 
                        , @cPackKey                OUTPUT 
                        --, @cTariffkey              OUTPUT 
                        --, @cSubreasonCode          OUTPUT 
                        --, @cReceiptLineNo_Borrowed OUTPUT 
                        , @cLottable01             OUTPUT 
                        , @cLottable02             OUTPUT 
                        , @cLottable03             OUTPUT 
                        , @dLottable04             OUTPUT 
                        , @cLottable06             OUTPUT
                        , @cLottable07             OUTPUT
                        , @cLottable08             OUTPUT
                        , @cLottable09             OUTPUT
                        , @cLottable10             OUTPUT
                        , @cLottable11             OUTPUT
                        , @cLottable12             OUTPUT
                        , @dLottable13             OUTPUT
                        , @dLottable14             OUTPUT
                        , @dLottable15             OUTPUT
                        , @cStorerKey             
                        , @cReceiptKey            

   IF @@RowCount = 0
   BEGIN
      SET @nErrNo = 76304
      SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'NoRecordFound'
      GOTO RollBackTran
   END
       
   SET @cNewReceiptLineNumber = ''      
   SELECT @cNewReceiptLineNumber = 
   RIGHT( '00000' + CAST( CAST( IsNULL( MAX( ReceiptLineNumber), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
   FROM dbo.ReceiptDetail (NOLOCK)
   WHERE ReceiptKey = @cReceiptKey
       
   -- Insert new ReceiptDetail line
   INSERT INTO dbo.ReceiptDetail 
      (ReceiptKey, ReceiptLineNumber, POKey, StorerKey, SKU, QTYExpected, BeforeReceivedQTY, 
      ToID, ToLOC, --Lottable01, Lottable02, Lottable03, Lottable04, --Lottable05, 
      Status, DateReceived, UOM, PackKey,  EffectiveDate, TariffKey, FinalizeFlag, SplitPalletFlag,
      ExternReceiptKey, ExternLineNo, AltSku, VesselKey, -- Added By Vicky
      VoyageKey, XdockKey, ContainerKey, UnitPrice, ExtendedPrice, FreeGoodQtyExpected,
      FreeGoodQtyReceived, ExportStatus, LoadKey, ExternPoKey,
      UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05,
      UserDefine06, UserDefine07, UserDefine08, UserDefine09, UserDefine10, POLineNumber, SubReasonCode, DuplicateFrom,
      Lottable01, Lottable02, Lottable03, Lottable04, Lottable06, 
      Lottable07, Lottable08, Lottable09, Lottable10, Lottable11, 
      Lottable12, Lottable13, Lottable14, Lottable15) 
   VALUES (
      @cReceiptKey, @cNewReceiptLineNumber, @cPOKey, @cStorerKey, @cSKU, 0, @nQtyReceived,  
      @cToID, @cToLOC, --@cLottable01, @cLottable02, @cLottable03, @dLottable04, --@dLottable05, 
      '0', GETDATE(), @cUOM, @cPackKey, GETDATE(), ISNULL(@cTariffKey,''), 'N', 'N',
      ISNULL(@cExternReceiptKey,''), '', ISNULL(@cAltSku, ''), ISNULL(@cVesselKey,''), 
      ISNULL(@cVoyageKey, ''), ISNULL(@cXdockKey, ''), ISNULL(@cContainerKey, ''), ISNULL(@nUnitPrice, 0), ISNULL(@nExtendedPrice, 0), ISNULL(@nFreeGoodQtyExpected, 0),
      ISNULL(@nFreeGoodQtyReceived, 0), ISNULL(@cExportStatus, '0'), @cLoadKey, @cExterPOKeyRD, 
      ISNULL(@cUserDefine01, ''), ISNULL(@cUserDefine02, ''), ISNULL(@cUserDefine03, ''), ISNULL(@cUserDefine04, ''), ISNULL(@cConditionCode, ''),
      @dtUserDefine06, @dtUserDefine07, ISNULL(RTRIM(@cCartonID),''), ISNULL(@cUserDefine09, ''), ISNULL(@cUserDefine10, ''), 
      ISNULL(@cPoLineNo, ''), ISNULL(@cSubreasonCode,'') , @cReceiptLineNumber, -- (ChewKP01)
      ISNULL(@cLottable01,''), ISNULL(@cLottable02,''), ISNULL(@cLottable03,''), ISNULL(@dLottable04,''), ISNULL(@cLottable06,''), 
      ISNULL(@cLottable07,''), ISNULL(@cLottable08,''), ISNULL(@cLottable09,''), ISNULL(@cLottable10,''), ISNULL(@cLottable11,''),
      ISNULL(@cLottable12,''), ISNULL(@dLottable13,''), ISNULL(@dLottable14,''), ISNULL(@dLottable15,'') )
       
   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 76302
      SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'InsReceiptDetFail'
      GOTO RollBackTran
   END                 

   GOTO Quit
           
   RollBackTran:
   ROLLBACK TRAN TM_CartonIDReceive_Confirm
    
   Quit:  
   WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started
      COMMIT TRAN TM_CartonIDReceive_Confirm
END        

GO