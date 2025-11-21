SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_839ExtScn03                                     */
/*                                                                      */  
/* Purpose:       For Defy                                              */  
/*                                                                      */  
/* Date        Rev  Author     Purposes                                 */
/* 2024-09-23  1.0  CYU027      FCR-808 PUMA SKU IMAGE widget           */
/************************************************************************/  
  
CREATE   PROC  [RDT].[rdt_839ExtScn03] (
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

   DECLARE @cSuggSKU       NVARCHAR( 20)

   SELECT @cSuggSKU = Value FROM @tExtScnData WHERE Variable = '@cSuggSKU'

   IF @nAction = 1
   BEGIN
      IF @nFunc = 839
      BEGIN
         --Here we will redirect screen 4642 to new screen 6445
         IF @nScn = 4642 --SKU/QTY Screen
         BEGIN

            SET @nAfterScn = 6445
            /********************************************************************************
               Scn = 6445. UCC screen
                  LOC         (field01)
                  SKUDetails  (field02)
                  DESCR       (field03)
                  SKU         (field04)
                  IMAGE       (field14)
                  barcode     (input)
                  lottable    (field08)
                  lottable    (field09)
                  lottable    (field10)
                  lottable    (field11)
                  PK QTY      (field07, input)
                  ACT QTY     (field06)
                  BAL QTY     (field13)
                  extinfo     (field12)
            ********************************************************************************/

            BEGIN TRY
               DECLARE @cSQL           NVARCHAR( MAX)
               DECLARE @cSQLParam      NVARCHAR( MAX)
               DECLARE @cColums     NVARCHAR(60)
               DECLARE @cSqlRes     NVARCHAR(MAX)
               DECLARE @cCode  NVARCHAR(60)
               DECLARE @curcdlkup   CURSOR

               SET @curcdlkup = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  SELECT UDF01, Code
                  FROM codelkup WITH (NOLOCK)
                  WHERE Listname ='SKUWIDGET'
                    AND Storerkey = @cStorerkey
                    AND Code in ('ELEMENT1','ELEMENT2','ELEMENT3','ELEMENT4')
               OPEN @curcdlkup
               FETCH NEXT FROM @curcdlkup INTO @cColums, @cCode
               WHILE @@FETCH_STATUS = 0

                  BEGIN
                     IF CHARINDEX('&',@cColums) > 0
                        SET @cSQL = 'SELECT @cSqlRes=CONCAT_WS(''-'',' + REPLACE(@cColums, '&',',') +') FROM SKU WHERE SKU = @cSuggSKU and Storerkey = @cStorerkey'
                     ELSE
                        SET @cSQL = 'SELECT @cSqlRes= ' + @cColums+' FROM SKU WHERE SKU = @cSuggSKU and Storerkey = @cStorerkey'

                     SET @cSQLParam =
                             '@cSuggSKU      NVARCHAR( 20) ' +
                             ',@cStorerkey    NVARCHAR( 15) ' +
                             ',@cSqlRes    NVARCHAR(MAX) OUTPUT'

                     EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                          @cSuggSKU = @cSuggSKU,
                          @cStorerkey = @cStorerkey,
                          @cSqlRes = @cSqlRes OUTPUT

                     IF @cCode = 'ELEMENT1'
                        SET @cOutField02 = @cSqlRes --SKUDetails
                     ELSE IF @cCode = 'ELEMENT2'
                        SET @cOutField03 = @cSqlRes --SKU Description
                     ELSE IF @cCode = 'ELEMENT3'
                        SET @cOutField04 = @cSqlRes --SKU sku
                     ELSE IF @cCode = 'ELEMENT4'
                        SET @cOutField14 = @cSqlRes -- Image

                     FETCH NEXT FROM @curcdlkup INTO @cColums, @cCode
                  END

               GOTO Quit

            END TRY
            BEGIN CATCH
               SET @nErrNo = 218921
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CdlookupErr
               GOTO Quit
            END CATCH

         END
      END

   END
   GOTO Quit

Quit:
END


GO