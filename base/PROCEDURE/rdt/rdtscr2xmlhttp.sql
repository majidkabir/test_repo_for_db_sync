SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store Procedure: rdtScr2XMLHttp  Ver 2.0                                */
/* Copyright      : Maersk                                                 */
/*                                                                         */
/* Purpose: Convert screen object (rdtScnDetail) to XML format <field>     */
/*                                                                         */
/* Date         Ver. Author    Purposes                                    */
/* 26-Sep-2023  1.0  YZH230    Created base on rdtScr2XMLHttp 2019-06-03   */
/* 17-07-2024   1.1  JACKC     UWP-21829 Error msg not visible             */
/* 2024-09-23   1.3  CYU027    Add Type Image                              */
/* 2025-01-09   1.4  CYU027    UWP-26488 Add Type List                     */
/***************************************************************************/

CREATE   PROC [RDT].[rdtScr2XMLHttp] (
    @nMobile    INT
   ,@cLangCode  NVARCHAR(3)
   ,@nScnKey    INT
   ,@cY         NVARCHAR(2)
   ,@cColText   NVARCHAR(60)
   ,@cXML       NVARCHAR(MAX) OUTPUT
)
AS
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

DECLARE @nScn           INT
DECLARE @cFieldNo       NVARCHAR(20)
DECLARE @cX             NVARCHAR(2)
DECLARE @cTxtColor      NVARCHAR(20)
DECLARE @cColType       NVARCHAR(20)
DECLARE @cColMatch      NVARCHAR(255)
DECLARE @cColVal        NVARCHAR(50)
DECLARE @bSelected      BIT
DECLARE @cColLength     NVARCHAR(10)
DECLARE @cColLookUpView NVARCHAR(200)
DECLARE @cFieldID       NVARCHAR(20)
DECLARE @cMobRecColName NVARCHAR(30)
DECLARE @cDataType      NVARCHAR(15)
DECLARE @cWebGroup      NVARCHAR(20)
DECLARE @cMsgLong       NVARCHAR(250)
DECLARE @cAttrAndVal    NVARCHAR(MAX) = ''

DECLARE @cSQL NVARCHAR(MAX)
DECLARE @nRowCount INT
DECLARE @tDropDown TABLE
    (
       RowRef INT IDENTITY(1,1),
       ColText   NVARCHAR (125) NULL,
       ColValue  NVARCHAR (125) NULL,
       SELECTED  BIT
    )

-- Custom messages
IF @nScnKey IS NULL
BEGIN
   SET @cXML = @cXML + '<field typ="output" x="01" y="' + @cY + '" value="' + @cColText + '"/>'
   RETURN
END

/*                FieldNo  ColType  ColText  ColValue    ColValueLenght ColLookupView
                  -------- -------- -------- ----------- -------------- -------------
   Label                   d        Value                0

   field display  01...15  d                             Numeric
   field input    01...15  i                             Numeric
                  V_field  i                             Numeric
   field password 01...15  p                             Numeric

   drop down      01...15  ddlb              Text        Numeric        SP/View

   radio button1  01       rb       Text     Value       1
   radio button2  01...15  rb       Text     Value       1

   checkbox1      01       cbx      Text     Value       Numeric
   checkbox2      02...15  cbx      Text     Value       Numeric
   
*/

-- Get screen defination
SELECT @nScn = Scn
      ,@cFieldNo = FieldNo
      ,@cX = XCol
      ,@cY = YRow
      ,@cTxtColor = TextColor
      ,@cColType = ColType
      ,@cColMatch = ColRegExp
      ,@cColText = ColText
      ,@cColVal = ColValue
      ,@cColLength = CAST( ColValueLength AS NVARCHAR(10))
      ,@cColLookUpView = ColLookUpView
      ,@cDataType = DataType
      ,@cWebGroup = WebGroup
FROM rdt.rdtSCNDetail WITH (NOLOCK)
WHERE SCNKey = @nScnKey

IF @cFieldNo IS NULL 
   SET @cFieldNo = ''

-- Calc field ID
IF ISNUMERIC( @cFieldNo) = 1
   SET @cFieldID = 'I_Field' + @cFieldNo
ELSE
   SET @cFieldID = @cFieldNo

