SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO




CREATE  PROC rdt.rdt_DecodeTest (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nInputKey     INT,
   @cStorerKey    NVARCHAR( 15),
   @cFacility     NVARCHAR( 5), 
   @cBarcode      NVARCHAR( 60),
   @cID           NVARCHAR( 18) = NULL OUTPUT,
   @cUPC          NVARCHAR( 30) = NULL OUTPUT,
   @nQTY          INT           = NULL OUTPUT,
   @cLottable01   NVARCHAR( 18) = NULL OUTPUT,
   @cLottable02   NVARCHAR( 18) = NULL OUTPUT,
   @cLottable03   NVARCHAR( 18) = NULL OUTPUT,
   @dLottable04   DATETIME      = -1   OUTPUT, -- date usually init as NULL or 0 in parent
   @dLottable05   DATETIME      = -1   OUTPUT, -- so use -1 to indicate param provide/not provide
   @cLottable06   NVARCHAR( 30) = NULL OUTPUT,
   @cLottable07   NVARCHAR( 30) = NULL OUTPUT,
   @cLottable08   NVARCHAR( 30) = NULL OUTPUT,
   @cLottable09   NVARCHAR( 30) = NULL OUTPUT,
   @cLottable10   NVARCHAR( 30) = NULL OUTPUT,
   @cLottable11   NVARCHAR( 30) = NULL OUTPUT,
   @cLottable12   NVARCHAR( 30) = NULL OUTPUT,
   @dLottable13   DATETIME      = -1   OUTPUT,
   @dLottable14   DATETIME      = -1   OUTPUT,
   @dLottable15   DATETIME      = -1   OUTPUT,
   @cUserDefine01 NVARCHAR( 60) = NULL OUTPUT,
   @cUserDefine02 NVARCHAR( 60) = NULL OUTPUT,
   @cUserDefine03 NVARCHAR( 60) = NULL OUTPUT,
   @cUserDefine04 NVARCHAR( 60) = NULL OUTPUT,
   @cUserDefine05 NVARCHAR( 60) = NULL OUTPUT,
   @nErrNo        INT           = 0    OUTPUT,
   @cErrMsg       NVARCHAR( 20) = ''   OUTPUT, 
   @cDebug        NVARCHAR( 1)  = '',
   @cType         NVARCHAR( 10) = '',
   @cDropID       NVARCHAR( 20) = ''   OUTPUT,
   @cUCCNo        NVARCHAR( 20) = ''   OUTPUT, 
   @cSerialNo     NVARCHAR( 30) = ''   OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- http://www.gs1.org/docs/barcodes/GS1_General_Specifications.pdf
   -- List of all fields (AI, Application Identifiers): page 120 of 438 (Section 3, GS1 Application Identifier definitions)
   -- FNC1, ASCII value: 29 (GS). Page 249 (5.4.7.5 Transmitted data (FNC1))

   DECLARE @nPos              INT
   DECLARE @nStart            INT
   DECLARE @nEnd              INT
   DECLARE @cDecoded          NVARCHAR( 1)
   DECLARE @nAllowGap         INT
   DECLARE @nSequence         INT
   DECLARE @nRowCount         INT
   
   DECLARE @cDecodeCode       NVARCHAR( 30)
   DECLARE @cDecodeLineNumber NVARCHAR( 5)
   DECLARE @cRegEx            NVARCHAR( 250)
   DECLARE @cFieldIdentifier  NVARCHAR( 10)
   DECLARE @cLengthType       NVARCHAR( 10)
   DECLARE @nMaxLength        INT
   DECLARE @nTerminateChar    TINYINT -- Usually is a GS char (ASCII=29). Terminator at end of variable length field (optional if it is the last field)
   DECLARE @cDataType         NVARCHAR( 10)
   DECLARE @cMapTo            NVARCHAR( 30)
   DECLARE @cFormatSP         NVARCHAR( 50)
   DECLARE @cProcessSP        NVARCHAR( 50)
   
   DECLARE @cCode             NVARCHAR( 60)
   DECLARE @cFieldData        NVARCHAR( 60)
   DECLARE @cString           NVARCHAR( 60)
   DECLARE @dDate             DATETIME
   DECLARE @nInteger          INT
   DECLARE @fFloat            FLOAT
   DECLARE @nPatternLen       INT
   
   DECLARE @cTempID           NVARCHAR( 18) 
   DECLARE @cTempUPC          NVARCHAR( 30) 
   DECLARE @nTempQTY          INT
   DECLARE @cTempLottable01   NVARCHAR( 18)
   DECLARE @cTempLottable02   NVARCHAR( 18)
   DECLARE @cTempLottable03   NVARCHAR( 18)
   DECLARE @dTempLottable04   DATETIME
   DECLARE @dTempLottable05   DATETIME
   DECLARE @cTempLottable06   NVARCHAR( 30)
   DECLARE @cTempLottable07   NVARCHAR( 30)
   DECLARE @cTempLottable08   NVARCHAR( 30)
   DECLARE @cTempLottable09   NVARCHAR( 30)
   DECLARE @cTempLottable10   NVARCHAR( 30)
   DECLARE @cTempLottable11   NVARCHAR( 30)
   DECLARE @cTempLottable12   NVARCHAR( 30)
   DECLARE @dTempLottable13   DATETIME
   DECLARE @dTempLottable14   DATETIME
   DECLARE @dTempLottable15   DATETIME
   DECLARE @cTempUserDefine01 NVARCHAR( 60)
   DECLARE @cTempUserDefine02 NVARCHAR( 60)
   DECLARE @cTempUserDefine03 NVARCHAR( 60)
   DECLARE @cTempUserDefine04 NVARCHAR( 60)
   DECLARE @cTempUserDefine05 NVARCHAR( 60)
   DECLARE @cTempDropID       NVARCHAR( 20) 
   DECLARE @cTempUCCNo        NVARCHAR( 20) 
   DECLARE @cTempSerialNo     NVARCHAR( 50) 
   
   -- If function specific DecodeCode not setup, use generic one
   IF @nFunc > 0
      IF NOT EXISTS( SELECT TOP 1 1 
         FROM BarcodeConfig WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND Function_ID = @nFunc)
         SET @nFunc = 0

   -- UPC should not require setup. Most of the module is only UPC, so pass-in blank, don't need to modify all modules
   IF @cType = ''
      SET @cType = 'UPC'

   -- Loop header
   DECLARE @curDH CURSOR
   DECLARE @curDD CURSOR
   SET @curDH = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DecodeCode, Sequence, AllowGap
      FROM BarcodeConfig WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND Function_ID = @nFunc
      ORDER BY Sequence
   OPEN @curDH
   FETCH NEXT FROM @curDH INTO @cDecodeCode, @nSequence, @nAllowGap
   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @nErrNo = 0
      SET @cErrMsg = ''
   
      -- Backup to temp
      SET @cCode           = @cBarCode 
      SET @cTempID         = @cID
      SET @cTempUPC        = @cUPC       
      SET @nTempQTY        = @nQTY       
      SET @cTempLottable01 = @cLottable01
      SET @cTempLottable02 = @cLottable02
      SET @cTempLottable03 = @cLottable03
      SET @dTempLottable04 = @dLottable04
      SET @dTempLottable05 = @dLottable05
      SET @cTempLottable06 = @cLottable06
      SET @cTempLottable07 = @cLottable07
      SET @cTempLottable08 = @cLottable08
      SET @cTempLottable09 = @cLottable09
      SET @cTempLottable10 = @cLottable10
      SET @cTempLottable11 = @cLottable11
      SET @cTempLottable12 = @cLottable12
      SET @dTempLottable13 = @dLottable13
      SET @dTempLottable14 = @dLottable14
      SET @dTempLottable15 = @dLottable15
      SET @cTempUserDefine01 = @cUserDefine01
      SET @cTempUserDefine02 = @cUserDefine02
      SET @cTempUserDefine03 = @cUserDefine03
      SET @cTempUserDefine04 = @cUserDefine04
      SET @cTempUserDefine05 = @cUserDefine05
      SET @cTempDropID       = @cDropID
      SET @cTempUCCNo        = @cUCCNo
      SET @cTempSerialNo     = @cSerialNo

      IF @cDebug = '1'
         select @cDecodeCode '@cDecodeCode', @nSequence '@nSequence'

      -- All fields are fix length
      IF NOT EXISTS( SELECT 1 FROM BarcodeConfigDetail WITH (NOLOCK) WHERE DecodeCode = @cDecodeCode AND LengthType = 'VARIABLE')
      BEGIN
         -- Calc total lenght

		 SELECT  MaxLength , FieldIdentifier,@cType,Type,@cBarcode '@cBarcode',DATALENGTH( FieldIdentifier)/2 'DATALENGTH', DATALENGTH( @cBarcode)/2 ' DATALENGTH( @cBarcode)/2'
         FROM BarcodeConfigDetail WITH (NOLOCK) 
         WHERE DecodeCode = @cDecodeCode
            AND ((@cType = 'UPC' AND Type IN ( '', 'UPC')) 
            OR Type = @cType)

         SELECT @nPatternLen = ISNULL( SUM( MaxLength + DATALENGTH( FieldIdentifier)/2), 0)
         FROM BarcodeConfigDetail WITH (NOLOCK) 
         WHERE DecodeCode = @cDecodeCode
            AND ((@cType = 'UPC' AND Type IN ( '', 'UPC')) 
             OR Type = @cType)

         -- Check length
         IF @nPatternLen <> DATALENGTH( @cBarcode)/2
         BEGIN
            SET @nErrNo = 98905
            SET @cErrMsg = cast(@cBarcode as varchar(10)) + ',' + rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid length
         END
      END

      -- Encounter error, try next pattern
      IF @nErrNo <> 0
      BEGIN
         IF @cDebug = '1' 
            select @nErrNo '@nErrNo', @cErrMsg '@cErrMsg'

         FETCH NEXT FROM @curDH INTO @cDecodeCode, @nSequence, @nAllowGap
         CONTINUE
      END
      
      -- Loop detail
      SET @nRowCount = 0
      SET @curDD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DecodeLineNumber, FieldIdentifier, LengthType, MaxLength, TerminateChar, DataType, MapTo, FormatSP, ProcessSP
         FROM BarcodeConfigDetail WITH (NOLOCK)
         WHERE DecodeCode = @cDecodeCode
            AND ((@cType = 'UPC' AND Type IN ( '', 'UPC')) 
             OR Type = @cType)
         ORDER BY DecodeLineNumber
      OPEN @curDD
      FETCH NEXT FROM @curDD INTO @cDecodeLineNumber, @cFieldIdentifier, @cLengthType, @nMaxLength, @nTerminateChar, @cDataType, @cMapTo, @cFormatSP, @cProcessSP
      WHILE @@FETCH_STATUS = 0
      BEGIN
         IF @nRowCount = 0 
            SET @nRowCount = 1

         SET @cFieldData = ''
   
         -- Find field identifier
         SET @nStart = PATINDEX( '%' + @cFieldIdentifier + '%', @cCode)
         IF @cDebug = '1'
            select @cDecodeLineNumber '@cDecodeLineNumber', @cCode '@cCode', @cFieldIdentifier '@cFieldIdentifier', @nStart '@nStart'
   
         -- Found field identifier
         IF @nStart > 0
         BEGIN
            -- Check leading data
            IF @nStart > 1 AND @nAllowGap <> 1 -- Found leading data and not allow gap
            BEGIN
               SET @nErrNo = 98907
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Found gap
               BREAK
            END
            
            -- Get max data
            SET @cFieldData = SUBSTRING( @cCode, @nStart + DATALENGTH( @cFieldIdentifier)/2, @nMaxLength)
   
            -- Terminate char is setup
            SET @nPos = 0
            IF @nTerminateChar > 0
            BEGIN
               -- Get terminate char position
               SET @nPos = CHARINDEX( CHAR( @nTerminateChar), @cFieldData, DATALENGTH( @cFieldIdentifier)/2 + 1)
               
               -- Get data up to terminate char 
               IF @nPos > 0
               BEGIN
                  SET @cFieldData = SUBSTRING( @cFieldData, 1, @nPos - 1)
                  SET @nEnd = @nEnd + 1
               END
            END
   
            -- Calc end of field
            SET @nEnd = @nStart + DATALENGTH( @cFieldIdentifier)/2 + DATALENGTH( @cFieldData)/2 + CASE WHEN @nPos > 0 THEN 1 ELSE 0 END
            IF @cDebug = '1'
               select @cDecodeLineNumber '@cDecodeLineNumber', @cFieldData '@cFieldData', @nEnd '@nEnd'

            -- Take out the field
            SET @cCode = SUBSTRING( @cCode, @nEnd, DATALENGTH( @cCode)/2)
         END
         
         -- Abstracted value 
         IF @cFieldData <> ''
         BEGIN
            SET @cString = ''
            SET @dDate = NULL
            SET @nInteger = 0
            SET @fFloat = 0
   
            -- Format data
            IF @cFormatSP <> ''
            BEGIN
               EXEC rdt.rdt_Decode_Format @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, 
                  @cDecodeCode, 
                  @cDecodeLineNumber, 
                  @cFormatSP, 
                  @cFieldData OUTPUT, 
                  @nErrNo     OUTPUT, 
                  @cErrMsg    OUTPUT
               IF @nErrNo <> 0
                  BREAK
            END
   
            -- Check string
            IF @cDataType = 'STRING' SET @cString = @cFieldData
            
            -- Check date
            ELSE IF @cDataType = 'DATE'
            BEGIN
               IF rdt.rdtIsValidDate( @cFieldData) = 0
               BEGIN
                  SET @nErrNo = 98901
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Date
                  BREAK
               END

               SET @dDate = rdt.rdtConvertToDate( @cFieldData)
            END
            
            -- Check integer
            ELSE IF @cDataType = 'INTEGER'
            BEGIN 
               -- QTY
               IF @cMapTo = 'QTY'
               BEGIN
                  IF rdt.rdtIsValidQTY( @cFieldData, 0) = 0 -- Not check for zero
                  BEGIN
                     SET @nErrNo = 98902
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid QTY
                     BREAK
                  END
               END
   
               -- Other int
               ELSE 
               BEGIN
                  IF rdt.rdtIsInteger( @cFieldData) = 0
                  BEGIN
                     SET @nErrNo = 98903
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid INT
                     BREAK
                  END
               END
               SET @nInteger = @cFieldData
            END
            
            -- Check numeric
            ELSE IF @cDataType = 'DECIMAL'
            BEGIN
               IF rdt.rdtIsValidQTY( @cFieldData, 20) = 0 -- Not check for zero
               BEGIN
                  SET @nErrNo = 98904
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid NUM
                  BREAK
               END
               SET @cString = @cFieldData
            END
            
			select @cString
            -- Field is mapped
            IF @cMapTo <> '' 
            BEGIN
               IF @cMapTo = 'UPC'          AND @cUPC          IS NOT NULL SET @cTempUPC          = LEFT( @cString, 30) ELSE 
               IF @cMapTo = 'QTY'          AND @nQTY          IS NOT NULL SET @nTempQTY          = @nInteger           ELSE 
               IF @cMapTo = 'LOTTABLE01'   AND @cLottable01   IS NOT NULL SET @cTempLottable01   = LEFT( @cString, 18) ELSE 
               IF @cMapTo = 'LOTTABLE02'   AND @cLottable02   IS NOT NULL SET @cTempLottable02   = LEFT( @cString, 18) ELSE 
               IF @cMapTo = 'LOTTABLE03'   AND @cLottable03   IS NOT NULL SET @cTempLottable03   = LEFT( @cString, 18) ELSE 
               IF @cMapTo = 'LOTTABLE04'   AND @dLottable04   <> -1       SET @dTempLottable04   = @dDate              ELSE 
               IF @cMapTo = 'LOTTABLE05'   AND @dLottable05   <> -1       SET @dTempLottable05   = @dDate              ELSE 
               IF @cMapTo = 'LOTTABLE06'   AND @cLottable06   IS NOT NULL SET @cTempLottable06   = LEFT( @cString, 30) ELSE
               IF @cMapTo = 'LOTTABLE07'   AND @cLottable07   IS NOT NULL SET @cTempLottable07   = LEFT( @cString, 30) ELSE
               IF @cMapTo = 'LOTTABLE08'   AND @cLottable08   IS NOT NULL SET @cTempLottable08   = LEFT( @cString, 30) ELSE
               IF @cMapTo = 'LOTTABLE09'   AND @cLottable09   IS NOT NULL SET @cTempLottable09   = LEFT( @cString, 30) ELSE
               IF @cMapTo = 'LOTTABLE10'   AND @cLottable10   IS NOT NULL SET @cTempLottable10   = LEFT( @cString, 30) ELSE
               IF @cMapTo = 'LOTTABLE11'   AND @cLottable11   IS NOT NULL SET @cTempLottable11   = LEFT( @cString, 30) ELSE
               IF @cMapTo = 'LOTTABLE12'   AND @cLottable12   IS NOT NULL SET @cTempLottable12   = LEFT( @cString, 30) ELSE
               IF @cMapTo = 'LOTTABLE13'   AND @dLottable13   <> -1       SET @dTempLottable13   = @dDate              ELSE
               IF @cMapTo = 'LOTTABLE14'   AND @dLottable14   <> -1       SET @dTempLottable14   = @dDate              ELSE 
               IF @cMapTo = 'LOTTABLE15'   AND @dLottable15   <> -1       SET @dTempLottable15   = @dDate              ELSE 
               IF @cMapTo = 'ID'           AND @cID           IS NOT NULL SET @cTempID           = LEFT( @cString, 18) ELSE
               IF @cMapTo = 'USERDEFINE01' AND @cUserDefine01 IS NOT NULL SET @cTempUserDefine01 = LEFT( @cString, 60) ELSE
               IF @cMapTo = 'USERDEFINE02' AND @cUserDefine02 IS NOT NULL SET @cTempUserDefine02 = LEFT( @cString, 60) ELSE
               IF @cMapTo = 'USERDEFINE03' AND @cUserDefine03 IS NOT NULL SET @cTempUserDefine03 = LEFT( @cString, 60) ELSE
               IF @cMapTo = 'USERDEFINE04' AND @cUserDefine04 IS NOT NULL SET @cTempUserDefine04 = LEFT( @cString, 60) ELSE
               IF @cMapTo = 'USERDEFINE05' AND @cUserDefine05 IS NOT NULL SET @cTempUserDefine05 = LEFT( @cString, 60) ELSE
               IF @cMapTo = 'DROPID'       AND @cDropID       IS NOT NULL SET @cTempDropID       = LEFT( @cString, 20) ELSE
               IF @cMapTo = 'UCCNO'        AND @cUCCNo        IS NOT NULL SET @cTempUCCNo        = LEFT( @cString, 20) ELSE
               IF @cMapTo = 'SERIALNO'     AND @cSerialNo     IS NOT NULL SET @cTempSerialNo     = LEFT( @cString, 50) 
            END
         END
         ELSE
         BEGIN
            SET @nErrNo = 98906
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Field no value
            BREAK
         END
         
         FETCH NEXT FROM @curDD INTO @cDecodeLineNumber, @cFieldIdentifier, @cLengthType, @nMaxLength, @nTerminateChar, @cDataType, @cMapTo, @cFormatSP, @cProcessSP
      END

      IF @cDebug = '1' AND @nErrNo <> 0
         select @nErrNo '@nErrNo', @cErrMsg '@cErrMsg'
      
      -- Successful decode
      IF @nErrNo = 0 AND @nRowCount > 0 
      BEGIN
         SET @cDecoded = 'Y'
         BREAK
      END
      
      FETCH NEXT FROM @curDH INTO @cDecodeCode, @nSequence, @nAllowGap
   END

   -- Save abstracted data
   IF @nErrNo = 0 AND @cDecoded = 'Y'
   BEGIN
      IF @cID           IS NOT NULL SET @cID           = @cTempID
      IF @cUPC          IS NOT NULL SET @cUPC          = @cTempUPC       
      IF @nQTY          IS NOT NULL SET @nQTY          = @nTempQTY       
      IF @cLottable01   IS NOT NULL SET @cLottable01   = @cTempLottable01
      IF @cLottable02   IS NOT NULL SET @cLottable02   = @cTempLottable02
      IF @cLottable03   IS NOT NULL SET @cLottable03   = @cTempLottable03
      IF @dLottable04   <> -1       SET @dLottable04   = @dTempLottable04
      IF @dLottable05   <> -1       SET @dLottable05   = @dTempLottable05
      IF @cLottable06   IS NOT NULL SET @cLottable06   = @cTempLottable06
      IF @cLottable07   IS NOT NULL SET @cLottable07   = @cTempLottable07
      IF @cLottable08   IS NOT NULL SET @cLottable08   = @cTempLottable08
      IF @cLottable09   IS NOT NULL SET @cLottable09   = @cTempLottable09
      IF @cLottable10   IS NOT NULL SET @cLottable10   = @cTempLottable10
      IF @cLottable11   IS NOT NULL SET @cLottable11   = @cTempLottable11
      IF @cLottable12   IS NOT NULL SET @cLottable12   = @cTempLottable12
      IF @dLottable13   <> -1       SET @dLottable13   = @dTempLottable13
      IF @dLottable14   <> -1       SET @dLottable14   = @dTempLottable14
      IF @dLottable15   <> -1       SET @dLottable15   = @dTempLottable15
      IF @cUserDefine01 IS NOT NULL SET @cUserDefine01 = @cTempUserDefine01
      IF @cUserDefine02 IS NOT NULL SET @cUserDefine02 = @cTempUserDefine02
      IF @cUserDefine03 IS NOT NULL SET @cUserDefine03 = @cTempUserDefine03
      IF @cUserDefine04 IS NOT NULL SET @cUserDefine04 = @cTempUserDefine04
      IF @cUserDefine05 IS NOT NULL SET @cUserDefine05 = @cTempUserDefine05
      IF @cDropID       IS NOT NULL SET @cDropID       = @cTempDropID
      IF @cUCCNo        IS NOT NULL SET @cUCCNo        = @cTempUCCNo
      IF @cSerialNo     IS NOT NULL SET @cSerialNo     = @cTempSerialNo

   END
   
Quit:

END

GO