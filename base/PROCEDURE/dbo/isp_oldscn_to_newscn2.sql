SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/    
/* Stored Procedure: isp_OldScn_to_NewScn2                                 */    
/* Creation Date: 13-Apr-2012                                              */    
/* Copyright: IDS                                                          */    
/* Written by: Chee Jun Yan                                                */    
/*                                                                         */    
/* Purpose: Convert from rdt.scn to rdt.scndetail                          */    
/*                                                                         */    
/*                                                                         */    
/* Input Parameters: Mobile No                                             */    
/*                                                                         */    
/* Output Parameters: NIL                                                  */    
/*                                                                         */    
/* Return Status:                                                          */    
/*                                                                         */    
/* Usage:                                                                  */    
/*                                                                         */    
/*                                                                         */    
/* Called By: isp_Trasnfer2NewScn                                          */    
/*                                                                         */    
/* PVCS Version: 1.0                                                       */    
/*                                                                         */    
/* Version: 5.4                                                            */    
/*                                                                         */    
/* Data Modifications:                                                     */    
/*                                                                         */    
/* Updates:                                                                */    
/* Date         Ver. Author    Purposes                                    */    
/*                                                                         */     
/***************************************************************************/    
   
/*
DECLARE @cMsg NVARCHAR(1024)

--SET @cMsg = 'Storer: %i`V_SKU`20`[0-9]{2}/[0-9]{2}/[0-9]{4}`1`QC`white %rb`01`10`O=Open```white         %ddlb`06`20`isp_GetLottable02ByAsn``PLS SELECT LOT02`Red'
--
--SET @cMsg = '%today`'
--
--SET @cMsg = '%d`Storer:`red   %d`01`20`white'

--1   2  white d     Storer:     NULL  
--9   2  white i     NULL     10 

SET @cMsg = 'Storer: %i`01`10`'

SET @cMsg = 'Facility: %i`02`05``1`'

SET @cMsg = '%ddlb`04`20`RDT.V_LookUp_Printer``/%Konica'

SET @cMsg = '%ddlb`05`20`RDT.V_LookUp_Printer`'

SET @cMsg = 'TEST: %i`03`20` %i`03`20`'

SET @cMsg = 'QTY AVL: %d`13`11` %d`13`11`'

SET @cMsg = '%rb`01`10`X=Cancelled` %rb`01`10`X=Cancelled`    %rb`01`10`X=Cancelled`'

--SET @cMsg = '%i`V_SKU`20`[0-9]{2}/[0-9]{2}/[0-9]{4}``QC`white'

EXEC [isp_OldScn_to_NewScn2]
'01',
@cMsg,
'OUT'
*/

CREATE PROC [dbo].[isp_OldScn_to_NewScn2] (  
   @y                NVARCHAR(10),  
   @cMsg             NVARCHAR(1024),  
   @cDefaultFromCol  NVARCHAR(3) = 'OUT'  
)  
AS  
  
BEGIN   
     