--- Label / display field
IF @cColType = 'd'
BEGIN
   -- Label field
   IF @cFieldNo = ''
   BEGIN
      -- Error field
      IF CHARINDEX('%e', @cColText, 1) = 1
      BEGIN
         -- Get error message
         SELECT @cColText = RTRIM( ISNULL( ErrMsg, '')) FROM rdt.rdtMOBREC (NOLOCK) WHERE Mobile = @nMobile

         -- Get long error message
         DECLARE @nPosition INT
         DECLARE @nMsgID    INT
            SELECT @nPosition = PATINDEX('%[^0-9]%', @cColText)
               IF @nPosition > 1
               BEGIN
                  SET @nMsgID = SUBSTRING( @cColText, 0, @nPosition) 
                  SET @cMsgLong = rdt.rdtGetMessageLong( @nMsgID, @cLangCode, 'DSP')
               END
      
         -- Get error color
         SELECT @cTxtColor = RTRIM( ISNULL( NSQLValue, '')) FROM RDT.NSQLCONFIG (NOLOCK) WHERE ConfigKey = 'DefaultErrMSGColor'
      END
      
      -- Special field on login screen
      ELSE IF @nScn = 0
      BEGIN
         -- DB server IP
         IF CHARINDEX( '%dbip', @cColText) > 0
            -- SELECT @cColText = REPLACE( @cColText, '%dbip', CAST( (select local_net_address from sys.dm_exec_connections where session_id = @@SPID) as NVARCHAR(20)) )
            SELECT @cColText = REPLACE( @cColText, '%dbip', CAST( CONNECTIONPROPERTY('local_net_address') as NVARCHAR(20)) )
      
         -- DB Server Name
         ELSE IF CHARINDEX('%dbsrv', @cColText, 1) > 0
            SELECT @cColText = REPLACE( @cColText, '%dbsrv', CAST( @@servername AS NVARCHAR(20)) )
   
         -- DB name
         ELSE IF CHARINDEX('%dbname', @cColText) > 0
            SELECT @cColText = REPLACE( @cColText, '%dbname', CAST( DB_NAME( DB_ID()) AS NVARCHAR(20)) )   
   
         -- Today Date field
         ELSE IF CHARINDEX( '%today', @cColText) > 0
            SELECT @cColText = REPLACE( @cColText,'%today', CAST( GETDATE() AS NVARCHAR(20)))
      END
   END
   
   -- Display field
   ELSE
   BEGIN
      -- Get display field value
      IF ISNUMERIC( @cFieldNo) = 1
         SET @cMobRecColName = 'O_Field' + @cFieldNo
      ELSE 
         SET @cMobRecColName = @cFieldNo
     EXEC rdt.rdtGetColumnValue @nMobile, @cMobRecColName, @cColText OUTPUT
   END
   
   -- Output XML
   IF @cColText <> ''
   BEGIN
      SET @cColText = rdt.rdtReplaceSpecialCharInXMLData( @cColText)

      --1.1 Jackc
      IF @cMsgLong IS NOT NULL AND @cMsgLong <> ''
         SET @cMsgLong = rdt.rdtReplaceSpecialCharInXMLData( @cMsgLong)
      --1.1 Jackc end

      --Add Style in XML Attribute, by storerkey + line + Scn
      EXEC rdt.rdtGetExtraAttribute @nScn, @cY, @nMobile, @cAttrAndVal OUTPUT

      IF @cFieldNo = '' 
         SET @cXML = @cXML + '<field typ="output" x="' + @cX + '" y="' + @cY +   
            '" value="' + CASE WHEN @cMsgLong IS NULL OR @cMsgLong = '' THEN @cColText ELSE @cMsgLong END +   
            '" color="' + @cTxtColor +
            '" label="true"' +
            + @cAttrAndVal +
            ' webgroup="' + @cWebGroup + '"/>'
      ELSE
         SET @cXML = @cXML + '<field typ="output" x="' + @cX + '" y="' + @cY +   
            '" value="' + CASE WHEN @cMsgLong IS NULL OR @cMsgLong = '' THEN @cColText ELSE @cMsgLong END +   
            '" color="' + @cTxtColor + '"'
            + @cAttrAndVal +
            ' webgroup="' + @cWebGroup + '"/>'
   END

   RETURN
END

