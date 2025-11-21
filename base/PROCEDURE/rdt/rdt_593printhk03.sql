SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_593PrintHK03                                          */
/*                  Call by rdtfnc_PrintLabelReport                           */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2021-07-12 1.0  ML         Copy from rdt_593PrintHK01 v1.6                 */
/*                            for new Parameters version of RDT Fn593         */
/* 2021-07-28 1.1  ML         1. Check Codelkup.Short has 'V' before createing*/
/*                               Temp table #tVar                             */
/*                            2. Add ErrLog for Try..Catch statement          */
/* 2022-08-09 1.2  ML         Fix @cFocusField no effect issue                */
/******************************************************************************/

CREATE PROC [RDT].[rdt_593PrintHK03] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5),
   @cStorerKey    NVARCHAR(15),
   @cLabelPrinter NVARCHAR(20),
   @cPaperPrinter NVARCHAR(20),
   @cOption       NVARCHAR(10),
   @cParam1Label  NVARCHAR(60) OUTPUT,
   @cParam2Label  NVARCHAR(60) OUTPUT,
   @cParam3Label  NVARCHAR(60) OUTPUT,
   @cParam4Label  NVARCHAR(60) OUTPUT,
   @cParam5Label  NVARCHAR(60) OUTPUT,
   @cParam1Value  NVARCHAR(60) OUTPUT,
   @cParam2Value  NVARCHAR(60) OUTPUT,
   @cParam3Value  NVARCHAR(60) OUTPUT,
   @cParam4Value  NVARCHAR(60) OUTPUT,
   @cParam5Value  NVARCHAR(60) OUTPUT,
   @cFieldAttr02  NVARCHAR( 1) OUTPUT,
   @cFieldAttr04  NVARCHAR( 1) OUTPUT,
   @cFieldAttr06  NVARCHAR( 1) OUTPUT,
   @cFieldAttr08  NVARCHAR( 1) OUTPUT,
   @cFieldAttr10  NVARCHAR( 1) OUTPUT,
   @nErrNo        INT          OUTPUT,
   @cErrMsg       NVARCHAR(20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cJobName         NVARCHAR(50)  = ''
         , @cCode2           NVARCHAR(30)  = ''
         , @cValidateAction  NVARCHAR(60)  = ''
         , @cShort           NVARCHAR(10)  = ''
         , @cReportType1     NVARCHAR(30)  = ''
         , @cReportType      NVARCHAR(30)  = ''
         , @cFocusField1     NVARCHAR(20)  = ''
         , @cFocusField      NVARCHAR(20)  = ''
         , @cMsgText         NVARCHAR(250) = ''
         , @cWarningMsg      NVARCHAR(250) = ''
         , @cValidateExp     NVARCHAR(MAX) = ''
         , @cReportTypeExp   NVARCHAR(MAX) = ''
         , @cPrintCmdExp     NVARCHAR(MAX) = ''
         , @cPrintCmd        NVARCHAR(MAX) = ''
         , @cLabelWinPrinter NVARCHAR(128) = ''
         , @cPaperWinPrinter NVARCHAR(128) = ''
         , @c_StorerKey      NVARCHAR(15)  = @cStorerKey
         , @c_Facility       NVARCHAR(5)   = @cFacility
         , @c_Sku            NVARCHAR(20)  = ''
         , @cParam6Value     NVARCHAR(60)  = ''
         , @cParam7Value     NVARCHAR(60)  = ''
         , @cParam8Value     NVARCHAR(60)  = ''
         , @cParam9Value     NVARCHAR(60)  = ''
         , @cParam10Value    NVARCHAR(60)  = ''
         , @cParams          NVARCHAR(10)  = ''
         , @nNoOfCopy        INT           = NULL
         , @bFocusEmptyFld   INT           = 1
         , @bSuccess         INT
         , @nTemp            INT
         , @cTemp            NVARCHAR(250)
         , @nRptTypeCnt      INT
         , @tReportParam     VariableTable
         , @cSQL             NVARCHAR(MAX)
         , @cSQLParam        NVARCHAR(MAX)
         , @cParmFldList     NVARCHAR(MAX)
         , @cParmValList     NVARCHAR(MAX)
         , @c_p_StorerKey    NVARCHAR(15)
         , @c_p_Facility     NVARCHAR(5)
         , @c_p_Sku          NVARCHAR(20)
         , @c_p_Param1       NVARCHAR(60)
         , @c_p_Param2       NVARCHAR(60)
         , @c_p_Param3       NVARCHAR(60)
         , @c_p_Param4       NVARCHAR(60)
         , @c_p_Param5       NVARCHAR(60)
         , @c_p_Param6       NVARCHAR(60)
         , @c_p_Param7       NVARCHAR(60)
         , @c_p_Param8       NVARCHAR(60)
         , @c_p_Param9       NVARCHAR(60)
         , @c_p_Param10      NVARCHAR(60)
         , @n_p_NoOfCopy     INT
         , @c_p_PrintCmd     NVARCHAR(MAX)

   SET @nErrNo = 0


   -- Get Codelkup RDTLBLRPT values
   SELECT @cShort         = ISNULL(Short,'')
        , @cReportType1   = ISNULL(Code2,'')
        , @cReportTypeExp = ISNULL(Notes,'')
        , @cPrintCmdExp   = ISNULL(Notes2,'')
     FROM dbo.CodeLkup WITH (NOLOCK)
    WHERE Listname = 'RDTLBLRPT' AND Code = @cOption AND Storerkey = @c_StorerKey
    ORDER BY Code2

    SET @cParams = CASE WHEN @cFieldAttr02='' THEN 'Y' ELSE 'N' END
                 + CASE WHEN @cFieldAttr04='' THEN 'Y' ELSE 'N' END
                 + CASE WHEN @cFieldAttr06='' THEN 'Y' ELSE 'N' END
                 + CASE WHEN @cFieldAttr08='' THEN 'Y' ELSE 'N' END
                 + CASE WHEN @cFieldAttr10='' THEN 'Y' ELSE 'N' END

   -- Check at least one parameter input
   IF NOT ((@cFieldAttr02='' AND ISNULL(@cParam1Value,'')<>'') OR
           (@cFieldAttr04='' AND ISNULL(@cParam2Value,'')<>'') OR
           (@cFieldAttr06='' AND ISNULL(@cParam3Value,'')<>'') OR
           (@cFieldAttr08='' AND ISNULL(@cParam4Value,'')<>'') OR
           (@cFieldAttr10='' AND ISNULL(@cParam5Value,'')<>'') )
   BEGIN
      SET @nErrNo = 172201
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Input Required
      GOTO Quit
   END

   -- Check mandatory parameter input
   -- (Parameter Text Label start with * means mandatory)
   SET @nTemp = CASE WHEN (@cFieldAttr02='' AND LEFT(@cParam1Label,1)='*' AND ISNULL(@cParam1Value,'')='') THEN 2
                     WHEN (@cFieldAttr04='' AND LEFT(@cParam2Label,1)='*' AND ISNULL(@cParam2Value,'')='') THEN 4
                     WHEN (@cFieldAttr06='' AND LEFT(@cParam3Label,1)='*' AND ISNULL(@cParam3Value,'')='') THEN 6
                     WHEN (@cFieldAttr08='' AND LEFT(@cParam4Label,1)='*' AND ISNULL(@cParam4Value,'')='') THEN 8
                     WHEN (@cFieldAttr10='' AND LEFT(@cParam5Label,1)='*' AND ISNULL(@cParam5Value,'')='') THEN 10
                     ELSE 0
                END
   IF @nTemp > 0
   BEGIN
      SET @nErrNo = 172202
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Input Required
      EXEC rdt.rdtSetFocusField @nMobile, @nTemp
      GOTO Quit
   END

   IF ISNULL(@cLabelPrinter,'') <> ''
   BEGIN
      SELECT @cLabelWinPrinter = LEFT(WinPrinter, CHARINDEX(',',WinPrinter+',') -1)
        FROM rdt.rdtPrinter WITH (NOLOCK)
       WHERE PrinterID = @cLabelPrinter
   END

   IF ISNULL(@cPaperPrinter,'') <> ''
   BEGIN
      SELECT @cPaperWinPrinter = LEFT(WinPrinter, CHARINDEX(',',WinPrinter+',') -1)
        FROM rdt.rdtPrinter WITH (NOLOCK)
       WHERE PrinterID = @cPaperPrinter
   END

   -- Prepare Temp Table for dynamic variables if necessary
   IF CHARINDEX('V', @cShort) >= 1
   BEGIN
      IF OBJECT_ID('tempdb..#tVar') IS NOT NULL
         DROP TABLE #tVar
   
      CREATE TABLE #tVar (
           [Var]       NVARCHAR(50)  NOT NULL
         , [Value]     NVARCHAR(MAX) NULL
         PRIMARY KEY CLUSTERED ([Var])
      )
   END

   -- Validate Input
   IF EXISTS(SELECT TOP 1 1 FROM dbo.CodeLkup WITH (NOLOCK)
              WHERE Listname = 'RDTLBLRVLD' AND Code = @cOption AND Storerkey = @c_StorerKey)
   BEGIN
      DECLARE C_VALIDATION CURSOR FAST_FORWARD READ_ONLY FOR
       SELECT FocusField     = Short
            , MsgText        = ISNULL(RTRIM(Long), '')
            , ValidateExp    = Notes
            , Code2          = Code2
            , ValidateAction = UDF01
         FROM dbo.CodeLkup WITH (NOLOCK)
        WHERE Listname = 'RDTLBLRVLD' AND Code = @cOption AND Storerkey = @c_StorerKey
          AND ISNULL(Notes,'')<>''
        ORDER BY Code2

      OPEN C_VALIDATION

      SET @cSQLParam = '@bSuccess    INT           OUTPUT'
                     +',@cMsgText    NVARCHAR(250) OUTPUT'
                     +',@cWarningMsg NVARCHAR(250) OUTPUT'
                     +',@cStorerKey  NVARCHAR(15)  OUTPUT'
                     +',@cFacility   NVARCHAR(5)   OUTPUT'
                     +',@cSku        NVARCHAR(20)  OUTPUT'
                     +',@cParam1     NVARCHAR(60)  OUTPUT'
                     +',@cParam2     NVARCHAR(60)  OUTPUT'
                     +',@cParam3     NVARCHAR(60)  OUTPUT'
                     +',@cParam4     NVARCHAR(60)  OUTPUT'
                     +',@cParam5     NVARCHAR(60)  OUTPUT'
                     +',@cParam6     NVARCHAR(60)  OUTPUT'
                     +',@cParam7     NVARCHAR(60)  OUTPUT'
                     +',@cParam8     NVARCHAR(60)  OUTPUT'
                     +',@cParam9     NVARCHAR(60)  OUTPUT'
                     +',@cParam10    NVARCHAR(60)  OUTPUT'
                     +',@nNoOfCopy   INT           OUTPUT'
                     +',@cOption     NVARCHAR(10)'
                     +',@cCode2      NVARCHAR(30)  OUTPUT'
                     +',@cValidateAction  NVARCHAR(60)  OUTPUT'
                     +',@cFocusField      NVARCHAR(20)  OUTPUT'
                     +',@cReportType      NVARCHAR(30)  OUTPUT'
                     +',@cReportTypeExp   NVARCHAR(MAX) OUTPUT'
                     +',@cPrintCmdExp     NVARCHAR(MAX) OUTPUT'
                     +',@cPrintCmd        NVARCHAR(MAX) OUTPUT'
                     +',@cLabelPrinter    NVARCHAR(10)  OUTPUT'
                     +',@cPaperPrinter    NVARCHAR(10)  OUTPUT'
                     +',@cLabelWinPrinter NVARCHAR(128) OUTPUT'
                     +',@cPaperWinPrinter NVARCHAR(128) OUTPUT'
                     +',@nMobile      INT'
                     +',@nFunc        INT'
                     +',@nStep        INT'
                     +',@cLangCode    NVARCHAR(3)'
                     +',@nInputKey    INT'
                     +',@cParam1Label NVARCHAR(60)  OUTPUT'
                     +',@cParam2Label NVARCHAR(60)  OUTPUT'
                     +',@cParam3Label NVARCHAR(60)  OUTPUT'
                     +',@cParam4Label NVARCHAR(60)  OUTPUT'
                     +',@cParam5Label NVARCHAR(60)  OUTPUT'
                     +',@cFieldAttr02 NVARCHAR(1)   OUTPUT'
                     +',@cFieldAttr04 NVARCHAR(1)   OUTPUT'
                     +',@cFieldAttr06 NVARCHAR(1)   OUTPUT'
                     +',@cFieldAttr08 NVARCHAR(1)   OUTPUT'
                     +',@cFieldAttr10 NVARCHAR(1)   OUTPUT'

      WHILE 1=1
      BEGIN
         FETCH NEXT FROM C_VALIDATION
          INTO @cFocusField1, @cMsgText, @cValidateExp, @cCode2, @cValidateAction

         IF @@FETCH_STATUS<>0
            BREAK

         SELECT @bSuccess = 0
              , @cWarningMsg = ''
              , @cFocusField = ''

         IF @cValidateAction='DECODE'
            SET @cSQL = 'SET @bSuccess=1 BEGIN ' +CHAR(10)+ @cValidateExp +CHAR(10)+ 'END'
         ELSE
            SET @cSQL = 'IF (' + @cValidateExp + ') SET @bSuccess=1'

         BEGIN TRY
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam
               , @bSuccess         OUTPUT
               , @cMsgText         OUTPUT
               , @cWarningMsg      OUTPUT
               , @c_StorerKey      OUTPUT
               , @c_Facility       OUTPUT
               , @c_Sku            OUTPUT
               , @cParam1Value     OUTPUT
               , @cParam2Value     OUTPUT
               , @cParam3Value     OUTPUT
               , @cParam4Value     OUTPUT
               , @cParam5Value     OUTPUT
               , @cParam6Value     OUTPUT
               , @cParam7Value     OUTPUT
               , @cParam8Value     OUTPUT
               , @cParam9Value     OUTPUT
               , @cParam10Value    OUTPUT
               , @nNoOfCopy        OUTPUT
               , @cOption
               , @cCode2           OUTPUT
               , @cValidateAction  OUTPUT
               , @cFocusField      OUTPUT
               , @cReportType1     OUTPUT
               , @cReportTypeExp   OUTPUT
               , @cPrintCmdExp     OUTPUT
               , @cPrintCmd        OUTPUT
               , @cLabelPrinter    OUTPUT
               , @cPaperPrinter    OUTPUT
               , @cLabelWinPrinter OUTPUT
               , @cPaperWinPrinter OUTPUT
               , @nMobile
               , @nFunc
               , @nStep
               , @cLangCode
               , @nInputKey
               , @cParam1Label     OUTPUT
               , @cParam2Label     OUTPUT
               , @cParam3Label     OUTPUT
               , @cParam4Label     OUTPUT
               , @cParam5Label     OUTPUT
               , @cFieldAttr02     OUTPUT
               , @cFieldAttr04     OUTPUT
               , @cFieldAttr06     OUTPUT
               , @cFieldAttr08     OUTPUT
               , @cFieldAttr10     OUTPUT
         END TRY
         BEGIN CATCH
            SELECT @nTemp = ISNULL(ERROR_NUMBER(),0)
                 , @cTemp = ISNULL(ERROR_MESSAGE(),'')
            EXEC nsp_logerror @nTemp, @cTemp, 'rdt_593PrintHK03 (Validation Loop)'

            SET @nErrNo = 172203
            SET @cErrMsg = 'VALIDATION ERR^' + ISNULL(@cCode2,'') --VALIDATION ERR
            BREAK
         END CATCH

         IF ISNULL(@cFocusField,'')<>''
           SET @cFocusField1 = @cFocusField
         ELSE IF ISNULL(@bSuccess,0)=1
           SET @cFocusField1 = ''

         IF ISNUMERIC(@cFocusField1) = 1
         BEGIN
            SET @nTemp = CONVERT(INT, CONVERT(FLOAT, @cFocusField1))
            IF @nTemp >= 1 AND @nTemp <=10 AND SUBSTRING(@cParams,@nTemp,1) = 'Y'
            BEGIN
               SET @nTemp = @nTemp * 2
               EXEC rdt.rdtSetFocusField @nMobile, @nTemp
            END
         END

         IF ISNULL(@bSuccess,0)<>1
         BEGIN
            IF ISNULL(@cValidateAction,'')='WARNING'
            BEGIN
               SET @cWarningMsg = ISNULL(@cMsgText,'')
            END
            ELSE
            BEGIN
               SET @nErrNo = 172204