SET NOCOUNT ON  
SET QUOTED_IDENTIFIER OFF  
SET ANSI_NULLS OFF  
SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE 
      @nFieldPos        INT,
      @nNextFieldPos    INT,
      @nPosition        INT,
      @nNextStartPos    INT,     
      @cValue           NVARCHAR(4000),
      @nInpLng          INT,  
      @cInpType         NVARCHAR(20),  
      @cInpColName      NVARCHAR(20),
      @cInpColor        NVARCHAR(20),
      @cInpPointer      NCHAR(1),
      @cDefaultValue    NVARCHAR(125),
      @cInpRegExp       NVARCHAR(255),
      @cInpText         NVARCHAR(20),
      @cInplkupV        NVARCHAR(4000),
      @x                INT,
      @nFieldString     NVARCHAR(4000),
      @nDebug           INT

   DECLARE @Format TABLE (  
        [mobile]  int,  
        [id]      [NVARCHAR] (20)   NULL DEFAULT '', 
        [x]       [NVARCHAR] (10)   NULL DEFAULT '',  
        [y]       [NVARCHAR] (10)   NULL DEFAULT '',  
        [color]   [NVARCHAR] (20)   NULL DEFAULT '',
        [type]    [NVARCHAR] (20)   NULL DEFAULT '',  
        [RegExp]  [NVARCHAR] (255)  NULL DEFAULT '',
        [text]    [NVARCHAR] (20)   NULL DEFAULT '',
        [value]   [NVARCHAR] (50)   NULL DEFAULT '', 
        [length]  [NVARCHAR] (20)   NULL DEFAULT '',  
        [lkupV]   [NVARCHAR] (4000) NULL DEFAULT '', 
        [func]    [NVARCHAR] (4)    NULL DEFAULT ''         
   )

   DECLARE 
      @cField01 NVARCHAR(20),
      @cField02 NVARCHAR(20),
      @cField03 NVARCHAR(20),
      @cField04 NVARCHAR(50),
      @cField05 NVARCHAR(20),
      @cField06 NVARCHAR(50),
      @cField07 NVARCHAR(20)

   SET @x = 1
   SET @nDebug = 0

   -- Message without %
   IF CharIndex('%', @cMsg, 1) = 0  
   BEGIN  
      INSERT INTO @Format ([mobile], [id], [x], [y], [color],[type], [text], [value], [length])  
      VALUES (0, '', RIGHT('0' + RTRIM(Cast(@x as char(2))), 2), @y, 'white', 'd', RTRIM(@cMsg), '', '0')   
  
      GOTO PROCESS_END  
   END  

   -- message with %
   WHILE LEN(@cMsg) > 0
   BEGIN

      SET @nPosition = 1
      SET @nFieldPos = 0 
      SET @cInpType = ''
      SET @cInpColName = ''
      SET @cInpColor = 'white'
      SET @cInpPointer = ''
      SET @cDefaultValue = ''
      SET @cInpRegExp = ''
      SET @cInplkupV = ''
      SET @cInpText = NULL

      SET @cField01 = ''
      SET @cField02 = ''
      SET @cField03 = ''
      SET @cField04 = ''
      SET @cField05 = ''
      SET @cField06 = ''
      SET @cField07 = ''

      -- REPLACE /% with '_p
      SET @cMsg = REPLACE(@cMsg, '/%', '''_p')

      -- REPLACE /` with '_ga
      SET @cMsg = REPLACE(@cMsg, '/`', '''_ga')

      -- Get position of %
      SET @nFieldPos = CharIndex('%', @cMsg, @nFieldPos)

      SET @nNextStartPos = CharIndex('%', @cMsg, @nFieldPos + 1)

      -- If Not found, use the last character for string as end position   
      IF @nNextStartPos = 0  
         SET @nNextStartPos = LEN(@cMsg) + 1

      -- Current fieldString
      SET @nFieldString = SUBSTRING(@cMsg, 1, @nNextStartPos-1)
      
      IF @nDebug = 1
      BEGIN
         SELECT 
            @cMsg AS '@cMsg',
            @nFieldString AS '@nFieldString',
            @nFieldPos AS '@nFieldPos',
            @nNextStartPos AS '@nNextStartPos'
      END

      -- % not in first char, insert word in front into @Format
      IF @nFieldPos > 1
      BEGIN
         
         SET @cInpText = SUBSTRING(@nFieldString, 1, @nFieldPos-1)

         IF LEN(@cInpText) > 0
         BEGIN
            INSERT INTO @Format ([mobile], [id], [x], [y], [color],[type], [text], [value], [length])  
            VALUES (0, NULL, RIGHT('0' + RTRIM(Cast(@x as char(2))), 2), @y, RTRIM(@cInpColor), 'd', RTRIM(@cInpText), '', NULL)
         END

         -- Increase @x
         SET @x = @x + LEN(REPLACE(@cInpText, ' ', '*'))

         -- TRUNCATE @nFieldString
         SET @nFieldString = SUBSTRING(@nFieldString, @nFieldPos, LEN(@nFieldString))

         -- Get new FieldPos
         SET @nFieldPos = CharIndex('%', @nFieldString)
         SET @cInpText = NULL

         IF @nDebug = 1
         BEGIN
            SELECT 
               @nFieldString AS '@nFieldString',
               @nFieldPos AS '@nFieldPos',
               @nNextStartPos AS '@nNextStartPos',
               @x AS '@x'
         END
      END -- IF @nFieldPos > 1

      -- GET Field01
      SET @nNextFieldPos = CharIndex('`', @nFieldString, @nFieldPos + 1)

      -- If Not found, use the last character for string as end position   
      IF @nNextFieldPos = 0  
         SET @nNextFieldPos = LEN(@nFieldString) + 1

      SET @cField01 = SUBSTRING(@nFieldString, @nFieldPos, @nNextFieldPos - @nFieldPos)

      SET @nFieldPos = @nNextFieldPos

      IF @nDebug = 1
      BEGIN
         SELECT 
            @cField01 AS '@cField01',
            @nFieldPos AS '@nFieldPos',
            @nNextFieldPos AS '@nNextFieldPos'
      END

      -- Special
      IF @cField01 IN ('%e', '%today', '%mob', '%dbip', '%dbname', '%dbsrv')  
      BEGIN
         -- color
         IF @nFieldPos < LEN(@nFieldString) + 1
         BEGIN
            SET @cField02 = SUBSTRING(@nFieldString, @nFieldPos+1, LEN(@nFieldString) - @nFieldPos)
            SET @cInpColor = CASE WHEN LEN(@cField02) > 0 THEN @cField02 ELSE @cInpColor END 
         END

         INSERT INTO @Format ([mobile], [id], [x], [y], [color],[type], [text], [value], [length])  
         VALUES (0, '', RIGHT('0' + RTRIM(Cast(@x as char(2))), 2), @y, RTRIM(@cInpColor), 'd', RTRIM(@cField01), '', '0') 
      END -- Special
      -- Others
      ELSE 
      BEGIN
         -- Get fields value
         WHILE @nFieldPos > 0
         BEGIN
            SET @nNextFieldPos = CharIndex('`', @nFieldString, @nFieldPos + 1)

            SET @cValue =  CASE @nNextFieldPos 
                           WHEN 0 THEN SUBSTRING(@nFieldString, @nFieldPos+1, LEN(REPLACE(@nFieldString,' ','*'))-@nFieldPos) 
                           ELSE SUBSTRING(@nFieldString, @nFieldPos+1, @nNextFieldPos-@nFieldPos-1) 
                           END 

            
            -- REPLACE '_p with %
            IF CHARINDEX('''_p', @cValue) > 0
               SET @cValue = REPLACE(@cValue, '''_p', '%')        
            -- REPLACE '_ga with `
            IF CHARINDEX('''_ga', @cValue) > 0
               SET @cValue = REPLACE(@cValue, '''_ga', '`')

            -- Increase @nPosition
            SET @nPosition = @nPosition + 1

            IF @nPosition = 2
               SET @cField02 = @cValue
            ELSE IF @nPosition = 3
               SET @cField03 = @cValue
            ELSE IF @nPosition = 4
               SET @cField04 = @cValue
            ELSE IF @nPosition = 5
               SET @cField05 = @cValue
            ELSE IF @nPosition = 6
               SET @cField06 = @cValue
            ELSE IF @nPosition = 7
               SET @cField07 = @cValue

            -- Get Next position for new field  
            SET @nFieldPos = @nNextFieldPos
         END -- WHILE @nFieldPos > 0

         SET @cInpType = SUBSTRING(@cField01, 2, LEN(@cField01)-1)
         
         

         -- word
         IF @nPosition = 3
         BEGIN
            SET @cInpText = @cField02
            SET @nInpLng = 0
            --SET @cInpColor = CASE WHEN LEN(@cField03) > 0 THEN @cField03 ELSE @cInpColor END 
         END
         -- Image
         IF @cInpType = 'img'
         BEGIN
            SET @cDefaultValue = @cField02
            SET @cInpText = @cField03
            SET @nInpLng = 0

            IF @nPosition > 4
               SET @nInpLng = @cField04
         END
         -- Others 
         ELSE 
         BEGIN
            
            IF ISNUMERIC(@cField03) = 1 
            BEGIN
               SET @cInpColName = @cField02 -- (ChewKPXX) 
               SET @nInpLng = @cField03 -- (ChewKPXX) 
            END

            SET @cInpPointer = CASE WHEN @nPosition > 5 THEN @cField05 ELSE '' END

            
            IF @cInpType IN ('i', 'v', 'p')
            BEGIN
               SET @cInpRegExp = CASE WHEN @nPosition > 4 THEN @cField04 ELSE '' END
               SET @cDefaultValue = CASE WHEN @nPosition > 6 THEN @cField06 ELSE '' END
            END
            ELSE IF @cInpType IN ('rb', 'cbx', 'ddlb', 'btn')
            BEGIN
               IF @cInpType = 'rb' OR @cInpType = 'btn'
               BEGIN
                  -- Store index of '=' into a temporary field 
                  SET @nNextFieldPos = CharIndex('=', @cField04)

                  -- Get ColValue and ColText
                  SET @cDefaultValue = SUBSTRING(@cField04, 1, @nNextFieldPos-1)
                  SET @cInpText = SUBSTRING(@cField04, @nNextFieldPos+1, LEN(@cField04) - @nNextFieldPos)
               END
               ELSE IF @cInpType = 'cbx'
               BEGIN
                  SET @cInpText = @cField04
                  SET @cDefaultValue = CASE WHEN @nPosition > 6 THEN @cField06 ELSE '' END
               END
               ELSE -- ddlb
               BEGIN
                  SET @cInpText = ''
                  SET @cInplkupV = @cField04
                  SET @cDefaultValue = CASE WHEN @nPosition > 6 THEN @cField06 ELSE '' END
               END -- IF @cInpType = 'rb' OR @cInpType = 'btn'    
            END -- IF @cInpType IN ('i', 'v', 'p')
         END -- IF @nPosition = 3

         -- Get Color From last Position in string
         SET @cInpColor = CASE @nPosition 
                           WHEN 3 THEN CASE WHEN LEN(@cField03) > 0 THEN @cField03 ELSE @cInpColor END 
                           WHEN 4 THEN CASE WHEN LEN(@cField04) > 0 THEN @cField04 ELSE @cInpColor END 
                           WHEN 5 THEN CASE WHEN LEN(@cField05) > 0 THEN @cField05 ELSE @cInpColor END 
                           WHEN 6 THEN CASE WHEN LEN(@cField06) > 0 THEN @cField06 ELSE @cInpColor END 
                           ELSE CASE WHEN LEN(@cField07) > 0 THEN @cField07 ELSE @cInpColor END 
                          END
         

         -- Cursor Pointer
         IF @cInpPointer = '1'
         BEGIN
            UPDATE RDT.rdtXML_Root WITH (ROWLOCK)  
               SET focus = @cInpColName  
            WHERE Mobile = 0  
         END

         INSERT INTO @Format ([mobile], [id], [x], [y], [color],[type], [RegExp], [text],[value], [length], [lkupV])  
         VALUES (0, @cInpColName, RIGHT('0' + RTRIM(Cast(@x as char(2))), 2), 
                  @y, RTRIM(@cInpColor), @cInpType, @cInpRegExp, RTRIM(@cInpText), @cDefaultValue, @nInpLng, @cInplkupV)   

         -- Store trailing space(s) length into a temporary field 
         SET @nPosition = CASE REPLACE(@cInpColor, ' ', '*')
                           WHEN 'white' THEN CASE @nPosition -- use default color, then get trailing space(s) from @cField0X
                                                WHEN 3 THEN LEN(REPLACE(@cField03, ' ', '*')) - LEN(@cField03)
                                                WHEN 4 THEN LEN(REPLACE(@cField04, ' ', '*')) - LEN(@cField04)
                                                WHEN 5 THEN LEN(REPLACE(@cField05, ' ', '*')) - LEN(@cField05)
                                                WHEN 6 THEN LEN(REPLACE(@cField06, ' ', '*')) - LEN(@cField06)
                                                ELSE LEN(REPLACE(@cField07, ' ', '*')) - LEN(@cField07)
                                             END
                           ELSE LEN(REPLACE(@cInpColor, ' ', '*')) - LEN(@cInpColor)
                          END       
   
         SET @x = @x + CASE @cInpType 
                        WHEN 'd' THEN CASE @cInpText 
                                       WHEN NULL THEN @nInpLng + @nPosition 
                                       ELSE LEN(REPLACE(@cInpText,' ', '*')) + @nPosition -- word
                                      END
                        WHEN 'rb' THEN @nInpLng + 4 + @nPosition -- (*)_ = 4 CHARs
                        WHEN 'cbx' THEN @nInpLng + 4 + @nPosition -- [*]_ = 4 CHARs 
                        ELSE @nInpLng + @nPosition
                       END

         IF @nDebug = 1
         BEGIN
            SELECT
             @cInpType AS '@cInpType'
            ,@cInpColName AS '@cInpColName'
            ,@cInpColor AS '@cInpColor'
            ,@cInpPointer AS '@cInpPointer'
            ,@cInplkupV AS '@cInplkupV'
            ,@cInpRegExp AS '@cInpRegExp'
            ,@cInpText AS '@cInpText'
            ,@nInpLng AS '@nInpLng'          
            ,@cDefaultValue AS '@cDefaultValue'
            ,@x AS '@x'
         END

      END -- Others 

      -- TRUNCATE @cMsg
      SET @cMsg = SUBSTRING(@cMsg, @nNextStartPos, LEN(@cMsg) - @nNextStartPos + 2)

   END -- WHILE LEN(@Msg) > 0

PROCESS_END:       
   SELECT * FROM @Format ORDER BY [X]

END  -- Procedure

GO