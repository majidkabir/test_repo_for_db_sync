SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/********************************************************************************/
/* Store procedure: rdt_Lottable                                                */
/* Copyright      : LF                                                          */
/*                                                                              */
/* Purpose: Dynamic lottable                                                    */
/*                                                                              */
/* Date        Rev    Author      Purposes                                      */
/* 08-10-2014  1.0    Ung         SOS317571. Created                            */
/* 28-09-2015  1.1    Ung         SOS317571 Add PRE not visible                 */
/*                                SOS350418 Add FormatSP                        */
/*                                Add POST remain in current screen             */
/* 21-10-2015  1.2    Ung         SOS352968 Add PRECAPTURE                      */
/* 23-12-2016  1.3    Ung         WMS-835 Add FormatSP remain in current screen */
/* 02-09-2018  1.4    Ung         WMS-5956 Fix CAPTURE 2nd page not shown       */
/* 05-11-2019  1.5    Ung         INC0896693 Fix disable lottable not capture   */
/* 08-12-2020  1.6    Ung         WMS-14691 Fix hidden field not clear          */
/*                                Fix validation fail cursor on next field      */
/* 08/02-2017  1.7    Ung         WMS-1000 Add VERIFY                           */
/* 08-05-2024  1.8    Dennis      UWP-19017 Add VERIFY                          */
/* 23-10-2024  1.9    Dennis      UWP-26096 Regardless of if editable,          */
/*                                call process sp                               */
/* 16-12-2024  2.0.0  NLT013      UWP-28462 Correct message id                  */
/********************************************************************************/