-- v1.2               SET @cErrMsg = CASE WHEN ISNULL(@cMsgText,'')<>'' THEN @cMsgText
-- v1.2                                   ELSE rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Data Not Found
-- v1.2                              END
               SET @cErrMsg = CASE WHEN @cMsgText='_' THEN '' ELSE ISNULL(@cMsgText,'') END   -- v1.2
               BREAK
            END
         END
      END

      CLOSE C_VALIDATION
      DEALLOCATE C_VALIDATION

      IF @nErrNo<>0
         GOTO Quit
   END


   -- Get ReportType
   SET @cSQL ='DECLARE C_REPORTTYPE CURSOR FAST_FORWARD READ_ONLY FOR '
             + CASE WHEN ISNULL(@cReportTypeExp,'')<>'' THEN ISNULL(@cReportTypeExp,'')
                    ELSE 'SELECT ReportType = ''' + REPLACE(@cReportType1,'''','''''') + ''','''','''''
                        + CASE WHEN ISNULL(@cReportType1,'')='' THEN ' WHERE 1=2' ELSE '' END
               END

   SET @cSQLParam = '@cStorerKey NVARCHAR(15)'
                  +',@cFacility NVARCHAR(5)'
                  +',@cSku NVARCHAR(20)'
                  +',@cParam1 NVARCHAR(60)'
                  +',@cParam2 NVARCHAR(60)'
                  +',@cParam3 NVARCHAR(60)'
                  +',@cParam4 NVARCHAR(60)'
                  +',@cParam5 NVARCHAR(60)'
                  +',@cParam6 NVARCHAR(60)'
                  +',@cParam7 NVARCHAR(60)'
                  +',@cParam8 NVARCHAR(60)'
                  +',@cParam9 NVARCHAR(60)'
                  +',@cParam10 NVARCHAR(60)'
                  +',@nNoOfCopy INT'
                  +',@cOption NVARCHAR(10)'
                  +',@cPrintCmdExp NVARCHAR(MAX)'
                  +',@cPrintCmd NVARCHAR(MAX)'
                  +',@cLabelPrinter NVARCHAR(10)'
                  +',@cPaperPrinter NVARCHAR(10)'
                  +',@cLabelWinPrinter NVARCHAR(128)'
                  +',@cPaperWinPrinter NVARCHAR(128)'
                  +',@cReportType NVARCHAR(30)'
                  +',@nMobile INT'
                  +',@nFunc INT'
                  +',@nStep INT'
                  +',@cLangCode NVARCHAR(3)'
                  +',@nInputKey    INT'
                  +',@cParam1Label NVARCHAR(60)'
                  +',@cParam2Label NVARCHAR(60)'
                  +',@cParam3Label NVARCHAR(60)'
                  +',@cParam4Label NVARCHAR(60)'
                  +',@cParam5Label NVARCHAR(60)'
                  +',@cFieldAttr02 NVARCHAR(1)'
                  +',@cFieldAttr04 NVARCHAR(1)'
                  +',@cFieldAttr06 NVARCHAR(1)'
                  +',@cFieldAttr08 NVARCHAR(1)'
                  +',@cFieldAttr10 NVARCHAR(1)'
                  

   BEGIN TRY
      EXEC sp_ExecuteSQL @cSQL, @cSQLParam
         , @c_StorerKey
         , @c_Facility
         , @c_Sku
         , @cParam1Value
         , @cParam2Value
         , @cParam3Value
         , @cParam4Value
         , @cParam5Value
         , @cParam6Value
         , @cParam7Value
         , @cParam8Value
         , @cParam9Value
         , @cParam10Value
         , @nNoOfCopy
         , @cOption
         , @cPrintCmdExp
         , @cPrintCmd
         , @cLabelPrinter
         , @cPaperPrinter
         , @cLabelWinPrinter
         , @cPaperWinPrinter
         , @cReportType
         , @nMobile
         , @nFunc
         , @nStep
         , @cLangCode
         , @nInputKey
         , @cParam1Label
         , @cParam2Label
         , @cParam3Label
         , @cParam4Label
         , @cParam5Label
         , @cFieldAttr02
         , @cFieldAttr04
         , @cFieldAttr06
         , @cFieldAttr08
         , @cFieldAttr10
   END TRY
   BEGIN CATCH
      SELECT @nTemp = ISNULL(ERROR_NUMBER(),0)
           , @cTemp = ISNULL(ERROR_MESSAGE(),'')
      EXEC nsp_logerror @nTemp, @cTemp, 'rdt_593PrintHK03 (Get ReportType)'

      SET @nErrNo = 172205
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetRptType ERR
      GOTO Quit
   END CATCH

   OPEN C_REPORTTYPE

   SET @nRptTypeCnt = 0

   WHILE 1=1
   BEGIN
      FETCH NEXT FROM C_REPORTTYPE
       INTO @cReportType, @cParmFldList, @cParmValList

      IF @@FETCH_STATUS<>0
         BREAK

      -- Prepare Parameters
      DELETE FROM @tReportParam

      IF ISNULL(@cParmFldList,'')<>'' AND ISNULL(@cParmValList,'')<>''
      BEGIN
         INSERT INTO @tReportParam (Variable, Value)
         SELECT a.ColValue, ISNULL(MAX(b.ColValue),'')
           FROM fnc_DelimSplit(LEFT(@cParmFldList,1),STUFF(@cParmFldList,1,1,'')) a
           LEFT JOIN fnc_DelimSplit(LEFT(@cParmValList,1),STUFF(@cParmValList,1,1,'')) b ON a.SeqNo=b.SeqNo
          GROUP BY a.ColValue
      END

      IF NOT EXISTS(SELECT 1 FROM @tReportParam WHERE Variable='@cStorerKey')
         INSERT INTO @tReportParam (Variable, Value)  VALUES  ('@cStorerKey', @c_StorerKey)
      IF NOT EXISTS(SELECT 1 FROM @tReportParam WHERE Variable='@cFacility')
         INSERT INTO @tReportParam (Variable, Value)  VALUES  ('@cFacility' , @c_Facility )
      IF NOT EXISTS(SELECT 1 FROM @tReportParam WHERE Variable='@cSku')
         INSERT INTO @tReportParam (Variable, Value)  VALUES  ('@cSku'      , @c_Sku      )
      IF NOT EXISTS(SELECT 1 FROM @tReportParam WHERE Variable='@cParam1')
         INSERT INTO @tReportParam (Variable, Value)  VALUES  ('@cParam1'   , @cParam1Value   )
      IF NOT EXISTS(SELECT 1 FROM @tReportParam WHERE Variable='@cParam2')
         INSERT INTO @tReportParam (Variable, Value)  VALUES  ('@cParam2'   , @cParam2Value   )
      IF NOT EXISTS(SELECT 1 FROM @tReportParam WHERE Variable='@cParam3')
         INSERT INTO @tReportParam (Variable, Value)  VALUES  ('@cParam3'   , @cParam3Value   )
      IF NOT EXISTS(SELECT 1 FROM @tReportParam WHERE Variable='@cParam4')
         INSERT INTO @tReportParam (Variable, Value)  VALUES  ('@cParam4'   , @cParam4Value   )
      IF NOT EXISTS(SELECT 1 FROM @tReportParam WHERE Variable='@cParam5')
         INSERT INTO @tReportParam (Variable, Value)  VALUES  ('@cParam5'   , @cParam5Value   )
      IF NOT EXISTS(SELECT 1 FROM @tReportParam WHERE Variable='@cParam6')
         INSERT INTO @tReportParam (Variable, Value)  VALUES  ('@cParam6'   , @cParam6Value   )
      IF NOT EXISTS(SELECT 1 FROM @tReportParam WHERE Variable='@cParam7')
         INSERT INTO @tReportParam (Variable, Value)  VALUES  ('@cParam7'   , @cParam7Value   )
      IF NOT EXISTS(SELECT 1 FROM @tReportParam WHERE Variable='@cParam8')
         INSERT INTO @tReportParam (Variable, Value)  VALUES  ('@cParam8'   , @cParam8Value   )
      IF NOT EXISTS(SELECT 1 FROM @tReportParam WHERE Variable='@cParam9')
         INSERT INTO @tReportParam (Variable, Value)  VALUES  ('@cParam9'   , @cParam9Value   )
      IF NOT EXISTS(SELECT 1 FROM @tReportParam WHERE Variable='@cParam10')
         INSERT INTO @tReportParam (Variable, Value)  VALUES  ('@cParam10'  , @cParam10Value  )
      IF NOT EXISTS(SELECT 1 FROM @tReportParam WHERE Variable='@nNoOfCopy')
         INSERT INTO @tReportParam (Variable, Value)  VALUES  ('@nNoOfCopy' , @nNoOfCopy  )
      IF NOT EXISTS(SELECT 1 FROM @tReportParam WHERE Variable='@cPrintCmd')
         INSERT INTO @tReportParam (Variable, Value)  VALUES  ('@cPrintCmd' , @cPrintCmd  )

      SELECT @c_p_StorerKey = (SELECT Value FROM @tReportParam WHERE Variable='@cStorerKey')
           , @c_p_Facility  = (SELECT Value FROM @tReportParam WHERE Variable='@cFacility' )
           , @c_p_Sku       = (SELECT Value FROM @tReportParam WHERE Variable='@cSku'      )
           , @c_p_Param1    = (SELECT Value FROM @tReportParam WHERE Variable='@cParam1'   )
           , @c_p_Param2    = (SELECT Value FROM @tReportParam WHERE Variable='@cParam2'   )
           , @c_p_Param3    = (SELECT Value FROM @tReportParam WHERE Variable='@cParam3'   )
           , @c_p_Param4    = (SELECT Value FROM @tReportParam WHERE Variable='@cParam4'   )
           , @c_p_Param5    = (SELECT Value FROM @tReportParam WHERE Variable='@cParam5'   )
           , @c_p_Param6    = (SELECT Value FROM @tReportParam WHERE Variable='@cParam6'   )
           , @c_p_Param7    = (SELECT Value FROM @tReportParam WHERE Variable='@cParam7'   )
           , @c_p_Param8    = (SELECT Value FROM @tReportParam WHERE Variable='@cParam8'   )
           , @c_p_Param9    = (SELECT Value FROM @tReportParam WHERE Variable='@cParam9'   )
           , @c_p_Param10   = (SELECT Value FROM @tReportParam WHERE Variable='@cParam10'  )
           , @n_p_NoOfCopy  = TRY_PARSE(ISNULL((SELECT Value FROM @tReportParam WHERE Variable='@nNoOfCopy' ),'') AS INT)
           , @c_p_PrintCmd  = (SELECT Value FROM @tReportParam WHERE Variable='@cPrintCmd' )


      -- Get Report Info
      SET @cJobName = 'rdt_593PrintHK03(' + LTRIM(RTRIM(ISNULL(@cOption,''))) + '): '

      SELECT @cJobName = @cJobName + ISNULL(RptDesc,'')
      FROM rdt.rdtReport WITH (NOLOCK)
      WHERE ReportType<>''
        AND ReportType = @cReportType
        AND StorerKey = @c_StorerKey
        AND (Function_ID = @nFunc OR Function_ID = 0)
      ORDER BY Function_ID DESC

      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 172206
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ReportNotSetup
         BREAK
      END


      SET @nRptTypeCnt += 1

      -- Prepare Command
      IF ISNULL(@cPrintCmdExp,'') <> '' AND ISNULL(@c_p_PrintCmd,'')=''
      BEGIN
         SET @cSQL = 'SET @cPrintCmd=' + @cPrintCmdExp
         SET @cSQLParam = '@cPrintCmd NVARCHAR(MAX) OUTPUT'
                        +',@cStorerKey NVARCHAR(15)'
                        +',@cFacility NVARCHAR(5)'
                        +',@cSku NVARCHAR(20)'
                        +',@cParam1 NVARCHAR(60)'
                        +',@cParam2 NVARCHAR(60)'
                        +',@cParam3 NVARCHAR(60)'
                        +',@cParam4 NVARCHAR(60)'
                        +',@cParam5 NVARCHAR(60)'
                        +',@cParam6 NVARCHAR(60)'
                        +',@cParam7 NVARCHAR(60)'
                        +',@cParam8 NVARCHAR(60)'
                        +',@cParam9 NVARCHAR(60)'
                        +',@cParam10 NVARCHAR(60)'
                        +',@nNoOfCopy INT'
                        +',@cOption NVARCHAR(10)'
                        +',@cLabelPrinter NVARCHAR(10)'
                        +',@cPaperPrinter NVARCHAR(10)'
                        +',@cLabelWinPrinter NVARCHAR(128)'
                        +',@cPaperWinPrinter NVARCHAR(128)'
                        +',@cReportType NVARCHAR(30)'
                        +',@nMobile INT'
                        +',@nFunc INT'
                        +',@nStep INT'
                        +',@cLangCode NVARCHAR(3)'
                        +',@nInputKey    INT'
                        +',@cParam1Label NVARCHAR(60)'
                        +',@cParam2Label NVARCHAR(60)'
                        +',@cParam3Label NVARCHAR(60)'
                        +',@cParam4Label NVARCHAR(60)'
                        +',@cParam5Label NVARCHAR(60)'
                        +',@cFieldAttr02 NVARCHAR(1)'
                        +',@cFieldAttr04 NVARCHAR(1)'
                        +',@cFieldAttr06 NVARCHAR(1)'
                        +',@cFieldAttr08 NVARCHAR(1)'
                        +',@cFieldAttr10 NVARCHAR(1)'

         BEGIN TRY
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam
               , @c_p_PrintCmd OUTPUT
               , @c_p_StorerKey
               , @c_p_Facility
               , @c_p_Sku
               , @c_p_Param1
               , @c_p_Param2
               , @c_p_Param3
               , @c_p_Param4
               , @c_p_Param5
               , @c_p_Param6
               , @c_p_Param7
               , @c_p_Param8
               , @c_p_Param9
               , @c_p_Param10
               , @n_p_NoOfCopy
               , @cOption
               , @cLabelPrinter
               , @cPaperPrinter
               , @cLabelWinPrinter
               , @cPaperWinPrinter
               , @cReportType
               , @nMobile
               , @nFunc
               , @nStep
               , @cLangCode
               , @nInputKey
               , @cParam1Label
               , @cParam2Label
               , @cParam3Label
               , @cParam4Label
               , @cParam5Label
               , @cFieldAttr02
               , @cFieldAttr04
               , @cFieldAttr06
               , @cFieldAttr08
               , @cFieldAttr10
         END TRY
         BEGIN CATCH
            SELECT @nTemp = ISNULL(ERROR_NUMBER(),0)
                 , @cTemp = ISNULL(ERROR_MESSAGE(),'')
            EXEC nsp_logerror @nTemp, @cTemp, 'rdt_593PrintHK03 (Prepare PrintCmd)'

            SET @nErrNo = 172207
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Cmd
            BREAK
         END CATCH
      END

      -- Print label
      EXEC RDT.rdt_Print
           @nMobile       = @nMobile
         , @nFunc         = @nFunc
         , @cLangCode     = @cLangCode
         , @nStep         = @nStep
         , @nInputKey     = @nInputKey
         , @cFacility     = @c_p_Facility
         , @cStorerKey    = @c_p_StorerKey
         , @cLabelPrinter = @cLabelPrinter
         , @cPaperPrinter = @cPaperPrinter
         , @cReportType   = @cReportType
         , @tReportParam  = @tReportParam
         , @cSourceType   = @cJobName
         , @nErrNo        = @nErrNo  OUTPUT
         , @cErrMsg       = @cErrMsg OUTPUT
         , @nNoOfCopy     = @n_p_NoOfCopy
         , @cPrintCommand = @c_p_PrintCmd
   END
   CLOSE C_REPORTTYPE
   DEALLOCATE C_REPORTTYPE

   IF @nErrNo<>0
      GOTO Quit

   IF @nRptTypeCnt = 0 AND NOT (ISNULL(@cReportType1,'')='' AND ISNULL(@cReportTypeExp,'')='')
   BEGIN
      SET @nErrNo = 172208
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ReportNotSetup
      GOTO Quit
   END

   -- Show Warning Message
   IF ISNULL(@cWarningMsg,'')<>''
      SET @cErrMsg = @cWarningMsg

   -- Focus next empty field
   IF CHARINDEX('R', @cShort)>=1 OR @cShort<>''
      AND ISNULL(@cFocusField,'')=''  -- V1.2
   BEGIN
      SET @nTemp = CASE WHEN @cFieldAttr02='' AND (@cParam1Value='' OR CHARINDEX('1',@cShort)=0) THEN 2
                        WHEN @cFieldAttr04='' AND (@cParam2Value='' OR CHARINDEX('2',@cShort)=0) THEN 4
                        WHEN @cFieldAttr06='' AND (@cParam3Value='' OR CHARINDEX('3',@cShort)=0) THEN 6
                        WHEN @cFieldAttr08='' AND (@cParam4Value='' OR CHARINDEX('4',@cShort)=0) THEN 8
                        WHEN @cFieldAttr10='' AND (@cParam5Value='' OR CHARINDEX('5',@cShort)=0) THEN 10
                   END
      IF ISNULL(@nTemp,0)>0
         EXEC rdt.rdtSetFocusField @nMobile, @nTemp
   END

Quit:
END

GO