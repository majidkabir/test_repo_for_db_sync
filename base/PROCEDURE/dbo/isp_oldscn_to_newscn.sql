SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/**************************************************************************   */
/* Stored Procedure: isp_OldScn_to_NewScn                                     */
/* Creation Date: 29-Mar-2010                                                 */
/* Copyright: IDS                                                             */
/* Written by: Shong                                                          */
/*                                                                            */
/* Purpose: Convert from rdt.scn to rdt.scndetail                             */
/*                                                                            */
/*                                                                            */
/* Input Parameters: Mobile No                                                */
/*                                                                            */
/* Output Parameters: NIL                                                     */
/*                                                                            */
/* Return Status:                                                             */
/*                                                                            */
/* Usage:                                                                     */
/*                                                                            */
/*                                                                            */
/* Called By: isp_Trasnfer2NewScn                                             */
/*                                                                            */
/* PVCS Version: 1.0                                                          */
/*                                                                            */
/* Version: 5.4                                                               */
/*                                                                            */
/* Data Modifications:                                                        */
/*                                                                            */
/* Updates:                                                                   */
/* Date        Ver  Author       Purposes                                     */
/* 27-06-2013  1.0  Ung          Expand field length to support 2D barcode    */
/* 01-10-2014  1.1  Ung          Support multi language                       */
/* 02-10-2018  1.2  Ung          INC0383981 V_Field need case sensitive in XML*/
/* 17-10-2023  1.3  JLC042       Add DataType and Web Group                   */
/* 2024-09-23  1.4  CYU027       FCR-808 Add Image + Type                     */
/******************************************************************************/