--- Input field
ELSE IF @cColType = 'i'
BEGIN
   -- Get field value
   IF ISNUMERIC( @cFieldNo) = 1
      SET @cMobRecColName = 'O_Field' + @cFieldNo
   ELSE 
      SET @cMobRecColName = @cFieldNo
   EXEC rdt.rdtGetColumnValue @nMobile, @cMobRecColName, @cColText OUTPUT

   IF @cColText <> ''
      SET @cColText = rdt.rdtReplaceSpecialCharInXMLData( @cColText)

   INPUT_FIELD:
   -- Get field attribute
   DECLARE @cFieldAttr NVARCHAR(1)
   IF ISNUMERIC( @cFieldNo) = 1
   BEGIN
      SET @cMobRecColName = 'FieldAttr'+ @cFieldNo
      EXEC rdt.rdtGetColumnValue @nMobile, @cMobRecColName, @cFieldAttr OUTPUT
   END

   -- Output XML
   IF @cFieldAttr = 'O' -- Disabled
      SET @cXML = @cXML + '<field typ="output" x="' + @cX + '" y="' + @cY + 
         '" value="' + @cColText + 
         '" color="' + @cTxtColor + 
         '" webgroup="' + @cWebGroup + '"/>'
   ELSE
      SET @cXML = @cXML + '<field typ="input" x="' + @cX + '" y="' + @cY + 
         '" length="' + @cColLength + 
         '" id="' + @cFieldID + 
         '" default="' + @cColText + 
         '" match="' + @cColMatch + 
         '" datatype="' + @cDataType + 
         '" webgroup="' + @cWebGroup + '"/>'

   RETURN
END

--- Password field
ELSE IF @cColType = 'p'
BEGIN
   -- Output XML
   SET @cXML = @cXML + '<field typ="password" x="' + @cX + '" y="' + @cY + 
      '" length="' + @cColLength + 
      '" id="' + @cFieldID + 
      '" match="' + @cColMatch + 
      '" webgroup="' + @cWebGroup + '"/>'

   RETURN
END

--- Combobox
ELSE IF @cColType = 'ddlb'
BEGIN
   -- Decide view or SP
   IF CHARINDEX('RDT.V_', @cColLookUpView) > 0
      SET @cSQL = 'SELECT * FROM ' + @cColLookUpView
   ELSE
      SET @cSQL = RTRIM( @cColLookUpView) + ' @nMobile = ' + CAST( @nMobile AS NVARCHAR( 10))

   -- Get data
   INSERT INTO @tDropDown( ColText, ColValue)
   EXEC (@cSQL)

   -- Get row count
   SELECT @nRowCount = COUNT( 1) FROM @tDropDown

   -- Drop down with data 
   IF @nRowCount > 0
   BEGIN
      -- Header
      SET @cXML = @cXML + '<field typ="select" x="' + @cX + '" y="' + @cY + 
         '" id="' + @cFieldID + 
         '" color="' + @cTxtColor + 
         '" webgroup="' + @cWebGroup + '">'

      -- Get default value of DropDown (from its OutField)
      DECLARE @cDropDownOutputField  NVARCHAR(10)
      DECLARE @cDropDownDefaultValue NVARCHAR(20)
      SET @cDropDownDefaultValue = ''
      SET @cDropDownOutputField = 'O_Field' + @cFieldNo
      EXEC rdt.rdtGetColumnValue @nMobile, @cDropDownOutputField, @cDropDownDefaultValue OUTPUT

      -- Loop detail
      DECLARE @curDropDown CURSOR
      SET @curDropDown = CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT ColText, ColValue
         FROM @tDropDown
         ORDER BY 
            CASE ColValue WHEN @cDropDownDefaultValue THEN 0 ELSE 1 END, 
            RowRef
      OPEN @curDropDown
      FETCH NEXT FROM @curDropDown INTO @cColText, @cColVal
      WHILE @@FETCH_STATUS = 0
      BEGIN
         IF @cColText <> ''
            SET @cColText = rdt.rdtReplaceSpecialCharInXMLData( @cColText)
         IF @cColVal <> ''
            SET @cColVal = rdt.rdtReplaceSpecialCharInXMLData( @cColVal)

         SET @cXML = @cXML + '<option text="' + @cColText + '" value="' + @cColVal + '"/>'
         FETCH NEXT FROM @curDropDown INTO @cColText, @cColVal
      END

      -- Footer
      SET @cXML = @cXML + '</field>'
      RETURN
   END
END

