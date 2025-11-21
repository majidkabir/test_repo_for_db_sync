SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO



/******************************************************************************/
/* Store procedure: rdt_593PrintHK02                                          */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2018-02-07 1.0  ML         Create                                          */
/* 2018-02-14 1.1  ML         Add Extended Validation Codelkup RDTLBLRVLD     */
/* 2018-02-15 1.2  ML         Handle multi ReportType                         */
/* 2018-04-20 1.3  ML         Pass @nNoOfCopy to rdt_Print                    */
/* 2018-08-20 1.4  CheeMUN    SCTASK0183384 - Extend Parms Length             */
/* 2019-05-20 1.5  ML         WMS-8878:Handle NoOfCopy,PrintCmd@ParmList(ML01)*/
/* 2022-12-22 1.6  YeeKung    WMS-21359 Extend option length (yeekung01)      */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_593PrintHK02] (
   @nMobile    INT,
   @nFunc      INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @cStorerKey NVARCHAR( 15),
   @cOption    NVARCHAR( 2), --(yeekung01)
   @cParam1    NVARCHAR(60),  --SCTASK0183384
   @cParam2    NVARCHAR(60),  --SCTASK0183384
   @cParam3    NVARCHAR(60),  --SCTASK0183384
   @cParam4    NVARCHAR(60),  --SCTASK0183384
   @cParam5    NVARCHAR(60),  --SCTASK0183384
   @nErrNo     INT           OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cJobName         NVARCHAR(50)
         , @cUDF01           NVARCHAR(60)
         , @cUDF02           NVARCHAR(60)
         , @cUDF03           NVARCHAR(60)
         , @cUDF04           NVARCHAR(60)
         , @cUDF05           NVARCHAR(60)
         , @cCode2           NVARCHAR(30)
         , @cValidateAction  NVARCHAR(60)
         , @cReportType1     NVARCHAR(30)
         , @cReportType      NVARCHAR(30)
         , @cFocusField      NVARCHAR(10)
         , @cMsgText         NVARCHAR(250)
         , @cWarningMsg      NVARCHAR(250)
         , @cValidateExp     NVARCHAR(MAX)
         , @cReportTypeExp   NVARCHAR(MAX)
         , @cPrintCmdExp     NVARCHAR(MAX)
         , @cPrintCmd        NVARCHAR(MAX)
         , @cLabelPrinter    NVARCHAR(10)
         , @cPaperPrinter    NVARCHAR(10)
         , @cLabelWinPrinter NVARCHAR(128)
         , @cPaperWinPrinter NVARCHAR(128)
         , @c_StorerKey      NVARCHAR(15)
         , @c_Facility       NVARCHAR(5)
         , @c_Sku            NVARCHAR(20)
         , @c_Param1         NVARCHAR(60)
         , @c_Param2         NVARCHAR(60)
         , @c_Param3         NVARCHAR(60)
         , @c_Param4         NVARCHAR(60)
         , @c_Param5         NVARCHAR(60)
         , @c_Param6         NVARCHAR(60)
         , @c_Param7         NVARCHAR(60)
         , @c_Param8         NVARCHAR(60)
         , @c_Param9         NVARCHAR(60)
         , @c_Param10        NVARCHAR(60)
         , @cParams          NVARCHAR(10)
         , @nNoOfCopy        INT
         , @bSuccess         INT
         , @nTemp            INT
         , @nRptTypeCnt      INT
         , @tReportParam  AS VariableTable
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
         , @n_p_NoOfCopy     INT           -- ML01
         , @c_p_PrintCmd     NVARCHAR(MAX) -- ML01

   SELECT @cReportType1     = ''
        , @cJobName         = ''
        , @cUDF01           = ''
        , @cUDF02           = ''
        , @cUDF03           = ''
        , @cUDF04           = ''
        , @cUDF05           = ''
        , @cReportTypeExp   = ''
        , @cPrintCmdExp     = ''
        , @cPrintCmd        = ''
        , @cLabelPrinter    = ''
        , @cPaperPrinter    = ''
        , @cLabelWinPrinter = ''
        , @cPaperWinPrinter = ''
        , @c_StorerKey      = @cStorerKey
        , @c_Facility       = ''
        , @c_Sku            = ''
        , @c_Param1         = @cParam1
        , @c_Param2         = @cParam2
        , @c_Param3         = @cParam3
        , @c_Param4         = @cParam4
        , @c_Param5         = @cParam5
        , @c_Param6         = ''
        , @c_Param7         = ''
        , @c_Param8         = ''
        , @c_Param9         = ''
        , @c_Param10        = ''
        , @cWarningMsg      = ''
        , @nNoOfCopy        = NULL

   -- Get Codelkup RDTLBLRPT values
   SELECT @cUDF01         = ISNULL(UDF01,'')
        , @cUDF02         = ISNULL(UDF02,'')
        , @cUDF03         = ISNULL(UDF03,'')
        , @cUDF04         = ISNULL(UDF04,'')
        , @cUDF05         = ISNULL(UDF05,'')
        , @cReportType1   = ISNULL(Code2,'')
        , @cReportTypeExp = ISNULL(Notes,'')
        , @cPrintCmdExp   = ISNULL(Notes2,'')
    FROM dbo.CodeLkup WITH (NOLOCK)
    WHERE Listname = 'RDTLBLRPT' AND Code = @cOption AND Storerkey = @c_StorerKey
    ORDER BY Code2

    SET @cParams = CASE WHEN @cUDF01<>'' THEN 'Y' ELSE 'N' END       --YYNNN
                 + CASE WHEN @cUDF02<>'' THEN 'Y' ELSE 'N' END
                 + CASE WHEN @cUDF03<>'' THEN 'Y' ELSE 'N' END
                 + CASE WHEN @cUDF04<>'' THEN 'Y' ELSE 'N' END
                 + CASE WHEN @cUDF05<>'' THEN 'Y' ELSE 'N' END

   -- Check at least one parameter input
   IF NOT ((@cUDF01<>'' AND ISNULL(@c_Param1,'')<>'') OR
           (@cUDF02<>'' AND ISNULL(@c_Param2,'')<>'') OR
           (@cUDF03<>'' AND ISNULL(@c_Param3,'')<>'') OR
           (@cUDF04<>'' AND ISNULL(@c_Param4,'')<>'') OR
           (@cUDF05<>'' AND ISNULL(@c_Param5,'')<>'') )
   BEGIN
      SET @nErrNo = 119901
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Input Required
      GOTO Quit
   END

   -- Check mandatory parameter input
   -- (Parameter Text Label start with * means mandatory)
   SET @nTemp = CASE WHEN (LEFT(@cUDF01,1)='*' AND ISNULL(@c_Param1,'')='') THEN 2
                     WHEN (LEFT(@cUDF02,1)='*' AND ISNULL(@c_Param2,'')='') THEN 4
                     WHEN (LEFT(@cUDF03,1)='*' AND ISNULL(@c_Param3,'')='') THEN 6
                     WHEN (LEFT(@cUDF04,1)='*' AND ISNULL(@c_Param4,'')='') THEN 8
                     WHEN (LEFT(@cUDF05,1)='*' AND ISNULL(@c_Param5,'')='') THEN 10
                     ELSE 0
                END
   IF @nTemp > 0
   BEGIN
      SET @nErrNo = 119902
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Input Required
      EXEC rdt.rdtSetFocusField @nMobile, @nTemp
      GOTO Quit
   END

   -- Get Login Info
   SELECT @cLabelPrinter = Printer
        , @cPaperPrinter = Printer_Paper
        , @c_Facility    = Facility
   FROM rdt.rdtMobRec WITH (NOLOCK)
   WHERE Mobile = @nMobile

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

      SET @cSQLParam = '@bSuccess   INT          OUTPUT'
                     +',@cMsgText   NVARCHAR(250) OUTPUT'
                     +',@cStorerKey NVARCHAR(15) OUTPUT'
                     +',@cFacility  NVARCHAR(5)  OUTPUT'
                     +',@cSku       NVARCHAR(20) OUTPUT'
                     +',@cParam1    NVARCHAR(60) OUTPUT'
                     +',@cParam2    NVARCHAR(60) OUTPUT'
                     +',@cParam3    NVARCHAR(60) OUTPUT'
                     +',@cParam4    NVARCHAR(60) OUTPUT'
                     +',@cParam5    NVARCHAR(60) OUTPUT'
                     +',@cParam6    NVARCHAR(60) OUTPUT'
                     +',@cParam7    NVARCHAR(60) OUTPUT'
                     +',@cParam8    NVARCHAR(60) OUTPUT'
                     +',@cParam9    NVARCHAR(60) OUTPUT'
                     +',@cParam10   NVARCHAR(60) OUTPUT'
                     +',@nNoOfCopy  INT OUTPUT'
                     +',@cOption    NVARCHAR(1)'
                     +',@cCode2     NVARCHAR(30)'
                     +',@cValidateAction NVARCHAR(60)'
                     +',@cPrintCmdExp NVARCHAR(MAX)'      -- ML01
                     +',@cPrintCmd  NVARCHAR(MAX) OUTPUT' -- ML01
                     +',@cLabelPrinter NVARCHAR(10)'      -- ML01
                     +',@cPaperPrinter NVARCHAR(10)'      -- ML01
                     +',@cLabelWinPrinter NVARCHAR(128)'  -- ML01
                     +',@cPaperWinPrinter NVARCHAR(128)'  -- ML01
                     +',@cReportType NVARCHAR(30)'        -- ML01
                     +',@nMobile INT'                     -- ML01
                     +',@nFunc INT'                       -- ML01
                     +',@nStep INT'                       -- ML01
                     +',@cLangCode NVARCHAR(3)'           -- ML01

      WHILE 1=1
      BEGIN
         FETCH NEXT FROM C_VALIDATION
          INTO @cFocusField, @cMsgText, @cValidateExp, @cCode2, @cValidateAction

         IF @@FETCH_STATUS<>0
            BREAK

         SET @bSuccess = 0
         IF @cValidateAction='DECODE'
            SET @cSQL = 'SET @bSuccess=1 BEGIN ' +CHAR(10)+ @cValidateExp +CHAR(10)+ 'END'
         ELSE
            SET @cSQL = 'IF (' + @cValidateExp + ') SET @bSuccess=1'

         BEGIN TRY
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam
               , @bSuccess    OUTPUT
               , @cMsgText    OUTPUT
               , @c_StorerKey OUTPUT
               , @c_Facility  OUTPUT
               , @c_Sku       OUTPUT
               , @c_Param1    OUTPUT
               , @c_Param2    OUTPUT
               , @c_Param3    OUTPUT
               , @c_Param4    OUTPUT
               , @c_Param5    OUTPUT
               , @c_Param6    OUTPUT
               , @c_Param7    OUTPUT
               , @c_Param8    OUTPUT
               , @c_Param9    OUTPUT
               , @c_Param10   OUTPUT
               , @nNoOfCopy   OUTPUT
               , @cOption
               , @cCode2
               , @cValidateAction
               , @cPrintCmdExp       -- ML01
               , @cPrintCmd   OUTPUT -- ML01
               , @cLabelPrinter      -- ML01
               , @cPaperPrinter      -- ML01
               , @cLabelWinPrinter   -- ML01
               , @cPaperWinPrinter   -- ML01
               , @cReportType        -- ML01
               , @nMobile            -- ML01
               , @nFunc              -- ML01
               , @nStep              -- ML01
               , @cLangCode          -- ML01
         END TRY
         BEGIN CATCH
            SET @nErrNo = 119903
            SET @cErrMsg = 'VALIDATION ERR^' + ISNULL(@cCode2,'')
            BREAK
         END CATCH

         IF ISNULL(@bSuccess,0)<>1
         BEGIN
            IF ISNUMERIC(@cFocusField) = 1
            BEGIN
               SET @nTemp = CONVERT(INT, CONVERT(FLOAT, @cFocusField))
               IF @nTemp >= 1 AND @nTemp <=10 AND SUBSTRING(@cParams,@nTemp,1) = 'Y'
               BEGIN
                  SET @nTemp = @nTemp * 2
                  EXEC rdt.rdtSetFocusField @nMobile, @nTemp
               END
            END

           IF ISNULL(@cValidateAction,'')='WARNING'
            BEGIN
               SET @cWarningMsg = ISNULL(@cMsgText,'')
            END
            ELSE
            BEGIN
               SET @nErrNo = 119904
               SET @cErrMsg = CASE WHEN ISNULL(@cMsgText,'')<>'' THEN @cMsgText
                                   ELSE rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Data Not Found
                              END
               BREAK
            END
         END
      END

      CLOSE C_VALIDATION
      DEALLOCATE C_VALIDATION

      IF @nErrNo<>0
         GOTO Quit
   END

  SELECT 'SHIPLABEL', ',@cStorerkey,@cPickslipno,@cStartCartonNo,@cEndCartonNo',','+@cStorerKey+','+@cParam1+ ','+ @cParam2+ ','+ @cParam2

   -- Get ReportType
   IF ISNULL(@cReportTypeExp,'') = ''
   BEGIN
      SET @cReportTypeExp = 'SELECT ReportType = ''' + REPLACE(@cReportType1,'''','''''') + ''','''','''''
   END

   SET @cSQL = 'DECLARE C_REPORTTYPE CURSOR FAST_FORWARD READ_ONLY FOR ' + ISNULL(@cReportTypeExp,'')
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
                  +',@cOption NVARCHAR(1)'
                  +',@cPrintCmdExp NVARCHAR(MAX)'     -- ML01
                  +',@cPrintCmd NVARCHAR(MAX)'        -- ML01
                  +',@cLabelPrinter NVARCHAR(10)'     -- ML01
                  +',@cPaperPrinter NVARCHAR(10)'     -- ML01
                  +',@cLabelWinPrinter NVARCHAR(128)' -- ML01
                  +',@cPaperWinPrinter NVARCHAR(128)' -- ML01
                  +',@cReportType NVARCHAR(30)'       -- ML01
                  +',@nMobile INT'                    -- ML01
                  +',@nFunc INT'                      -- ML01
                  +',@nStep INT'                      -- ML01
                  +',@cLangCode NVARCHAR(3)'          -- ML01

   BEGIN TRY
      EXEC sp_ExecuteSQL @cSQL, @cSQLParam
         , @c_StorerKey
         , @c_Facility
         , @c_Sku
         , @c_Param1
         , @c_Param2
         , @c_Param3
         , @c_Param4
         , @c_Param5
         , @c_Param6
         , @c_Param7
         , @c_Param8
         , @c_Param9
         , @c_Param10
         , @nNoOfCopy
         , @cOption
         , @cPrintCmdExp     -- ML01
         , @cPrintCmd        -- ML01
         , @cLabelPrinter    -- ML01
         , @cPaperPrinter    -- ML01
         , @cLabelWinPrinter -- ML01
         , @cPaperWinPrinter -- ML01
         , @cReportType      -- ML01
         , @nMobile          -- ML01
         , @nFunc            -- ML01
         , @nStep            -- ML01
         , @cLangCode        -- ML01
   END TRY
   BEGIN CATCH
   SET @nErrNo = 119905
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ReportNotSetup
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
         SELECT a.ColValue, MAX(b.ColValue)
           FROM fnc_DelimSplit(LEFT(@cParmFldList,1),STUFF(@cParmFldList,1,1,'')) a
           JOIN fnc_DelimSplit(LEFT(@cParmValList,1),STUFF(@cParmValList,1,1,'')) b ON a.SeqNo=b.SeqNo
          GROUP BY a.ColValue
      END

      IF NOT EXISTS(SELECT 1 FROM @tReportParam WHERE Variable='@cStorerKey')
         INSERT INTO @tReportParam (Variable, Value)  VALUES  ('@cStorerKey', @c_StorerKey)
      IF NOT EXISTS(SELECT 1 FROM @tReportParam WHERE Variable='@cFacility')
         INSERT INTO @tReportParam (Variable, Value)  VALUES  ('@cFacility' , @c_Facility )
      IF NOT EXISTS(SELECT 1 FROM @tReportParam WHERE Variable='@cSku')
         INSERT INTO @tReportParam (Variable, Value)  VALUES  ('@cSku'      , @c_Sku      )
      IF NOT EXISTS(SELECT 1 FROM @tReportParam WHERE Variable='@cParam1')
         INSERT INTO @tReportParam (Variable, Value)  VALUES  ('@cParam1'   , @c_Param1   )
      IF NOT EXISTS(SELECT 1 FROM @tReportParam WHERE Variable='@cParam2')
         INSERT INTO @tReportParam (Variable, Value)  VALUES  ('@cParam2'   , @c_Param2   )
      IF NOT EXISTS(SELECT 1 FROM @tReportParam WHERE Variable='@cParam3')
         INSERT INTO @tReportParam (Variable, Value)  VALUES  ('@cParam3'   , @c_Param3   )
      IF NOT EXISTS(SELECT 1 FROM @tReportParam WHERE Variable='@cParam4')
         INSERT INTO @tReportParam (Variable, Value)  VALUES  ('@cParam4'   , @c_Param4   )
      IF NOT EXISTS(SELECT 1 FROM @tReportParam WHERE Variable='@cParam5')
         INSERT INTO @tReportParam (Variable, Value)  VALUES  ('@cParam5'   , @c_Param5   )
      IF NOT EXISTS(SELECT 1 FROM @tReportParam WHERE Variable='@cParam6')
         INSERT INTO @tReportParam (Variable, Value)  VALUES  ('@cParam6'   , @c_Param6   )
      IF NOT EXISTS(SELECT 1 FROM @tReportParam WHERE Variable='@cParam7')
         INSERT INTO @tReportParam (Variable, Value)  VALUES  ('@cParam7'   , @c_Param7   )
      IF NOT EXISTS(SELECT 1 FROM @tReportParam WHERE Variable='@cParam8')
         INSERT INTO @tReportParam (Variable, Value)  VALUES  ('@cParam8'   , @c_Param8   )
      IF NOT EXISTS(SELECT 1 FROM @tReportParam WHERE Variable='@cParam9')
         INSERT INTO @tReportParam (Variable, Value)  VALUES  ('@cParam9'   , @c_Param9   )
      IF NOT EXISTS(SELECT 1 FROM @tReportParam WHERE Variable='@cParam10')
         INSERT INTO @tReportParam (Variable, Value)  VALUES  ('@cParam10'  , @c_Param10  )
      IF NOT EXISTS(SELECT 1 FROM @tReportParam WHERE Variable='@nNoOfCopy')                  -- ML01
         INSERT INTO @tReportParam (Variable, Value)  VALUES  ('@nNoOfCopy' , @nNoOfCopy  )   -- ML01
      IF NOT EXISTS(SELECT 1 FROM @tReportParam WHERE Variable='@cPrintCmd')                  -- ML01
         INSERT INTO @tReportParam (Variable, Value)  VALUES  ('@cPrintCmd' , @cPrintCmd  )   -- ML01

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
           , @n_p_NoOfCopy  = TRY_PARSE(ISNULL((SELECT Value FROM @tReportParam WHERE Variable='@nNoOfCopy' ),'') AS INT) -- ML01
           , @c_p_PrintCmd  = (SELECT Value FROM @tReportParam WHERE Variable='@cPrintCmd' )                              -- ML01


      -- Get Report Info
      SET @cJobName = 'rdt_593PrintHK01(' + ISNULL(@cOption,'') + '): '

      SELECT @cJobName = @cJobName + ISNULL(RptDesc,'')
      FROM rdt.rdtReport WITH (NOLOCK)
      WHERE ReportType<>''
        AND ReportType = @cReportType
        AND StorerKey = @c_StorerKey
        AND (Function_ID = @nFunc OR Function_ID = 0)
      ORDER BY Function_ID DESC

      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 119906
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
                        +',@cLabelPrinter NVARCHAR(10)'
                        +',@cPaperPrinter NVARCHAR(10)'
                        +',@cLabelWinPrinter NVARCHAR(128)'
                        +',@cPaperWinPrinter NVARCHAR(128)'
                        +',@cReportType NVARCHAR(30)'
                        +',@nMobile INT'
                        +',@nFunc INT'
                        +',@nStep INT'
                        +',@cLangCode NVARCHAR(3)'
                        +',@cOption NVARCHAR(1)'

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
               , @cLabelPrinter
               , @cPaperPrinter
               , @cLabelWinPrinter
               , @cPaperWinPrinter
               , @cReportType
               , @nMobile
               , @nFunc
               , @nStep
               , @cLangCode
               , @cOption
         END TRY
         BEGIN CATCH
            SET @nErrNo = 119907
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Cmd
            BREAK
         END CATCH
      END

      -- Print label
      EXEC RDT.rdt_Print
           @nMobile       = @nMobile
         , @nFunc         = @nFunc
         , @cLangCode     = @cLangCode
         , @nStep         = 0
         , @nInputKey     = 1
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

   IF @nRptTypeCnt = 0
   BEGIN
      SET @nErrNo = 119908
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ReportNotSetup
      GOTO Quit
   END

   DECLARE @cPickSlipNo NVARCHAR(10)
   SET @cPickSlipNo = ''
   SET @cPickSlipNo = CASE WHEN @cUDF01 LIKE '%Pickslipno%' THEN @c_Param1
                           WHEN @cUDF02 LIKE '%Pickslipno%' THEN @c_Param2
                           WHEN @cUDF03 LIKE '%Pickslipno%' THEN @c_Param3
                           WHEN @cUDF04 LIKE '%Pickslipno%' THEN @c_Param4
                           WHEN @cUDF05 LIKE '%Pickslipno%' THEN @c_Param5
                      END
   IF @cPickSlipNo = ''
      GOTO Quit

   -- Get Order info
   DECLARE @cSOStatus NVARCHAR(10)
   SELECT @cSOStatus = O.SOStatus
   FROM dbo.Orders O WITH (NOLOCK)
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
   WHERE PD.PickSlipNo = @cPickSlipNo

   -- Order cancel not print packing list
   IF @cSOStatus = 'CANC'
   BEGIN
      GOTO Quit
   END

   --Get DropID from PackDetail
   DECLARE @cDropID NVARCHAR(20)
   SET @cDropID = ''
   SELECT @cDropID = DropID
   FROM dbo.PackDetail WITH(NOLOCK)
   WHERE PickSlipNo = @cPickSlipNo

   -- Insert DropID
   IF NOT EXISTS( SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cDropID)
   BEGIN
      -- Insert DropID
      INSERT INTO dbo.DropID (DropID, Status) VALUES (@cDropID, '9')
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 92804
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsDropIDFail
         GOTO Fail
      END
   END

   /*
   Last carton logic:
   1. If not fully pack (PickDetail.Status = 0 or 4), definitely not last carton
   2. If all carton pack and scanned (all PackDetail and DropID records tally), it is last carton
   */
   DECLARE @cLastCarton NVARCHAR( 1)
   -- 1. Check outstanding PickDetail
   IF EXISTS( SELECT TOP 1 1 FROM dbo.PickDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND Status IN ('0', '4') AND QTY > 0)
      SET @cLastCarton = 'N'
   ELSE
      -- 2. Check manifest printed
      IF EXISTS( SELECT TOP 1 1
         FROM dbo.PackDetail PD WITH (NOLOCK)
            LEFT JOIN dbo.DropID WITH (NOLOCK) ON (PD.DropID = DropID.DropID)
         WHERE PD.PickSlipNo = @cPickSlipNo
               AND DropID.DropID IS NULL)
         SET @cLastCarton = 'N'
      ELSE
         SET @cLastCarton = 'Y'

   -- Last carton then only print pack list
   IF @cLastCarton = 'Y'
   BEGIN
      -- Get printer
      SELECT
         @cPaperPrinter = Printer_Paper,
         @cStorerKey = StorerKey
      FROM rdt.rdtMobRec WITH (NOLOCK)
      WHERE Mobile = @nMobile

      -- Check paper printer blank
      IF @cPaperPrinter = ''
      BEGIN
         SET @nErrNo = 92801
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PaperPrnterReq
         EXEC rdt.rdtSetFocusField @nMobile, 4 --PrintGS1Label
         GOTO Quit
      END

      -- Get packing list report info
      DECLARE  @cDataWindow NVARCHAR(50)
      DECLARE  @cTargetDB NVARCHAR(20)

      SET @cDataWindow = ''
      SET @cTargetDB = ''
      SELECT
         @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
         @cTargetDB = ISNULL(RTRIM(TargetDB), '')
      FROM RDT.RDTReport WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND ReportType = 'PACKLIST'

      -- Check data window
      IF ISNULL( @cDataWindow, '') = ''
      BEGIN
         SET @nErrNo = 92802
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup
         GOTO Quit
      END

      -- Check database
      IF ISNULL( @cTargetDB, '') = ''
      BEGIN
         SET @nErrNo = 92803
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set
         GOTO Quit
      END

      -- Insert print job
      EXEC RDT.rdt_BuiltPrintJob
         @nMobile,
         @cStorerKey,
         'PACKLIST',       -- ReportType
         'PRINT_PACKLIST', -- PrintJobName
         @cDataWindow,
         @cPaperPrinter,
         @cTargetDB,
         @cLangCode,
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT,
         @cPickSlipNo

      -- Update DropID
      UPDATE dbo.DropID SET
         ManifestPrinted = '1'
      WHERE DropID = @cDropID
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 92805
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD DropIDFail
         GOTO Fail
      END
   END

   -- Show Warning Message
   IF ISNULL(@cWarningMsg,'')<>''
   BEGIN
      SET @cErrMsg = @cWarningMsg
      GOTO Quit
   END
Fail:
   RETURN
Quit:



GO