CREATE   PROCEDURE rdt.rdt_Lottable
   @nMobile          INT, 
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3), 
   @nScn             INT, 
   @nInputKey        INT, 
   @cStorerKey       NVARCHAR( 15),  
   @cSKU             NVARCHAR( 20),  
   @cLottableCode    NVARCHAR( 30), 
   @cScreenType      NVARCHAR( 15),  -- CAPTURE/PRECAPTURE/DISPLAY/VERIFY/FILTER
   @cAction          NVARCHAR( 10),  -- POPULATE/CHECK
   @nLottableOnPage  INT,            -- Number of lottables on a page
   @nStartOutField   INT,            -- First out field for lottable on page
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
   @nMorePage        INT           OUTPUT,
   @nErrNo           INT           OUTPUT, 
   @cErrMsg          NVARCHAR( 20) OUTPUT, 
   @cSourceKey       NVARCHAR( 15),
   @cSourceType      NVARCHAR( 20)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cLottable01Label NVARCHAR( 20)
   DECLARE @cLottable02Label NVARCHAR( 20)
   DECLARE @cLottable03Label NVARCHAR( 20)
   DECLARE @cLottable04Label NVARCHAR( 20)
   DECLARE @cLottable05Label NVARCHAR( 20)
   DECLARE @cLottable06Label NVARCHAR( 20)
   DECLARE @cLottable07Label NVARCHAR( 20)
   DECLARE @cLottable08Label NVARCHAR( 20)
   DECLARE @cLottable09Label NVARCHAR( 20)
   DECLARE @cLottable10Label NVARCHAR( 20)
   DECLARE @cLottable11Label NVARCHAR( 20)
   DECLARE @cLottable12Label NVARCHAR( 20)
   DECLARE @cLottable13Label NVARCHAR( 20)
   DECLARE @cLottable14Label NVARCHAR( 20)
   DECLARE @cLottable15Label NVARCHAR( 20)

   DECLARE @cLottable04 NVARCHAR( 20)
   DECLARE @cLottable05 NVARCHAR( 20)
   DECLARE @cLottable13 NVARCHAR( 20)
   DECLARE @cLottable14 NVARCHAR( 20)
   DECLARE @cLottable15 NVARCHAR( 20)   

   DECLARE @nRowCount   INT
   DECLARE @nCount      INT
   DECLARE @nLottableNo INT
   DECLARE @cVisible    NVARCHAR(1)
   DECLARE @cEditable   NVARCHAR(1)
   DECLARE @cRequired   NVARCHAR(1)
   DECLARE @cDesc       NVARCHAR(20)
   DECLARE @cLottable   NVARCHAR(60)
   DECLARE @cFieldAttr  NVARCHAR(1)
   DECLARE @cFormatSP   NVARCHAR(50)
   DECLARE @nSequence   INT
   DECLARE @nCursorPos  INT
   DECLARE @curLC       CURSOR

   DECLARE @nPOS        INT  
   DECLARE @nFirstSeq   INT  
   DECLARE @nLastSeq    INT
   DECLARE @nRemainInCurrentScreen INT
   DECLARE @cStorerConfig        NVARCHAR( 50),
           @dLotDate             DATETIME,
           @nLotNum              INT,
           @cLotValue            NVARCHAR( 30)


   -- Temp table for lottable
   DECLARE @tLC TABLE 
   (
      RowRef      INT           IDENTITY( 1,1), 
      LottableNo  INT           NOT NULL, 
      Visible     NVARCHAR(  1) NOT NULL, 
      Editable    NVARCHAR(  1) NOT NULL, 
      Required    NVARCHAR(  1) NOT NULL, 
      Sequence    INT           NOT NULL, 
      Description NVARCHAR( 20) NOT NULL, 
      FormatSP    NVARCHAR( 50) NOT NULL
   )

   -- If function specific lottablecode not setup, use generic one
   IF @nFunc > 0
      IF NOT EXISTS( SELECT TOP 1 1 
         FROM rdt.rdtLottableCode WITH (NOLOCK)
         WHERE LottableCode = @cLottableCode
            AND Function_ID = @nFunc
            AND StorerKey = @cStorerKey)
         SET @nFunc = 0


   /********************************************************************************************
   
                                                DISPLAY
                                                
   ********************************************************************************************/
   IF @cScreenType = 'DISPLAY'
   BEGIN
      DECLARE @nOutField INT
      SET @nOutField = @nStartOutField
      
      INSERT INTO @tLC (LottableNo, Visible, Editable, Required, Sequence, Description, FormatSP) 
      SELECT TOP (@nLottableOnPage)
         LottableNo, Visible, Editable, Required, Sequence, Description, FormatSP
      FROM rdt.rdtLottableCode WITH (NOLOCK)
      WHERE LottableCode = @cLottableCode
         AND Function_ID = @nFunc
         AND StorerKey = @cStorerKey
         AND Visible = '1'
      ORDER BY Sequence

      SET @curLC = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT LottableNo, Sequence
         FROM @tLC
         ORDER BY Sequence
      OPEN @curLC
      FETCH NEXT FROM @curLC INTO @nLottableNo, @nSequence
   
      -- Loop lottable position on screen (some could be blank)
      SET @nCount = 1
      WHILE @nCount <= @nLottableOnPage
      BEGIN
         -- Lottable available to show on this position
         IF @@FETCH_STATUS = 0
         BEGIN
            -- Get lottable
            IF @nLottableNo = 1  SELECT @cLottable = @cLottable01                     ELSE 
            IF @nLottableNo = 2  SELECT @cLottable = @cLottable02                     ELSE 
            IF @nLottableNo = 3  SELECT @cLottable = @cLottable03                     ELSE 
            IF @nLottableNo = 4  SELECT @cLottable = rdt.rdtFormatDate( @dLottable04) ELSE 
            IF @nLottableNo = 5  SELECT @cLottable = rdt.rdtFormatDate( @dLottable05) ELSE 
            IF @nLottableNo = 6  SELECT @cLottable = @cLottable06                     ELSE 
            IF @nLottableNo = 7  SELECT @cLottable = @cLottable07                     ELSE 
            IF @nLottableNo = 8  SELECT @cLottable = @cLottable08                     ELSE 
            IF @nLottableNo = 9  SELECT @cLottable = @cLottable09                     ELSE 
            IF @nLottableNo = 10 SELECT @cLottable = @cLottable10                     ELSE 
            IF @nLottableNo = 11 SELECT @cLottable = @cLottable11                     ELSE 
            IF @nLottableNo = 12 SELECT @cLottable = @cLottable12                     ELSE 
            IF @nLottableNo = 13 SELECT @cLottable = rdt.rdtFormatDate( @dLottable13) ELSE 
            IF @nLottableNo = 14 SELECT @cLottable = rdt.rdtFormatDate( @dLottable14) ELSE 
            IF @nLottableNo = 15 SELECT @cLottable = rdt.rdtFormatDate( @dLottable15)

            -- Format output
            SET @cLottable = RTRIM( CAST( @nLottableNo AS NVARCHAR(2))) + ' ' + @cLottable
         END
         ELSE
            -- No lottable for this position
            SELECT @cLottable = ''
         
         -- Output to screen
         IF @nOutField = 1  SELECT @cOutField01 = @cLottable ELSE 
         IF @nOutField = 2  SELECT @cOutField02 = @cLottable ELSE 
         IF @nOutField = 3  SELECT @cOutField03 = @cLottable ELSE 
         IF @nOutField = 4  SELECT @cOutField04 = @cLottable ELSE 
         IF @nOutField = 5  SELECT @cOutField05 = @cLottable ELSE 
         IF @nOutField = 6  SELECT @cOutField06 = @cLottable ELSE 
         IF @nOutField = 7  SELECT @cOutField07 = @cLottable ELSE 
         IF @nOutField = 8  SELECT @cOutField08 = @cLottable ELSE 
         IF @nOutField = 9  SELECT @cOutField09 = @cLottable ELSE 
         IF @nOutField = 10 SELECT @cOutField10 = @cLottable ELSE 
         IF @nOutField = 11 SELECT @cOutField11 = @cLottable ELSE 
         IF @nOutField = 12 SELECT @cOutField12 = @cLottable ELSE 
         IF @nOutField = 13 SELECT @cOutField13 = @cLottable ELSE 
         IF @nOutField = 14 SELECT @cOutField14 = @cLottable ELSE 
         IF @nOutField = 15 SELECT @cOutField15 = @cLottable
         
         SET @nOutField = @nOutField + 1
         SET @nCount = @nCount + 1
         FETCH NEXT FROM @curLC INTO @nLottableNo, @nSequence
      END
   END


   /********************************************************************************************
   
                                              PRECAPTURE
                                                
   ********************************************************************************************/
   IF @cScreenType = 'PRECAPTURE'
   BEGIN
      /********************************************************************************************
                                          Validate lottable (POST)
      ********************************************************************************************/
      IF @cAction = 'CHECK' AND  -- Validation
         @nInputKey = 1 AND      -- ENTER
         @nScn <> 3990           -- SKU/UCC screen
      BEGIN
         -- Get all dynamic lottable
         INSERT INTO @tLC (LottableNo, Visible, Editable, Required, Sequence, Description, FormatSP) 
         SELECT 
            LottableNo, Visible, Editable, Required, Sequence, Description, FormatSP
         FROM rdt.rdtLottableCode WITH (NOLOCK)
         WHERE LottableCode = @cLottableCode
            AND Function_ID = @nFunc
            AND StorerKey = @cStorerKey
         ORDER BY Sequence

         -- Dynamic lottable rule (POST)
         SET @nCount = 1
         SET @curLC = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT LottableNo, Sequence
            FROM @tLC
            ORDER BY Sequence
         OPEN @curLC
         FETCH NEXT FROM @curLC INTO @nLottableNo, @nSequence
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Get label, lottable
            IF @nLottableNo =  1 SELECT @cLottable = @cLottable01                     ELSE 
            IF @nLottableNo =  2 SELECT @cLottable = @cLottable02                     ELSE 
            IF @nLottableNo =  3 SELECT @cLottable = @cLottable03                     ELSE 
            IF @nLottableNo =  4 SELECT @cLottable = rdt.rdtFormatDate( @dLottable04) ELSE 
            IF @nLottableNo =  5 SELECT @cLottable = rdt.rdtFormatDate( @dLottable05) ELSE 
            IF @nLottableNo =  6 SELECT @cLottable = @cLottable06                     ELSE 
            IF @nLottableNo =  7 SELECT @cLottable = @cLottable07                     ELSE 
            IF @nLottableNo =  8 SELECT @cLottable = @cLottable08                     ELSE 
            IF @nLottableNo =  9 SELECT @cLottable = @cLottable09                     ELSE 
            IF @nLottableNo = 10 SELECT @cLottable = @cLottable10                     ELSE 
            IF @nLottableNo = 11 SELECT @cLottable = @cLottable11                     ELSE 
            IF @nLottableNo = 12 SELECT @cLottable = @cLottable12                     ELSE 
            IF @nLottableNo = 13 SELECT @cLottable = rdt.rdtFormatDate( @dLottable13) ELSE 
            IF @nLottableNo = 14 SELECT @cLottable = rdt.rdtFormatDate( @dLottable14) ELSE 
            IF @nLottableNo = 15 SELECT @cLottable = rdt.rdtFormatDate( @dLottable15)

            -- Dynamic lottable rule (POST)
            IF @nInputKey = 1  -- ENTER 
               EXEC rdt.rdt_Lottable_Rule @nMobile, @nFunc, @cLangCode, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, @nLottableNo, @cLottable, 'POST', 
                  @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT,  
                  @cLottable06 OUTPUT, @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT,  
                  @cLottable11 OUTPUT, @cLottable12 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT,
                  @nErrNo      OUTPUT, 
                  @cErrMsg     OUTPUT, 
                  @cSourceKey, 
                  @cSourceType

            IF @nErrNo <> 0
            BEGIN
               SET @nMorePage = 0
               GOTO Quit
            END
            
            SET @nCount = @nCount + 1
            FETCH NEXT FROM @curLC INTO @nLottableNo, @nSequence
         END 

         -- Dynamic lottable validate (for Required = 1)
         SET @nCount = 1
         SET @curLC = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT LottableNo, Sequence, Required
            FROM @tLC
            WHERE @cRequired = '1'
            ORDER BY Sequence
         OPEN @curLC
         FETCH NEXT FROM @curLC INTO @nLottableNo, @nSequence, @cRequired
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Get lottable
            IF @nLottableNo =  1 SELECT @cLottable = @cLottable01                     ELSE 
            IF @nLottableNo =  2 SELECT @cLottable = @cLottable02                     ELSE 
            IF @nLottableNo =  3 SELECT @cLottable = @cLottable03                     ELSE 
            IF @nLottableNo =  4 SELECT @cLottable = rdt.rdtFormatDate( @dLottable04) ELSE 
            IF @nLottableNo =  5 SELECT @cLottable = rdt.rdtFormatDate( @dLottable05) ELSE 
            IF @nLottableNo =  6 SELECT @cLottable = @cLottable06                     ELSE 
            IF @nLottableNo =  7 SELECT @cLottable = @cLottable07                     ELSE 
            IF @nLottableNo =  8 SELECT @cLottable = @cLottable08                     ELSE 
            IF @nLottableNo =  9 SELECT @cLottable = @cLottable09                     ELSE 
            IF @nLottableNo = 10 SELECT @cLottable = @cLottable10                     ELSE 
            IF @nLottableNo = 11 SELECT @cLottable = @cLottable11                     ELSE 
            IF @nLottableNo = 12 SELECT @cLottable = @cLottable12                     ELSE 
            IF @nLottableNo = 13 SELECT @cLottable = rdt.rdtFormatDate( @dLottable13) ELSE 
            IF @nLottableNo = 14 SELECT @cLottable = rdt.rdtFormatDate( @dLottable14) ELSE 
            IF @nLottableNo = 15 SELECT @cLottable = rdt.rdtFormatDate( @dLottable15)

            -- Check blank
            IF @cLottable = ''
            BEGIN
               SET @nErrNo = 92317
               SET @cErrMsg = RTRIM( rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')) + RIGHT( '0' + CAST( @nLottableNo AS NVARCHAR(2)), 2) --NeedLottable
               SET @nMorePage = 0
               GOTO Quit
            END

            -- Check date
            IF @nLottableNo IN (4, 5, 13, 14, 15) -- Date fields
            BEGIN
               -- Check valid date
               IF @cLottable <> '' AND rdt.rdtIsValidDate( @cLottable) = 0
               BEGIN
                  SET @nErrNo = 92318
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid date
                  SET @nMorePage = 0
                  GOTO Quit
               END
            END
            
            SET @nCount = @nCount + 1
            FETCH NEXT FROM @curLC INTO @nLottableNo, @nSequence, @cRequired
         END
         
         GOTO Quit
      END
      
      /********************************************************************************************
                                           Default lottable (PRE)
      ********************************************************************************************/      
      IF @cAction = 'POPULATE' AND  -- Going into lottable screen
         @nInputKey = 1 AND         -- ENTER
         @nScn <> 3990              -- Before lottable screen
      BEGIN
         -- First time need to go thru all lottables for possible PRE logic
         INSERT INTO @tLC (LottableNo, Visible, Editable, Required, Sequence, Description, FormatSP) 
         SELECT LottableNo, Visible, Editable, Required, Sequence, Description, FormatSP
         FROM rdt.rdtLottableCode WITH (NOLOCK)
         WHERE LottableCode = @cLottableCode
            AND Function_ID = @nFunc
            AND StorerKey = @cStorerKey
            AND ProcessSP <> '' -- PRECAPTURE's ProcessSP only define in RDT, not in Exceed
         ORDER BY Sequence
         
         IF @@ROWCOUNT > 0
         BEGIN
            -- Loop all lottable
            SET @curLC = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT LottableNo, Visible, Sequence
               FROM @tLC
               ORDER BY Sequence
            OPEN @curLC
            FETCH NEXT FROM @curLC INTO @nLottableNo, @cVisible, @nSequence
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- Get lottable
               IF @nLottableNo = 1  SELECT @cLottable = @cLottable01                     ELSE 
               IF @nLottableNo = 2  SELECT @cLottable = @cLottable02                     ELSE 
               IF @nLottableNo = 3  SELECT @cLottable = @cLottable03                     ELSE 
               IF @nLottableNo = 4  SELECT @cLottable = rdt.rdtFormatDate( @dLottable04) ELSE 
               IF @nLottableNo = 5  SELECT @cLottable = rdt.rdtFormatDate( @dLottable05) ELSE 
               IF @nLottableNo = 6  SELECT @cLottable = @cLottable06                     ELSE 
               IF @nLottableNo = 7  SELECT @cLottable = @cLottable07                     ELSE 
               IF @nLottableNo = 8  SELECT @cLottable = @cLottable08                     ELSE 
               IF @nLottableNo = 9  SELECT @cLottable = @cLottable09                     ELSE 
               IF @nLottableNo = 10 SELECT @cLottable = @cLottable10                     ELSE 
               IF @nLottableNo = 11 SELECT @cLottable = @cLottable11                     ELSE 
               IF @nLottableNo = 12 SELECT @cLottable = @cLottable12                     ELSE 
               IF @nLottableNo = 13 SELECT @cLottable = rdt.rdtFormatDate( @dLottable13) ELSE 
               IF @nLottableNo = 14 SELECT @cLottable = rdt.rdtFormatDate( @dLottable14) ELSE 
               IF @nLottableNo = 15 SELECT @cLottable = rdt.rdtFormatDate( @dLottable15)
      
               -- PRE is require when ENTER for next lottable. ESC for previous lottable don't need PRE
               IF @nInputKey = 1 
                  -- Dynamic lottable rule (PRE)
                  EXEC rdt.rdt_Lottable_Rule @nMobile, @nFunc, @cLangCode, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, @nLottableNo, @cLottable, 'PRE', 
                     @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT,  
                     @cLottable06 OUTPUT, @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT,  
                     @cLottable11 OUTPUT, @cLottable12 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT,
                     @nErrNo      OUTPUT, 
                     @cErrMsg     OUTPUT, 
                     @cSourceKey, 
                     @cSourceType
               
               -- Calc sequence of the page
               IF @cVisible = '1'
               BEGIN
                  SET @nLastSeq = @nSequence
                  IF @nFirstSeq IS NULL
                     SET @nFirstSeq = @nSequence
               END
               
               FETCH NEXT FROM @curLC INTO @nLottableNo, @cVisible, @nSequence
            END
   
            -- Clear dynamic lottable
            DELETE @tLC
         END
      END

      /********************************************************************************************
                                          Take-in lottable value
      ********************************************************************************************/
      -- Get lottable start, end sequence of the page
      IF @nScn = 3990
      BEGIN
         SET @nPOS = CHARINDEX( ',', @cOutField15)                                     -- Delimeter position
         SET @nFirstSeq = SUBSTRING( @cOutField15, 1, @nPOS-1)                         -- First lottable sequence of the page
         SET @nLastSeq = SUBSTRING( @cOutField15, @nPOS+1, LEN( @cOutField15) - @nPOS) -- Last lottable sequence of the page

         -- Take-in PRE value
         IF @cAction = 'CHECK' AND @nInputKey = 1 -- ENTER
         BEGIN
            -- Get the dynamic lottable in the sequence range
            INSERT INTO @tLC (LottableNo, Visible, Editable, Required, Sequence, Description, FormatSP) 
            SELECT TOP 5
               LottableNo, Visible, Editable, Required, Sequence, Description, FormatSP
            FROM rdt.rdtLottableCode WITH (NOLOCK)
            WHERE LottableCode = @cLottableCode
               AND Function_ID = @nFunc
               AND StorerKey = @cStorerKey
               AND Visible = '1'
               AND Sequence BETWEEN @nFirstSeq AND @nLastSeq
            ORDER BY Sequence
   
            -- Get dynamic lottable input
            SET @nCount = 1
            SET @nRemainInCurrentScreen = 0
            SET @curLC = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT LottableNo, Sequence, FormatSP
               FROM @tLC
               ORDER BY Sequence
            OPEN @curLC
            FETCH NEXT FROM @curLC INTO @nLottableNo, @nSequence, @cFormatSP
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- Get input value
               IF @nCount = 1 SELECT @cLottable = CASE WHEN @cFieldAttr02 = '' THEN @cInField02 ELSE @cOutField02 END ELSE 
               IF @nCount = 2 SELECT @cLottable = CASE WHEN @cFieldAttr04 = '' THEN @cInField04 ELSE @cOutField04 END ELSE 
               IF @nCount = 3 SELECT @cLottable = CASE WHEN @cFieldAttr06 = '' THEN @cInField06 ELSE @cOutField06 END ELSE 
               IF @nCount = 4 SELECT @cLottable = CASE WHEN @cFieldAttr08 = '' THEN @cInField08 ELSE @cOutField08 END ELSE 
               IF @nCount = 5 SELECT @cLottable = CASE WHEN @cFieldAttr10 = '' THEN @cInField10 ELSE @cOutField10 END 

               IF @cFormatSP <> ''
               BEGIN
                  EXEC rdt.rdt_Lottable_Format @nMobile, @nFunc, @cLangCode, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, @nLottableNo, @cFormatSP, 
                     @cLottable  OUTPUT, 
                     @nErrNo     OUTPUT, 
                     @cErrMsg    OUTPUT

                  IF @nErrNo <> 0
                  BEGIN
                     SET @nCursorPos = @nCount * 2
                     EXEC rdt.rdtSetFocusField @nMobile, @nCursorPos
                        
                     IF @nErrNo = -1  -- Remain in current screen
                     BEGIN
                        SET @nErrNo = 0
                        SET @nRemainInCurrentScreen = 1
                     END
                     ELSE
                     BEGIN
                        SET @nMorePage = 0
                        GOTO CAPTURE_Quit
                     END
                  END
               END
               
               -- Set to respective lottable
               IF @nLottableNo =  1 SELECT @cLottable01 = @cLottable ELSE 
               IF @nLottableNo =  2 SELECT @cLottable02 = @cLottable ELSE 
               IF @nLottableNo =  3 SELECT @cLottable03 = @cLottable ELSE 
               IF @nLottableNo =  4 SELECT @cLottable04 = @cLottable ELSE 
               IF @nLottableNo =  5 SELECT @cLottable05 = @cLottable ELSE 
               IF @nLottableNo =  6 SELECT @cLottable06 = @cLottable ELSE 
               IF @nLottableNo =  7 SELECT @cLottable07 = @cLottable ELSE 
               IF @nLottableNo =  8 SELECT @cLottable08 = @cLottable ELSE 
               IF @nLottableNo =  9 SELECT @cLottable09 = @cLottable ELSE 
               IF @nLottableNo = 10 SELECT @cLottable10 = @cLottable ELSE 
               IF @nLottableNo = 11 SELECT @cLottable11 = @cLottable ELSE 
               IF @nLottableNo = 12 SELECT @cLottable12 = @cLottable ELSE 
               IF @nLottableNo = 13 SELECT @cLottable13 = @cLottable ELSE 
               IF @nLottableNo = 14 SELECT @cLottable14 = @cLottable ELSE 
               IF @nLottableNo = 15 SELECT @cLottable15 = @cLottable
   
               IF @nLottableNo IN (4, 5, 13, 14, 15)
               BEGIN
                  IF @cLottable <> '' AND RDT.rdtIsValidDate( @cLottable) = 0
                  BEGIN
                     SET @nErrNo = 92320
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Date
                     SET @nCursorPos = @nCount * 2
                     EXEC rdt.rdtSetFocusField @nMobile, @nCursorPos
                        
                     SET @nMorePage = 0
                     GOTO CAPTURE_Quit
                  END
                  
                  IF @nLottableNo =  4 SET @dLottable04 = rdt.rdtConvertToDate( @cLottable) ELSE 
                  IF @nLottableNo =  5 SET @dLottable05 = rdt.rdtConvertToDate( @cLottable) ELSE 
                  IF @nLottableNo = 13 SET @dLottable13 = rdt.rdtConvertToDate( @cLottable) ELSE 
                  IF @nLottableNo = 14 SET @dLottable14 = rdt.rdtConvertToDate( @cLottable) ELSE 
                  IF @nLottableNo = 15 SET @dLottable15 = rdt.rdtConvertToDate( @cLottable)
               END
               
               SET @nCount = @nCount + 1
               FETCH NEXT FROM @curLC INTO @nLottableNo, @nSequence, @cFormatSP
            END
            IF @nRemainInCurrentScreen = 1
            BEGIN
               SET @nErrNo = -1
               SET @nMorePage = 0
               GOTO CAPTURE_Quit
            END  

            -- Clear dynamic lottable
            DELETE @tLC
         END
      END

      /********************************************************************************************
                                             Get next lottable
      ********************************************************************************************/
      IF @cAction = 'CHECK'
      BEGIN
         -- Insert lottable to show
         IF @nInputKey = 1 -- ENTER
            INSERT INTO @tLC (LottableNo, Visible, Editable, Required, Sequence, Description, FormatSP) 
            SELECT TOP 5 
               LottableNo, Visible, Editable, Required, Sequence, Description, FormatSP
            FROM rdt.rdtLottableCode WITH (NOLOCK)
            WHERE LottableCode = @cLottableCode
               AND Function_ID = @nFunc
               AND StorerKey = @cStorerKey
               AND Visible = '1'
               AND Sequence > @nLastSeq
            ORDER BY Sequence
         ELSE
            INSERT INTO @tLC (LottableNo, Visible, Editable, Required, Sequence, Description, FormatSP) 
            SELECT TOP 5
               LottableNo, Visible, Editable, Required, Sequence, Description, FormatSP
            FROM rdt.rdtLottableCode WITH (NOLOCK)
            WHERE LottableCode = @cLottableCode
               AND Function_ID = @nFunc
               AND StorerKey = @cStorerKey
               AND Visible = '1'
               AND Sequence < @nFirstSeq
            ORDER BY Sequence DESC
      END
   
      IF @cAction = 'POPULATE'
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            INSERT INTO @tLC (LottableNo, Visible, Editable, Required, Sequence, Description, FormatSP) 
            SELECT TOP 5
               LottableNo, Visible, Editable, Required, Sequence, Description, FormatSP
            FROM rdt.rdtLottableCode WITH (NOLOCK)
            WHERE LottableCode = @cLottableCode
               AND Function_ID = @nFunc
               AND StorerKey = @cStorerKey
               AND Visible = '1'
            ORDER BY Sequence
         END
         ELSE
         BEGIN
            IF @nScn = 3990
               INSERT INTO @tLC (LottableNo, Visible, Editable, Required, Sequence, Description, FormatSP) 
               SELECT TOP 5
                  LottableNo, Visible, Editable, Required, Sequence, Description, FormatSP
               FROM rdt.rdtLottableCode WITH (NOLOCK)
               WHERE LottableCode = @cLottableCode
                  AND Function_ID = @nFunc
                  AND StorerKey = @cStorerKey
                  AND Visible = '1'
                  AND Sequence < @nFirstSeq
               ORDER BY Sequence DESC
            ELSE
            BEGIN
               INSERT INTO @tLC (LottableNo, Visible, Editable, Required, Sequence, Description, FormatSP) 
               SELECT LottableNo, Visible, Editable, Required, Sequence, Description, FormatSP
               FROM rdt.rdtLottableCode WITH (NOLOCK)
               WHERE LottableCode = @cLottableCode
                  AND Function_ID = @nFunc
                  AND StorerKey = @cStorerKey
                  AND Visible = '1'
               ORDER BY Sequence
               SET @nRowCount = @@ROWCOUNT
   
               -- Multi pages
               WHILE @nRowCount > 5
               BEGIN
                  -- Delete lottable page except for last page
                  DELETE @tLC WHERE RowRef IN (SELECT TOP 5 RowRef FROM @tLC ORDER BY Sequence)
                  SELECT @nRowCount = COUNT(1) FROM @tLC
               END
            END
         END
      END

      /********************************************************************************************
                                             Show next lottable 
      ********************************************************************************************/
      IF NOT EXISTS( SELECT TOP 1 1 FROM @tLC)
      BEGIN
         -- Lottable screen that had previously written hidden field
         IF @nScn = 3990
            SET @cOutField15 = '' -- Clear hidden field 
            
         SET @nMorePage = 0 -- No more dynamic lottable page
         GOTO Quit -- Nothing to show
      END
      ELSE         
      BEGIN
         SET @nFirstSeq = NULL
         SET @curLC = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT LottableNo, Sequence, Editable, Description
            FROM @tLC
            ORDER BY Sequence
         OPEN @curLC
         FETCH NEXT FROM @curLC INTO @nLottableNo, @nSequence, @cEditable, @cDesc
      
         -- Loop 5 lottable position on screen (some could be blank)
         SET @nCursorPos = 0
         SET @nCount = 1
         WHILE @nCount <= 5
         BEGIN
            -- Lottable available to show on this position
            IF @@FETCH_STATUS = 0
            BEGIN
               -- Get lottable
               IF @nLottableNo = 1  SELECT @cLottable = @cLottable01                     ELSE 
               IF @nLottableNo = 2  SELECT @cLottable = @cLottable02                     ELSE 
               IF @nLottableNo = 3  SELECT @cLottable = @cLottable03                     ELSE 
               IF @nLottableNo = 4  SELECT @cLottable = rdt.rdtFormatDate( @dLottable04) ELSE 
               IF @nLottableNo = 5  SELECT @cLottable = rdt.rdtFormatDate( @dLottable05) ELSE 
               IF @nLottableNo = 6  SELECT @cLottable = @cLottable06                     ELSE 
               IF @nLottableNo = 7  SELECT @cLottable = @cLottable07                     ELSE 
               IF @nLottableNo = 8  SELECT @cLottable = @cLottable08                     ELSE 
               IF @nLottableNo = 9  SELECT @cLottable = @cLottable09                     ELSE 
               IF @nLottableNo = 10 SELECT @cLottable = @cLottable10                     ELSE 
               IF @nLottableNo = 11 SELECT @cLottable = @cLottable11                     ELSE 
               IF @nLottableNo = 12 SELECT @cLottable = @cLottable12                     ELSE 
               IF @nLottableNo = 13 SELECT @cLottable = rdt.rdtFormatDate( @dLottable13) ELSE 
               IF @nLottableNo = 14 SELECT @cLottable = rdt.rdtFormatDate( @dLottable14) ELSE 
               IF @nLottableNo = 15 SELECT @cLottable = rdt.rdtFormatDate( @dLottable15)
   
               -- Enable / disable field
               IF @cEditable = '1' 
                  SET @cFieldAttr = '' 
               ELSE 
                  SET @cFieldAttr = 'O'
                  
               IF @nFirstSeq IS NULL
                  SET @nFirstSeq = @nSequence
               SET @nLastSeq = @nSequence
            END
            ELSE
               -- No lottable for this position
               SELECT @cDesc = '', @cLottable = '', @cFieldAttr = 'O'
            
            -- Output to screen
            IF @nCount = 1 SELECT @cOutField01 = @cDesc, @cOutField02 = @cLottable, @cInField02 = @cLottable, @cFieldAttr02 = @cFieldAttr ELSE 
            IF @nCount = 2 SELECT @cOutField03 = @cDesc, @cOutField04 = @cLottable, @cInField04 = @cLottable, @cFieldAttr04 = @cFieldAttr ELSE 
            IF @nCount = 3 SELECT @cOutField05 = @cDesc, @cOutField06 = @cLottable, @cInField06 = @cLottable, @cFieldAttr06 = @cFieldAttr ELSE 
            IF @nCount = 4 SELECT @cOutField07 = @cDesc, @cOutField08 = @cLottable, @cInField08 = @cLottable, @cFieldAttr08 = @cFieldAttr ELSE 
            IF @nCount = 5 SELECT @cOutField09 = @cDesc, @cOutField10 = @cLottable, @cInField10 = @cLottable, @cFieldAttr10 = @cFieldAttr
   
            -- Calc cursor position
            IF @nCursorPos = 0                           -- Not save before
               IF @cFieldAttr = '' AND @cLottable = ''   -- Lottable enable with blank value
                  SET @nCursorPos = @nCount * 2
            
            SET @nCount = @nCount + 1
            FETCH NEXT FROM @curLC INTO @nLottableNo, @nSequence, @cEditable, @cDesc
         END
   
         -- Position cursor
         IF @nCursorPos <> 0
            EXEC rdt.rdtSetFocusField @nMobile, @nCursorPos

         -- Save sequence range of the page into hidden field
         SET @cOutField15 = CAST( @nFirstSeq AS NVARCHAR(2)) + ',' + CAST( @nLastSeq AS NVARCHAR(2))

         SET @nMorePage = 1 -- Next dynamic lottable page
      END
   END


   /********************************************************************************************
   
                                                CAPTURE
                                                
   ********************************************************************************************/
   IF @cScreenType = 'CAPTURE'
   BEGIN
      -- Get lottable start, end sequence of the page
      IF @nScn = 3990
      BEGIN
         SET @nPOS = CHARINDEX( ',', @cOutField15)                                     -- Delimeter position
         SET @nFirstSeq = SUBSTRING( @cOutField15, 1, @nPOS-1)                         -- First lottable sequence of the page
         SET @nLastSeq = SUBSTRING( @cOutField15, @nPOS+1, LEN( @cOutField15) - @nPOS) -- Last lottable sequence of the page
      END

      /********************************************************************************************
                                          Validate lottable (POST)
      ********************************************************************************************/
      IF @cAction = 'CHECK'
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Get the dynamic lottable in the sequence range
            INSERT INTO @tLC (LottableNo, Visible, Editable, Required, Sequence, Description, FormatSP) 
            SELECT TOP 5
               LottableNo, Visible, Editable, Required, Sequence, Description, FormatSP
            FROM rdt.rdtLottableCode WITH (NOLOCK)
            WHERE LottableCode = @cLottableCode
               AND Function_ID = @nFunc
               AND StorerKey = @cStorerKey
               AND Visible = '1'
               AND Sequence BETWEEN @nFirstSeq AND @nLastSeq
            ORDER BY Sequence
   
            -- Get dynamic lottable input
            SET @nCount = 1
            SET @curLC = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT LottableNo, Sequence, FormatSP
               FROM @tLC
               ORDER BY Sequence
            OPEN @curLC
            FETCH NEXT FROM @curLC INTO @nLottableNo, @nSequence, @cFormatSP
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- Get input value
               IF @nCount = 1 SELECT @cLottable = CASE WHEN @cFieldAttr02 = '' THEN @cInField02 ELSE @cOutField02 END ELSE 
               IF @nCount = 2 SELECT @cLottable = CASE WHEN @cFieldAttr04 = '' THEN @cInField04 ELSE @cOutField04 END ELSE 
               IF @nCount = 3 SELECT @cLottable = CASE WHEN @cFieldAttr06 = '' THEN @cInField06 ELSE @cOutField06 END ELSE 
               IF @nCount = 4 SELECT @cLottable = CASE WHEN @cFieldAttr08 = '' THEN @cInField08 ELSE @cOutField08 END ELSE 
               IF @nCount = 5 SELECT @cLottable = CASE WHEN @cFieldAttr10 = '' THEN @cInField10 ELSE @cOutField10 END 

               IF @cFormatSP <> ''
               BEGIN
                  EXEC rdt.rdt_Lottable_Format @nMobile, @nFunc, @cLangCode, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, @nLottableNo, @cFormatSP, 
                     @cLottable  OUTPUT, 
                     @nErrNo     OUTPUT, 
                     @cErrMsg    OUTPUT

                  IF @nErrNo <> 0
                  BEGIN
                     SET @nCursorPos = @nCount * 2
                     EXEC rdt.rdtSetFocusField @nMobile, @nCursorPos
                        
                     SET @nMorePage = 0
                     GOTO CAPTURE_Quit
                  END
               END
               
               -- Set to respective lottable
               IF @nLottableNo =  1 SELECT @cLottable01 = @cLottable ELSE 
               IF @nLottableNo =  2 SELECT @cLottable02 = @cLottable ELSE 
               IF @nLottableNo =  3 SELECT @cLottable03 = @cLottable ELSE 
               IF @nLottableNo =  4 SELECT @cLottable04 = @cLottable ELSE 
               IF @nLottableNo =  5 SELECT @cLottable05 = @cLottable ELSE 
               IF @nLottableNo =  6 SELECT @cLottable06 = @cLottable ELSE 
               IF @nLottableNo =  7 SELECT @cLottable07 = @cLottable ELSE 
               IF @nLottableNo =  8 SELECT @cLottable08 = @cLottable ELSE 
               IF @nLottableNo =  9 SELECT @cLottable09 = @cLottable ELSE 
               IF @nLottableNo = 10 SELECT @cLottable10 = @cLottable ELSE 
               IF @nLottableNo = 11 SELECT @cLottable11 = @cLottable ELSE 
               IF @nLottableNo = 12 SELECT @cLottable12 = @cLottable ELSE 
               IF @nLottableNo = 13 SELECT @cLottable13 = @cLottable ELSE 
               IF @nLottableNo = 14 SELECT @cLottable14 = @cLottable ELSE 
               IF @nLottableNo = 15 SELECT @cLottable15 = @cLottable
   
               IF @nLottableNo IN (4, 5, 13, 14, 15)
               BEGIN
                  IF @cLottable <> '' AND RDT.rdtIsValidDate( @cLottable) = 0
                  BEGIN
                     SET @nErrNo = 92316
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Date
                     SET @nCursorPos = @nCount * 2
                     EXEC rdt.rdtSetFocusField @nMobile, @nCursorPos
                        
                     SET @nMorePage = 0
                     GOTO CAPTURE_Quit
                  END
                  
                  IF @nLottableNo =  4 SET @dLottable04 = rdt.rdtConvertToDate( @cLottable) ELSE 
                  IF @nLottableNo =  5 SET @dLottable05 = rdt.rdtConvertToDate( @cLottable) ELSE 
                  IF @nLottableNo = 13 SET @dLottable13 = rdt.rdtConvertToDate( @cLottable) ELSE 
                  IF @nLottableNo = 14 SET @dLottable14 = rdt.rdtConvertToDate( @cLottable) ELSE 
                  IF @nLottableNo = 15 SET @dLottable15 = rdt.rdtConvertToDate( @cLottable)
                  SET @cStorerConfig = ISNULL(rdt.RDTGetConfig( @nFunc, 'NoFutureDateLottable', @cStorerKey),'')
                  IF @cStorerConfig != ''
                  BEGIN
                     DECLARE LIST CURSOR FOR 
                     SELECT TRY_CAST(value AS INT) FROM STRING_SPLIT(@cStorerConfig, ',')
                     OPEN LIST
                     FETCH NEXT FROM LIST INTO @nLotNum
                     WHILE @@FETCH_STATUS = 0
                     BEGIN
                        IF @nLotNum = @nLottableNo
                        BEGIN
                           SET @dLotDate = CASE
                                    WHEN @nLotNum = 4  THEN @dLottable04  WHEN @nLotNum = 5 THEN @dLottable05
                                    WHEN @nLotNum = 13 THEN @dLottable13 WHEN @nLotNum = 14 THEN @dLottable14
                                    WHEN @nLotNum = 15 THEN @dLottable15
                                    END 
                           SET @cLotValue = rdt.rdtFormatDate(@dLotDate)
                           IF ISNULL(@cLotValue,'') = '' OR (@cLotValue <> '' AND rdt.rdtIsValidDate( @cLotValue) = 0)
                           BEGIN
                              GOTO CLOSELIST
                           END
                           IF @dLotDate >= DATEADD(DAY, 0, DATEDIFF(DAY, -1, GETDATE()))
                           BEGIN
                              SET @nErrNo = 92321
                              SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Date Required To BeBefore Than Today
                              SET @nCursorPos = @nCount * 2
                              EXEC rdt.rdtSetFocusField @nMobile, @nCursorPos
                              SET @nMorePage = 0
                              CLOSE LIST
                              DEALLOCATE LIST
                              GOTO CAPTURE_Quit
                           END
                        END
                        FETCH NEXT FROM LIST INTO @nLotNum
                     END
                     GOTO CLOSELIST
                     CLOSELIST:
                        CLOSE LIST
                        DEALLOCATE LIST
                  END
               END
               
               SET @nCount = @nCount + 1
               FETCH NEXT FROM @curLC INTO @nLottableNo, @nSequence, @cFormatSP
            END

            -- Dynamic lottable rule (POST)
            SET @nRemainInCurrentScreen = 0
            SET @nCount = 1
            SET @curLC = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT LottableNo, Sequence
               FROM @tLC
               ORDER BY Sequence
            OPEN @curLC
            FETCH NEXT FROM @curLC INTO @nLottableNo, @nSequence
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- Get field attribute value
               IF @nCount = 1 SELECT @cFieldAttr = @cFieldAttr02 ELSE 
               IF @nCount = 2 SELECT @cFieldAttr = @cFieldAttr04 ELSE 
               IF @nCount = 3 SELECT @cFieldAttr = @cFieldAttr06 ELSE 
               IF @nCount = 4 SELECT @cFieldAttr = @cFieldAttr08 ELSE 
               IF @nCount = 5 SELECT @cFieldAttr = @cFieldAttr10
               
               -- Get label, lottable
               IF @nLottableNo =  1 SELECT @cLottable = @cLottable01                     ELSE 
               IF @nLottableNo =  2 SELECT @cLottable = @cLottable02                     ELSE 
               IF @nLottableNo =  3 SELECT @cLottable = @cLottable03                     ELSE 
               IF @nLottableNo =  4 SELECT @cLottable = rdt.rdtFormatDate( @dLottable04) ELSE 
               IF @nLottableNo =  5 SELECT @cLottable = rdt.rdtFormatDate( @dLottable05) ELSE 
               IF @nLottableNo =  6 SELECT @cLottable = @cLottable06                     ELSE 
               IF @nLottableNo =  7 SELECT @cLottable = @cLottable07                     ELSE 
               IF @nLottableNo =  8 SELECT @cLottable = @cLottable08                     ELSE 
               IF @nLottableNo =  9 SELECT @cLottable = @cLottable09                     ELSE 
               IF @nLottableNo = 10 SELECT @cLottable = @cLottable10                     ELSE 
               IF @nLottableNo = 11 SELECT @cLottable = @cLottable11                     ELSE 
               IF @nLottableNo = 12 SELECT @cLottable = @cLottable12                     ELSE 
               IF @nLottableNo = 13 SELECT @cLottable = rdt.rdtFormatDate( @dLottable13) ELSE 
               IF @nLottableNo = 14 SELECT @cLottable = rdt.rdtFormatDate( @dLottable14) ELSE 
               IF @nLottableNo = 15 SELECT @cLottable = rdt.rdtFormatDate( @dLottable15)
   
               -- Dynamic lottable rule (POST)
               IF @nInputKey = 1 AND (@cFieldAttr = '' OR ISNULL(rdt.RDTGetConfig( @nFunc, 'LotIgnoreIfEditable', @cStorerKey),'') = '1') -- ENTER and enable or Config is open
                  EXEC rdt.rdt_Lottable_Rule @nMobile, @nFunc, @cLangCode, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, @nLottableNo, @cLottable, 'POST', 
                     @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT,  
                     @cLottable06 OUTPUT, @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT,  
                     @cLottable11 OUTPUT, @cLottable12 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT,
                     @nErrNo      OUTPUT, 
                     @cErrMsg     OUTPUT, 
                     @cSourceKey, 
                     @cSourceType

               IF @nErrNo <> 0
               BEGIN
                  SET @nCursorPos = @nCount * 2
                  EXEC rdt.rdtSetFocusField @nMobile, @nCursorPos
                     
                  IF @nErrNo = -1  -- Remain in current screen
                  BEGIN
                     SET @nErrNo = 0
                     SET @nRemainInCurrentScreen = 1
                  END
                  ELSE
                  BEGIN
                     SET @nMorePage = 0
                     GOTO CAPTURE_Quit
                  END
               END
               
               SET @nCount = @nCount + 1
               FETCH NEXT FROM @curLC INTO @nLottableNo, @nSequence
            END
            IF @nRemainInCurrentScreen = 1
            BEGIN
               SET @nErrNo = -1
               SET @nMorePage = 0
               GOTO CAPTURE_Quit
            END  

            -- Dynamic lottable validate (for the page)
            SET @nCount = 1
            SET @curLC = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT LottableNo, Sequence, Required
               FROM @tLC
               ORDER BY Sequence
            OPEN @curLC
            FETCH NEXT FROM @curLC INTO @nLottableNo, @nSequence, @cRequired
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- Get lottable
               IF @nLottableNo =  1 SELECT @cLottable = @cLottable01                     ELSE 
               IF @nLottableNo =  2 SELECT @cLottable = @cLottable02                     ELSE 
               IF @nLottableNo =  3 SELECT @cLottable = @cLottable03                     ELSE 
               IF @nLottableNo =  4 SELECT @cLottable = rdt.rdtFormatDate( @dLottable04) ELSE 
               IF @nLottableNo =  5 SELECT @cLottable = rdt.rdtFormatDate( @dLottable05) ELSE 
               IF @nLottableNo =  6 SELECT @cLottable = @cLottable06                     ELSE 
               IF @nLottableNo =  7 SELECT @cLottable = @cLottable07                     ELSE 
               IF @nLottableNo =  8 SELECT @cLottable = @cLottable08                     ELSE 
               IF @nLottableNo =  9 SELECT @cLottable = @cLottable09                     ELSE 
               IF @nLottableNo = 10 SELECT @cLottable = @cLottable10                     ELSE 
               IF @nLottableNo = 11 SELECT @cLottable = @cLottable11                     ELSE 
               IF @nLottableNo = 12 SELECT @cLottable = @cLottable12                     ELSE 
               IF @nLottableNo = 13 SELECT @cLottable = rdt.rdtFormatDate( @dLottable13) ELSE 
               IF @nLottableNo = 14 SELECT @cLottable = rdt.rdtFormatDate( @dLottable14) ELSE 
               IF @nLottableNo = 15 SELECT @cLottable = rdt.rdtFormatDate( @dLottable15)
   
               -- Check blank
               IF @cLottable = '' AND @cRequired = '1'
               BEGIN
                  SET @nErrNo = 92325
                  SET @cErrMsg = RTRIM( rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')) + RIGHT( '0' + CAST( @nLottableNo AS NVARCHAR(2)), 2) --NeedLottable
                  SET @nCursorPos = @nCount * 2
                  EXEC rdt.rdtSetFocusField @nMobile, @nCursorPos
                  SET @nMorePage = 0
                  GOTO CAPTURE_Quit
               END
   
               -- Check date
               IF @nLottableNo IN (4, 5, 13, 14, 15) -- Date fields
               BEGIN
                  -- Check valid date
                  IF @cLottable <> '' AND rdt.rdtIsValidDate( @cLottable) = 0
                  BEGIN
                     SET @nErrNo = 92322
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid date
                     SET @nCursorPos = @nCount * 2
                     EXEC rdt.rdtSetFocusField @nMobile, @nCursorPos
                     SET @nMorePage = 0
                     GOTO CAPTURE_Quit
                  END
               END
               
               SET @nCount = @nCount + 1
               FETCH NEXT FROM @curLC INTO @nLottableNo, @nSequence, @cRequired
            END
         END
      END
      
      /********************************************************************************************
                                             Get next lottable
      ********************************************************************************************/
      -- Clear dynamic lottable
      DELETE @tLC
      
      IF @cAction = 'CHECK'
      BEGIN         
         -- Insert lottable to show
         IF @nInputKey = 1 -- ENTER
            INSERT INTO @tLC (LottableNo, Visible, Editable, Required, Sequence, Description, FormatSP) 
            SELECT TOP 5 
               LottableNo, Visible, Editable, Required, Sequence, Description, FormatSP
            FROM rdt.rdtLottableCode WITH (NOLOCK)
            WHERE LottableCode = @cLottableCode
               AND Function_ID = @nFunc
               AND StorerKey = @cStorerKey
               AND Visible = '1'
               AND Sequence > @nLastSeq
            ORDER BY Sequence
         ELSE
            INSERT INTO @tLC (LottableNo, Visible, Editable, Required, Sequence, Description, FormatSP) 
            SELECT TOP 5
               LottableNo, Visible, Editable, Required, Sequence, Description, FormatSP
            FROM rdt.rdtLottableCode WITH (NOLOCK)
            WHERE LottableCode = @cLottableCode
               AND Function_ID = @nFunc
               AND StorerKey = @cStorerKey
               AND Visible = '1'
               AND Sequence < @nFirstSeq
            ORDER BY Sequence DESC
      END
   
      IF @cAction = 'POPULATE'
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            INSERT INTO @tLC (LottableNo, Visible, Editable, Required, Sequence, Description, FormatSP) 
            SELECT TOP 5
               LottableNo, Visible, Editable, Required, Sequence, Description, FormatSP
            FROM rdt.rdtLottableCode WITH (NOLOCK)
            WHERE LottableCode = @cLottableCode
               AND Function_ID = @nFunc
               AND StorerKey = @cStorerKey
               AND Visible = '1'
            ORDER BY Sequence

            -- Include not visible but required, for possible PRE logic
            INSERT INTO @tLC (LottableNo, Visible, Editable, Required, Sequence, Description, FormatSP) 
            SELECT LottableNo, Visible, Editable, Required, Sequence, Description, FormatSP
            FROM rdt.rdtLottableCode WITH (NOLOCK)
            WHERE LottableCode = @cLottableCode
               AND Function_ID = @nFunc
               AND StorerKey = @cStorerKey
               AND Visible = '0'
               -- AND Required = '1'
            ORDER BY Sequence            
         END
         ELSE
         BEGIN
            IF @nScn = 3990
               INSERT INTO @tLC (LottableNo, Visible, Editable, Required, Sequence, Description, FormatSP) 
               SELECT TOP 5
                  LottableNo, Visible, Editable, Required, Sequence, Description, FormatSP
               FROM rdt.rdtLottableCode WITH (NOLOCK)
               WHERE LottableCode = @cLottableCode
                  AND Function_ID = @nFunc
                  AND StorerKey = @cStorerKey
                  AND Visible = '1'
                  AND Sequence < @nFirstSeq
               ORDER BY Sequence DESC
            ELSE
            BEGIN
               INSERT INTO @tLC (LottableNo, Visible, Editable, Required, Sequence, Description, FormatSP) 
               SELECT LottableNo, Visible, Editable, Required, Sequence, Description, FormatSP
               FROM rdt.rdtLottableCode WITH (NOLOCK)
               WHERE LottableCode = @cLottableCode
                  AND Function_ID = @nFunc
                  AND StorerKey = @cStorerKey
                  AND Visible = '1'
               ORDER BY Sequence
               SET @nRowCount = @@ROWCOUNT
   
               -- Multi pages
               WHILE @nRowCount > 5
               BEGIN
                  -- Delete lottable page except for last page
                  DELETE @tLC WHERE RowRef IN (SELECT TOP 5 RowRef FROM @tLC ORDER BY Sequence)
                  SELECT @nRowCount = COUNT(1) FROM @tLC
               END
            END
         END
      END
      
      /********************************************************************************************
                                          Process next lottable (PRE)
      ********************************************************************************************/      
      SET @nFirstSeq = NULL

      -- Loop next lottable
      SET @curLC = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT LottableNo, Sequence, Visible
         FROM @tLC
         ORDER BY Sequence
      OPEN @curLC
      FETCH NEXT FROM @curLC INTO @nLottableNo, @nSequence, @cVisible
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Get lottable
         IF @nLottableNo = 1  SELECT @cLottable = @cLottable01                     ELSE 
         IF @nLottableNo = 2  SELECT @cLottable = @cLottable02                     ELSE 
         IF @nLottableNo = 3  SELECT @cLottable = @cLottable03                     ELSE 
         IF @nLottableNo = 4  SELECT @cLottable = rdt.rdtFormatDate( @dLottable04) ELSE 
         IF @nLottableNo = 5  SELECT @cLottable = rdt.rdtFormatDate( @dLottable05) ELSE 
         IF @nLottableNo = 6  SELECT @cLottable = @cLottable06                     ELSE 
         IF @nLottableNo = 7  SELECT @cLottable = @cLottable07                     ELSE 
         IF @nLottableNo = 8  SELECT @cLottable = @cLottable08                     ELSE 
         IF @nLottableNo = 9  SELECT @cLottable = @cLottable09                     ELSE 
         IF @nLottableNo = 10 SELECT @cLottable = @cLottable10                     ELSE 
         IF @nLottableNo = 11 SELECT @cLottable = @cLottable11                     ELSE 
         IF @nLottableNo = 12 SELECT @cLottable = @cLottable12                     ELSE 
         IF @nLottableNo = 13 SELECT @cLottable = rdt.rdtFormatDate( @dLottable13) ELSE 
         IF @nLottableNo = 14 SELECT @cLottable = rdt.rdtFormatDate( @dLottable14) ELSE 
         IF @nLottableNo = 15 SELECT @cLottable = rdt.rdtFormatDate( @dLottable15)

         -- PRE is require when ENTER for next lottable. ESC for previous lottable don't need PRE
         IF @nInputKey = 1 
            -- Dynamic lottable rule (PRE)
            EXEC rdt.rdt_Lottable_Rule @nMobile, @nFunc, @cLangCode, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, @nLottableNo, @cLottable, 'PRE', 
               @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT,  
               @cLottable06 OUTPUT, @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT,  
               @cLottable11 OUTPUT, @cLottable12 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT,
               @nErrNo      OUTPUT, 
               @cErrMsg     OUTPUT, 
               @cSourceKey, 
               @cSourceType
         
         -- Calc sequence of the page
         IF @cVisible = '1'
            SET @nLastSeq = @nSequence
         IF @nFirstSeq IS NULL
            SET @nFirstSeq = @nSequence
         
         FETCH NEXT FROM @curLC INTO @nLottableNo, @nSequence, @cVisible
      END
      
      /********************************************************************************************
                                              Calculate next page
      ********************************************************************************************/      
      -- Calc page
      IF EXISTS( SELECT TOP 1 1 FROM @tLC WHERE Visible = '1')
      BEGIN
         -- Save sequence range of the page into hidden field
         SET @cOutField15 = CAST( @nFirstSeq AS NVARCHAR(2)) + ',' + CAST( @nLastSeq AS NVARCHAR(2))

         SET @nMorePage = 1 -- Next dynamic lottable page
      END
      ELSE
      BEGIN
         -- Lottable screen that had previously written hidden field
         IF @nScn = 3990
            SET @cOutField15 = '' -- Clear hidden field 
         
         SET @nMorePage = 0 -- No more dynamic lottable page
      END
      
      IF @nMorePage = 0
      BEGIN
         IF @cAction = 'CHECK'
         BEGIN
            IF EXISTS( SELECT TOP 1 1 FROM @tLC)
               DELETE @tLC 
               
            INSERT INTO @tLC (LottableNo, Visible, Editable, Required, Sequence, Description, FormatSP) 
            SELECT LottableNo, Visible, Editable, Required, Sequence, Description, FormatSP
            FROM rdt.rdtLottableCode WITH (NOLOCK)
            WHERE LottableCode = @cLottableCode
               AND Function_ID = @nFunc
               AND StorerKey = @cStorerKey
               AND Required = '1'
   
            SET @curLC = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT LottableNo
               FROM @tLC
               ORDER BY Sequence
            OPEN @curLC
            FETCH NEXT FROM @curLC INTO @nLottableNo
            WHILE @@FETCH_STATUS = 0
            BEGIN
   /*
            -- Finish captured, check all lottables
            SET @nLottableNo = 1
            WHILE @nLottableNo <= 15
            BEGIN
   */
               -- Get label, lottable
               IF @nLottableNo =  1 SELECT @cLottable = @cLottable01                     ELSE 
               IF @nLottableNo =  2 SELECT @cLottable = @cLottable02                     ELSE 
               IF @nLottableNo =  3 SELECT @cLottable = @cLottable03                     ELSE 
               IF @nLottableNo =  4 SELECT @cLottable = rdt.rdtFormatDate( @dLottable04) ELSE 
               IF @nLottableNo =  5 SELECT @cLottable = rdt.rdtFormatDate( @dLottable05) ELSE 
               IF @nLottableNo =  6 SELECT @cLottable = @cLottable06                     ELSE 
               IF @nLottableNo =  7 SELECT @cLottable = @cLottable07                     ELSE 
               IF @nLottableNo =  8 SELECT @cLottable = @cLottable08                     ELSE 
               IF @nLottableNo =  9 SELECT @cLottable = @cLottable09                     ELSE 
               IF @nLottableNo = 10 SELECT @cLottable = @cLottable10                     ELSE 
               IF @nLottableNo = 11 SELECT @cLottable = @cLottable11                     ELSE 
               IF @nLottableNo = 12 SELECT @cLottable = @cLottable12                     ELSE 
               IF @nLottableNo = 13 SELECT @cLottable = rdt.rdtFormatDate( @dLottable13) ELSE 
               IF @nLottableNo = 14 SELECT @cLottable = rdt.rdtFormatDate( @dLottable14) ELSE 
               IF @nLottableNo = 15 SELECT @cLottable = rdt.rdtFormatDate( @dLottable15)
   
               -- Check blank
               IF @cLottable = ''
               BEGIN
                  SET @nErrNo = 92319
                  SET @cErrMsg = RTRIM( rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')) + RIGHT( '0' + CAST( @nLottableNo AS NVARCHAR(2)), 2) --NeedLottable
                  GOTO Quit
               END
               --SET @nLottableNo = @nLottableNo + 1
               FETCH NEXT FROM @curLC INTO @nLottableNo
            END
         END
         
         GOTO Quit -- Nothing to show
      END

   /********************************************************************************************
                                       Show lottable to screen
   ********************************************************************************************/
   CAPTURE_Quit:

      -- Get SKU info
      SELECT 
         @cLottable01Label = Lottable01Label,
         @cLottable02Label = Lottable02Label,
         @cLottable03Label = Lottable03Label,
         @cLottable04Label = Lottable04Label,
         @cLottable05Label = Lottable05Label,
         @cLottable06Label = Lottable06Label,
         @cLottable07Label = Lottable07Label,
         @cLottable08Label = Lottable08Label,
         @cLottable09Label = Lottable09Label,
         @cLottable10Label = Lottable10Label,
         @cLottable11Label = Lottable11Label,
         @cLottable12Label = Lottable12Label,
         @cLottable13Label = Lottable13Label,
         @cLottable14Label = Lottable14Label,
         @cLottable15Label = Lottable15Label
      FROM SKU WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey 
         AND SKU = @cSKU  
   
      SET @curLC = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT LottableNo, Sequence, Editable, Description
         FROM @tLC
         WHERE Visible = '1'
         ORDER BY Sequence
      OPEN @curLC
      FETCH NEXT FROM @curLC INTO @nLottableNo, @nSequence, @cEditable, @cDesc
   
      -- Loop 5 lottable position on screen (some could be blank)
      -- SET @nCursorPos = 0 -- cannot reset due to caller already set it
      SET @nCount = 1
      WHILE @nCount <= 5
      BEGIN
         -- Lottable available to show on this position
         IF @@FETCH_STATUS = 0
         BEGIN
            -- Get lottable
            IF @nLottableNo = 1  SELECT @cDesc = CASE WHEN @cDesc = '' THEN @cLottable01Label ELSE @cDesc END, @cLottable = @cLottable01                     ELSE 
            IF @nLottableNo = 2  SELECT @cDesc = CASE WHEN @cDesc = '' THEN @cLottable02Label ELSE @cDesc END, @cLottable = @cLottable02                     ELSE 
            IF @nLottableNo = 3  SELECT @cDesc = CASE WHEN @cDesc = '' THEN @cLottable03Label ELSE @cDesc END, @cLottable = @cLottable03                     ELSE 
            IF @nLottableNo = 4  SELECT @cDesc = CASE WHEN @cDesc = '' THEN @cLottable04Label ELSE @cDesc END, @cLottable = rdt.rdtFormatDate( @dLottable04) ELSE 
            IF @nLottableNo = 5  SELECT @cDesc = CASE WHEN @cDesc = '' THEN @cLottable05Label ELSE @cDesc END, @cLottable = rdt.rdtFormatDate( @dLottable05) ELSE 
            IF @nLottableNo = 6  SELECT @cDesc = CASE WHEN @cDesc = '' THEN @cLottable06Label ELSE @cDesc END, @cLottable = @cLottable06                     ELSE 
            IF @nLottableNo = 7  SELECT @cDesc = CASE WHEN @cDesc = '' THEN @cLottable07Label ELSE @cDesc END, @cLottable = @cLottable07                     ELSE 
            IF @nLottableNo = 8  SELECT @cDesc = CASE WHEN @cDesc = '' THEN @cLottable08Label ELSE @cDesc END, @cLottable = @cLottable08                     ELSE 
            IF @nLottableNo = 9  SELECT @cDesc = CASE WHEN @cDesc = '' THEN @cLottable09Label ELSE @cDesc END, @cLottable = @cLottable09                     ELSE 
            IF @nLottableNo = 10 SELECT @cDesc = CASE WHEN @cDesc = '' THEN @cLottable10Label ELSE @cDesc END, @cLottable = @cLottable10                     ELSE 
            IF @nLottableNo = 11 SELECT @cDesc = CASE WHEN @cDesc = '' THEN @cLottable11Label ELSE @cDesc END, @cLottable = @cLottable11                     ELSE 
            IF @nLottableNo = 12 SELECT @cDesc = CASE WHEN @cDesc = '' THEN @cLottable12Label ELSE @cDesc END, @cLottable = @cLottable12                     ELSE 
            IF @nLottableNo = 13 SELECT @cDesc = CASE WHEN @cDesc = '' THEN @cLottable13Label ELSE @cDesc END, @cLottable = rdt.rdtFormatDate( @dLottable13) ELSE 
            IF @nLottableNo = 14 SELECT @cDesc = CASE WHEN @cDesc = '' THEN @cLottable14Label ELSE @cDesc END, @cLottable = rdt.rdtFormatDate( @dLottable14) ELSE 
            IF @nLottableNo = 15 SELECT @cDesc = CASE WHEN @cDesc = '' THEN @cLottable15Label ELSE @cDesc END, @cLottable = rdt.rdtFormatDate( @dLottable15)

            -- Enable / disable field
            IF @cEditable = '1' 
               SET @cFieldAttr = '' 
            ELSE 
               SET @cFieldAttr = 'O'
         END
         ELSE
            -- No lottable for this position
            SELECT @cDesc = '', @cLottable = '', @cFieldAttr = 'O'
         
         -- Output to screen
         IF @nCount = 1 SELECT @cOutField01 = @cDesc, @cOutField02 = @cLottable, @cInField02 = @cLottable, @cFieldAttr02 = @cFieldAttr ELSE 
         IF @nCount = 2 SELECT @cOutField03 = @cDesc, @cOutField04 = @cLottable, @cInField04 = @cLottable, @cFieldAttr04 = @cFieldAttr ELSE 
         IF @nCount = 3 SELECT @cOutField05 = @cDesc, @cOutField06 = @cLottable, @cInField06 = @cLottable, @cFieldAttr06 = @cFieldAttr ELSE 
         IF @nCount = 4 SELECT @cOutField07 = @cDesc, @cOutField08 = @cLottable, @cInField08 = @cLottable, @cFieldAttr08 = @cFieldAttr ELSE 
         IF @nCount = 5 SELECT @cOutField09 = @cDesc, @cOutField10 = @cLottable, @cInField10 = @cLottable, @cFieldAttr10 = @cFieldAttr

         -- Calc cursor position
         IF @nCursorPos IS NULL                       -- Not save before
            IF @cFieldAttr = '' AND @cLottable = ''   -- Lottable enable with blank value
               SET @nCursorPos = @nCount * 2
         
         SET @nCount = @nCount + 1
         FETCH NEXT FROM @curLC INTO @nLottableNo, @nSequence, @cEditable, @cDesc
      END

      -- Position cursor
      IF @nCursorPos IS NOT NULL
         EXEC rdt.rdtSetFocusField @nMobile, @nCursorPos
   END

   /********************************************************************************************
   
                                                VERIFY
                                                
   ********************************************************************************************/
   IF @cScreenType = 'VERIFY'
   BEGIN  
      /********************************************************************************************
                                            Validate lottable
      ********************************************************************************************/
      -- Get lottable start, end sequence of the page
      IF @cAction = 'CHECK' AND  -- Validation
         @nInputKey = 1 AND      -- ENTER
         @nScn = 3990            -- Lottable screen
      BEGIN
         SET @nPOS = CHARINDEX( ',', @cOutField15)                                     -- Delimeter position
         SET @nFirstSeq = SUBSTRING( @cOutField15, 1, @nPOS-1)                         -- First lottable sequence of the page
         SET @nLastSeq = SUBSTRING( @cOutField15, @nPOS+1, LEN( @cOutField15) - @nPOS) -- Last lottable sequence of the page

         -- Take-in PRE value
         IF @cAction = 'CHECK' AND @nInputKey = 1 -- ENTER
         BEGIN
            -- Get the dynamic lottable in the sequence range
            INSERT INTO @tLC (LottableNo, Visible, Editable, Required, Sequence, Description, FormatSP) 
            SELECT TOP 5
               LottableNo, Visible, Editable, Required, Sequence, Description, FormatSP
            FROM rdt.rdtLottableCode WITH (NOLOCK)
            WHERE LottableCode = @cLottableCode
               AND Function_ID = @nFunc
               AND StorerKey = @cStorerKey
               AND Verify = '1'
               AND Sequence BETWEEN @nFirstSeq AND @nLastSeq
            ORDER BY Sequence
   
            -- Get dynamic lottable input
            SET @nCount = 1
            SET @nRemainInCurrentScreen = 0
            SET @curLC = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT LottableNo, Sequence, FormatSP
               FROM @tLC
               ORDER BY Sequence
            OPEN @curLC
            FETCH NEXT FROM @curLC INTO @nLottableNo, @nSequence, @cFormatSP
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- Get input value
               IF @nCount = 1 SELECT @cLottable = @cInField02 ELSE 
               IF @nCount = 2 SELECT @cLottable = @cInField04 ELSE 
               IF @nCount = 3 SELECT @cLottable = @cInField06 ELSE 
               IF @nCount = 4 SELECT @cLottable = @cInField08 ELSE 
               IF @nCount = 5 SELECT @cLottable = @cInField10

               IF @cFormatSP <> ''
               BEGIN
                  EXEC rdt.rdt_Lottable_Format @nMobile, @nFunc, @cLangCode, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, @nLottableNo, @cFormatSP, 
                     @cLottable  OUTPUT, 
                     @nErrNo     OUTPUT, 
                     @cErrMsg    OUTPUT

                  IF @nErrNo <> 0
                  BEGIN
                     SET @nCursorPos = @nCount * 2
                     EXEC rdt.rdtSetFocusField @nMobile, @nCursorPos
                        
                     IF @nErrNo = -1  -- Remain in current screen
                     BEGIN
                        SET @nErrNo = 0
                        SET @nRemainInCurrentScreen = 1
                     END
                     ELSE
                     BEGIN
                        SET @nMorePage = 0
                        GOTO Quit
                     END
                  END
               END

               -- Check date lottable
               IF @nLottableNo IN (4, 5, 13, 14, 15)
               BEGIN
                  IF @cLottable <> '' AND RDT.rdtIsValidDate( @cLottable) = 0
                  BEGIN
                     SET @nErrNo = 92324
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Date
                     SET @nCursorPos = @nCount * 2
                     EXEC rdt.rdtSetFocusField @nMobile, @nCursorPos
                        
                     SET @nMorePage = 0
                     GOTO Quit
                  END
               END

               -- Verify lottable
               IF @nLottableNo =  1 BEGIN IF @cLottable01 <> @cLottable                        SET @nErrNo = 92323 END ELSE 
               IF @nLottableNo =  2 BEGIN IF @cLottable02 <> @cLottable                        SET @nErrNo = 92323 END ELSE 
               IF @nLottableNo =  3 BEGIN IF @cLottable03 <> @cLottable                        SET @nErrNo = 92323 END ELSE 
               IF @nLottableNo =  4 BEGIN IF @dLottable04 <> rdt.rdtConvertToDate( @cLottable) SET @nErrNo = 92323 END ELSE 
               IF @nLottableNo =  5 BEGIN IF @dLottable05 <> rdt.rdtConvertToDate( @cLottable) SET @nErrNo = 92323 END ELSE 
               IF @nLottableNo =  6 BEGIN IF @cLottable06 <> @cLottable                        SET @nErrNo = 92323 END ELSE 
               IF @nLottableNo =  7 BEGIN IF @cLottable07 <> @cLottable                        SET @nErrNo = 92323 END ELSE 
               IF @nLottableNo =  8 BEGIN IF @cLottable08 <> @cLottable                        SET @nErrNo = 92323 END ELSE 
               IF @nLottableNo =  9 BEGIN IF @cLottable09 <> @cLottable                        SET @nErrNo = 92323 END ELSE 
               IF @nLottableNo = 10 BEGIN IF @cLottable10 <> @cLottable                        SET @nErrNo = 92323 END ELSE 
               IF @nLottableNo = 11 BEGIN IF @cLottable11 <> @cLottable                        SET @nErrNo = 92323 END ELSE 
               IF @nLottableNo = 12 BEGIN IF @cLottable12 <> @cLottable                        SET @nErrNo = 92323 END ELSE 
               IF @nLottableNo = 13 BEGIN IF @dLottable13 <> rdt.rdtConvertToDate( @cLottable) SET @nErrNo = 92323 END ELSE 
               IF @nLottableNo = 14 BEGIN IF @dLottable14 <> rdt.rdtConvertToDate( @cLottable) SET @nErrNo = 92323 END ELSE 
               IF @nLottableNo = 15 BEGIN IF @dLottable15 <> rdt.rdtConvertToDate( @cLottable) SET @nErrNo = 92323 END 

               IF @nErrNo = 92323
               BEGIN
                  SET @cErrMsg = RTRIM( rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')) + RIGHT( '0' + CAST( @nLottableNo AS NVARCHAR(2)), 2) --DiffLottable
                  SET @nCursorPos = @nCount * 2
                  EXEC rdt.rdtSetFocusField @nMobile, @nCursorPos
                     
                  SET @nMorePage = 0
                  GOTO Quit
               END
               
               -- Output to screen
               IF @nCount = 1 SELECT @cOutField02 = @cLottable ELSE 
               IF @nCount = 2 SELECT @cOutField04 = @cLottable ELSE 
               IF @nCount = 3 SELECT @cOutField06 = @cLottable ELSE 
               IF @nCount = 4 SELECT @cOutField08 = @cLottable ELSE 
               IF @nCount = 5 SELECT @cOutField10 = @cLottable
               
               SET @nCount = @nCount + 1
               FETCH NEXT FROM @curLC INTO @nLottableNo, @nSequence, @cFormatSP
            END
            IF @nRemainInCurrentScreen = 1
            BEGIN
               SET @nErrNo = -1
               SET @nMorePage = 0
               GOTO Quit
            END  

            -- Clear dynamic lottable
            DELETE @tLC
         END
      END

      /********************************************************************************************
                                             Get next lottable
      ********************************************************************************************/
      IF @cAction = 'CHECK'
      BEGIN
         -- Insert lottable to show
         IF @nInputKey = 1 -- ENTER
            INSERT INTO @tLC (LottableNo, Visible, Editable, Required, Sequence, Description, FormatSP) 
            SELECT TOP 5 
               LottableNo, Visible, Editable, Required, Sequence, Description, FormatSP
            FROM rdt.rdtLottableCode WITH (NOLOCK)
            WHERE LottableCode = @cLottableCode
               AND Function_ID = @nFunc
               AND StorerKey = @cStorerKey
               AND Verify = '1'
               AND Sequence > @nLastSeq
            ORDER BY Sequence
         ELSE
            INSERT INTO @tLC (LottableNo, Visible, Editable, Required, Sequence, Description, FormatSP) 
            SELECT TOP 5
               LottableNo, Visible, Editable, Required, Sequence, Description, FormatSP
            FROM rdt.rdtLottableCode WITH (NOLOCK)
            WHERE LottableCode = @cLottableCode
               AND Function_ID = @nFunc
               AND StorerKey = @cStorerKey
               AND Verify = '1'
               AND Sequence < @nFirstSeq
            ORDER BY Sequence DESC
      END
   
      IF @cAction = 'POPULATE'
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            INSERT INTO @tLC (LottableNo, Visible, Editable, Required, Sequence, Description, FormatSP) 
            SELECT TOP 5
               LottableNo, Visible, Editable, Required, Sequence, Description, FormatSP
            FROM rdt.rdtLottableCode WITH (NOLOCK)
            WHERE LottableCode = @cLottableCode
               AND Function_ID = @nFunc
               AND StorerKey = @cStorerKey
               AND Verify = '1'
            ORDER BY Sequence
         END
         ELSE
         BEGIN
            IF @nScn = 3990
               INSERT INTO @tLC (LottableNo, Visible, Editable, Required, Sequence, Description, FormatSP) 
               SELECT TOP 5
                  LottableNo, Visible, Editable, Required, Sequence, Description, FormatSP
               FROM rdt.rdtLottableCode WITH (NOLOCK)
               WHERE LottableCode = @cLottableCode
                  AND Function_ID = @nFunc
                  AND StorerKey = @cStorerKey
                  AND Verify = '1'
                  AND Sequence < @nFirstSeq
               ORDER BY Sequence DESC
            ELSE
            BEGIN
               INSERT INTO @tLC (LottableNo, Visible, Editable, Required, Sequence, Description, FormatSP) 
               SELECT LottableNo, Visible, Editable, Required, Sequence, Description, FormatSP
               FROM rdt.rdtLottableCode WITH (NOLOCK)
               WHERE LottableCode = @cLottableCode
                  AND Function_ID = @nFunc
                  AND StorerKey = @cStorerKey
                  AND Verify = '1'
               ORDER BY Sequence
               SET @nRowCount = @@ROWCOUNT
   
               -- Multi pages
               WHILE @nRowCount > 5
               BEGIN
                  -- Delete lottable page except for last page
                  DELETE @tLC WHERE RowRef IN (SELECT TOP 5 RowRef FROM @tLC ORDER BY Sequence)
                  SELECT @nRowCount = COUNT(1) FROM @tLC
               END
            END
         END
      END

      /********************************************************************************************
                                             Show next lottable 
      ********************************************************************************************/
      IF NOT EXISTS( SELECT TOP 1 1 FROM @tLC)
      BEGIN
         SET @nMorePage = 0 -- No more dynamic lottable page
         GOTO Quit -- Nothing to show
      END
      ELSE         
      BEGIN
         SET @nFirstSeq = NULL
         SET @curLC = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT LottableNo, Sequence, Editable, Description
            FROM @tLC
            ORDER BY Sequence
         OPEN @curLC
         FETCH NEXT FROM @curLC INTO @nLottableNo, @nSequence, @cEditable, @cDesc
      
         -- Loop 5 lottable position on screen (some could be blank)
         SET @nCursorPos = 0
         SET @nCount = 1
         WHILE @nCount <= 5
         BEGIN
            -- Lottable available to show on this position
            IF @@FETCH_STATUS = 0
            BEGIN
               SET @cFieldAttr = '' 
                  
               IF @nFirstSeq IS NULL
                  SET @nFirstSeq = @nSequence
               SET @nLastSeq = @nSequence
            END
            ELSE
               -- No lottable for this position
               SELECT @cDesc = '', @cFieldAttr = 'O'
            
            -- Output to screen
            IF @nCount = 1 SELECT @cOutField01 = @cDesc, @cOutField02 = '', @cInField02 = '', @cFieldAttr02 = @cFieldAttr ELSE 
            IF @nCount = 2 SELECT @cOutField03 = @cDesc, @cOutField04 = '', @cInField04 = '', @cFieldAttr04 = @cFieldAttr ELSE 
            IF @nCount = 3 SELECT @cOutField05 = @cDesc, @cOutField06 = '', @cInField06 = '', @cFieldAttr06 = @cFieldAttr ELSE 
            IF @nCount = 4 SELECT @cOutField07 = @cDesc, @cOutField08 = '', @cInField08 = '', @cFieldAttr08 = @cFieldAttr ELSE 
            IF @nCount = 5 SELECT @cOutField09 = @cDesc, @cOutField10 = '', @cInField10 = '', @cFieldAttr10 = @cFieldAttr
   
            -- Calc cursor position
            IF @nCursorPos = 0                           -- Not save before
               IF @cFieldAttr = ''                       -- Lottable field with blank value
                  SET @nCursorPos = @nCount * 2
            
            SET @nCount = @nCount + 1
            FETCH NEXT FROM @curLC INTO @nLottableNo, @nSequence, @cEditable, @cDesc
         END
   
         -- Position cursor
         IF @nCursorPos <> 0
            EXEC rdt.rdtSetFocusField @nMobile, @nCursorPos

         -- Save sequence range of the page into hidden field
         SET @cOutField15 = CAST( @nFirstSeq AS NVARCHAR(2)) + ',' + CAST( @nLastSeq AS NVARCHAR(2))

         SET @nMorePage = 1 -- Next dynamic lottable page
      END
   END
      
Quit:

END -- End Procedure

GO