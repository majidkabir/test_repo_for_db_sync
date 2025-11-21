SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Procedure: rdtScr2XML_V1  Ver 2.0                                */
/* Creation Date: 19-Dec-2004                                           */
/* Copyright: IDS                                                       */
/* Written by: Shong                                                    */
/*                                                                      */
/* Purpose: Build the screen format for the Functional Screen           */
/*          Insert into the Temporary table and later will transfer     */
/*          into XML format by another SP                               */
/*                                                                      */
/* Input Parameters: Mobile No                                          */
/*                   y - Line Number                                    */
/*                   Message - The formated line that going to display  */
/*                             on the screen.                           */
/*                   default from columns - IN/OUT. In is getting from  */
/*                   RDTMOBREC IN = I_Field99 and Out = O_Fieldxx       */
/* Output Parameters: NIL                                               */
/*                                                                      */
/* Called By: rdtGetMenu, rdtGetScreen                                  */
/*                                                                      */
/* Data Modifications:                                                  */
/* Date         Author        Purposes                                  */
/* 2008-11-17   Vicky         Add Trim to fields (Vicky01)              */
/* 2010-11-26   Ung           Add %dbip and %dbname                     */
/* 2011-07-21   Ung           Add %server                               */
/************************************************************************/

CREATE PROC [RDT].[rdtScr2XML_V1] (
   @nMobile          int,
   @y                NVARCHAR(10),
   @cMsg             NVARCHAR(1024),
   @cDefaultFromCol  NVARCHAR(3) = 'OUT'
)
AS
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF

   DECLARE @nFieldPos    int, 
           @cFieldLabel  NVARCHAR(20), 
           @nLabelPos    int 
   
   DECLARE @idx            int,
           @Length         int,
           @cNextChar      NVARCHAR(1),
           @Label          NVARCHAR(255),
           @Default        NVARCHAR(60),
           @Input          NVARCHAR(60),
           @InpStart       int,
           @x              int,
           @InpType        NVARCHAR(20),
           @inpLng         NVARCHAR(2),
           @InpColNo       int,
           @InpColName     NVARCHAR(20),
           @cErrMsg        NVARCHAR(125),
           @cOutput        NVARCHAR(1024),
           @nInpCol        int,
           @nLoop          int,
           @cValue         NVARCHAR(125), 
           @cEndString     NVARCHAR(1024), 
           @nNextBlankChar int, 
           @cDefaultValue  NVARCHAR(125),
           @cMobRecColName NVARCHAR(30) 
   
   SET @nFieldPos = 0

   DECLARE @Format TABLE (
        [mobile]  int,
        [typ]     [varchar] (20)  NULL ,
        [x]       [varchar] (10)  NULL ,
        [y]       [varchar] (10)  NULL,
        [length]  [varchar] (10)  NULL ,
        [id]      [varchar] (20)  NULL ,
        [default] [varchar] (60)  NULL ,
        [type]    [varchar] (20)  NULL ,
        [value]   [varchar] (125) NULL
   )

   -- Error Message 
   IF CharIndex('%e', @cMsg, 1) = 1
   BEGIN
      SELECT @cErrMsg = ISNULL(RTRIM(ErrMsg),'') -- (Vicky01)
      FROM   RDT.RDTMOBREC (NOLOCK)
      WHERE  Mobile = @nMobile

      IF RTRIM(@cErrMsg) IS NOT NULL AND RTRIM(@cErrMsg) <> ''
      BEGIN
         INSERT INTO @Format ([mobile], [typ],[x],[y], [length],[id],[default],[type],[value])
         VALUES (@nMobile, 'output', '01', @y, NULL, NULL, NULL, NULL, RTRIM(@cErrMsg)) -- (Vicky01)
      END

      GOTO PROCESS_END
   END 
   ELSE IF CharIndex('%today', @cMsg, 1) > 0 OR 
           CharIndex('%dbip', @cMsg, 1) > 0 OR
           CharIndex('%dbname', @cMsg, 1) > 0 OR
           CharIndex('%dbsrv', @cMsg, 1) > 0 OR
           CharIndex('%mob', @cMsg, 1) > 0
   BEGIN
      -- Today Date
      IF CharIndex('%today', @cMsg, 1) > 0
      BEGIN
         SELECT @cMsg = REPLACE(@cMsg, '%today', Cast( GetDate() as NVARCHAR(20)) )
      END

      -- DB server IP
      IF CharIndex('%dbip', @cMsg, 1) > 0
         SELECT @cMsg = REPLACE(@cMsg, '%dbip', Cast( (select local_net_address from sys.dm_exec_connections where session_id = @@SPID) as NVARCHAR(20)) )
         
      -- DB server name
      IF CharIndex('%dbsrv', @cMsg, 1) > 0
         SELECT @cMsg = REPLACE(@cMsg, '%dbsrv', Cast( @@servername as NVARCHAR(20)) )


      -- DB name
      IF CharIndex('%dbname', @cMsg, 1) > 0
         SELECT @cMsg = REPLACE(@cMsg, '%dbname', Cast( DB_NAME( DB_ID()) as NVARCHAR(20)) )

      -- Mobile Number
      IF CharIndex('%mob', @cMsg, 1) > 0
      BEGIN
         SELECT @cMsg = REPLACE(@cMsg, '%mob', RTRIM(CAST(@nMobile as NVARCHAR(5))) )
      END

      INSERT INTO @Format ([mobile], [typ],[x],[y], [length],[id],[default],[type],[value])
      VALUES (@nMobile, 'output', '01', @y, NULL, NULL, NULL, NULL, RTRIM(@cMsg) ) -- (Vicky01)

      GOTO PROCESS_END
   END
   ELSE IF CharIndex('%', @cMsg, 1) = 0
   BEGIN
      INSERT INTO @Format ([mobile], [typ],[x],[y], [length],[id],[default],[type],[value])
      VALUES (@nMobile, 'output', '01', @y, NULL, NULL, NULL, NULL, RTRIM(@cMsg)) -- (Vicky01)

      GOTO PROCESS_END
   END


   -- Insert All the Field Column into Temp Table
   SET @nFieldPos = CharIndex('%', @cMsg, @nFieldPos)

   WHILE @nFieldPos > 0 
   BEGIN
      -- 7 Chars include 2 = Field Length + 1 = Type + 2 = Field Sequence (If Numeric) + 1 = Focus 
      IF @nFieldPos + 6 > LEN(@cMsg) 
         SET @cFieldLabel = SUBSTRING(@cMsg, @nFieldPos, 7) 
      ELSE
         SET @cFieldLabel = SUBSTRING(@cMsg, @nFieldPos, 6) 
   
      SELECT @InpType = CASE SubString(@cFieldLabel, 4, 1)
                           WHEN 'p' THEN 'password'
                           WHEN 'i' THEN 'input'
                           WHEN 'd' THEN 'display'
                           WHEN 'v' THEN 'inverse'
                        END
   
   
      -- Get Next position for SPACE
      SET @nNextBlankChar = CharIndex(' ', @cMsg, @nFieldPos + 1 ) 
   
      -- If Not found, use the last character for string as end position 
      IF @nNextBlankChar = 0 
         SET @nNextBlankChar = LEN(@cMsg) + 1
   
   -- -- Not going to handle the default value as this time 
   --    IF @nNextBlankChar <> 0 
   --    BEGIN 
   --       -- Get Default Value 
   --       IF LEN( SUBSTRING(@cMsg, @nFieldPos, (@nNextBlankChar - @nFieldPos)) ) > 6  
   --       BEGIN
   --          SET @cDefaultValue =  SUBSTRING(@cMsg, @nFieldPos + 6, (@nNextBlankChar - @nFieldPos - 6))  
   --       END 
   --       ELSE
   --          SET @cDefaultValue = '' 
   --    END
   --    ELSE
      SET @cDefaultValue = '' 
   
      SET @InpLng  = SubString(@cFieldLabel, 2, 2)
      
      -- If the character position 5 + 6 is not numeric, means this column is V_xxxx 
      IF ISNUMERIC( SubString(@cFieldLabel, 5, 2) ) = 1
      BEGIN 
         SET @InpColNo = CAST(SubString(@cFieldLabel, 5, 2) as int) 
         SET @InpColName = 'Field' + RIGHT('0' + RTRIM(Cast(@InpColNo as NVARCHAR(2))), 2)
   
         IF @cDefaultFromCol = 'IN'  
            SET @cMobRecColName = 'I_' + @InpColName 
         ELSE
            SET @cMobRecColName = 'O_' + @InpColName
      END
      ELSE
      BEGIN
         -- Get Column Name other then Field99 
         -- For example: V_SKU, V_UOM 
         IF LEN( SUBSTRING(@cMsg, @nFieldPos, (@nNextBlankChar - @nFieldPos)) ) > 6  
         BEGIN
            SET @InpColName = SUBSTRING(@cMsg, @nFieldPos + 4, (@nNextBlankChar - @nFieldPos - 4)) 
            SET @cMobRecColName =  SUBSTRING(@cMsg, @nFieldPos + 4, (@nNextBlankChar - @nFieldPos - 4))  
         END 
         ELSE
            SET @cMobRecColName = '' 
   
         SET @InpColName = @cMobRecColName 
         
      END
   
      IF RIGHT(@cMobRecColName, 1) = '*'
      BEGIN
         SET @cMobRecColName =  SUBSTRING(@cMobRecColName, 1, LEN(@cMobRecColName) - 1 )  
   
         UPDATE RDT.rdtXML_Root WITH (ROWLOCK)
            SET focus = @InpColName
         WHERE Mobile = @nMobile
      END
   

      -- Get Value from rdtMobRec for the column..   
      IF @cMobRecColName <> ''
         EXEC RDT.rdtGetColumnValue @nMobile, @cMobRecColName, @Default OUTPUT
   
   
      IF @InpType = 'display'  
      BEGIN
         IF RTRIM(@Default) IS NOT NULL AND RTRIM(@Default) <> ''
         BEGIN
            INSERT INTO @Format ([mobile], [typ],[x],[y], [length],[id],[default],[type],[value])
            VALUES (@nMobile, @InpType, RIGHT('0' + RTRIM(Cast(@nFieldPos as NVARCHAR(2))), 2), @y, 
                    NULL,  NULL, NULL, NULL, RTRIM(@Default)) -- (Vicky01)
         END 
      END -- @InpType = 'display' 
      ELSE
      BEGIN
         INSERT INTO @Format ([mobile], [typ],[x],[y], [length],[id],[default],[type],[value])
         VALUES (@nMobile, @InpType, RIGHT('0' + RTRIM(Cast(@nFieldPos as NVARCHAR(2))), 2), @y, 
                 @InpLng, @InpColName, @Default, NULL, RTRIM(@cValue)) -- (Vicky01)
      END
         
      -- Get the rest of the string after the current field position 
      SET @cEndString = ''
      IF @nNextBlankChar > 0 
      BEGIN 
         SET @cEndString = SUBSTRING(@cMsg, @nNextBlankChar, LEN(@cMsg) - @nNextBlankChar + 1)
      END 
   
      -- Replace the Field with ^ character base on the Field Length defined in rdtScn 
      SET @cMsg = LEFT(@cMsg, @nFieldPos - 1) + REPLICATE('^', @InpLng) + @cEndString  
   
      -- Get Next position for new field
      SET @nFieldPos = CharIndex('%', @cMsg, @nFieldPos + 1 )
   END
 
   -- Build All the Label Into Temp Table
   SET @nLabelPos = 1 
   
   -- Build the Column X & Y and the Value for the "Label Column" 
   SET @nFieldPos = CharIndex('^', @cMsg, @nFieldPos)
   WHILE @nFieldPos > 0 
   BEGIN
      SET @cValue = SUBSTRING(@cMsg, @nLabelPos, @nFieldPos - @nLabelPos) 
   
      IF RTRIM(@cValue) <> '' AND RTRIM(@cValue) IS NOT NULL
      BEGIN
         INSERT INTO @Format ([mobile], [typ],[x],[y], [length],[id],[default],[type],[value])
         VALUES (@nMobile, 'display', RIGHT('0' + RTRIM(Cast(@nLabelPos as NVARCHAR(2))), 2), @y, NULL, NULL, NULL, NULL, RTRIM(@cValue)) -- (Vicky01)
   
      END
      
      SET @cNextChar = '^' 
      WHILE @cNextChar = '^' OR RTRIM(@cNextChar) = ''
      BEGIN 
         SET @nFieldPos = @nFieldPos + 1 
   
         IF @nFieldPos > LEN(@cMsg)
            BREAK 
   
         SET @cNextChar = SUBSTRING(@cMsg, @nFieldPos, 1) 
      END 
      SET @nLabelPos = @nFieldPos     
   
      SET @nFieldPos = CharIndex('^', @cMsg, @nFieldPos + 1 )
   END   
   IF LEN(@cMsg) >= @nLabelPos 
   BEGIN
      SET @cValue = SUBSTRING(@cMsg, @nLabelPos, LEN(@cMsg) - @nLabelPos + 1) 
      
      IF RTRIM(@cValue) <> '' AND RTRIM(@cValue) IS NOT NULL
      BEGIN
         INSERT INTO @Format ([mobile], [typ],[x],[y], [length],[id],[default],[type],[value])
         VALUES (@nMobile, 'display', RIGHT('0' + RTRIM(Cast(@nLabelPos as NVARCHAR(2))), 2), @y, NULL, NULL, NULL, NULL, RTRIM(@cValue)) -- (Vicky01)
      
      END
   END

PROCESS_END:
   UPDATE @Format
   SET [DEFAULT] = CASE [DEFAULT] WHEN '' THEN NULL ELSE [DEFAULT] END,
        typ = CASE typ
                 WHEN 'display' THEN 'output'
                 ELSE typ
              END
   
   SELECT * FROM @Format ORDER BY [X]


GO