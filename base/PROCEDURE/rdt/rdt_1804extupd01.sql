SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_1804ExtUpd01                                    */  
/* Purpose: Update lottable10 = new ucc no using transfer               */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date         Author    Ver.  Purposes                                */  
/* 2017-Mar-10  James     1.0   WMS1318. Created                        */  
/* 2019-Sep-03  James     1.1   WMS-10372. Add channel (james01)        */  
/************************************************************************/  
CREATE PROCEDURE [RDT].[rdt_1804ExtUpd01]  
    @nMobile         INT   
   ,@nFunc           INT   
   ,@cLangCode       NVARCHAR( 3)   
   ,@nStep           INT   
   ,@cStorerKey      NVARCHAR( 15)  
   ,@cFacility       NVARCHAR(  5)  
   ,@cFromLOC        NVARCHAR( 10)  
   ,@cFromID         NVARCHAR( 18)  
   ,@cSKU            NVARCHAR( 20)  
   ,@nQTY            INT  
   ,@cUCC            NVARCHAR( 20)  
   ,@cToID           NVARCHAR( 18)  
   ,@cToLOC          NVARCHAR( 10)  
   ,@nErrNo          INT           OUTPUT   
   ,@cErrMsg         NVARCHAR( 20) OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @nTranCount           INT
   DECLARE @cToLottable01        NVARCHAR( 18), 
           @cToLottable02        NVARCHAR( 18), 
           @cToLottable03        NVARCHAR( 18), 
           @dToLottable04        DATETIME, 
           @dToLottable05        DATETIME, 
           @cToLottable06        NVARCHAR( 30), 
           @cToLottable07        NVARCHAR( 30), 
           @cToLottable08        NVARCHAR( 30), 
           @cToLottable09        NVARCHAR( 30), 
           @cToLottable10        NVARCHAR( 30), 
           @cToLottable11        NVARCHAR( 30), 
           @cToLottable12        NVARCHAR( 30), 
           @dToLottable13        DATETIME, 
           @dToLottable14        DATETIME, 
           @dToLottable15        DATETIME,
           @cLOT                 NVARCHAR( 10),
           @cNewLOT              NVARCHAR( 10),
           @cTransferLineNumber  NVARCHAR( 5),
           @cTransferKey         NVARCHAR( 10),
           @cPackkey             NVARCHAR( 10),
           @cUOM                 NVARCHAR( 10),
           @cLabelPrinter        NVARCHAR( 10),
           @cDataWindow          NVARCHAR( 50),
           @cTargetDB            NVARCHAR( 20),
           @bSuccess             INT,
           @nUCC_Qty             INT,
           @nTempUCC_Qty         INT,
           @nChvQty              INT,
           @nSUM_ChnQty          INT,
           @nTempChvQty          INT


   DECLARE @cFromChannel           NVARCHAR( 20) = '', 
           @cToChannel             NVARCHAR( 20) = '', 
           @cChannelInventoryMgmt  NVARCHAR(10) = '0',
           @nFromChannel_ID        BIGINT = 0,  
           @nToChannel_ID          BIGINT = 0


   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_1804ExtUpd01 -- For rollback or commit only our own transaction

   -- Move To UCC 
   IF @nFunc = 1804  
   BEGIN  
      IF @nStep = 7 -- UCC
      BEGIN  
         DECLARE CUR_TRANSFER CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
         SELECT LOT, ISNULL( SUM ( QTY), 0)
         FROM dbo.UCC WITH (NOLOCK) 
         WHERE STORERKEY = @cStorerKey
         AND   UCCNo = @cUCC
         AND   SKU = @cSKU
         AND   [Status] = '1'
         GROUP BY LOT
         OPEN CUR_TRANSFER
         FETCH NEXT FROM CUR_TRANSFER INTO @cLOT, @nUCC_Qty
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            IF @nUCC_Qty > @nQty
               SET @nQty = @nUCC_Qty

            -- UCC with multi sku do not have lottable10 stamped with ucc no
            -- then need do a transfer to update lottable10 = uccno
            IF NOT EXISTS ( SELECT 1 FROM dbo.LOTAttribute WITH (NOLOCK) 
                            WHERE LOT = @cLOT
                            AND   Lottable10 = @cUCC)
            BEGIN
               SELECT @cToLottable01 = Lottable01, 
                      @cToLottable02 = Lottable02, 
                      @cToLottable03 = Lottable03, 
                      @dToLottable04 = Lottable04, 
                      @dToLottable05 = Lottable05, 
                      @cToLottable06 = Lottable06, 
                      @cToLottable07 = Lottable07, 
                      @cToLottable08 = Lottable08, 
                      @cToLottable09 = Lottable09, 
                      @cToLottable10 = Lottable10, 
                      @cToLottable11 = Lottable11, 
                      @cToLottable12 = Lottable12, 
                      @dToLottable13 = Lottable13, 
                      @dToLottable14 = Lottable14, 
                      @dToLottable15 = Lottable15
               FROM dbo.LOTAttribute WITH (NOLOCK)
               WHERE LOT = @cLOT

               IF ISNULL( @cTransferKey, '') = ''
               BEGIN
                  SELECT @bSuccess = 0
                  EXECUTE nspg_getkey
                     @KeyName       = 'TRANSFER',
                     @fieldlength   = 10,
                     @keystring     = @cTransferKey   OUTPUT,
                     @b_success     = @bSuccess       OUTPUT,
                     @n_err         = @nErrNo         OUTPUT,
                     @c_errmsg      = @cErrMsg        OUTPUT
         
                  IF @bSuccess = 1
                  BEGIN
                     INSERT INTO dbo.TRANSFER 
                        (Transferkey, FromStorerkey, ToStorerkey, Type, ReasonCode, Remarks, Facility, ToFacility)
                     VALUES 
                        (@cTransferKey, @cStorerkey, @cStorerkey, 'MV2UCC', 'RDTMv2UCC', 'rdtfnc_MoveToUCC', @cFacility, @cFacility)
   	              
   	               IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 106851
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins XFER Fail
                        GOTO RollBackTran
                     END
     	            END
                  ELSE
                  BEGIN
                     SET @nErrNo = 106852
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Getkey Fail
                     GOTO RollBackTran
                  END
               END


               SELECT @cPackkey = PACK.Packkey,
                      @cUOM = PACK.PackUOM3
               FROM SKU SKU WITH (NOLOCK)
               join PACK PACK WITH (NOLOCK) ON SKU.Packkey = PACK.Packkey
               WHERE SKU.STORERKEY = @cStorerKey
               AND   SKU = @cSKU

               SET @cChannelInventoryMgmt = '0'
               SELECT @bSuccess = 0
               Execute nspGetRight     
                  @c_Facility    = @cFacility,
                  @c_StorerKey   = @cStorerKey, 
                  @c_sku         = '', 
                  @c_ConfigKey   = 'ChannelInventoryMgmt', 
                  @b_success     = @bSuccess       OUTPUT,
                  @c_authority   = @cChannelInventoryMgmt  OUTPUT,
                  @n_err         = @nErrNo         OUTPUT,
                  @c_errmsg      = @cErrMsg        OUTPUT

               If @bSuccess <> 1
               BEGIN
                  SET @nErrNo = 106860
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Get Right Fail
                  GOTO RollBackTran
               END

               IF @cChannelInventoryMgmt = '1'
               BEGIN
                  -- Check if any channel exists to move
                  IF EXISTS ( SELECT 1
                              FROM dbo.CHANNELINV WITH (NOLOCK)
                              WHERE SKU = @cSKU
                              AND   StorerKey = @cStorerKey
                              AND   C_Attribute01 = @cToLottable07)
                  BEGIN
                     -- Get 1 channel that can fullfill move qty, insrt transferdetail 1 time
                     SELECT TOP 1
                        @cFromChannel = Channel,
                        @cToChannel = Channel,
                        @nFromChannel_ID = Channel_ID,
                        @nToChannel_ID = Channel_ID
                     FROM dbo.CHANNELINV WITH (NOLOCK)
                     WHERE SKU = @cSKU
                     AND   StorerKey = @cStorerKey
                     AND   C_Attribute01 = @cToLottable07
                     AND   ((([Qty]-[QtyAllocated])-[QtyonHold]-@nUCC_Qty)>=0)
                     ORDER BY 1

                     IF @@ROWCOUNT = 1
                     BEGIN
                        IF ISNULL( @cFromChannel, '') = ''
                        BEGIN
                           SET @nErrNo = 106861
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Channel blank
                           GOTO RollBackTran
                        END

                        IF ISNULL( @nFromChannel_ID, 0) = 0
                        BEGIN
                           SET @nErrNo = 106862
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ChannelID blank
                           GOTO RollBackTran
                        END

                        -- Get next LineNumber
                        SELECT @cTransferLineNumber = 
                           RIGHT( '00000' + CAST( CAST( IsNULL( MAX( TransferLineNumber), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
                        FROM dbo.TransferDetail (NOLOCK)
                        WHERE TransferKey = @cTransferKey

                        INSERT INTO dbo.TRANSFERDETAIL
                        (TransferKey, TransferLineNumber, FromStorerKey, FromSku, FromLoc, FromLot, FromId, 
                        FromQty, FromPackKey, FromUOM, 
                        Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, 
                        Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, 
                        Lottable11, Lottable12, Lottable13, Lottable14, Lottable15,
                        ToStorerKey, ToSku, ToLoc, ToLot, ToId, ToQty, ToPackKey, ToUOM, Status, EffectiveDate, 
                        ToLottable01, ToLottable02, ToLottable03, ToLottable04, ToLottable05, 
                        ToLottable06, ToLottable07, ToLottable08, ToLottable09, ToLottable10, 
                        ToLottable11, ToLottable12, ToLottable13, ToLottable14, ToLottable15,
                        UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05, 
                        UserDefine06, UserDefine07, UserDefine08, UserDefine09, UserDefine10,
                        FromChannel, ToChannel, FromChannel_ID, ToChannel_ID)
                        VALUES
                        (@cTransferKey, @cTransferLineNumber, @cStorerKey, @cSKU, @cToLOC, @cLot, @cTOID, 
                        @nUCC_Qty, @cPackkey, @cUOM, 
                        @cToLottable01, @cToLottable02, @cToLottable03, @dToLottable04, @dToLottable05,
                        @cToLottable06, @cToLottable07, @cToLottable08, @cToLottable09, @cToLottable10, 
                        @cToLottable11, @cToLottable12, @dToLottable13, @dToLottable14, @dToLottable15,
                        @cStorerKey, @cSKU, @cToLOC, '', @cToID, @nUCC_Qty, @cPackkey, @cUOM, '0', GETDATE(), 
                        @cToLottable01, @cToLottable02, @cToLottable03, @dToLottable04, @dToLottable05, 
                        @cToLottable06, @cToLottable07, @cToLottable08, @cToLottable09, @cUCC, -- lottable10
                        @cToLottable11, @cToLottable12, @dToLottable13, @dToLottable14, @dToLottable15,
                        '', '', '', '', '', '', '', '', '', '',
                        @cFromChannel, @cToChannel, @nFromChannel_ID, @nToChannel_ID)

                        IF @@ERROR <> 0
                        BEGIN
                           SET @nErrNo = 106863
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins XFERD Fail
                           GOTO RollBackTran
                        END
                     END
                     ELSE
                     BEGIN
                        -- No single record in channel that can fullfill move qty then look for 
                        -- multi single line and insert multi transferdetail
                        SELECT @nSUM_ChnQty = ISNULL( SUM( (([Qty]-[QtyAllocated]))), 0)
                        FROM dbo.CHANNELINV WITH (NOLOCK)
                        WHERE SKU = @cSKU
                        AND   StorerKey = @cStorerKey
                        AND   C_Attribute01 = @cToLottable07
                        AND   ((([Qty]-[QtyAllocated])) >= 0)  -->0 here meaning the line must X hit constraint

                        IF @nSUM_ChnQty >= @nUCC_Qty
                        BEGIN
                           SET @nTempUCC_Qty = @nUCC_Qty

                           DECLARE @curChannel CURSOR
                           SET @curChannel = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                           SELECT Channel_ID, Channel, (([Qty]-[QtyAllocated]))
                           FROM dbo.CHANNELINV WITH (NOLOCK)
                           WHERE SKU = @cSKU
                           AND   StorerKey = @cStorerKey
                           AND   C_Attribute01 = @cToLottable07
                           AND   ((([Qty]-[QtyAllocated]))>=1) -->1 here meaning record with available qty only
                           ORDER BY Channel_ID
                           OPEN @curChannel
                           FETCH NEXT FROM @curChannel INTO @nFromChannel_ID, @cFromChannel, @nChvQty
                           WHILE @@FETCH_STATUS = 0
                           BEGIN
                              SET @nToChannel_ID = @nFromChannel_ID
                              SET @cToChannel = @cFromChannel

                              -- If balance > channel available, take balance only
                              IF @nTempUCC_Qty < @nChvQty
                                 SET @nChvQty = @nTempUCC_Qty

                              SET @nTempChvQty = @nChvQty
                              WHILE @nTempChvQty > 0
                              BEGIN
                                 -- Get next LineNumber
                                 SELECT @cTransferLineNumber = 
                                    RIGHT( '00000' + CAST( CAST( IsNULL( MAX( TransferLineNumber), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
                                 FROM dbo.TransferDetail (NOLOCK)
                                 WHERE TransferKey = @cTransferKey

                                 INSERT INTO dbo.TRANSFERDETAIL
                                 (TransferKey, TransferLineNumber, FromStorerKey, FromSku, FromLoc, FromLot, FromId, 
                                 FromQty, FromPackKey, FromUOM, 
                                 Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, 
                                 Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, 
                                 Lottable11, Lottable12, Lottable13, Lottable14, Lottable15,
                                 ToStorerKey, ToSku, ToLoc, ToLot, ToId, ToQty, ToPackKey, ToUOM, Status, EffectiveDate, 
                                 ToLottable01, ToLottable02, ToLottable03, ToLottable04, ToLottable05, 
                                 ToLottable06, ToLottable07, ToLottable08, ToLottable09, ToLottable10, 
                                 ToLottable11, ToLottable12, ToLottable13, ToLottable14, ToLottable15,
                                 UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05, 
                                 UserDefine06, UserDefine07, UserDefine08, UserDefine09, UserDefine10,
                                 FromChannel, ToChannel, FromChannel_ID, ToChannel_ID)
                                 VALUES
                                 (@cTransferKey, @cTransferLineNumber, @cStorerKey, @cSKU, @cToLOC, @cLot, @cTOID, 
                                 1, @cPackkey, @cUOM, 
                                 @cToLottable01, @cToLottable02, @cToLottable03, @dToLottable04, @dToLottable05,
                                 @cToLottable06, @cToLottable07, @cToLottable08, @cToLottable09, @cToLottable10, 
                                 @cToLottable11, @cToLottable12, @dToLottable13, @dToLottable14, @dToLottable15,
                                 @cStorerKey, @cSKU, @cToLOC, '', @cToID, 1, @cPackkey, @cUOM, '0', GETDATE(), 
                                 @cToLottable01, @cToLottable02, @cToLottable03, @dToLottable04, @dToLottable05, 
                                 @cToLottable06, @cToLottable07, @cToLottable08, @cToLottable09, @cUCC, -- lottable10
                                 @cToLottable11, @cToLottable12, @dToLottable13, @dToLottable14, @dToLottable15,
                                 '', '', '', '', '', '', '', '', '', '',
                                 @cFromChannel, @cToChannel, @nFromChannel_ID, @nToChannel_ID)

                                 IF @@ERROR <> 0
                                 BEGIN
                                    SET @nErrNo = 106863
                                    SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins XFERD Fail
                                    GOTO RollBackTran
                                 END

                                 SET @nTempChvQty = @nTempChvQty  - 1
                              END

                              -- Deduct channel qty
                              SET @nTempUCC_Qty = @nTempUCC_Qty - @nChvQty

                              IF @nTempUCC_Qty = 0
                                 BREAK

                              FETCH NEXT FROM @curChannel INTO @nFromChannel_ID, @cFromChannel, @nChvQty
                           END
                        END
                     END
                  END
               END
               ELSE
               BEGIN
                  -- Get next LineNumber
                  SELECT @cTransferLineNumber = 
                     RIGHT( '00000' + CAST( CAST( IsNULL( MAX( TransferLineNumber), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
                  FROM dbo.TransferDetail (NOLOCK)
                  WHERE TransferKey = @cTransferKey

                  INSERT INTO dbo.TRANSFERDETAIL
                  (TransferKey, TransferLineNumber, FromStorerKey, FromSku, FromLoc, FromLot, FromId, 
                  FromQty, FromPackKey, FromUOM, 
                  Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, 
                  Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, 
                  Lottable11, Lottable12, Lottable13, Lottable14, Lottable15,
                  ToStorerKey, ToSku, ToLoc, ToLot, ToId, ToQty, ToPackKey, ToUOM, Status, EffectiveDate, 
                  ToLottable01, ToLottable02, ToLottable03, ToLottable04, ToLottable05, 
                  ToLottable06, ToLottable07, ToLottable08, ToLottable09, ToLottable10, 
                  ToLottable11, ToLottable12, ToLottable13, ToLottable14, ToLottable15,
                  UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05, 
                  UserDefine06, UserDefine07, UserDefine08, UserDefine09, UserDefine10)
                  VALUES
                  (@cTransferKey, @cTransferLineNumber, @cStorerKey, @cSKU, @cToLOC, @cLot, @cTOID, 
                  @nUCC_Qty, @cPackkey, @cUOM, 
                  @cToLottable01, @cToLottable02, @cToLottable03, @dToLottable04, @dToLottable05,
                  @cToLottable06, @cToLottable07, @cToLottable08, @cToLottable09, @cToLottable10, 
                  @cToLottable11, @cToLottable12, @dToLottable13, @dToLottable14, @dToLottable15,
                  @cStorerKey, @cSKU, @cToLOC, '', @cToID, @nUCC_Qty, @cPackkey, @cUOM, '0', GETDATE(), 
                  @cToLottable01, @cToLottable02, @cToLottable03, @dToLottable04, @dToLottable05, 
                  @cToLottable06, @cToLottable07, @cToLottable08, @cToLottable09, @cUCC, -- lottable10
                  @cToLottable11, @cToLottable12, @dToLottable13, @dToLottable14, @dToLottable15,
                  '', '', '', '', '', '', '', '', '', '')

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 106853
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins XFERD Fail
                     GOTO RollBackTran
                  END
               END
            END
            
            DECLARE @curFinalize CURSOR
            SET @curFinalize = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT TransferLineNumber
            FROM dbo.TRANSFERDETAIL WITH (NOLOCK)
            WHERE TransferKey = @cTransferKey
            AND   [Status] <> '9'
            OPEN @curFinalize
            FETCH NEXT FROM @curFinalize INTO @cTransferLineNumber
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- Finalize transfer
               UPDATE dbo.TRANSFERDETAIL WITH (ROWLOCK) SET
                  [Status] = '9'
               WHERE TransferKey = @cTransferKey
               AND   TransferLineNumber = @cTransferLineNumber
         
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 106854
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins XFERD Fail
                  GOTO RollBackTran
               END

               FETCH NEXT FROM @curFinalize INTO @cTransferLineNumber
            END
                     
            -- Get the new lot # after transfer
            SELECT @cNewLOT = Lot
            FROM dbo.Itrn WITH (NOLOCK)
            WHERE SourceKey = @cTransferKey + @cTransferLineNumber
            AND   SourceType = 'ntrTransferDetailUpdate'
            AND   TranType = 'DP'
            AND   StorerKey = @cStorerKey
            AND   SKU = @cSKU
            AND   Lottable10 = @cUCC

            IF ISNULL( @cNewLOT, '') = '' OR @cNewLOT = @cLOT
            BEGIN
               SET @nErrNo = 106858
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC Relot Fail
               GOTO RollBackTran
            END

            -- Update the ucc with new lot
            UPDATE dbo.UCC WITH (ROWLOCK) SET 
               LOT = @cNewLOT
            WHERE StorerKey = @cStorerKey
            AND   UCCNo = @cUCC
            AND   Lot = @cLOT

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 106859
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC Relot Fail
               GOTO RollBackTran
            END
            
            -- Reduce qty
            SET @nQty = @nQty - @nUCC_Qty

            IF @nQty = 0
               BREAK

            FETCH NEXT FROM CUR_TRANSFER INTO @cLOT, @nUCC_Qty
         END
         CLOSE CUR_TRANSFER
         DEALLOCATE CUR_TRANSFER

         -- if report type not setup then no need print
         IF NOT EXISTS ( SELECT 1 FROM RDT.RDTReport WITH (NOLOCK) 
                         WHERE StorerKey = @cStorerKey
                         AND   ReportType = 'UCCLABEL'
                         AND   (Function_ID = 0) OR (Function_ID = @nFunc))
            GOTO Quit

         -- Get packing list report info
         SET @cDataWindow = ''
         SET @cTargetDB = ''
         SELECT 
            @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
            @cTargetDB = ISNULL(RTRIM(TargetDB), '') 
         FROM RDT.RDTReport WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND   ReportType = 'UCCLABEL'
            
         -- Check data window
         IF ISNULL( @cDataWindow, '') = ''
         BEGIN
            SET @nErrNo = 106855
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup
            GOTO RollBackTran
         END
   
         -- Check database
         IF ISNULL( @cTargetDB, '') = ''
         BEGIN
            SET @nErrNo = 106856
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set
            GOTO RollBackTran
         END

         SELECT @cLabelPrinter = Printer 
         FROM RDT.RDTMOBREC WITH (NOLOCK)
         WHERE MOBILE = @nMobile

         -- Check label printer blank
         IF @cLabelPrinter = ''
         BEGIN
            SET @nErrNo = 106857
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq
            GOTO RollBackTran
         END

         EXEC RDT.rdt_BuiltPrintJob
            @nMobile,
            @cStorerKey,
            'UCCLABEL',       -- ReportType
            'PRINT_UCCLABEL', -- PrintJobName
            @cDataWindow,
            @cLabelPrinter,
            @cTargetDB,
            @cLangCode,
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT, 
            @cUCC,
            @cStorerKey

         IF @nErrNo <> 0
            GOTO RollBackTran

      END -- IF @nStep = 7
    
   END  -- IF @nFunc = 1804

   GOTO Quit
        
   RollBackTran:
      ROLLBACK TRAN rdt_1804ExtUpd01 -- Only rollback change made here
   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN
END

GO