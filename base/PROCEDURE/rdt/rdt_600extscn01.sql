SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_600ExtScn01                                     */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose:       For Unilever                                          */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2024-02-26 1.0  Dennis   Draft                                       */
/* 2024-03-01 1.1  Dennis   UWP-14799                                   */
/* 2024-08-26 1.2  VPA235                                               */
/*                                                                      */
/************************************************************************/

CREATE    PROC [RDT].[rdt_600ExtScn01] (
	@nMobile      INT,           
	@nFunc        INT,           
	@cLangCode    NVARCHAR( 3),  
	@nStep INT,           
	@nScn  INT,           
	@nInputKey    INT,           
	@cFacility    NVARCHAR( 5),  
	@cStorerKey   NVARCHAR( 15), 

	@cSuggLOC     NVARCHAR( 10) OUTPUT, 
	@cLOC         NVARCHAR( 20) OUTPUT, 
	@cID          NVARCHAR( 20) OUTPUT, 
	@cSKU         NVARCHAR( 20) OUTPUT, 
   @cReceiptKey  NVARCHAR( 10), 
   @cPOKey       NVARCHAR( 10),
   @cReasonCode  NVARCHAR( 10),
   @cReceiptLineNumber  NVARCHAR( 5),
   @cPalletType  NVARCHAR( 10),  

   @cInField01       NVARCHAR( 60) OUTPUT,  @cOutField01 NVARCHAR( 60) OUTPUT,  @cFieldAttr01 NVARCHAR( 1) OUTPUT,  @cLottable01 NVARCHAR( 18) OUTPUT,  
   @cInField02       NVARCHAR( 60) OUTPUT,  @cOutField02 NVARCHAR( 60) OUTPUT,  @cFieldAttr02 NVARCHAR( 1) OUTPUT,  @cLottable02 NVARCHAR( 18) OUTPUT,  
   @cInField03       NVARCHAR( 60) OUTPUT,  @cOutField03 NVARCHAR( 60) OUTPUT,  @cFieldAttr03 NVARCHAR( 1) OUTPUT,  @cLottable03 NVARCHAR( 18) OUTPUT,  
   @cInField04       NVARCHAR( 60) OUTPUT,  @cOutField04 NVARCHAR( 60) OUTPUT,  @cFieldAttr04 NVARCHAR( 1) OUTPUT,  @dLottable04 DATETIME      OUTPUT,  
   @cInField05       NVARCHAR( 60) OUTPUT,  @cOutField05 NVARCHAR( 60) OUTPUT,  @cFieldAttr05 NVARCHAR( 1) OUTPUT,  @dLottable05 DATETIME      OUTPUT,  
   @cInField06       NVARCHAR( 60) OUTPUT,  @cOutField06 NVARCHAR( 60) OUTPUT,  @cFieldAttr06 NVARCHAR( 1) OUTPUT,  @cLottable06 NVARCHAR( 30) OUTPUT, 
   @cInField07       NVARCHAR( 60) OUTPUT,  @cOutField07 NVARCHAR( 60) OUTPUT,  @cFieldAttr07 NVARCHAR( 1) OUTPUT,  @cLottable07 NVARCHAR( 30) OUTPUT, 
   @cInField08       NVARCHAR( 60) OUTPUT,  @cOutField08 NVARCHAR( 60) OUTPUT,  @cFieldAttr08 NVARCHAR( 1) OUTPUT,  @cLottable08 NVARCHAR( 30) OUTPUT, 
   @cInField09       NVARCHAR( 60) OUTPUT,  @cOutField09 NVARCHAR( 60) OUTPUT,  @cFieldAttr09 NVARCHAR( 1) OUTPUT,  @cLottable09 NVARCHAR( 30) OUTPUT, 
   @cInField10       NVARCHAR( 60) OUTPUT,  @cOutField10 NVARCHAR( 60) OUTPUT,  @cFieldAttr10 NVARCHAR( 1) OUTPUT,  @cLottable10 NVARCHAR( 30) OUTPUT, 
   @cInField11       NVARCHAR( 60) OUTPUT,  @cOutField11 NVARCHAR( 60) OUTPUT,  @cFieldAttr11 NVARCHAR( 1) OUTPUT,  @cLottable11 NVARCHAR( 30) OUTPUT,
   @cInField12       NVARCHAR( 60) OUTPUT,  @cOutField12 NVARCHAR( 60) OUTPUT,  @cFieldAttr12 NVARCHAR( 1) OUTPUT,  @cLottable12 NVARCHAR( 30) OUTPUT,
   @cInField13       NVARCHAR( 60) OUTPUT,  @cOutField13 NVARCHAR( 60) OUTPUT,  @cFieldAttr13 NVARCHAR( 1) OUTPUT,  @dLottable13 DATETIME      OUTPUT,
   @cInField14       NVARCHAR( 60) OUTPUT,  @cOutField14 NVARCHAR( 60) OUTPUT,  @cFieldAttr14 NVARCHAR( 1) OUTPUT,  @dLottable14 DATETIME      OUTPUT,
   @cInField15       NVARCHAR( 60) OUTPUT,  @cOutField15 NVARCHAR( 60) OUTPUT,  @cFieldAttr15 NVARCHAR( 1) OUTPUT,  @dLottable15 DATETIME      OUTPUT,
	@nAction      INT, --0 Jump Screen, 1 Validation(pass through all input fields), 2 Update, 3 Prepare output fields .....
	@nAfterScn    INT OUTPUT, @nAfterStep    INT OUTPUT, 
   @nErrNo             INT            OUTPUT, 
   @cErrMsg            NVARCHAR( 20)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE @nShelfLife FLOAT
   DECLARE @cResultCode NVARCHAR( 60)
   DECLARE
   @nRowCount            INT,
   @cexternReceiptKey    NVARCHAR( 30), 
   @cexternLineNo        NVARCHAR( 30),    
   @nLotNum              INT,
   @cListName            NVARCHAR( 30),
   @cLotValue            NVARCHAR( 30),     
   @cStorerConfig        NVARCHAR( 50),  
   @SQL                  NVARCHAR( MAX),
   @cUserDefine08        NVARCHAR( 30),  
   @nSQLResult           INT,
   @nCheckDigit          INT,
   @cActLoc              NVARCHAR( 20),
   @cPalletTypeInUse     NVARCHAR( 5),
   @cPalletTypeSave      NVARCHAR( 10),
   @cLott10              NVARCHAR( 30),
   @cSKUReceived         NVARCHAR( 20),
   @cDamagedCode         NVARCHAR(30),
   @cExpiredCode         NVARCHAR(30)

   SELECT
   @cLott10 = C_String1,
   @cPalletTypeSave = C_String2,
   @cSKUReceived = C_String3
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   IF @nAction = 3 --Prepare output fields
   BEGIN
	   IF @nFunc = 600 
	   BEGIN
         IF @nInputKey = 1
         BEGIN
            IF( @nStep IN (4,5,8) )
            BEGIN
               IF rdt.RDTGetConfig( @nFunc, 'DEFCONDASN', @cStorerKey) = '1'
               BEGIN
                  SELECT TOP 1 @cOutField10 = ISNULL(RD.Lottable12,'')
                  FROM dbo.Receipt R WITH (NOLOCK)
                     INNER JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON R.ReceiptKey  = RD.ReceiptKey
                  WHERE R.Facility = @cFacility AND R.StorerKey = @cStorerKey
                     AND R.ReceiptKey = @cReceiptKey AND (@cPOKey='NOPO' or RD.POKey = @cPOKey)
                     AND RD.Sku = @cSKU
                  ORDER BY RD.ReceiptLineNumber
               END
            END
         END
         IF @nInputKey = 0
         BEGIN
            IF( @nStep = 14 )
            BEGIN
               IF rdt.RDTGetConfig( @nFunc, 'DEFCONDASN', @cStorerKey) = '1'
               BEGIN
                  SELECT TOP 1 @cOutField10 = ISNULL(RD.Lottable12,'')
                  FROM dbo.Receipt R WITH (NOLOCK)
                     INNER JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON R.ReceiptKey  = RD.ReceiptKey
                  WHERE R.Facility = @cFacility AND R.StorerKey = @cStorerKey
                     AND R.ReceiptKey = @cReceiptKey AND (@cPOKey='NOPO' or RD.POKey = @cPOKey)
                     AND RD.Sku = @cSKU
                  ORDER BY RD.ReceiptLineNumber
               END
            END
         END
		END
      GOTO Quit
	END

   IF @nAction = 2 --Update fields
   BEGIN
	   IF @nFunc = 600 
	   BEGIN
         IF @nInputKey = 1
         BEGIN
            IF( @nStep = 6 )
            BEGIN
               IF (ISNULL( rdt.RDTGetConfig( @nFunc, 'RCTSHLFVLD', @cStorerKey),'') != '')
               BEGIN
                  SET @cLottable11 = ''

                  SELECT TOP 1 @cUserDefine08 = ISNULL(RD.UserDefine08,'')
                  FROM dbo.Receipt R WITH (NOLOCK)
                     INNER JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON R.ReceiptKey  = RD.ReceiptKey
                  WHERE R.Facility = @cFacility AND R.StorerKey = @cStorerKey
                     AND R.ReceiptKey = @cReceiptKey AND (@cPOKey='NOPO' or RD.POKey = @cPOKey)
                     AND RD.Sku = @cSKU
                  ORDER BY RD.ReceiptLineNumber

                  SELECT TOP 1 @nShelfLife = ISNULL(UDF02,0),@cResultCode = UDF03
                  FROM dbo.CodeLKUP WITH (NOLOCK)
                     WHERE ListName = 'CCODEVALID'
                     AND UDF01 = 'IBD'
                     AND Code = @cFacility
                     AND code2 = @cUserDefine08
                     AND Storerkey = @cStorerKey

                  IF (DATEDIFF(day,GETDATE(),@dLottable04) < (DATEDIFF(day,@dLottable13,@dLottable04) * @nShelfLife/100 )) AND GETDATE() < @dLottable04
                  BEGIN
                     SET @cLottable11 = @cResultCode
                  END
               END
               IF (ISNULL( rdt.RDTGetConfig( @nFunc, 'ULLottable06', @cStorerKey),'0') != '0')
               BEGIN
                  SET @cLottable06 = ''
                  SELECT TOP 1 @cUserDefine08 = ISNULL(RD.UserDefine08,'')
                  FROM dbo.Receipt R WITH (NOLOCK)
                     INNER JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON R.ReceiptKey  = RD.ReceiptKey
                  WHERE R.Facility = @cFacility AND R.StorerKey = @cStorerKey
                     AND R.ReceiptKey = @cReceiptKey AND (@cPOKey='NOPO' or RD.POKey = @cPOKey)
                     AND RD.Sku = @cSKU
                  ORDER BY RD.ReceiptLineNumber
                  IF (@cUserDefine08 != '' AND ISNULL(@cUserDefine08,N'OK') != N'OK') OR ISNULL(@cLottable11,'')!='' OR ISNULL(@cLottable12,'')!=''
                  BEGIN    
                     SET @cLottable06 = '1'
                  END
                  IF ISNULL(@cLottable12,'') <> '' AND 
                  EXISTS (SELECT 1 FROM CODELKUP WITH (NOLOCK) 
                              WHERE LISTNAME = 'ASNREASON'
                              AND Code = @cLottable12
                              AND StorerKey = @cStorerkey)
                  BEGIN
                     SET @cDamagedCode = ''
                     SELECT @cDamagedCode = ISNULL(Code,'')
                     FROM CODELKUP WITH (NOLOCK)
                     WHERE storerkey = @cStorerkey
                     AND UDF01 = 'RMPM_Damaged'
                     AND LISTNAME = 'SLCode'

                     IF ISNULL(@cDamagedCode,'') <> ''
                     BEGIN
                           SET @cLottable06 = '1'
                           SET @cLottable07 = @cDamagedCode
                     END
                     ELSE 
                     BEGIN
                        SET @nErrNo = 63533;
                        SET @cErrMsg = 'Damaged Code is not configured for this Storer key' +@cStorerkey;
                        GOTO QUIT
                     END 
                  END
                  IF ISNULL(@dLottable04,'') <> '' AND DATEDIFF(DAY, GETDATE(), @dLottable04) <= 0
                  BEGIN
                     SET @cExpiredCode = ''

                     SELECT @cExpiredCode = ISNULL(Code,'')
                     FROM CODELKUP WITH (NOLOCK)
                     WHERE storerkey = @cStorerkey
                        AND UDF01 = 'RMPM_Expired' 
                        AND LISTNAME = 'SLCode'         
                              
                     IF ISNULL(@cExpiredCode,'') = ''
                     BEGIN
                        SET @nErrNo = 63533;
                        SET @cErrMsg = 'Expired Code is not configured for this Storer key' +@cStorerkey;
                        GOTO Quit
                     END
                     ELSE
                     BEGIN
                        SET @cLottable07 = @cExpiredCode
                        SET @cLottable06 = '1'
                     END
                  END

                  --ADDED BY VPA235 FOR FG NEAR EXPIRY START
                  IF ISNULL(@dLottable04, '') <> '' AND
                     DATEDIFF(DAY, GETDATE(), @dLottable04) > 0 AND
                     DATEDIFF(DAY, GETDATE(), @dLottable04) <= 180 AND
                     (ISNULL([rdt].[RDTGetConfig](@nFunc, 'FGNEAREXPIRYVLD', @cStorerKey),
                              '0') != '0')
                  BEGIN
                     SET @cExpiredCode = ''
                     
                     SELECT @cExpiredCode = ISNULL([Code], '')
                     FROM [CODELKUP] WITH (NOLOCK)
                     WHERE [storerkey] = @cStorerkey
                        AND [UDF01] = 'FG_NearExpire'
                        AND [LISTNAME] = 'SLCode'
                     
                     IF ISNULL(@cExpiredCode, '') = ''
                     BEGIN
                        SET @nErrNo = 63533;
                        SET @cErrMsg = 'Near Expire Code is not configured for this Storer key' + @cStorerkey;
                        GOTO Quit
                     END
                     ELSE
                     BEGIN
                        SET @cLottable07 = @cExpiredCode
                     END
                  END
                  --ADDED BY VPA235 FOR FG NEAR EXPIRY END
               END
            END
         END

         IF( @nStep = 7)
         BEGIN
            IF (ISNULL( rdt.RDTGetConfig( @nFunc, 'ACTVASWO', @cStorerKey),'0') != '0')
            BEGIN
               SET @cLott10 = @cLottable10
               IF ISNULL(@cLottable09,'') != ''
               BEGIN
                  BEGIN TRANSACTION
                  BEGIN TRY

                     SELECT 
                        @cexternReceiptKey = ExternReceiptKey,
                        @cexternLineNo = ExternLineNo
                     FROM dbo.ReceiptDetail RD WITH (NOLOCK)
                     WHERE RD.ReceiptKey = @cReceiptKey
                     AND RD.ReceiptLineNumber = @cReceiptLineNumber

                     EXECUTE [RDT].[rdt_CreateVASWorkOrder] 
                        @nFunc
                        ,@nMobile
                        ,@cLangCode
                        ,@cStorerKey
                        ,@cFacility
                        ,@cexternReceiptKey
                        ,@cexternLineNo
                        ,''
                        ,''
                        ,@cLottable09 -- From ID
                        ,@cID
                        ,'YES'
                        ,'RPLT IB PL'
                        ,@cSKU
                        ,'VASWOCODE'
                        ,1
                        ,@nErrNo OUTPUT
                        ,@cErrMsg OUTPUT

                     IF @nErrNo = 211710
                     BEGIN
                        SET @nErrNo = 0
                        SET @cErrMsg = ''
                        COMMIT TRANSACTION 
                        GOTO Quit
                     END

                     IF @cLottable10 = 'N' --Auto Finalize
                     BEGIN
                        EXEC [RDT].[rdt_FinalizeVASWorkOrder]
                        @nFunc = @nFunc,
                        @nMobile = @nMobile,
                        @cLangCode = @cLangCode,
                        @cStorerKey = @cStorerKey,
                        @cFacility = @cFacility,
                        @cPalletID = @cID,
                        @nErrNo = @nErrNo OUTPUT,
                        @cErrMsg = @cErrMsg OUTPUT
                     END
                  END TRY
                  BEGIN CATCH
                     SET @nErrNo = 211714
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Generate WorkOrder Fail'
                     GOTO Exception
                  END CATCH

                  COMMIT TRANSACTION 
                  GOTO Quit
               END
            END
         END 

         IF( @nStep = 9)
         BEGIN
            IF (ISNULL( rdt.RDTGetConfig( @nFunc, 'ACTVASWO', @cStorerKey),'0') != '0')
            BEGIN
               BEGIN TRANSACTION
               BEGIN TRY

                  SELECT 
                     @cexternReceiptKey = ExternReceiptKey,
                     @cexternLineNo = ExternLineNo
                  FROM dbo.ReceiptDetail RD WITH (NOLOCK)
                  WHERE RD.ReceiptKey = @cReceiptKey
                  AND RD.ReceiptLineNumber = @cReceiptLineNumber

                  EXECUTE [RDT].[rdt_CreateVASWorkOrder] 
                     @nFunc
                     ,@nMobile
                     ,@cLangCode
                     ,@cStorerKey
                     ,@cFacility
                     ,@cexternReceiptKey
                     ,@cexternLineNo
                     ,''
                     ,''
                     ,'' -- From ID
                     ,@cID
                     ,'YES'
                     ,'LABEL PLT'
                     ,@cSKUReceived
                     ,'VASWOCODE'
                     ,1
                     ,@nErrNo OUTPUT
                     ,@cErrMsg OUTPUT

                  IF @nErrNo = 211710
                  BEGIN
                     SET @nErrNo = 0
                     SET @cErrMsg = ''
                     COMMIT TRANSACTION 
                     GOTO Quit
                  END

                  IF @cLott10 = 'N' --Auto Finalize
                  BEGIN
                     EXEC [RDT].[rdt_FinalizeVASWorkOrder]
                     @nFunc = @nFunc,
                     @nMobile = @nMobile,
                     @cLangCode = @cLangCode,
                     @cStorerKey = @cStorerKey,
                     @cFacility = @cFacility,
                     @cPalletID = @cID,
                     @nErrNo = @nErrNo OUTPUT,
                     @cErrMsg = @cErrMsg OUTPUT
                  END
               END TRY
               BEGIN CATCH
                  SET @nErrNo = 211714
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Generate WorkOrder Fail'
                  GOTO Exception
               END CATCH

               COMMIT TRANSACTION 
               GOTO Quit
            END
         END 
         
		END
      GOTO Quit
	END

   IF @nAction = 1 --Validation
   BEGIN
	   IF @nFunc = 600 
	   BEGIN
         IF @nInputKey = 1
         BEGIN
            IF( @nStep = 99 )
            BEGIN
               IF (ISNULL( rdt.RDTGetConfig( @nFunc, 'ValidatePalletType', @cStorerKey),'0') != '0')
               BEGIN
                  SELECT 
                  @cPalletTypeInUse = PalletTypeInUse
                  FROM dbo.PalletTypeMaster WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                     AND Facility = @cFacility
                     AND PalletType = @cPalletType

                  IF @@ROWCOUNT = 0
                  BEGIN
                     SET @nErrNo = 212601
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --212601Pallet Type Not Configured
                     GOTO Quit
                  END

                  IF @cPalletTypeInUse != 'Y'
                  BEGIN
                     SET @nErrNo = 212602
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --212602Pallet Type Not In Use
                     GOTO Quit
                  END

                  SET @cPalletTypeSave = @cPalletType
               END
            END
            IF( @nStep = 2 )
            BEGIN
               IF ISNULL(rdt.RDTGetConfig( @nFunc, 'ReceiveDefaultToLoc', @cStorerKey),'') = @cLOC
                  GOTO QUIT

               SELECT
                  @nCheckDigit = CheckDigitLengthForLocation
               FROM dbo.FACILITY WITH (NOLOCK)
               WHERE facility = @cFacility

               IF @nCheckDigit > 0
               BEGIN
                  SELECT @cActLoc = loc 
                  FROM dbo.LOC WITH (NOLOCK)
                  WHERE Facility = @cFacility AND CONCAT(LOC,LOCCHECKDIGIT) = @cLOC
                  SET @nRowCount = @@ROWCOUNT
                  IF @nRowCount > 1
                  BEGIN
                     SET @nErrNo = 212603
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --212603Unique location not identified
                     GOTO Quit
                  END
                  ELSE IF @nRowCount = 0
                  BEGIN
                     SET @nErrNo = 212604
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --212604Loc Not Found
                     GOTO Quit
                  END
                  SET @cLOC = @cActLoc
                  GOTO QUIT
               END
            END
            IF( @nStep = 5 )
            BEGIN
               SET @cStorerConfig = ISNULL(rdt.RDTGetConfig( @nFunc, 'ValidateLottable', @cStorerKey),'')
               IF @cStorerConfig != ''
               BEGIN
                  SELECT TOP 1 @nLotNum = TRY_CAST(value AS INT) FROM STRING_SPLIT(@cStorerConfig, ',')
                  SELECT @cListName = value FROM STRING_SPLIT(@cStorerConfig, ',')
                  SET @cLotValue = CASE
                                    WHEN @nLotNum = 1  THEN @cLottable01 WHEN @nLotNum = 2  THEN @cLottable02 
                                    WHEN @nLotNum = 3  THEN @cLottable03 WHEN @nLotNum = 6  THEN @cLottable06 
                                    WHEN @nLotNum = 7  THEN @cLottable07 WHEN @nLotNum = 8  THEN @cLottable08 
                                    WHEN @nLotNum = 9  THEN @cLottable09 WHEN @nLotNum = 10 THEN @cLottable10 
                                    WHEN @nLotNum = 11 THEN @cLottable11 WHEN @nLotNum = 12 THEN @cLottable12
                                    END 
                  IF ISNULL(@cLotValue,'') = ''
                  BEGIN
                     GOTO Quit
                  END
                  SET @SQL = 'SELECT  @Result = COUNT(1)
                     FROM dbo.CodeLKUP WITH (NOLOCK)
                     WHERE ListName = '+CONCAT('''',@cListName,'''')+
                     'AND Storerkey = '+CONCAT('''',@cStorerkey,'''')
                  EXEC sp_executesql @SQL,N'@Result INT OUTPUT', @nSQLResult OUTPUT
                  IF @nSQLResult = 0
                  BEGIN
                     SET @nErrNo = 212605
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'List not maintained'
                     GOTO Quit
                  END
                  SET @SQL = 'SELECT  @Result = COUNT(1)
                     FROM dbo.CodeLKUP WITH (NOLOCK)
                     WHERE ListName = '+CONCAT('''',@cListName,'''')+
                     'AND Storerkey = '+CONCAT('''',@cStorerkey,'''')+
                     'AND Code ='+ CONCAT('''',@cLotValue,'''')
                  EXEC sp_executesql @SQL,N'@Result INT OUTPUT', @nSQLResult OUTPUT
                  IF @nSQLResult = 0
                  BEGIN
                     SET @nErrNo = 212606
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Value'
                     GOTO Quit
                  END
               END
            END
            IF( @nStep = 6 )
            BEGIN
               IF(ISNULL(rdt.RDTGetConfig( @nFunc, 'ValidatePalletType', @cStorerKey),'0'))!='0' -- Capture pallet type
               BEGIN
                  IF ISNULL(@cPalletTypeSave,'')!=''
                  BEGIN
                     UPDATE RECEIPTDETAIL SET PalletType = @cPalletTypeSave
                     WHERE ReceiptKey = @cReceiptKey
                     AND ReceiptLineNumber = @cReceiptLineNumber
                  END
               END
            END
         END
		END
      GOTO Quit
	END

Exception:
   ROLLBACK TRANSACTION

Quit:
UPDATE RDT.RDTMOBREC SET
   C_String1 = @cLott10,
   C_String2 = @cPalletTypeSave,
   C_String3 = CASE WHEN ISNULL(@cSKU,'')='' THEN @cSKUReceived ELSE @cSKU END 
   WHERE Mobile = @nMobile

END; 

SET QUOTED_IDENTIFIER OFF 
GO