ELSE IF @cColType = 'l'
BEGIN

   DECLARE @cListTitle NVARCHAR (20) = ''
   SET @cListTitle = @cColText
   -- Get display field value
   IF ISNUMERIC( @cFieldNo) = 1
      SET @cMobRecColName = 'O_Field' + @cFieldNo
   ELSE
      SET @cMobRecColName = @cFieldNo
   EXEC rdt.rdtGetColumnValue @nMobile, @cMobRecColName, @cColText OUTPUT

   --LIST SP NOT EXISTS, treat as normal output field
   IF NOT EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM( @cColText) AND type = 'P')
      GOTO INPUT_FIELD
   -- SP in @cColText
   SET @cSQL = 'rdt.' + RTRIM( @cColText)
                  + ' @nMobile = ' + CAST( @nMobile AS NVARCHAR( 10))

   -- Get data
   INSERT INTO @tDropDown( ColText, ColValue, SELECTED)
      EXEC (@cSQL)

   -- Get row count
   SELECT @nRowCount = COUNT( 1) FROM @tDropDown

   -- Drop down with data
   IF @nRowCount > 0
   BEGIN
      -- Header
      SET @cXML = @cXML + '<field typ="select" x="' + @cX + '" y="' + @cY +
                  '" id="' + @cFieldID +
                  '" color="' + @cTxtColor +
                  '" title-label="' + @cListTitle +
                  '" webgroup="' + @cWebGroup + '">'

      -- Loop detail
      DECLARE @curList CURSOR
      SET @curList = CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT ColText, ColValue, SELECTED
         FROM @tDropDown

      OPEN @curList
      FETCH NEXT FROM @curList INTO @cColText, @cColVal, @bSelected
      WHILE @@FETCH_STATUS = 0
         BEGIN
            IF @cColText <> ''
               SET @cColText = rdt.rdtReplaceSpecialCharInXMLData( @cColText)
            IF @cColVal <> ''
               SET @cColVal = rdt.rdtReplaceSpecialCharInXMLData( @cColVal)

            SET @cXML = @cXML + '<option text="' + @cColText
                           + '" value="' + @cColVal
                           + IIF(@bSelected = 1,'" selected="TRUE', '')
                           + '"/>'
            FETCH NEXT FROM @curList INTO @cColText, @cColVal, @bSelected
         END

      -- Footer
      SET @cXML = @cXML + '</field>'
      RETURN
   END
END

--- Radio button
ELSE IF @cColType = 'rb'
BEGIN
   DECLARE @nMaxScnKey INT
   DECLARE @nMinScnKey INT
   SELECT 
      @nMinScnKey = MIN( ScnKey), 
      @nMaxScnKey = MAX( ScnKey) 
   FROM rdt.rdtScnDetail (NOLOCK)
   WHERE scn = @nScn
      AND FieldNo = @cFieldNo
      AND ColType = @cColType

   -- Header
   IF @nScnKey = @nMinScnKey
      SET @cXML = @cXML + '<field typ="radio" id="' + @cFieldID + '" webgroup="' + @cWebGroup +'">'

   -- Radio
   IF @nScnKey BETWEEN @nMinScnKey AND @nMaxScnKey
   BEGIN
      IF @cColText <> ''
         SET @cColText = rdt.rdtReplaceSpecialCharInXMLData( @cColText)
      IF @cColVal <> ''
         SET @cColVal = rdt.rdtReplaceSpecialCharInXMLData( @cColVal)      

      SET @cXML = @cXML + '<option x="' + @cX + '" y="' + @cY + '" text="' + @cColText + '" value="' + @cColVal + '"/>'
   END

   -- Footer
   IF @nScnKey = @nMaxScnKey
      SET @cXML = @cXML + '</field>'

   RETURN
END

--- Checkbox
ELSE IF @cColType = 'cbx'
BEGIN
   IF @cColText <> ''
      SET @cColText = rdt.rdtReplaceSpecialCharInXMLData( @cColText)
   IF @cColVal <> ''
      SET @cColVal = rdt.rdtReplaceSpecialCharInXMLData( @cColVal)  
   
   SET @cXML = @cXML + '<field typ="checkbox" x="' + @cX + '" y="' + @cY + 
      '" id="' + @cFieldID + 
      '" text="' + @cColText + 
      '" value="' + @cColVal + 
      '" webgroup="' + @cWebGroup +'"/>'
   RETURN
END

ELSE IF @cColType = 'm'
BEGIN

   IF ISNUMERIC( @cFieldNo) = 1
      SET @cMobRecColName = 'O_Field' + @cFieldNo
   ELSE
      SET @cMobRecColName = @cFieldNo
   EXEC rdt.rdtGetColumnValue @nMobile, @cMobRecColName, @cColText OUTPUT

   IF @cColText <> ''
      SET @cColText = rdt.rdtReplaceSpecialCharInXMLData( @cColText)
   ELSE
      RETURN


   EXEC rdt.rdtGetExtraAttribute @nScn, @cY, @nMobile, @cAttrAndVal OUTPUT


   SET @cXML = @cXML + '<field typ="img" x="' + @cX + '" y="' + @cY +
               '" value="' + @cColText +'"'
               + @cAttrAndVal +
               ' webgroup="' + @cWebGroup +'"/>'

   RETURN

END



GO