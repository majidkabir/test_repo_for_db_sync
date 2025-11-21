SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_608RcvCfm06                                           */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose        : UA                                                        */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2019-06-21 1.0  YeeKung    WMS-9091 Created                                */
/* 2019-10-16 1.1  Chermaine  WMS-10897 Remove updating                       */
/*                 receiptdetail.lottable08 (cc01)                            */
/* 2020-03-24 1.2  YeeKung    Performance tune(yeekung01)                     */
/* 2022-08-15 1.3  Ung        WMS-20251 Fix DuplicateFrom                     */
/*                            Merge RTN feature in productoin (ad-hoc, no FBR)*/
/******************************************************************************/
CREATE   PROC [RDT].[rdt_608RcvCfm06](
    @nFunc          INT,
    @nMobile        INT,
    @cLangCode      NVARCHAR( 3),
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
    @nNOPOFlag      INT,
    @cConditionCode NVARCHAR( 10),
    @cSubreasonCode NVARCHAR( 10),
    @cRDLineNo      NVARCHAR( 5)  OUTPUT,
    @nErrNo         INT           OUTPUT,
    @cErrMsg        NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount           INT
   DECLARE @n_Err                INT
   DECLARE @cSQL                 NVARCHAR( MAX)
   DECLARE @cSQLParam            NVARCHAR( MAX)
   DECLARE @cDataType            NVARCHAR(128)
   DECLARE @cRDField             NVARCHAR(30)
   DECLARE @cDefaultValue        NVARCHAR(250)
   DECLARE @cEvaluateField       NVARCHAR(60)
   DECLARE @cEvaluateValue       NVARCHAR(30)
   DECLARE @cLottable            NVARCHAR( 30)
   DECLARE @cAssignDefaultValue  NVARCHAR(1)
          ,@cCountryOfOrigin     NVARCHAR(30)
          ,@cDefaultLottable08   NVARCHAR(30)
          ,@cLineSKU             NVARCHAR(20)

   DECLARE  @cExternReceiptKey            NVARCHAR( 20),
            @cVesselKey                   NVARCHAR( 18),
            @cVoyageKey                   NVARCHAR( 18),
            @cXdockKey                    NVARCHAR( 18),
            @cContainerKey                NVARCHAR( 18),
            @cExportStatus                NVARCHAR(  1),
            @cLoadKey                     NVARCHAR( 10),
            @cExternPoKey                 NVARCHAR( 20),
            @cUserDefine01                NVARCHAR( 30),
            @cUserDefine02                NVARCHAR( 30),
            @cUserDefine03                NVARCHAR( 30),
            @cUserDefine04                NVARCHAR( 30),
            @cUserDefine05                NVARCHAR( 30),
            @dtUserDefine06               DATETIME,
            @dtUserDefine07               DATETIME,
            @cUserDefine08                NVARCHAR( 30),
            @cUserDefine09                NVARCHAR( 30),
            @cUserDefine10                NVARCHAR( 30),
            @cChannel                     NVARCHAR( 20),  
   @cDocType                     NVARCHAR( 1),             
   @cRecType                     NVARCHAR( 10),  
   @nRTNFlag                     INT = 0  

   DECLARE @curDef CURSOR

   IF (@cLottable10 NOT IN ('107ZZZZZ','207ZZZZZ','307ZZZZZ'))  
   BEGIN  
      SET @nErrNo = 141007    
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOT10        
      GOTO Quit    
   END  
     
   SET @cLottable10 = UPPER(@cLottable10)  
        
   SET @nTranCount = @@TRANCOUNT

   -- Get default for lottable field
   IF EXISTS( SELECT 1 FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RTNDETDEF' AND StorerKey = @cStorerKey AND Code LIKE 'Lottable%')
   BEGIN
      SET @curDef = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT Code, Long, UDF01, Code2
      FROM CodeLKUP WITH (NOLOCK)
      WHERE ListName = 'RTNDETDEF'
         AND StorerKey = @cStorerKey
         AND Code LIKE 'Lottable%'
      ORDER BY Code
      OPEN @curDef
      FETCH NEXT FROM @curDef INTO @cRDField, @cDefaultValue, @cEvaluateField, @cEvaluateValue
      WHILE @@FETCH_STATUS = 0
      BEGIN
         SET @cAssignDefaultValue = 'N'

         -- Evaluation
         IF @cEvaluateField <> ''
         BEGIN
            SELECT @cLottable =
               CASE @cEvaluateField
                  WHEN 'LOTTABLE01' THEN @cLottable01
                  WHEN 'LOTTABLE02' THEN @cLottable02
                  WHEN 'LOTTABLE03' THEN @cLottable03
                  WHEN 'LOTTABLE04' THEN rdt.rdtFormatDate( @dLottable04)
                  WHEN 'LOTTABLE05' THEN rdt.rdtFormatDate( @dLottable05)
                  WHEN 'LOTTABLE06' THEN @cLottable06
                  WHEN 'LOTTABLE07' THEN @cLottable07
                  WHEN 'LOTTABLE08' THEN @cLottable08
                  WHEN 'LOTTABLE09' THEN @cLottable09
                  WHEN 'LOTTABLE10' THEN @cLottable10
                  WHEN 'LOTTABLE11' THEN @cLottable11
                  WHEN 'LOTTABLE12' THEN @cLottable12
                  WHEN 'LOTTABLE13' THEN rdt.rdtFormatDate( @dLottable13)
                  WHEN 'LOTTABLE14' THEN rdt.rdtFormatDate( @dLottable14)
                  WHEN 'LOTTABLE15' THEN rdt.rdtFormatDate( @dLottable15)
               END
            IF @cLottable = @cEvaluateValue
               SET @cAssignDefaultValue = 'Y'
         END
         ELSE
            SET @cAssignDefaultValue = 'Y'

         -- Check date
         IF (@cRDField = 'LOTTABLE04' OR
             @cRDField = 'LOTTABLE05' OR
             @cRDField = 'LOTTABLE13' OR
             @cRDField = 'LOTTABLE14' OR
             @cRDField = 'LOTTABLE15') AND
             @cDefaultValue <> ''
         BEGIN
            IF rdt.rdtIsValidDate( @cDefaultValue) = 0
            BEGIN
               SET @nErrNo = 141001
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid date
               GOTO Quit
            END
         END

         IF @cAssignDefaultValue = 'Y'
         BEGIN
            IF @cRDField = 'LOTTABLE01' SET @cLottable01 = LEFT( @cDefaultValue, 18)             ELSE
            IF @cRDField = 'LOTTABLE02' SET @cLottable02 = LEFT( @cDefaultValue, 18)             ELSE
            IF @cRDField = 'LOTTABLE03' SET @cLottable03 = LEFT( @cDefaultValue, 18)             ELSE
            IF @cRDField = 'LOTTABLE04' SET @dLottable04 = rdt.rdtConvertToDate( @cDefaultValue) ELSE
            IF @cRDField = 'LOTTABLE05' SET @dLottable05 = rdt.rdtConvertToDate( @cDefaultValue) ELSE
            IF @cRDField = 'LOTTABLE06' SET @cLottable06 = @cDefaultValue                        ELSE
            IF @cRDField = 'LOTTABLE07' SET @cLottable07 = @cDefaultValue                        ELSE
            IF @cRDField = 'LOTTABLE08' SET @cLottable08 = @cDefaultValue                        ELSE
            IF @cRDField = 'LOTTABLE09' SET @cLottable09 = @cDefaultValue                        ELSE
            IF @cRDField = 'LOTTABLE10' SET @cLottable10 = @cDefaultValue                        ELSE
            IF @cRDField = 'LOTTABLE11' SET @cLottable11 = @cDefaultValue                        ELSE
            IF @cRDField = 'LOTTABLE12' SET @cLottable12 = @cDefaultValue                        ELSE
            IF @cRDField = 'LOTTABLE13' SET @dLottable13 = rdt.rdtConvertToDate( @cDefaultValue) ELSE
            IF @cRDField = 'LOTTABLE14' SET @dLottable14 = rdt.rdtConvertToDate( @cDefaultValue) ELSE
            IF @cRDField = 'LOTTABLE15' SET @dLottable15 = rdt.rdtConvertToDate( @cDefaultValue)
         END

         FETCH NEXT FROM @curDef INTO @cRDField, @cDefaultValue, @cEvaluateField, @cEvaluateValue
      END
   END

   SELECT
      @cDocType = DocType,
      @cRecType = RECType
   FROM Receipt WITH (NOLOCK)
   WHERE ReceiptKey = @cReceiptKey

   IF @cDocType = 'R' AND @cRecType IN ('RTN','GRN')
   BEGIN
      SET @nRTNFlag = 1
      SET @cLottable01 = @cLottable10
   END

   IF (@cDocType = 'R' AND @cRecType IN ('RTN','GRN')) OR
      (@cDocType = 'A' AND @cRecType IN ('STO'))
      SET @cLottable11 = 'ZZ'

   -- Handling transaction
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_608RcvCfm06 -- For rollback or commit only our own transaction
  
   -- Receive
   EXEC rdt.rdt_Receive_V7
      @nFunc         = @nFunc,
      @nMobile       = @nMobile,
      @cLangCode     = @cLangCode,
      @nErrNo        = @nErrNo OUTPUT,
      @cErrMsg       = @cErrMsg OUTPUT,
      @cStorerKey    = @cStorerKey,
      @cFacility     = @cFacility,
      @cReceiptKey   = @cReceiptKey,
      @cPOKey        = @cPOKey,
      @cToLOC        = @cToLOC,
      @cToID         = @cToID,
      @cSKUCode      = @cSKUCode,
      @cSKUUOM       = @cSKUUOM,
      @nSKUQTY       = @nSKUQTY,
      @cUCC          = '',
      @cUCCSKU       = '',
      @nUCCQTY       = '',
      @cCreateUCC    = '',
      @cLottable01   = @cLottable01,
      @cLottable02   = @cLottable02,
      @cLottable03   = @cLottable03,
      @dLottable04   = @dLottable04,
      @dLottable05   = NULL,
      @cLottable06   = @cLottable06,
      @cLottable07   = @cLottable07,
      @cLottable08   = @cLottable08,
      @cLottable09   = @cLottable09,
      @cLottable10   = @cLottable10,
      @cLottable11   = @cLottable11,
      @cLottable12   = @cLottable12,
      @dLottable13   = @dLottable13,
      @dLottable14   = @dLottable14,
      @dLottable15   = @dLottable15,
      @nNOPOFlag     = @nNOPOFlag,
      @cConditionCode = @cConditionCode,
      @cSubreasonCode = '',
      @cReceiptLineNumberOutput = @cRDLineNo OUTPUT
   IF @nErrNo <> 0
      GOTO RollBackTran

   IF EXISTS( SELECT 1 FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'RTNDETDEF' AND StorerKey = @cStorerKey AND Code NOT LIKE 'Lottable%')
   BEGIN
      SET @curDef = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT Code, Long, UDF01, Code2
         FROM CodeLKUP WITH (NOLOCK)
         WHERE ListName = 'RTNDETDEF'
            AND StorerKey = @cStorerKey
            AND Code NOT LIKE 'Lottable%'
         ORDER BY Code
      OPEN @curDef
      FETCH NEXT FROM @curDef INTO @cRDField, @cDefaultValue, @cEvaluateField, @cEvaluateValue
      WHILE @@FETCH_STATUS = 0
      BEGIN
         SET @cAssignDefaultValue = 'N'

         -- Evaluate
         IF @cEvaluateField <> ''
         BEGIN
            -- Get RDField data type
            SET @cDataType = ''
            SELECT @cDataType = DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Receipt' AND COLUMN_NAME = @cEvaluateField

            IF @cDataType <> ''
            BEGIN
               IF @cDataType = 'nvarchar' SET @n_Err = 1                                        ELSE
               IF @cDataType = 'datetime' SET @n_Err = rdt.rdtIsValidDate( @cEvaluateValue)     ELSE
               IF @cDataType = 'int'      SET @n_Err = rdt.rdtIsInteger(   @cEvaluateValue)     ELSE
               IF @cDataType = 'float'    SET @n_Err = rdt.rdtIsValidQTY(  @cEvaluateValue, 20)

               -- Check data type
               IF @n_Err = 0
               BEGIN
                  SET @nErrNo = 141002
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Eval Value
                  GOTO RollbackTran
               END

               -- Get evaluate field value
               SET @cSQL =
                  ' SELECT @cAssignDefaultValue = ''Y'' ' +
                  ' FROM ReceiptDetail WITH (NOLOCK) ' +
                  ' WHERE ReceiptKey = @cReceiptKey ' +
                     ' AND ReceiptLineNumber = @cRDLineNo ' +
                     CASE WHEN @cDataType = 'datetime'
                        THEN ' AND ' + @cEvaluateField + ' = rdt.rdtConvertToDate( @cEvaluateValue) '
                        ELSE ' AND ' + @cEvaluateField + ' = @cEvaluateValue '
                     END
               SET @cSQLParam =
                  ' @cReceiptKey NVARCHAR( 10), ' +
                  ' @cRDLineNo   NVARCHAR( 5),  ' +
                  ' @cEvaluateValue NVARCHAR( MAX), ' +
                  ' @cAssignDefaultValue NVARCHAR( 1) OUTPUT '
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @cReceiptKey,
                  @cRDLineNo,
                  @cEvaluateValue,
                  @cAssignDefaultValue OUTPUT
            END
         END
         ELSE
            SET @cAssignDefaultValue = 'Y'

         IF @cAssignDefaultValue = 'Y'
         BEGIN
            -- Get RDField data type
            SET @cDataType = ''
            SELECT @cDataType = DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Receipt' AND COLUMN_NAME = @cRDField

            IF @cDataType <> ''
            BEGIN
               IF @cDataType = 'nvarchar' SET @n_Err = 1                                       ELSE
               IF @cDataType = 'datetime' SET @n_Err = rdt.rdtIsValidDate( @cDefaultValue)     ELSE
               IF @cDataType = 'int'      SET @n_Err = rdt.rdtIsInteger(   @cDefaultValue)     ELSE
               IF @cDataType = 'float'    SET @n_Err = rdt.rdtIsValidQTY(  @cDefaultValue, 20)

               -- Check data type
               IF @n_Err = 0
               BEGIN
                  SET @nErrNo = 141003
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Def Value
                  EXEC rdt.rdtSetFocusField @nMobile, 3 -- RefNo
                  GOTO RollbackTran
               END
            END

            SET @cSQL =
               ' UPDATE ReceiptDetail WITH (ROWLOCK) SET ' +
                     CASE WHEN @cDataType = 'datetime'
                        THEN @cRDField + ' = rdt.rdtConverToDate( @cDefaultValue) '
                        ELSE @cRDField + ' = @cDefaultValue '
                     END +
               ' WHERE ReceiptKey = @cReceiptKey ' +
                  ' AND ReceiptLineNumber = @cRDLineNo '
            SET @cSQLParam =
               ' @cReceiptKey NVARCHAR( 10), ' +
               ' @cRDLineNo   NVARCHAR( 5),  ' +
               ' @cDefaultValue NVARCHAR( MAX) '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @cReceiptKey,
               @cRDLineNo,
               @cDefaultValue

            IF @nErrNo <> 0
               GOTO RollbackTran
         END

         FETCH NEXT FROM @curDef INTO @cRDField, @cDefaultValue, @cEvaluateField, @cEvaluateValue
      END
   END

   IF EXISTS ( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND ReceiptKey = @cReceiptKey
                  AND ReceiptLineNumber = @cRDLineNo
                  AND (DuplicateFrom <> '' AND DuplicateFrom  IS NOT NULL))
   BEGIN
      SELECT
         @cLottable01          = Lottable01,      
         @cLottable03          = Lottable03         ,         
         @cLottable07          = Lottable07         ,
         @cLottable08          = Lottable08         ,      
         @cLottable12          = Lottable12         ,     
         @cExternReceiptKey    = ExternReceiptKey   ,
         @cVesselKey           = VesselKey          ,
         @cVoyageKey           = VoyageKey          ,
         @cXdockKey            = XdockKey           ,
         @cContainerKey        = ContainerKey       ,
         @cExportStatus        = ExportStatus       ,
         @cLoadKey             = LoadKey            ,
         @cExternPoKey         = ExternPoKey        ,
         @cPOKey               = POKey              ,
         @cUserDefine01        = UserDefine01       ,
         @cUserDefine02        = UserDefine02       ,
         @cUserDefine03        = UserDefine03       ,
         @cUserDefine04        = UserDefine04       ,
         @cUserDefine05        = UserDefine05       ,
         @dtUserDefine06       = UserDefine06       ,
         @dtUserDefine07       = UserDefine07       ,
         @cUserDefine08        = UserDefine08       ,
         @cUserDefine09        = UserDefine09       ,
         @cUserDefine10        = UserDefine10       ,
         @cSKUUOM              = UOM                ,
         @cChannel             = Channel
      FROM dbo.ReceiptDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND ReceiptKey = @cReceiptKey
      AND ReceiptLineNumber = (  SELECT Duplicatefrom FROM dbo.ReceiptDetail WITH (NOLOCK)
                                 WHERE StorerKey = @cStorerKey
                                    AND ReceiptKey = @cReceiptKey
                                    AND ReceiptLineNumber=@cRDLineNo)

      UPDATE dbo.ReceiptDetail WITH (ROWLOCK)
      SET
         Lottable01        = CASE WHEN @nRTNFlag <> 1 THEN ISNULL(@cLottable01,'') ELSE Lottable01 END,      
         Lottable03        = ISNULL(@cLottable03,''),      
         Lottable07        = ISNULL(@cLottable07,''),
         Lottable08        = ISNULL(@cLottable08,''),     
         Lottable12        = ISNULL(@cLottable12,''),      
         ExternReceiptKey  = ISNULL(@cExternReceiptKey,''),
         VesselKey         = ISNULL(@cVesselKey,''),
         VoyageKey         = ISNULL(@cVoyageKey,''),
         XdockKey          = ISNULL(@cXdockKey,''),
         ContainerKey      = ISNULL(@cContainerKey,''),
         ExportStatus      = ISNULL(@cExportStatus,''),
         LoadKey           = ISNULL(@cLoadKey,''),
         ExternPoKey       = ISNULL(@cExternPoKey,''),
         POKey             = ISNULL(@cPOKey,''),
         UserDefine01      = ISNULL(@cUserDefine01,''),
         UserDefine02      = ISNULL(@cUserDefine02,''),
         UserDefine03      = ISNULL(@cUserDefine03,''),
         UserDefine04      = ISNULL(@cUserDefine04,''),
         UserDefine05      = ISNULL(@cUserDefine05,''),
         UserDefine06      = ISNULL(@dtUserDefine06,''),
         UserDefine07      = ISNULL(@dtUserDefine07,''),
         UserDefine08      = ISNULL(@cUserDefine08,''),
         UserDefine09      = ISNULL(@cUserDefine09,''),
         UserDefine10      = ISNULL(@cUserDefine10,''),
         UOM               = ISNULL(@cSKUUOM,''),
         Channel           = ISNULL(@cChannel,'')
      WHERE StorerKey = @cStorerKey
      AND ReceiptKey = @cReceiptKey
      AND ReceiptLineNumber=@cRDLineNo

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 141005
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdRcptDetFail
         GOTO Quit
      END

   END

   SELECT @cLineSKU = SKU
   FROM dbo.ReceiptDetail WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
     AND ReceiptKey = @cReceiptKey
     AND ReceiptLineNumber = '00001'



  IF EXISTS ( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK)
                   WHERE StorerKey = @cStorerKey
                   AND ReceiptKey = @cReceiptKey
                   AND SKU = @cSKUCode
                   AND DuplicateFrom = '00001' )
   BEGIN
      IF @cSKUCode <> @cLineSKU
      BEGIN
         UPDATE dbo.ReceiptDetail WITH (ROWLOCK)
         SET ExternLineNo        = '' ,
             AltSku              = '' ,
             UnitPrice           = '' ,
             ExtendedPrice       = '' ,
             FreeGoodQtyExpected = '' ,
             FreeGoodQtyReceived = '' ,
             POLineNumber        = '' ,
             TrafficCop          = NULL
         WHERE StorerKey = @cStorerKey
         AND ReceiptKey = @cReceiptKey
         AND SKU = @cSKUCode
         AND DuplicateFrom = '00001'
         AND ISNULL(ExternLineNo,'')  <> ''

         IF @@ERROR <> 0
         BEGIN
             SET @nErrNo = 141006
             SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdRcptDetFail
             GOTO Quit
         END
      END
   END


   COMMIT TRAN rdt_608RcvCfm06
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_608RcvCfm06
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO