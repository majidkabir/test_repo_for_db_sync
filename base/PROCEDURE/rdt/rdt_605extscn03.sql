SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_605ExtScn03                                     */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose:       For Unilever                                          */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2024-10-08 1.0  Vikas   Created                                      */
/************************************************************************/

CREATE   PROC [RDT].[rdt_605ExtScn03] (
	@nMobile          INT,           
   @nFunc            INT,           
   @cLangCode        NVARCHAR( 3),  
   @nStep            INT,           
   @nScn             INT,           
   @nInputKey        INT,           
   @cFacility        NVARCHAR( 5),  
   @cStorerKey       NVARCHAR( 15), 
   @tExtScnData      VariableTable READONLY,
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
   @nAction          INT, --0 Jump Screen, 1 Validation(pass through all input fields), 2 Update, 3 Prepare output fields .....
   @nAfterScn        INT OUTPUT, @nAfterStep    INT OUTPUT, 
   @nErrNo           INT            OUTPUT, 
   @cErrMsg          NVARCHAR( 20)  OUTPUT,
   @cUDF01  NVARCHAR( 250) OUTPUT, @cUDF02 NVARCHAR( 250) OUTPUT, @cUDF03 NVARCHAR( 250) OUTPUT,
   @cUDF04  NVARCHAR( 250) OUTPUT, @cUDF05 NVARCHAR( 250) OUTPUT, @cUDF06 NVARCHAR( 250) OUTPUT,
   @cUDF07  NVARCHAR( 250) OUTPUT, @cUDF08 NVARCHAR( 250) OUTPUT, @cUDF09 NVARCHAR( 250) OUTPUT,
   @cUDF10  NVARCHAR( 250) OUTPUT, @cUDF11 NVARCHAR( 250) OUTPUT, @cUDF12 NVARCHAR( 250) OUTPUT,
   @cUDF13  NVARCHAR( 250) OUTPUT, @cUDF14 NVARCHAR( 250) OUTPUT, @cUDF15 NVARCHAR( 250) OUTPUT,
   @cUDF16  NVARCHAR( 250) OUTPUT, @cUDF17 NVARCHAR( 250) OUTPUT, @cUDF18 NVARCHAR( 250) OUTPUT,
   @cUDF19  NVARCHAR( 250) OUTPUT, @cUDF20 NVARCHAR( 250) OUTPUT, @cUDF21 NVARCHAR( 250) OUTPUT,
   @cUDF22  NVARCHAR( 250) OUTPUT, @cUDF23 NVARCHAR( 250) OUTPUT, @cUDF24 NVARCHAR( 250) OUTPUT,
   @cUDF25  NVARCHAR( 250) OUTPUT, @cUDF26 NVARCHAR( 250) OUTPUT, @cUDF27 NVARCHAR( 250) OUTPUT,
   @cUDF28  NVARCHAR( 250) OUTPUT, @cUDF29 NVARCHAR( 250) OUTPUT, @cUDF30 NVARCHAR( 250) OUTPUT
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
   @nSQLResult           INT,
   @nCheckDigit          INT,
   @cActLoc              NVARCHAR( 20),
   @cPalletTypeInUse     NVARCHAR( 5),
   @cPalletTypeSave      NVARCHAR( 10),
   @cLott10              NVARCHAR( 30),
   @cSKUReceived         NVARCHAR( 20),
   @cDamagedCode         NVARCHAR(30),
   @cExpiredCode         NVARCHAR(30)

   DECLARE @cOption        NVARCHAR(1),
           @cUserName      NVARCHAR(18),
           @cUserDefine08  NVARCHAR(30),
           @cReceiptKey    NVARCHAR(10),
           @cSKU           NVARCHAR(20),
           @cID            NVARCHAR(18),
           @cActReceiptKey NVARCHAR(10),
           @cDescr         NVARCHAR(60),
           @cRefNo         NVARCHAR(20),
           @cExtendedInfo  NVARCHAR(20),
           @cExtendedUpdateSP   NVARCHAR(20),
           @cExtendedInfoSP     NVARCHAR(20),
           @cPUOM_Desc     NCHAR(5),
           @cMUOM_Desc     NCHAR(5),
           @cPUOM          NVARCHAR(1),
           @cRDLineNo      NVARCHAR(5),
           @cSQL           NVARCHAR( MAX),
           @cSQLParam      NVARCHAR( MAX),
           @nCurrentScanned INT,
           @nCurrentLine   INT,
           @nTotalLine     INT,
           @nPUOM_Div      INT,
           @nQTY           INT,
           @nPQTY          INT,
           @nMQTY          INT


   Declare @cRectype             NVARCHAR(10),
           @cAvailcode           NVARCHAR(5),
           @cSkutype             NVARCHAR(50)

   SET @nAfterScn = @nScn
   SET @nAfterStep = @nStep

   SELECT
      --@cLott10 = C_String1,
      --@cPalletTypeSave = C_String2,
      --@cSKUReceived = C_String3
      @nPQTY           = V_PQTY,
      @nMQTY           = V_MQTY,
      @nQTY            = V_Integer1,
      @cUserName       = UserName,
      @nCurrentLine    = V_Integer2,
      @nTotalLine      = V_Integer3,
      @nCurrentScanned = V_Integer4,
      @cRDLineNo       = V_String9,
      @cReceiptKey     = V_ReceiptKey,
      @cActReceiptKey  = V_String22,
      @cRefNo          = V_String21,
      @cExtendedInfo   = V_String14,
      @cExtendedUpdateSP   = V_String12,
      @cExtendedInfoSP     = V_String13,
      @cID             = V_ID,
      @cSKU            = V_SKU,
      @cDescr          = V_SKUDescr,
      @cPUOM           = V_UOM,
      @cMUOM_Desc          = V_String1,
      @cPUOM_Desc          = V_String2
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile
   
   IF @nFunc = 605
   BEGIN
      IF @nAction = 0
      BEGIN
         IF @nStep = 3 AND @nInputKey = 1
         BEGIN
            SET @nAfterScn = 6441
            SET @nAfterStep = 99
            GOTO QUIT
         END
      END

      IF @nStep = 99
      BEGIN
         IF @nInputKey = 1
         Begin
            -- Screen mapping
            
            SET @cOption = @cInField14

            -- Check option valid
            IF @cOption NOT IN ('1','2','3','4')
            BEGIN
               SET @nErrNo = 224251
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
               GOTO Quit
            END

            -- Blank to get next line
            IF @cOption = '2'
            BEGIN
               -- Get next line
               EXEC rdt.rdt_PalletReceive_GetDetail @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cFacility, @cStorerKey,
                  @cActReceiptKey,
                  @cID,
                  @cSKU        OUTPUT,
                  @nQTY        OUTPUT,
                  @cRDLineNo   OUTPUT,
                  @cOutField01 OUTPUT,
                  @cOutField02 OUTPUT,
                  @cOutField03 OUTPUT,
                  @cOutField04 OUTPUT,
                  @cOutField05 OUTPUT,
                  @cOutField06 OUTPUT,
                  @cOutField07 OUTPUT,
                  @cOutField08 OUTPUT,
                  @cOutField09 OUTPUT,
                  @cOutField10 OUTPUT,
                  @cOutField11 OUTPUT,
                  @cOutField12 OUTPUT,
                  @cOutField13 OUTPUT,
                  @cOutField14 OUTPUT,
                  @cOutField15 OUTPUT,
                  @nErrNo      OUTPUT,
                  @cErrMsg     OUTPUT
               IF @nErrNo <> 0
               BEGIN
                  -- No more record
                  IF @nErrNo = -1
                  BEGIN
                     SET @nErrNo = 224252
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No more record
                  END
                  GOTO Quit
               END

               SET @nCurrentLine = @nCurrentLine + 1

               -- Get Pack info
               SELECT
                  @cDescr = SKU.Descr,
                  @cMUOM_Desc = Pack.PackUOM3,
                  @cPUOM_Desc =
                     CASE @cPUOM
                        WHEN '2' THEN Pack.PackUOM1 -- Case
                        WHEN '3' THEN Pack.PackUOM2 -- Inner pack
                        WHEN '6' THEN Pack.PackUOM3 -- Master unit
                        WHEN '1' THEN Pack.PackUOM4 -- Pallet
                        WHEN '4' THEN Pack.PackUOM8 -- Other unit 1
                        WHEN '5' THEN Pack.PackUOM9 -- Other unit 2
                     END,
                  @nPUOM_Div = CAST( IsNULL(
                     CASE @cPUOM
                        WHEN '2' THEN Pack.CaseCNT
                        WHEN '3' THEN Pack.InnerPack
                        WHEN '6' THEN Pack.QTY
                        WHEN '1' THEN Pack.Pallet
                        WHEN '4' THEN Pack.OtherUnit1
                        WHEN '5' THEN Pack.OtherUnit2
                     END, 1) AS INT)
               FROM dbo.SKU SKU WITH (NOLOCK)
                  INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
               WHERE SKU.StorerKey = @cStorerKey
                  AND SKU.SKU = @cSKU

               -- Convert to prefer UOM QTY
               IF @cPUOM = '6' OR -- When preferred UOM = master unit
                  @nPUOM_Div = 0  -- UOM not setup
               BEGIN
                  SET @cPUOM_Desc = ''
                  SET @nPQTY = 0
                  SET @nMQTY = @nQTY
               END
               ELSE
               BEGIN
                  SET @nPQTY = @nQTY / @nPUOM_Div  -- Calc QTY in preferred UOM
                  SET @nMQTY = @nQTY % @nPUOM_Div  -- Calc the remaining in master unit
               END

               -- Prepare next screen var
               SET @cOutField01 = @cID
               SET @cOutField02 = @cSKU
               SET @cOutField03 = SUBSTRING( @cDescr, 1, 20)
               SET @cOutField04 = SUBSTRING( @cDescr, 21, 20)
               SET @cOutField05 = '1:' + CASE WHEN @nPUOM_Div > 99999 THEN '*' ELSE CAST( @nPUOM_Div AS NCHAR( 5)) END +  -- 12345678901234567890
                                 rdt.rdtRightAlign( @cPUOM_Desc, 5) + SPACE( 3) +                                        -- 1:99999XXXXX   XXXXX
                                 rdt.rdtRightAlign( @cMUOM_Desc, 5)                     -- QTY: 9999999 9999999
               SET @cOutField06 = rdt.rdtRightAlign( CAST( @nPQTY AS NCHAR( 7)), 7) -- PQTY
               SET @cOutField07 = rdt.rdtRightAlign( CAST( @nMQTY AS NCHAR( 7)), 7) -- MQTY
               SET @cOutField13 = CAST( @nCurrentLine AS NVARCHAR( 2)) + '/' + CAST( @nTotalLine AS NVARCHAR( 2))
               SET @cOutField14 = @cOption

               -- Remain in current screen

               GOTO Quit
            END
            
             IF (ISNULL( rdt.RDTGetConfig( @nFunc, 'RCTSHLFVLD', @cStorerKey),'') != '')
               BEGIN
                     SELECT
                  @dLottable04 = Lottable04,
                  @dLottable13 = Lottable13
               FROM ReceiptDetail WITH(NOLOCK)
               WHERE ReceiptKey = @cReceiptKey
               AND ReceiptLineNumber = @cRDLineNo

               IF ISNULL(@dLottable04,'') = ''
               BEGIN
                  SET @nErrNo = 224253
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Expired Date
                  GOTO Quit
               END

               IF ISNULL(@dLottable13,'') = ''
               BEGIN
                  SET @nErrNo = 224254
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Production Date
                  GOTO Quit
               END

               IF @cOption = '1'
               BEGIN
                  SET @cLottable10 = 'N'
               END
               ELSE IF @cOption = '3'
               BEGIN
                  SET @cLottable10 = 'Y'
               END
               ELSE IF @cOption = '4'
               BEGIN
                  SET @cLottable10 = 'Y'
				  --VPA235 2024/10/10 Start
                  --SELECT TOP 1
                  --   @cLottable12 = Code
                  --FROM CodeLKUP
                  --WHERE storerkey = @cStorerkey
                  --AND UDF01 = 'LOT12_DMG'
                  --AND LISTNAME = 'SLCODE'

				   SELECT TOP 1
                     @cLottable12 = ISNULL(Code,'INTRDMG')
				  FROM CodeLKUP
                  WHERE storerkey =  @cStorerkey
                  AND SHORT = 'INTRDMG'
                  AND LISTNAME = 'ASNREASON'

				  --VPA235 2024/10/10 End


                  --SET @cLottable12 = 'In transit DMG'
               END

               SET @cLottable11 = ''

               SELECT TOP 1 @cUserDefine08 = ISNULL(RD.UserDefine08,'') ,@cRectype=R.RECType
               FROM dbo.Receipt R WITH (NOLOCK)
                  INNER JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON R.ReceiptKey  = RD.ReceiptKey
               WHERE R.Facility = @cFacility AND R.StorerKey = @cStorerKey
                  AND R.ReceiptKey = @cReceiptKey 
                  --AND (@cPOKey='NOPO' or RD.POKey = @cPOKey)
                  AND RD.Sku = @cSKU
               ORDER BY RD.ReceiptLineNumber

                  SELECT TOP 1 @nShelfLife = ISNULL(UDF02,0),@cResultCode = UDF03
                  FROM dbo.CodeLKUP WITH (NOLOCK)
                     WHERE ListName = 'CCODEVALID'
                     -- AND UDF01 = 'IBD'              --VPA235(1008)
                     AND UDF01 = @cRectype
                     AND Code = @cFacility
                     AND code2 = @cUserDefine08
                     AND Storerkey = @cStorerKey


					 					 									  				   				   				  
                --VPA235(1008)
                  --IF (DATEDIFF(day,GETDATE(),@dLottable04) < (DATEDIFF(day,@dLottable13,@dLottable04) * @nShelfLife/100 )) AND GETDATE() < @dLottable04
                  --BEGIN
                  --   SET @cLottable11 = @cResultCode
                  --END

                  IF (DATEDIFF(day,GETDATE(),@dLottable04) < (DATEDIFF(day,@dLottable13,@dLottable04) * @nShelfLife/100 )) 
                     AND GETDATE() < @dLottable04 AND @cRectype ='IBD'
                  BEGIN
                     SET @cLottable11 = @cResultCode
                  END
				  				  		   
              --IF (@cUserDefine08 != '' AND ISNULL(@cUserDefine08,N'OK' ) != N'OK') OR ISNULL(@cLottable11,'')!='' OR ISNULL(@cLottable12,'')!=''				  
                IF   (@cLottable01='ML12' OR  ISNULL(@cLottable12,'')!='')
                  BEGIN                         
                     SET @cLottable06 = '1'                  
                  END
				  				   				   				  							 			 
             
--				    IF @cRectype  IN ('IBD', 'TO')  AND ISNULL(@cLottable12,'')='' AND (@cUserDefine08 = '' OR ISNULL(@cUserDefine08,N'OK') = N'OK')
                    IF (@cRectype  IN ('IBD', 'TO')  AND ISNULL(@cLottable12,'')='')
                  BEGIN    
                					   				
                     SELECT @cSkutype= BUSR3 FROM SKU WHERE SKU= @cSKU AND STORERKEY= @cStorerKey

                     IF( (ISNULL(@dLottable04, '') <> '' AND DATEDIFF(DAY, GETDATE(), @dLottable04) < 211 
                        AND ROUND(CAST((DATEDIFF (day, getdate(), @dLottable04)  ) as float)/ CAST((DATEDIFF (day,@dLottable13,@dLottable04)  ) as float)*100,2)< 60
                        AND DATEDIFF(DAY, GETDATE(), @dLottable04) > 60  
						AND @cSkutype ='FROZEN_FOOD' ) 
                        OR 
                        (ISNULL(@dLottable04, '') <> '' AND DATEDIFF(DAY, GETDATE(), @dLottable04) < 391 
                        AND ROUND(CAST((DATEDIFF (day, getdate(), @dLottable04)  ) as float)/ CAST((DATEDIFF (day,@dLottable13,@dLottable04)  ) as float)*100,2)< 60
						AND DATEDIFF(DAY, GETDATE(), @dLottable04) > 60 
                        AND  @cSkutype = 'CABINETS' ))
                  BEGIN     
                     SET @cAvailcode = ''
                     SELECT @cAvailcode = ISNULL(Code,'')
                     FROM CODELKUP WITH (NOLOCK)
                     WHERE storerkey = @cStorerkey
                     AND UDF01 = 'FG_NearExpire_<310'
                     AND LISTNAME = 'SLCode'

                     SET @cLottable06 = '1'
                     SET @cLottable07 = CASE WHEN @cLottable01='ML11' THEN @cAvailcode 
					                    ELSE  @cLottable07 END 

                  END

                  IF( (ISNULL(@dLottable04, '') <> '' AND DATEDIFF(DAY, GETDATE(), @dLottable04) > 210 
                     AND ROUND(CAST((DATEDIFF (day, getdate(), @dLottable04)  ) as float)/ CAST((DATEDIFF (day,@dLottable13,@dLottable04)  ) as float)*100,2)< 60
                     AND @cSkutype ='FROZEN_FOOD' ) 
                     OR 
                     (ISNULL(@dLottable04, '') <> '' AND DATEDIFF(DAY, GETDATE(), @dLottable04) > 390 
                     AND ROUND(CAST((DATEDIFF (day, getdate(), @dLottable04)  ) as float)/ CAST((DATEDIFF (day,@dLottable13,@dLottable04)  ) as float)*100,2)< 60
                     AND  @cSkutype = 'CABINETS' ))
                  BEGIN     
                     SET @cAvailcode = ''

                     SELECT @cAvailcode = ISNULL(Code,'')
                     FROM CODELKUP WITH (NOLOCK)
                     WHERE storerkey = @cStorerkey
                        AND UDF01 = 'FG_NearExpire_>310'
                        AND LISTNAME = 'SLCode'

                   
                     SET @cLottable07 = CASE WHEN @cLottable01='ML11' THEN @cAvailcode 
					                    ELSE  @cLottable07 END 
                   END
               END		                    
             END   
                 
               IF (ISNULL( rdt.RDTGetConfig( @nFunc, 'ULLottable06', @cStorerKey),'0') != '0')
               BEGIN
                  --SET @cLottable06 = ''                  

              --VPA235(1008)
                  --IF ISNULL(@cLottable12,'') <> '' AND      
                IF ISNULL(@cLottable12,'') <> '' AND  @cRectype NOT IN ('RO', 'CF') AND 
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


				   IF ISNULL(@dLottable04,'') <> ''  AND @cLottable01<>'ML12' AND ISNULL(@cLottable12,'')='' AND DATEDIFF(DAY, GETDATE(), @dLottable04) <= 60  
                  BEGIN
                     SET @cExpiredCode = ''

                     SELECT @cExpiredCode = ISNULL(Code,'')
                     FROM CODELKUP WITH (NOLOCK)
                     WHERE storerkey = @cStorerkey
                        AND UDF01 = 'RMPM_Expired' 
                        AND LISTNAME = 'SLCode'         
                              
                      
                        SET @cLottable06 = '1'
                     SET @cLottable07 =	 CASE WHEN @cLottable01='ML11' THEN @cExpiredCode 
					                     ELSE  @cLottable07 END 
                   END

				   IF @cRectype  IN ('RO', 'CF')
                  BEGIN
                     SET @cExpiredCode = ''

                     SELECT @cExpiredCode = ISNULL(Code,'')
                     FROM CODELKUP WITH (NOLOCK)
                     WHERE storerkey = @cStorerkey
                        AND UDF01 = 'BUDFG_RET' 
                        AND LISTNAME = 'SLCode'

                     SET @cLottable06 = '1'
                     SET @cLottable07 = @cExpiredCode
                  END
                  
                  --ADDED BY VPA235(1008) FOR FG NEAR EXPIRY END
               END
            
            DECLARE @nTranCount INT
            SET @nTranCount = @@TRANCOUNT
            BEGIN TRANSACTION
            SAVE TRAN rdtfnc_PalletReceive
            

            IF (ISNULL( rdt.RDTGetConfig( @nFunc, 'ACTVASWO', @cStorerKey),'0') != '0')
            BEGIN
               BEGIN TRY
                  -- VAS/DMG 
                  IF @cOption IN ('3','4')
                  BEGIN
                     SELECT 
                        @cexternReceiptKey = ExternReceiptKey,
                        @cexternLineNo = ExternLineNo
                     FROM dbo.ReceiptDetail RD WITH (NOLOCK)
                     WHERE RD.ReceiptKey = @cReceiptKey
                     AND RD.ReceiptLineNumber = @cRDLineNo

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

                     -- Duplicated VAS Action
                     IF @nErrNo = 211710
                     BEGIN
                        SET @nErrNo = 0
                        SET @cErrMsg = ''
                     END
                     ELSE IF @nErrNo <> 0
                     BEGIN
                        ROLLBACK TRAN rdtfnc_PalletReceive
                        WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                           COMMIT TRAN
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
                  END
               END TRY
               BEGIN CATCH
                  SET @nErrNo = 211714
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Generate WorkOrder Fail'
                  
                  ROLLBACK TRAN rdtfnc_PalletReceive
                  WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                     COMMIT TRAN
                  GOTO Quit
               END CATCH            
            END

            -- Receive
            EXEC rdt.rdt_PalletReceive_Confirm @nFunc, @nMobile, @cLangCode, @cStorerKey, @cFacility,
               @cActReceiptKey,
               @cID,
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT
            IF @nErrNo <> 0
            BEGIN
               ROLLBACK TRAN rdtfnc_PalletReceive
               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                  COMMIT TRAN
               GOTO Quit
            END

            UPDATE ReceiptDetail
            SET Lottable06 = ISNULL(@cLottable06,''),
                Lottable07 = ISNULL(@cLottable07,''),
                Lottable10 = ISNULL(@cLottable10,''),
                Lottable11 = ISNULL(@cLottable11,''),
                Lottable12 = ISNULL(@cLottable12,'')
            WHERE storerkey = @cStorerKey
            AND ReceiptKey = @cActReceiptKey
            AND ToID = @cID

            -- Extended update
            IF @cExtendedUpdateSP <> ''
            BEGIN
               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
               BEGIN
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cReceiptKey, @cRefNo, @cID, ' +
                     ' @nErrNo OUTPUT, @cErrMsg OUTPUT'
                  SET @cSQLParam =
                     '@nMobile      INT,           ' +
                     '@nFunc        INT,           ' +
                     '@cLangCode    NVARCHAR( 3),  ' +
                     '@nStep        INT,           ' +
                     '@nInputKey    INT,           ' +
                     '@cFacility    NVARCHAR( 5),  ' +
                     '@cStorerKey   NVARCHAR( 15), ' +
                     '@cReceiptKey  NVARCHAR( 10), ' +
                     '@cRefNo       NVARCHAR( 20), ' +
                     '@cID          NVARCHAR( 18), ' +
                     '@nErrNo       INT            OUTPUT, ' +
                     '@cErrMsg      NVARCHAR( 20)  OUTPUT'

                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cReceiptKey, @cRefNo, @cID,
                     @nErrNo OUTPUT, @cErrMsg OUTPUT

                  IF @nErrNo <> 0
                  BEGIN
                     ROLLBACK TRAN rdtfnc_PalletReceive
                     WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                        COMMIT TRAN
                     GOTO Quit
                  END
               END
            END

            COMMIT TRAN rdtfnc_PalletReceive
            WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
               COMMIT TRAN

            SET @nCurrentScanned = @nCurrentScanned + 1

                  -- Extended validate
            IF @cExtendedInfoSP <> ''
            BEGIN
               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
               BEGIN
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cReceiptKey, @cRefNo, @cID,@nCurrentScanned, ' +
                     '@cExtendedInfo OUTPUT'
                  SET @cSQLParam =
                     '@nMobile      INT,           ' +
                     '@nFunc       INT,           ' +
                     '@cLangCode    NVARCHAR( 3),  ' +
                     '@nStep        INT,           ' +
                     '@nInputKey    INT,           ' +
                     '@cFacility    NVARCHAR( 5),  ' +
                     '@cStorerKey   NVARCHAR( 15), ' +
                     '@cReceiptKey  NVARCHAR( 10), ' +
                     '@cRefNo       NVARCHAR( 20), ' +
                     '@cID          NVARCHAR( 18), ' +
                     '@nCurrentScanned INT,           ' +
                     '@cExtendedInfo NVARCHAR(20) OUTPUT'

                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cReceiptKey, @cRefNo, @cID,@nCurrentScanned,
                     @cExtendedInfo OUTPUT
               END
            END

            -- EventLog
            EXEC RDT.rdt_STD_EventLog
               @cActionType   = '2', -- Receiving
               @cUserID       = @cUserName,
               @nMobileNo     = @nMobile,
               @nFunctionID   = @nFunc,
               @cFacility     = @cFacility,
               @cStorerKey    = @cStorerKey,
               @cReceiptKey   = @cReceiptKey,
               @cID           = @cID,
               @cRefNo1       = @cRefNo,
               @nStep         = @nStep

            -- Prep next screen var
            SET @cOutField01 = @cReceiptKey
            SET @cOutField02 = @cRefNo
            SET @cOutField03 = '' -- ID
            SET @cOutField04 = @cExtendedInfo

            -- Go to ID screen
            SET @nAfterScn = 4251
            SET @nAfterStep = 2
         END
            
         IF @nInputKey = 0 -- ESC
         BEGIN
            -- Prep next screen var
            SET @cOutField01 = @cReceiptKey
            SET @cOutField02 = @cRefNo
            SET @cOutField03 = '' -- ID

            -- Go to ID screen
            SET @nAfterScn = 4251
            SET @nAfterStep = 2
         END

         GOTO Quit
      END
   END


Quit:
   IF @nScn = 6441
   BEGIN
      SET @cUDF01 = @nPQTY
      SET @cUDF02 = @nMQTY
      SET @cUDF03 = @nQTY
      SET @cUDF04 = @nCurrentLine
      SET @cUDF05 = @nTotalLine
      SET @cUDF06 = @nCurrentScanned
      SET @cUDF07 = @cRDLineNo
      SET @cUDF08 = @cReceiptKey
      SET @cUDF09 = @cActReceiptKey
      SET @cUDF10 = @cRefNo
      SET @cUDF11 = @cExtendedInfo
      SET @cUDF12 = @cID
      SET @cUDF13 = @cSKU
      SET @cUDF14 = @cDescr
      SET @cUDF15 = @cPUOM
      SET @cUDF16 = @cMUOM_Desc
      SET @cUDF17 = @cPUOM_Desc
   END
END

SET QUOTED_IDENTIFIER OFF

GO