CREATE   PROC [dbo].[isp_OldScn_to_NewScn] (
   @y                NVARCHAR(10),
   @cMsg             NVARCHAR(2048),
   @cDefaultFromCol  NVARCHAR(3) = 'OUT'
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
      @nFieldPos         INT,
      --@cFieldLabel      NVARCHAR(20),
      @nLabelPos         INT,
      @nPos            INT,
      @cNextChar         NVARCHAR(1),
      @x               NVARCHAR(10),
      @InpType         NVARCHAR(20),
      @InpLng            NVARCHAR(10),
      @InpColNo         INT,
      @InpColName         NVARCHAR(20),
      @cValue            NVARCHAR(125),
      @cEndString         NVARCHAR(1024),
      @nNextBlankChar      INT,
      @cMobRecColName      NVARCHAR(30),
      @cDataType         NVARCHAR(15) = NULL,
      @cFieldLabel      NVARCHAR(50)

   DECLARE @Format TABLE
   (
      [mobile]   INT,
      [typ]      NVARCHAR(20)   NULL DEFAULT '',
      [x]         NVARCHAR(10)   NULL DEFAULT '',
      [y]         NVARCHAR(10)   NULL DEFAULT '',
      [length]   NVARCHAR(10)   NULL DEFAULT '',
      [id]      NVARCHAR(20)   NULL DEFAULT '',
      [default]   NVARCHAR(60)   NULL DEFAULT '',
      [type]      NVARCHAR(20)   NULL DEFAULT '',
      [value]      NVARCHAR(125)   NULL DEFAULT '',
      [func]      NVARCHAR(4)      NULL DEFAULT ''
      ,
      [datatype]   NVARCHAR(15)   NULL DEFAULT '',
      [webgroup]   NVARCHAR(20)   NULL DEFAULT ''
   )

   -- Error Message
   IF (
         CHARINDEX('%e', @cMsg, 1) = 1
         OR CHARINDEX('%today', @cMsg, 1) > 0
         OR CHARINDEX('%mob', @cMsg, 1) > 0
         OR CHARINDEX('%dbip', @cMsg, 1) > 0
         OR CHARINDEX('%dbname', @cMsg, 1) > 0
         OR CHARINDEX('%dbsrv', @cMsg, 1) > 0
         OR CHARINDEX('%', @cMsg, 1) = 0
         )
   BEGIN
      EXEC [RDT].[isp_GetFieldAttrs] 
         @cMsg = @cMsg,
         @cDataType = @cDataType OUTPUT,
         @cFieldLabel = @cMsg OUTPUT

      INSERT INTO @Format ([mobile], [typ], [x], [y], [length], [id], [default], [type], [value], [func], [datatype])
      VALUES (0, 'd', '01', @y, '', '', '', '', RTRIM(@cMsg), '', @cDataType) -- (Vicky01)

      GOTO PROCESS_END
   END

   -- Get 1st field position
   SET @nFieldPos = 0
   SET @nFieldPos = CHARINDEX('%', @cMsg, @nFieldPos)

   -- Loop each field
   WHILE @nFieldPos > 0
   BEGIN
      /* 2 types of field:
         I/O_field format = %99...X99*DDDDDDDD...
            %     = field delimeter
            99... = field length
            X     = field type (i=input, d=display, p=password, v=inverse color)
            99    = field sequence
            *     = focus         (not used)
            DD... = default value (not used)

         V_field format = %99...XV_FieldName...
            %     = field delimeter
            99... = field length
            X     = field type (i=input, d=display, p=password, v=inverse color)
            V_FieldName = V_* field on rdt.rdtMobRec
      */
      -- Get x coordinate
      SET @x = CASE 
            WHEN @nFieldPos > 99
               THEN CAST(@nFieldPos AS NVARCHAR(4))
            ELSE RIGHT('0' + RTRIM(CAST(@nFieldPos AS NVARCHAR(2))), 2)
            END
      -- Get next delimeter position
      SET @nNextBlankChar = CHARINDEX(' ', @cMsg, @nFieldPos + 1)

      -- If Not found, use the last character for string as end position
      IF @nNextBlankChar = 0
         SET @nNextBlankChar = LEN(@cMsg) + 1

      -- Get field
      SET @cFieldLabel = SUBSTRING(@cMsg, @nFieldPos, @nNextBlankChar - @nFieldPos)

      EXEC [RDT].[isp_GetFieldAttrs] 
         @cMsg = @cFieldLabel,
         @cDataType = @cDataType OUTPUT,
         @cFieldLabel = @cFieldLabel OUTPUT

      -- Get field type
      SET @nPos = 0

      IF @nPos = 0
         SET @nPos = CHARINDEX('i', @cFieldLabel)

      IF @nPos = 0
         SET @nPos = CHARINDEX('l', @cFieldLabel) -- DropList

      IF @nPos = 0
         SET @nPos = CHARINDEX('d', @cFieldLabel)

      IF @nPos = 0
         SET @nPos = CHARINDEX('p', @cFieldLabel)

      IF @nPos = 0
         SET @nPos = CHARINDEX('v', @cFieldLabel)

      IF @nPos = 0
         SET @nPos = CHARINDEX('m', @cFieldLabel) -- Image

      SET @InpType = CASE SUBSTRING(@cFieldLabel, @nPos, 1)
            WHEN 'p'
               THEN 'p'
            WHEN 'i'
               THEN 'i'
            WHEN 'l'
               THEN 'l'
            WHEN 'd'
               THEN 'd'
            WHEN 'm'
               THEN 'm'
            WHEN 'v'
               THEN 'i' -- Inverse is not used?
            END
      -- Get field length
      SET @InpLng = SUBSTRING(@cFieldLabel, 2, @nPos - 2)

      -- Get field sequence
      SET @nPos = @nPos + 1

      IF ISNUMERIC(SUBSTRING(@cFieldLabel, @nPos, 2)) = 1
      BEGIN
         SET @InpColNo = CAST(SUBSTRING(@cFieldLabel, @nPos, 2) AS INT)
         SET @InpColName = RIGHT('0' + RTRIM(CAST(@InpColNo AS NVARCHAR(2))), 2)

         IF @cDefaultFromCol = 'IN'
            SET @cMobRecColName = 'I_' + @InpColName
         ELSE
            SET @cMobRecColName = 'O_' + @InpColName
      END
      ELSE
      BEGIN
         -- Get V_FieldName
         --SET @InpColName = SUBSTRING(@cFieldLabel, @nPos, @nNextBlankChar-@nPos)
         SET @InpColName = SUBSTRING(@cFieldLabel, @nPos, LEN(@cFieldLabel) + 1 - @nPos)
         SET @cMobRecColName = @InpColName
      END

      -- Default field
      IF RIGHT(@cMobRecColName, 1) = '*'
      BEGIN
         -- Remove the '*'
         SET @cMobRecColName = SUBSTRING(@cMobRecColName, 1, LEN(@cMobRecColName) - 1)

         -- SET field focus
         UPDATE RDT.rdtXML_Root WITH (ROWLOCK)
         SET focus = @cMobRecColName
         WHERE Mobile = 0
      END

      -- Check field exist on MobRec
      IF LEFT(@cMobRecColName, 2) = 'V_'
      BEGIN
         IF NOT EXISTS (
               SELECT TOP 1 1
               FROM INFORMATION_SCHEMA.COLUMNS
               WHERE TABLE_NAME = 'rdtMobRec'
                  AND COLUMN_NAME = @cMobRecColName COLLATE Latin1_General_BIN
               )
         BEGIN
            DECLARE @cErrMsg NVARCHAR(100)
            SET @cErrMsg = 'rdt.rdtMobRec.' + @cMobRecColName + ' not exist. Field name is case sensitive'
            RAISERROR (@cErrMsg, 16, 0)

            RETURN
         END
      END

      --Dropdown List set title
      DECLARE @clistTitle NVARCHAR(20) = ''
      -- 'COND CODE%10l10' as title+list
      IF @InpType = 'l'
      BEGIN
         SET @clistTitle = SUBSTRING(@cMsg, 1, @nFieldPos - 1)
         SET @cMsg = STUFF(@cMsg, 1, @nFieldPos, REPLICATE('`', @nFieldPos));
      END

      -- Insert field
      INSERT INTO @Format ([mobile], [typ], [x], [y], [length], [id], [default], [type], [value], [func], [datatype])
      VALUES (0, @InpType, @x, @y, @InpLng, @InpColName, '', '', @clistTitle, '', @cDataType)

      -- Get the rest of the string after the current field position
      SET @cEndString = ''
      IF @nNextBlankChar > 0
      BEGIN
         SET @cEndString = SUBSTRING(@cMsg, @nNextBlankChar, LEN(@cMsg) - @nNextBlankChar + 1)
      END

      -- Replace the Field with ^ character base on the Field Length defined in rdtScn
      SET @cMsg = LEFT(@cMsg, @nFieldPos - 1) + REPLICATE('`', @InpLng) + @cEndString

      -- Get Next position for new field
      SET @nFieldPos = CHARINDEX('%', @cMsg, @nFieldPos + 1)
   END

   -- Build All the Label Into Temp Table
   SET @nLabelPos = 1
   -- Build the Column X & Y and the Value for the "Label Column"
   SET @nFieldPos = CHARINDEX('`', @cMsg, @nFieldPos)

   WHILE @nFieldPos > 0
   BEGIN
      SET @cValue = SUBSTRING(@cMsg, @nLabelPos, @nFieldPos - @nLabelPos)

      IF RTRIM(@cValue) <> '' AND RTRIM(@cValue) IS NOT NULL
      BEGIN
         EXEC [RDT].[isp_GetFieldAttrs] 
            @cMsg = @cValue,
            @cDataType = @cDataType OUTPUT,
            @cFieldLabel = @cValue OUTPUT

         INSERT INTO @Format ([mobile], [typ], [x], [y], [length], [id], [default], [type], [value], [func], [datatype])
         VALUES (0, 'display', RIGHT('0' + RTRIM(Cast(@nLabelPos AS NVARCHAR(2))), 2), @y, NULL, NULL, NULL, NULL, RTRIM(@cValue), '', @cDataType) -- (Vicky01)
      END

      SET @cNextChar = '`'
      WHILE @cNextChar = '`' OR RTRIM(@cNextChar) = ''
      BEGIN
         SET @nFieldPos = @nFieldPos + 1

         IF @nFieldPos > LEN(@cMsg)
            BREAK

         SET @cNextChar = SUBSTRING(@cMsg, @nFieldPos, 1)
      END

      SET @nLabelPos = @nFieldPos
      SET @nFieldPos = CHARINDEX('`', @cMsg, @nFieldPos + 1)
   END

   IF LEN(@cMsg) >= @nLabelPos
   BEGIN
      SET @cValue = SUBSTRING(@cMsg, @nLabelPos, LEN(@cMsg) - @nLabelPos + 1)

      IF RTRIM(@cValue) <> '' AND RTRIM(@cValue) IS NOT NULL
      BEGIN
         EXEC [RDT].[isp_GetFieldAttrs] 
            @cMsg = @cValue,
            @cDataType = @cDataType OUTPUT,
            @cFieldLabel = @cValue OUTPUT

         INSERT INTO @Format ([mobile], [typ], [x], [y], [length], [id], [default], [type], [value], [func], [datatype])
         VALUES (0, 'display', RIGHT('0' + RTRIM(Cast(@nLabelPos AS NVARCHAR(2))), 2), @y, NULL, NULL, NULL, NULL, RTRIM(@cValue), '', @cDataType) -- (Vicky01)
      END
   END

   PROCESS_END:

   UPDATE @Format
   SET [default] = CASE [default]
         WHEN ''
            THEN NULL
         ELSE [default]
         END,
      typ = CASE typ
         WHEN 'display'
            THEN 'd'
         ELSE typ
         END

   SELECT * FROM @Format ORDER BY [X]

END


GO