SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: rdtScr2XML  Ver 2.0                                */
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
/* 2009-11-23   ChewKP        Changes For RDT2 Column Attributes        */
/* 2010-03-30   Shong         Bug Fixing                                */
/* 2010-11-26   Ung           Add %dbip and %dbname                     */
/* 2010-12-04   ChewKP        Changes for RDT2 Column Attribute         */
/* 2011-07-21   Ung           Add %dbsrv                                */
/* 2011-12-09   ChewKP        Display Default DropDown Value @ Top      */
/*                            (ChewKP01)                                */
/* 2013-09-29   Ung           Support multi language                    */
/* 2015-10-02   Ung           Performance tuning for CN Nov 11          */
/* 2019-06-03   Paddy         Performance tuning                        */
/************************************************************************/

CREATE PROC [RDT].[rdtScr2XML] (
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
DECLARE @cColLength     NVARCHAR(10)
DECLARE @cColLookUpView NVARCHAR(200)
DECLARE @cFieldID       NVARCHAR(20)
DECLARE @cMobRecColName NVARCHAR(30)

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
      SET @cXML = @cXML + '<field typ="output" x="' + @cX + '" y="' + @cY + 
         '" value="' + @cColText + 
         '" color="' + @cTxtColor + '"/>'
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
         '" color="' + @cTxtColor + '"/>'
   ELSE
      SET @cXML = @cXML + '<field typ="input" x="' + @cX + '" y="' + @cY + 
         '" length="' + @cColLength + 
         '" id="' + @cFieldID + 
         '" default="' + @cColText + 
         '" match="' + @cColMatch + '"/>'
   RETURN
END

--- Password field
ELSE IF @cColType = 'p'
BEGIN
   -- Output XML
   SET @cXML = @cXML + '<field typ="password" x="' + @cX + '" y="' + @cY + 
      '" length="' + @cColLength + 
      '" id="' + @cFieldID + 
      '" match="' + @cColMatch + '"/>'
   RETURN
END

--- Combobox
ELSE IF @cColType = 'ddlb'
BEGIN
   DECLARE @tDropDown TABLE 
   (
	   RowRef INT IDENTITY(1,1),
      ColText   NVARCHAR (125) NULL, 
      ColValue  NVARCHAR (125) NULL
   )

   -- Decide view or SP
   DECLARE @cSQL NVARCHAR(MAX)
   IF CHARINDEX('RDT.V_', @cColLookUpView) > 0
      SET @cSQL = 'SELECT * FROM ' + @cColLookUpView
   ELSE
      SET @cSQL = RTRIM( @cColLookUpView) + ' @nMobile = ' + CAST( @nMobile AS NVARCHAR( 10))

   -- Get data
   INSERT INTO @tDropDown( ColText, ColValue)
   EXEC (@cSQL)

   -- Get row count
   DECLARE @nRowCount INT
   SELECT @nRowCount = COUNT( 1) FROM @tDropDown

   -- Drop down with data 
   IF @nRowCount > 0
   BEGIN
      -- Header
      SET @cXML = @cXML + '<field typ="select" x="' + @cX + '" y="' + @cY + 
         '" id="' + @cFieldID + 
         '" color="' + @cTxtColor + '">'

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
      SET @cXML = @cXML + '<field typ="radio" id="' + @cFieldID + '">'

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
      '" value="' + @cColVal + '"/>'
   RETURN
END


GO