SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_ReceiveByShipmentID_Confirm                     */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Confirm Receiving                                           */
/*                                                                      */
/* Called from: rdtfnc_ReceiveByShipmentID                              */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 21-03-2013 1.0  James    Created                                     */
/************************************************************************/

CREATE PROC [RDT].[rdt_ReceiveByShipmentID_Confirm] (
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
      ,@cConditionCode NVARCHAR(10)
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

    DECLARE   @cExternReceiptKey       NVARCHAR( 20),  
		        @cExternLineNo           NVARCHAR( 20),  
		        @cAltSku                 NVARCHAR( 20),  
		        @cVesselKey              NVARCHAR( 18),  
		        @cVoyageKey              NVARCHAR( 18),  
		        @cXdockKey               NVARCHAR( 18),  
		        @cContainerKey           NVARCHAR( 18),  
		        @nUnitPrice              FLOAT,      
		        @nExtendedPrice          FLOAT,      
		        @nFreeGoodQtyExpected    INT,        
		        @nFreeGoodQtyReceived    INT,        
		        @cExportStatus           NVARCHAR(  1),  
		        @cLoadKey                NVARCHAR( 10),  
		        @cUserDefine01           NVARCHAR( 30),
		        @cUserDefine02           NVARCHAR( 30),
		        @cUserDefine03           NVARCHAR( 30),
		        @cUserDefine04           NVARCHAR( 30),
		        @cUserDefine05           NVARCHAR( 30),
		        @dtUserDefine06          DATETIME,   
		        @dtUserDefine07          DATETIME,   
		        @cUserDefine08           NVARCHAR( 30),
		        @cUserDefine09           NVARCHAR( 30),
		        @cUserDefine10           NVARCHAR( 30),
              @cPoLineNo               NVARCHAR(  5),
              @cOrgPOKey               NVARCHAR( 10),
              @cPOKey                  NVARCHAR( 10),
              @cUOM                    NVARCHAR( 10),
              @cNewReceiptLineNumber   NVARCHAR( 5),
              @cPackKey                NVARCHAR( 10),
              @cTariffkey              NVARCHAR( 10),
              @cSubreasonCode          NVARCHAR( 10),
              @cReceiptLineNo_Borrowed NVARCHAR( 5),
              @cLottable01             NVARCHAR( 18),    
              @cLottable02             NVARCHAR( 18),    
              @cLottable03             NVARCHAR( 18),    
              @dLottable04             DATETIME,
              @cExterPOKeyRD           NVARCHAR( 20),
              @cReceiptLineNumber      NVARCHAR( 5),
              @cItemClass              NVARCHAR( 10),
              @cExecStatements		   NVARCHAR( 4000),
              @cExecArguments          NVARCHAR( 4000),
              @cExtraID                NVARCHAR( 1),
              @cExtraSKU               NVARCHAR( 1),
              @cUserDefine             NVARCHAR( 2),
              @cConditionSQL           NVARCHAR( 4000),
              @cExecStatements_2		   NVARCHAR( 4000),
              @cExecStatements_3		   NVARCHAR( 4000),
              @nDistributeReceivedQty  INT,
              @nTotalRecordCount       INT,
              @nRecordCount            INT,
              @nQtyExpected            INT,
              @nBeforeReceivedQty      INT,
              @cDisAllowRDTOverReceipt NVARCHAR( 1), 
              @cNewLoc                 NVARCHAR( 10), 
              @cNewID                  NVARCHAR( 18) 

    SET @nTranCount = @@TRANCOUNT
    SET @cReceiptLineNumber = ''
    
    SET @cDisAllowRDTOverReceipt = ''
    SET @cDisAllowRDTOverReceipt = rdt.RDTGetConfig( @nFunc, 'DisAllowRDTOverReceipt', @cStorerKey) -- Parse in Function

    BEGIN TRAN
    SAVE TRAN TM_ShipmentID_Confirm
    
    SET @cExtraID = 'N'
    SET @cExtraSKU = 'N'
    SET @cUserDefine = ''
    SET @cConditionSQL = ''
       
    -- Condition Checking 
    -- If Carton ID exist in ReceiptDetail
    IF EXISTS ( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK)
                WHERE StorerKey = @cStorerKey
                AND ReceiptKey = @cReceiptKey
                AND UserDefine01 = @cCartonID )
    BEGIN
      -- If SKU with Same Carton ID exist in ReceiptDetail
      IF EXISTS ( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                  AND ReceiptKey = @cReceiptKey
                  AND UserDefine01 = @cCartonID
                  AND SKU = @cSKU )
      BEGIN
         SET @cExtraID = 'N'
         SET @cExtraSKU = 'N'
      END
      ELSE
      BEGIN
         SET @cExtraID = 'N'
         SET @cExtraSKU = 'Y'
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
   						   '  @cConditionCode       = RD.ConditionCode      , ' +
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
                        '  @dLottable04          = RD.Lottable04           ' +
      	             ' FROM dbo.ReceiptDetail RD WITH (NOLOCK) ' 
               	         
   SET @cExecStatements_2 =  ' WHERE RD.StorerKey = ''' + RTRIM(@cStorerKey)  + ''' ' + 
                            ' AND RD.ReceiptKey = ''' + RTRIM(@cReceiptKey) + ''' ' 

   DECLARE @nb4ReceivedQty INT, @cb4ToLoc NVARCHAR(10), @cb4ToID NVARCHAR(18), @cb4FinalizeFlag NVARCHAR( 1)
   IF @cExtraID = 'N' AND @cExtraSKU = 'N'
   BEGIN
      IF NOT EXISTS ( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK) 
                  WHERE StorerKey = @cStorerKey
                  AND   ReceiptKey = @cReceiptKey
                  AND   UserDefine01 = @cCartonID 
                  AND   ToLOC = @cToLOC
                  AND   SKU = @cSKU )
      BEGIN
         SELECT @nb4ReceivedQty = BeforeReceivedQty,  @cb4ToLoc = ToLoc, @cb4FinalizeFlag = FinalizeFlag 
         FROM dbo.ReceiptDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND   ReceiptKey = @cReceiptKey
         AND   UserDefine01 = @cCartonID
         AND   SKU = @cSKU
         ORDER BY BeforeReceivedQty 
      END
      ELSE
      BEGIN
         SELECT @nb4ReceivedQty = BeforeReceivedQty,  @cb4ToLoc = ToLoc, @cb4FinalizeFlag = FinalizeFlag  
         FROM dbo.ReceiptDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND   ReceiptKey = @cReceiptKey
         AND   UserDefine01 = @cCartonID
         AND   ToLOC = @cToLOC
         AND   ToID = @cToID
         AND   SKU = @cSKU 
      END
      
      IF (@nb4ReceivedQty > 0 AND @cb4ToLoc <> @cToLOC) OR @cb4FinalizeFlag = 'Y'
         GOTO Continue_AddLine
         
      SET @nTotalRecordCount = 0
      SET @nRecordCount = 1
          
      SELECT @nTotalRecordcount = COUNT(ReceiptKey) 
      FROM dbo.ReceiptDetail WITH (NOLOCK)
      WHERE StorerKey  = @cStorerKey
          AND ReceiptKey   = @cReceiptKey
          AND SKU          = @cSKU
          AND UserDefine01 = @cCartonID

      IF @nb4ReceivedQty > 0
      BEGIN
         SELECT @nTotalRecordcount = COUNT(ReceiptKey) 
         FROM dbo.ReceiptDetail WITH (NOLOCK)
         WHERE StorerKey  = @cStorerKey
             AND ReceiptKey   = @cReceiptKey
             AND SKU          = @cSKU
             AND UserDefine01 = @cCartonID
             AND ToLOC        = @cToLOC
             AND ToID         = @cToID
          
         DECLARE CursorRDUpdate CURSOR LOCAL FAST_FORWARD READ_ONLY FOR            
         SELECT QtyExpected , BeforeReceivedQty, ReceiptLineNumber
         FROM dbo.ReceiptDetail WITH (NOLOCK)
         WHERE StorerKey  = @cStorerKey
             AND ReceiptKey   = @cReceiptKey
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
          AND SKU          = @cSKU
          AND UserDefine01 = @cCartonID
          
         DECLARE CursorRDUpdate CURSOR LOCAL FAST_FORWARD READ_ONLY FOR            
         SELECT QtyExpected , BeforeReceivedQty, ReceiptLineNumber
         FROM dbo.ReceiptDetail WITH (NOLOCK)
         WHERE StorerKey  = @cStorerKey
             AND ReceiptKey   = @cReceiptKey
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
               SET @nErrNo = 80501
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
            ,ToLoc = @cToLoc
            ,ToID = @cToID
         WHERE StorerKey  = @cStorerKey
         AND ReceiptKey   = @cReceiptKey
         AND SKU          = @cSKU
         AND UserDefine01 = @cCartonID
         AND ReceiptLineNumber = @cReceiptLineNumber
                
         IF @@ERROR <> 0 
         BEGIN
            SET @nErrNo = 80502
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdReceiptDetFail'
            GOTO RollBackTran
         END

         -- If no more discrepancy then update status = '1' (Audited) automatically
         IF EXISTS ( SELECT 1 
                     FROM dbo.ReceiptDetail WITH (NOLOCK) 
                     WHERE StorerKey  = @cStorerKey
                     AND ReceiptKey   = @cReceiptKey
                     AND SKU          = @cSKU
                     AND UserDefine01 = @cCartonID
                     AND ReceiptLineNumber = @cReceiptLineNumber
                     AND [Status] = '0'
                     HAVING ISNULL( SUM( QtyExpected), 0) = ISNULL( SUM( BeforeReceivedQty), 0))
         BEGIN
            UPDATE dbo.ReceiptDetail WITH (ROWLOCK) SET 
               [Status] = '1'
            WHERE StorerKey  = @cStorerKey
            AND ReceiptKey   = @cReceiptKey
            AND SKU          = @cSKU
            AND UserDefine01 = @cCartonID
            AND ReceiptLineNumber = @cReceiptLineNumber
            AND [Status] = '0'
            
            IF @@ERROR <> 0 
            BEGIN
               SET @nErrNo = 80506
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdReceiptDetFail'
               GOTO RollBackTran
            END
         END

         -- If over receipt and status = '1' (Audited) then need to update the status back to 0
         -- coz user need to audit again.
         IF EXISTS ( SELECT 1 
                     FROM dbo.ReceiptDetail WITH (NOLOCK) 
                     WHERE StorerKey  = @cStorerKey
                     AND ReceiptKey   = @cReceiptKey
                     AND SKU          = @cSKU
                     AND UserDefine01 = @cCartonID
                     AND ReceiptLineNumber = @cReceiptLineNumber
                     AND [Status] = '1'
                     HAVING ISNULL( SUM( QtyExpected), 0) < ISNULL( SUM( BeforeReceivedQty), 0))
         BEGIN
            UPDATE dbo.ReceiptDetail WITH (ROWLOCK) SET 
               [Status] = '0'
            WHERE StorerKey  = @cStorerKey
            AND ReceiptKey   = @cReceiptKey
            AND SKU          = @cSKU
            AND UserDefine01 = @cCartonID
            AND ReceiptLineNumber = @cReceiptLineNumber
            AND [Status] = '1'
            
            IF @@ERROR <> 0 
            BEGIN
               SET @nErrNo = 80508
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdReceiptDetFail'
               GOTO RollBackTran
            END
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

   Continue_Addline:
   IF @cDisAllowRDTOverReceipt <> '1' 
   BEGIN
      IF @cExtraID = 'N' AND @cExtraSKU = 'N'
         SET @cConditionSQL = ' AND UserDefine01 = ''' + RTRIM(@cCartonID) + ''' '
      
      IF @cExtraID = 'N' AND @cExtraSKU = 'Y'
         SET @cConditionSQL = ' AND UserDefine01 = ''' + RTRIM(@cCartonID) + ''' '
   END
   ELSE 
   BEGIN 
      SET @nErrNo = 80503
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
       
   SET @cExecArguments = N'  @cReceiptLineNumber     NVARCHAR( 5)     OUTPUT ,' + 
                        '  @cExternReceiptKey      NVARCHAR( 20)      OUTPUT ,' +   
         		         '  @cExternLineNo          NVARCHAR( 20)      OUTPUT ,' +   
         		         '  @cAltSku                NVARCHAR( 20)      OUTPUT ,' +   
         		         '  @cVesselKey             NVARCHAR( 18)      OUTPUT ,' +   
         		         '  @cVoyageKey             NVARCHAR( 18)      OUTPUT ,' +   
         		         '  @cXdockKey              NVARCHAR( 18)      OUTPUT ,' +   
         		         '  @cContainerKey          NVARCHAR( 18)      OUTPUT ,' +   
         		         '  @cConditionCode         NVARCHAR( 10)      OUTPUT ,' +   
         		         '  @nUnitPrice             FLOAT             OUTPUT ,' +    
         		         '  @nExtendedPrice         FLOAT             OUTPUT ,' +   
         		         '  @nFreeGoodQtyExpected   INT               OUTPUT ,' +   
         		         '  @nFreeGoodQtyReceived   INT               OUTPUT ,' +   
         		         '  @cExportStatus          NVARCHAR(  1)      OUTPUT ,' +   
         		         '  @cLoadKey               NVARCHAR( 10)      OUTPUT ,' +  
         		         '  @cExterPOKeyRD          NVARCHAR( 20)      OUTPUT ,' +
         		         '  @cUserDefine01          NVARCHAR( 30)      OUTPUT ,' + 
         		         '  @cUserDefine02          NVARCHAR( 30)      OUTPUT ,' + 
         		         '  @cUserDefine03          NVARCHAR( 30)      OUTPUT ,' + 
         		         '  @cUserDefine04          NVARCHAR( 30)      OUTPUT ,' + 
         		         '  @cUserDefine05          NVARCHAR( 30)      OUTPUT ,' + 
         		         '  @dtUserDefine06         DATETIME          OUTPUT ,' + 
         		         '  @dtUserDefine07         DATETIME          OUTPUT ,' + 
         		         '  @cUserDefine08          NVARCHAR( 30)      OUTPUT ,' + 
         		         '  @cUserDefine09          NVARCHAR( 30)      OUTPUT ,' + 
         		         '  @cUserDefine10          NVARCHAR( 30)      OUTPUT ,' + 
                        '  @cPoLineNo              NVARCHAR(  5)      OUTPUT ,' + 
                        '  @cPOKey                 NVARCHAR( 10)      OUTPUT ,' + 
                        '  @cUOM                   NVARCHAR( 10)      OUTPUT ,' + 
                        '  @cPackKey               NVARCHAR( 10)      OUTPUT ,' + 
                        '  @cLottable01            NVARCHAR( 18)      OUTPUT ,' +   
                        '  @cLottable02            NVARCHAR( 18)      OUTPUT ,' +  
                        '  @cLottable03            NVARCHAR( 18)      OUTPUT ,' +  
                        '  @dLottable04            DATETIME          OUTPUT ,' + 
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
                        , @cConditionCode          OUTPUT 
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
                        , @cPOKey                  OUTPUT 
                        , @cUOM                    OUTPUT 
                        , @cPackKey                OUTPUT 
                        , @cLottable01             OUTPUT 
                        , @cLottable02             OUTPUT 
                        , @cLottable03             OUTPUT 
                        , @dLottable04             OUTPUT 
                        , @cStorerKey             
                        , @cReceiptKey            

   IF @@RowCount = 0
   BEGIN
      SET @nErrNo = 80504
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
      ToID, ToLOC,   
      Status, DateReceived, UOM, PackKey,  EffectiveDate, TariffKey, FinalizeFlag, SplitPalletFlag,
      ExternReceiptKey, ExternLineNo, AltSku, VesselKey, 
      VoyageKey, XdockKey, ContainerKey, UnitPrice, ExtendedPrice, FreeGoodQtyExpected,
      FreeGoodQtyReceived, ExportStatus, LoadKey, ExternPoKey,
      UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05,
      UserDefine06, UserDefine07, UserDefine08, UserDefine09, UserDefine10, POLineNumber, SubReasonCode, DuplicateFrom,
      Lottable01, Lottable02, Lottable03, Lottable04, ConditionCode) 
   VALUES (
      @cReceiptKey, @cNewReceiptLineNumber, @cPOKey, @cStorerKey, @cSKU, 0, @nQtyReceived,  
      @cToID, @cToLOC, 
      '0', GETDATE(), @cUOM, @cPackKey, GETDATE(), ISNULL(@cTariffKey,''), 'N', 'N',
      ISNULL(@cExternReceiptKey,''), @cExternLineNo, ISNULL(@cAltSku, ''), ISNULL(@cVesselKey,''), 
      ISNULL(@cVoyageKey, ''), ISNULL(@cXdockKey, ''), ISNULL(@cContainerKey, ''), ISNULL(@nUnitPrice, 0), ISNULL(@nExtendedPrice, 0), ISNULL(@nFreeGoodQtyExpected, 0),
      ISNULL(@nFreeGoodQtyReceived, 0), ISNULL(@cExportStatus, '0'), @cLoadKey, @cExterPOKeyRD, 
      ISNULL(@cUserDefine01, ''), ISNULL(@cUserDefine02, ''), ISNULL(@cUserDefine03, ''), ISNULL(@cUserDefine04, ''), ISNULL(@cUserDefine05, ''),
      @dtUserDefine06, @dtUserDefine07, ISNULL(RTRIM(@cUserDefine08),''), ISNULL(@cUserDefine09, ''), ISNULL(@cUserDefine10, ''), 
      ISNULL(@cPoLineNo, ''), ISNULL(@cSubreasonCode,'') , @cReceiptLineNumber, 
      ISNULL(@cLottable01,''), ISNULL(@cLottable02,''), ISNULL(@cLottable03,''), ISNULL(@dLottable04,''), @cConditionCode )
       
   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 80505
      SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'InsReceiptDetFail'
      GOTO RollBackTran
   END                 

   IF EXISTS ( SELECT 1 
               FROM dbo.ReceiptDetail WITH (NOLOCK) 
               WHERE StorerKey  = @cStorerKey
               AND ReceiptKey   = @cReceiptKey
               AND SKU          = @cSKU
               AND UserDefine01 = @cCartonID
               AND ReceiptLineNumber = @cNewReceiptLineNumber
               AND [Status] = '0'
               HAVING ISNULL( SUM( QtyExpected), 0) = ISNULL( SUM( BeforeReceivedQty), 0))
   BEGIN
      UPDATE dbo.ReceiptDetail WITH (ROWLOCK) SET 
         [Status] = '1'
      WHERE StorerKey  = @cStorerKey
      AND ReceiptKey   = @cReceiptKey
      AND SKU          = @cSKU
      AND UserDefine01 = @cCartonID
      AND ReceiptLineNumber = @cNewReceiptLineNumber
      AND [Status] = '0'
      
      IF @@ERROR <> 0 
      BEGIN
         SET @nErrNo = 80507
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdReceiptDetFail'
         GOTO RollBackTran
      END
   END
         
   GOTO Quit
           
   RollBackTran:
   ROLLBACK TRAN TM_ShipmentID_Confirm
    
   Quit:  
   WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started
      COMMIT TRAN TM_ShipmentID_Confirm
END        

GO