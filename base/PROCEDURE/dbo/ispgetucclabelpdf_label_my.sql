SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ispGetUCCLABELPDF_Label_MY                                  */
/* Creation Date: 26-Jun-2020                                           */
/* Copyright: LF Logistics                                              */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-13933 - [MY]-Skechers Selluseller ECOM Print ShipLabel  */
/*          and Invoice-[CR]                                            */
/*                                                                      */
/* Called By: isp_GetPrint2PDFConfig                                    */
/*                                                                      */
/* GitLab Version: 1.1                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2020-11-09  WLChooi  1.1   Fix - Get parameters from Option5 in Sub- */
/*                            SP & Add @n_PrintAction (WL01)            */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispGetUCCLABELPDF_Label_MY]
       @c_Storerkey       NVARCHAR(15),
       @c_Facility        NVARCHAR(5), 
       @c_Configkey       NVARCHAR(30),
       @c_Param01         NVARCHAR(50),
       @c_Param02         NVARCHAR(50),
       @c_Param03         NVARCHAR(50),
       @c_Param04         NVARCHAR(50),
       @c_Param05         NVARCHAR(50),
       @c_PdfFolder       NVARCHAR(500),
       @c_PdfFile         NVARCHAR(500)   OUTPUT,
       @c_Printer         NVARCHAR(500)   OUTPUT,
       @c_ArchiveFolder   NVARCHAR(500)   OUTPUT,
       @c_ActionType      NVARCHAR(10)    OUTPUT,  --2 = Print and don't move 3 = Print and move (Default)
       @n_PrintAction     INT             OUTPUT,  --0=Not print PDF  1=Print PDF   2=Print PDF and continue other printing
       @c_Dimension       NVARCHAR(50)    OUTPUT,  --Dimension in mm x mm, eg. 210x297
       @n_NoOfPDFSheet    INT = 1,               --PDF Sheets number (For 1 ReportType print multiple layout)
       --@c_PostPrinting  NVARCHAR(1)   OUTPUT,  --Y - PostPrinting, N - DirectPrint (Need to wait)
       --@c_SubFolder       NVARCHAR(500),   --WL01
       --@c_PDFNameFormat   NVARCHAR(4000),  --WL01
       --@c_Prefix          NVARCHAR(500),   --WL01
       @b_Success         INT             OUTPUT,  
       @n_Err             INT             OUTPUT, 
       @c_ErrMsg          NVARCHAR(255)   OUTPUT
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
      
   DECLARE @n_continue        INT 

   DECLARE @c_ReportType      NVARCHAR( 10)
         , @c_ProcessType     NVARCHAR( 15)
         , @c_FilePath        NVARCHAR(100)       
         , @c_PrintFilePath   NVARCHAR(100)      
         , @c_PrintCommand    NVARCHAR(MAX)    
         , @c_WinPrinter      NVARCHAR(128)  
         , @c_PrinterName     NVARCHAR(100) 
         , @c_FileName        NVARCHAR(255)     
         , @c_JobStatus       NVARCHAR( 1)    
         , @c_PrintJobName    NVARCHAR(50)
         , @c_TargetDB        NVARCHAR(20)
         , @n_Mobile          INT   
         , @c_SpoolerGroup    NVARCHAR(20)
         , @c_IPAddress       NVARCHAR(40)               
         , @c_PortNo          NVARCHAR(5)           
         , @c_Command         NVARCHAR(1024)            
         , @c_IniFilePath     NVARCHAR(200)  
         , @c_DataReceived    NVARCHAR(4000) 
         , @c_Application     NVARCHAR(30)           
         , @n_JobID           INT    
         , @n_QueueID         INT 
         , @n_starttcnt       INT
         , @c_JobID           NVARCHAR(10) 
         , @c_PrintData       NVARCHAR(MAX) 
         , @c_userid          NVARCHAR(20) 
         , @c_PrinterID       NVARCHAR(20)    
         , @n_IsExists        INT = 0  
         , @c_PDFFilePath     NVARCHAR(500) = ''
         , @c_ArchivePath     NVARCHAR(200) = ''
         , @c_TrackingNo      NVARCHAR(30)  = ''
         , @c_Type            NVARCHAR(20)  = ''
         , @c_Option5         NVARCHAR(4000) = ''
         , @c_Shipperkey      NVARCHAR(50) = ''
         , @b_Debug           INT = 0
         , @c_GetShipperkey   NVARCHAR(250) = ''
         , @c_GetDoctype      NVARCHAR(250) = ''
         , @c_GetOrdType      NVARCHAR(250) = ''
         , @c_GetECOMFlag     NVARCHAR(250) = ''
         
   DECLARE  @c_OrderKey       NVARCHAR(10)
   	    , @c_DocType        NVARCHAR(10)
   	    , @c_OrdType        NVARCHAR(50)
   	    , @c_ExtOrderkey    NVARCHAR(50)
   	    , @c_ECOMFlag       NVARCHAR(1)
   	    , @c_PDFNameFormat  NVARCHAR(4000)   --WL01
   	    , @c_Prefix         NVARCHAR(500)    --WL01
   	    , @c_SubFolder      NVARCHAR(500)    --WL01
   	    , @c_GetPrintAction NVARCHAR(1)      --WL01
   	    
   SET @n_err = 0
   SET @b_success = 1
   SET @c_errmsg = ''
   SET @n_continue = 1
   SET @n_starttcnt = @@TRANCOUNT
   SET @c_SpoolerGroup = '' 
   SET @c_userid = SUSER_SNAME()

   SELECT @c_OrderKey    = LTRIM(RTRIM(ISNULL(ORDERS.OrderKey,''))) 
        , @c_DocType     = LTRIM(RTRIM(ISNULL(ORDERS.DocType,''))) 
        , @c_OrdType     = LTRIM(RTRIM(ISNULL(ORDERS.[Type],'')))
        , @c_ExtOrderkey = LTRIM(RTRIM(ISNULL(ORDERS.ExternOrderKey,'')))
        , @c_Shipperkey  = LTRIM(RTRIM(ISNULL(ORDERS.ShipperKey,'')))
        , @c_TrackingNo  = LTRIM(RTRIM(ISNULL(ORDERS.TrackingNo,'')))
        , @c_ECOMFlag    = LTRIM(RTRIM(ISNULL(ORDERS.ECOM_Single_Flag,'')))
   FROM PACKHEADER (NOLOCK)
   JOIN ORDERS (NOLOCK) ON PACKHEADER.Orderkey = ORDERS.Orderkey
   WHERE PACKHEADER.PickSlipNo = @c_Param01
   
   --IF @c_DocType <> 'E'
   --BEGIN
   --	SET @n_PrintAction = 0
   --	GOTO QUIT_SP
   --END
   
   --Use Option 5 to filter column (If available)
   IF (@n_continue = 1 OR @n_continue = 2)
   BEGIN
      SELECT @c_Option5 = ISNULL(SC.Option5,'')
      FROM STORERCONFIG SC (NOLOCK)
      WHERE SC.Storerkey = @c_Storerkey
      AND SC.Configkey = @c_Configkey
      
      SELECT @c_GetShipperkey = dbo.fnc_GetParamValueFromString('@c_Shipperkey', @c_Option5, @c_GetShipperkey)  
      SELECT @c_GetDoctype    = dbo.fnc_GetParamValueFromString('@c_Doctype ',   @c_Option5, @c_GetDoctype)  
      SELECT @c_GetOrdType    = dbo.fnc_GetParamValueFromString('@c_OrdType ',   @c_Option5, @c_GetOrdType)  
      SELECT @c_GetECOMFlag   = dbo.fnc_GetParamValueFromString('@c_ECOMFlag',   @c_Option5, @c_GetECOMFlag)  

      IF ISNULL(@c_GetShipperkey,'') <> ''
      BEGIN
      	IF @c_Shipperkey NOT IN (SELECT LTRIM(RTRIM(ColValue)) FROM dbo.fnc_delimsplit (',',@c_GetShipperkey) )
      	BEGIN
      		SET @n_PrintAction = 0
            GOTO QUIT_SP
      	END
      END
      
      IF ISNULL(@c_GetDoctype,'') <> ''
      BEGIN
      	IF @c_Doctype NOT IN (SELECT LTRIM(RTRIM(ColValue)) FROM dbo.fnc_delimsplit (',',@c_GetDoctype) )
      	BEGIN
      		SET @n_PrintAction = 0
            GOTO QUIT_SP
      	END
      END
      
      IF ISNULL(@c_GetOrdType,'') <> ''
      BEGIN
      	IF @c_OrdType NOT IN (SELECT LTRIM(RTRIM(ColValue)) FROM dbo.fnc_delimsplit (',',@c_GetOrdType) )
      	BEGIN
      		SET @n_PrintAction = 0
            GOTO QUIT_SP
      	END
      END
      
      IF ISNULL(@c_GetECOMFlag,'') <> ''
      BEGIN
      	IF @c_ECOMFlag NOT IN (SELECT LTRIM(RTRIM(ColValue)) FROM dbo.fnc_delimsplit (',',@c_GetECOMFlag) )
      	BEGIN
      		SET @n_PrintAction = 0
            GOTO QUIT_SP
      	END
      END
      
      --WL01 START
      IF ISNULL(@c_PDFNameFormat,'') = ''
         SELECT @c_PDFNameFormat = dbo.fnc_GetParamValueFromString('@c_PDFNameFormat', @c_Option5, @c_PDFNameFormat)   

      IF ISNULL(@c_Prefix,'') = ''
         SELECT @c_Prefix = dbo.fnc_GetParamValueFromString('@c_Prefix', @c_Option5, @c_Prefix)   
      
      IF ISNULL(@c_SubFolder,'') = ''
         SELECT @c_SubFolder = dbo.fnc_GetParamValueFromString('@c_SubFolder', @c_Option5, @c_SubFolder)   
         
      SELECT @c_GetPrintAction = dbo.fnc_GetParamValueFromString('@c_GetPrintAction', @c_Option5, @c_GetPrintAction)  
      --WL01 END
   END
  
   --@c_FileName = '<Orders.StorerKey>_<PREFIX>_<Orders.Externorderkey>.pdf' @c_Prefix = 'SuS_SHPLBL,SuS_Invoice'
   IF(@n_continue = 1 OR @n_continue = 2)
   BEGIN
      CREATE TABLE #TEMP_Prefix (SeqNo INT, Prefix NVARCHAR(100))

      CREATE TABLE #TEMP_Subfolder (SeqNo INT, SubFolder NVARCHAR(100))

      CREATE TABLE #TMP_Table (
         Parm1     NVARCHAR(200) NULL,
         Parm2     NVARCHAR(200) NULL,
         Parm3     NVARCHAR(200) NULL,
         Parm4     NVARCHAR(200) NULL,
         Parm5     NVARCHAR(200) NULL,
         Parm6     NVARCHAR(200) NULL,
         Parm7     NVARCHAR(200) NULL,
         Parm8     NVARCHAR(200) NULL,
         Parm9     NVARCHAR(200) NULL,
         Parm10    NVARCHAR(200) NULL )
      
      DECLARE @c_Parm1   NVARCHAR(200) = '',
              @c_Parm2   NVARCHAR(200) = '',
              @c_Parm3   NVARCHAR(200) = '',
              @c_Parm4   NVARCHAR(200) = '',
              @c_Parm5   NVARCHAR(200) = '',
              @c_Parm6   NVARCHAR(200) = '',
              @c_Parm7   NVARCHAR(200) = '',
              @c_Parm8   NVARCHAR(200) = '',
              @c_Parm9   NVARCHAR(200) = '',
              @c_Parm10  NVARCHAR(200) = ''
      
      DECLARE @c_Parm1label   NVARCHAR(200) = '',
              @c_Parm2label   NVARCHAR(200) = '',
              @c_Parm3label   NVARCHAR(200) = '',
              @c_Parm4label   NVARCHAR(200) = '',
              @c_Parm5label   NVARCHAR(200) = '',
              @c_Parm6label   NVARCHAR(200) = '',
              @c_Parm7label   NVARCHAR(200) = '',
              @c_Parm8label   NVARCHAR(200) = '',
              @c_Parm9label   NVARCHAR(200) = '',
              @c_Parm10label  NVARCHAR(200) = ''

      DECLARE --@c_FileName NVARCHAR(4000) = '<Orders.StorerKey>_<PREFIX>_<Orders.Externorderkey>.pdf',
              @n_FileNameLen INT, @n_Start INT, @n_End INT, @c_FileEXT NVARCHAR(50), 
              @c_PDFName NVARCHAR(4000), 
              @c_SQL NVARCHAR(4000) = 'SELECT TOP 1 ', @c_ExecArguments NVARCHAR(4000), @c_SQLInsert NVARCHAR(4000), @c_SQL2 NVARCHAR(4000),
              @c_SQLFrom NVARCHAR(4000) = 'FROM PACKHEADER (NOLOCK) JOIN ORDERS (NOLOCK) ON PACKHEADER.Orderkey = ORDERS.Orderkey 
                                           JOIN LOADPLANDETAIL (NOLOCK) ON LOADPLANDETAIL.Orderkey = ORDERS.Orderkey
                                           JOIN LOADPLAN (NOLOCK) ON LOADPLAN.Loadkey = LOADPLANDETAIL.Loadkey
                                           WHERE PACKHEADER.PickSlipNo = @c_Param01 ',
              @n_Count INT = 1, @n_CountCol INT = 0, @c_TempColumn NVARCHAR(4000) = '',
              @c_DelimiterStart NVARCHAR(10) = '<', @c_DelimiterEnd NVARCHAR(10) = '>'

      DECLARE @c_ColumnName NVARCHAR(4000), @c_TableName NVARCHAR(4000), @c_ColName NVARCHAR(4000), @c_ColType NVARCHAR(50)

      SET @c_PDFName = @c_PDFNameFormat
   END

   --Extract SubFolder, @c_ArchiveFolder must not start with \\
   IF(ISNULL(@c_SubFolder,'') <> '' AND LEFT(LTRIM(RTRIM(ISNULL(@c_ArchiveFolder,''))),2) <> '\\')
   BEGIN
      IF RIGHT(RTRIM(@c_PdfFolder),1) <> '\'
      BEGIN
         SET @c_PdfFolder = @c_PdfFolder + '\'
      END
         
      SET @c_PdfFolder = @c_PdfFolder + @c_SubFolder + '\'
      
      IF @b_Debug = 1
         SELECT @c_PdfFolder
   END
   
   --IF(@n_continue = 1 OR @n_continue = 2)
   --BEGIN
   --   INSERT INTO #TEMP_Prefix
   --   SELECT SeqNo, LTRIM(RTRIM(ColValue)) FROM dbo.fnc_delimsplit (',',@c_Prefix) 
   
   --   IF @n_NoOfPDFSheet = 1
   --   BEGIN
   --      SELECT @c_Prefix = ISNULL(Prefix,'')
   --      FROM #TEMP_Prefix
   --      WHERE SeqNo = 1
   --   END
   --   ELSE IF @n_NoOfPDFSheet = 2
   --   BEGIN
   --      SELECT @c_Prefix = ISNULL(Prefix,'')
   --      FROM #TEMP_Prefix
   --      WHERE SeqNo = 2
   --   END
   --   ELSE 
   --   BEGIN
   --      SELECT @n_continue = 3
   --      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60020  
   --      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) 
   --                      + ': Invalid @n_NoOfPDFSheet ' 
   --                      + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
   --      SET @n_PrintAction = 0
   --      GOTO QUIT_SP
   --   END
   --END
   
   --Check and extract prefix
   SELECT @c_Prefix = ISNULL(Prefix,'')
   FROM #TEMP_Prefix
   
   --Main function
   IF(@n_continue = 1 OR @n_continue = 2)
   BEGIN
      SELECT @c_FileEXT = REVERSE(LEFT(REVERSE(@c_PDFNameFormat), CHARINDEX('.',REVERSE(@c_PDFNameFormat))))   --.pdf
      SELECT @c_PDFNameFormat = SUBSTRING(@c_PDFNameFormat, 1, LEN(@c_PDFNameFormat) - LEN(@c_FileEXT))   --<Orders.StorerKey>_<PREFIX>_<Orders.Externorderkey>

      WHILE LEN(@c_PDFNameFormat) > 0
      BEGIN
         SET @n_FileNameLen = LEN(LTRIM(RTRIM(@c_PDFNameFormat)))
         SELECT @n_Start = CHARINDEX(@c_DelimiterStart, @c_PDFNameFormat,1)
         SELECT @n_End = CHARINDEX(@c_DelimiterEnd, @c_PDFNameFormat,1)
         
         SELECT @c_ColumnName = SUBSTRING(@c_PDFNameFormat, @n_Start + 1, @n_End - @n_Start - 1)
         
         SELECT @c_ColumnName = LTRIM(RTRIM(@c_ColumnName))
         
         IF @c_ColumnName = 'PREFIX' GOTO NEXT_LOOP
         
         SET @c_TableName = LEFT(@c_ColumnName, CharIndex('.', @c_ColumnName) - 1)  
         SET @c_ColName  = SUBSTRING(@c_ColumnName,   
                           CharIndex('.', @c_ColumnName) + 1, LEN(@c_ColumnName) - CharIndex('.', @c_ColumnName))  
         
         SET @c_ColType = ''  
         SELECT @c_ColType = DATA_TYPE   
         FROM   INFORMATION_SCHEMA.COLUMNS   
         WHERE  TABLE_NAME = @c_TableName  
         AND    COLUMN_NAME = @c_ColName  
         
         SET @c_SQL = @c_SQL + 'ISNULL(RTRIM(' + @c_ColumnName + '),'''') AS Parm' + CAST(@n_Count AS NVARCHAR(5)) +',  '
         
         SET @c_SQL2 = 'SELECT @c_Parm' + CAST(@n_Count AS NVARCHAR(5)) + 'label = ' + '''' + @c_DelimiterStart + LTRIM(RTRIM(@c_ColumnName)) + @c_DelimiterEnd + '''' 
         
         IF @b_Debug = 1
            SELECT @c_SQL2
         
         SET @c_ExecArguments = N'   @c_Parm1label             NVARCHAR(200) OUTPUT
                                   , @c_Parm2label             NVARCHAR(200) OUTPUT
                                   , @c_Parm3label             NVARCHAR(200) OUTPUT
                                   , @c_Parm4label             NVARCHAR(200) OUTPUT
                                   , @c_Parm5label             NVARCHAR(200) OUTPUT
                                   , @c_Parm6label             NVARCHAR(200) OUTPUT
                                   , @c_Parm7label             NVARCHAR(200) OUTPUT
                                   , @c_Parm8label             NVARCHAR(200) OUTPUT
                                   , @c_Parm9label             NVARCHAR(200) OUTPUT
                                   , @c_Parm10label            NVARCHAR(200) OUTPUT  '   
                                    
         EXEC sp_ExecuteSql     @c_SQL2, @c_ExecArguments, 
                                @c_Parm1label  OUTPUT 
                              , @c_Parm2label  OUTPUT
                              , @c_Parm3label  OUTPUT
                              , @c_Parm4label  OUTPUT
                              , @c_Parm5label  OUTPUT
                              , @c_Parm6label  OUTPUT
                              , @c_Parm7label  OUTPUT
                              , @c_Parm8label  OUTPUT
                              , @c_Parm9label  OUTPUT
                              , @c_Parm10label OUTPUT
         
         --SELECT @c_SQL
         
         IF ISNULL(RTRIM(@c_ColType), '') = ''   
         BEGIN  
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60030
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) 
                  + ': Invalid Column name. (' + @c_ColType + ')' 
                  + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            SET @n_PrintAction = 0
            GOTO QUIT_SP
         END  
         
         SET @n_Count = @n_Count + 1

NEXT_LOOP: 
         IF @b_Debug = 1     
            SELECT @c_ColType, @n_FileNameLen, @c_ColumnName, @c_TableName, @c_ColName, @n_End
      
         IF @n_FileNameLen - @n_End > 0
         BEGIN
            SELECT @c_PDFNameFormat = SUBSTRING(@c_PDFNameFormat, @n_End + 1, @n_FileNameLen - @n_End)
         END
         ELSE
         BEGIN
            SET @c_PDFNameFormat = ''
         END
      
         IF @b_Debug = 1
            SELECT @c_PDFNameFormat AS [FileName]
      END

      SET @c_SQLInsert = 'INSERT INTO #TMP_Table ('
      SET @n_CountCol = 1
      SET @n_Count = @n_Count - 1
      
      WHILE(@n_Count > 0)
      BEGIN
         SET @c_TempColumn = 'Parm' + CAST(@n_CountCol AS NVARCHAR(5)) + ', '
         SET @n_Count = @n_Count - 1
         SET @n_CountCol = @n_CountCol + 1
         SET @c_SQLInsert = @c_SQLInsert + ' ' + @c_TempColumn
      
         IF(@n_Count = 0)
         BEGIN
            SET @c_SQLInsert = LEFT(@c_SQLInsert, LEN(LTRIM(RTRIM(@c_SQLInsert))) - 1 ) + ' )'
         END
      END
      
      SELECT @c_SQL = @c_SQLInsert + ' ' + SUBSTRING(LTRIM(RTRIM(@c_SQL)), 1, LEN(LTRIM(RTRIM(@c_SQL))) - 1) + ' ' + LTRIM(RTRIM(@c_SQLFrom))

      IF @b_Debug = 1
         SELECT @c_SQL,@c_SQLInsert
      
      SET @c_ExecArguments = N'   @c_Param01           NVARCHAR(80), 
                                  @c_Param02           NVARCHAR(80), 
                                  @c_Param03           NVARCHAR(80), 
                                  @c_Param04           NVARCHAR(80), 
                                  @c_Param05           NVARCHAR(80) '     
                                                   
      EXEC sp_ExecuteSql     @c_SQL       
                           , @c_ExecArguments      
                           , @c_Param01   
                           , @c_Param02   
                           , @c_Param03  
                           , @c_Param04   
                           , @c_Param05  
                            
      SELECT @c_Parm1  = LTRIM(RTRIM(ISNULL(Parm1,''))),
             @c_Parm2  = LTRIM(RTRIM(ISNULL(Parm2,''))),
             @c_Parm3  = LTRIM(RTRIM(ISNULL(Parm3,''))),
             @c_Parm4  = LTRIM(RTRIM(ISNULL(Parm4,''))),
             @c_Parm5  = LTRIM(RTRIM(ISNULL(Parm5,''))),
             @c_Parm6  = LTRIM(RTRIM(ISNULL(Parm6,''))),
             @c_Parm7  = LTRIM(RTRIM(ISNULL(Parm7,''))),
             @c_Parm8  = LTRIM(RTRIM(ISNULL(Parm8,''))),
             @c_Parm9  = LTRIM(RTRIM(ISNULL(Parm9,''))),
             @c_Parm10 = LTRIM(RTRIM(ISNULL(Parm10,'')))
      FROM #TMP_Table

      IF @b_Debug = 1
         SELECT  @c_Parm1 
               , @c_Parm2 
               , @c_Parm3 
               , @c_Parm4 
               , @c_Parm5 
               , @c_Parm6 
               , @c_Parm7 
               , @c_Parm8 
               , @c_Parm9 
               , @c_Parm10

      SELECT @c_PDFName = REPLACE(@c_PDFName, @c_DelimiterStart + 'PREFIX' + @c_DelimiterEnd, @c_Prefix)
      SELECT @c_PDFName = REPLACE(@c_PDFName, @c_Parm1label, @c_Parm1)
      SELECT @c_PDFName = REPLACE(@c_PDFName, @c_Parm2label, @c_Parm2)
      SELECT @c_PDFName = REPLACE(@c_PDFName, @c_Parm3label, @c_Parm3)
      SELECT @c_PDFName = REPLACE(@c_PDFName, @c_Parm4label, @c_Parm4)
      SELECT @c_PDFName = REPLACE(@c_PDFName, @c_Parm5label, @c_Parm5)
      SELECT @c_PDFName = REPLACE(@c_PDFName, @c_Parm6label, @c_Parm6)
      SELECT @c_PDFName = REPLACE(@c_PDFName, @c_Parm7label, @c_Parm7)
      SELECT @c_PDFName = REPLACE(@c_PDFName, @c_Parm8label, @c_Parm8)
      SELECT @c_PDFName = REPLACE(@c_PDFName, @c_Parm9label, @c_Parm9)
      SELECT @c_PDFName = REPLACE(@c_PDFName, @c_Parm10label, @c_Parm10)

      IF @b_Debug = 1
         SELECT @c_PDFName

      IF ISNULL(@c_Parm1label,'') <> '' AND ISNULL(@c_Parm1,'') = ''
      BEGIN
      	SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 65111   
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': ' + @c_Parm1label + ' is empty. '
                         +'(ispGetUCCLABELPDF_Label_MY)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
      	SET @n_PrintAction = 0
         GOTO QUIT_SP
      END
      ELSE IF ISNULL(@c_Parm2label,'') <> '' AND ISNULL(@c_Parm2,'') = ''
      BEGIN
      	SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 65111   
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': ' + @c_Parm2label + ' is empty. '
                         +'(ispGetUCCLABELPDF_Label_MY)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
      	SET @n_PrintAction = 0
         GOTO QUIT_SP
      END
      ELSE IF ISNULL(@c_Parm3label,'') <> '' AND ISNULL(@c_Parm3,'') = ''
      BEGIN
      	SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 65111   
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': ' + @c_Parm3label + ' is empty. '
                         +'(ispGetUCCLABELPDF_Label_MY)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
      	SET @n_PrintAction = 0
         GOTO QUIT_SP
      END
      ELSE IF ISNULL(@c_Parm4label,'') <> '' AND ISNULL(@c_Parm4,'') = ''
      BEGIN
      	SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 65111   
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': ' + @c_Parm4label + ' is empty. '
                         +'(ispGetUCCLABELPDF_Label_MY)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
      	SET @n_PrintAction = 0
         GOTO QUIT_SP
      END
      ELSE IF ISNULL(@c_Parm5label,'') <> '' AND ISNULL(@c_Parm5,'') = ''
      BEGIN
      	SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 65111   
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': ' + @c_Parm5label + ' is empty. '
                         +'(ispGetUCCLABELPDF_Label_MY)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
      	SET @n_PrintAction = 0
         GOTO QUIT_SP
      END
      ELSE IF ISNULL(@c_Parm6label,'') <> '' AND ISNULL(@c_Parm6,'') = ''
      BEGIN
      	SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 65111   
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': ' + @c_Parm6label + ' is empty. '
                         +'(ispGetUCCLABELPDF_Label_MY)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
      	SET @n_PrintAction = 0
         GOTO QUIT_SP
      END
      ELSE IF ISNULL(@c_Parm7label,'') <> '' AND ISNULL(@c_Parm7,'') = ''
      BEGIN
      	SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 65111   
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': ' + @c_Parm7label + ' is empty. '
                         +'(ispGetUCCLABELPDF_Label_MY)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
      	SET @n_PrintAction = 0
         GOTO QUIT_SP
      END
      ELSE IF ISNULL(@c_Parm8label,'') <> '' AND ISNULL(@c_Parm8,'') = ''
      BEGIN
      	SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 65111   
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': ' + @c_Parm8label + ' is empty. '
                         +'(ispGetUCCLABELPDF_Label_MY)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
      	SET @n_PrintAction = 0
         GOTO QUIT_SP
      END
      ELSE IF ISNULL(@c_Parm9label,'') <> '' AND ISNULL(@c_Parm9,'') = ''
      BEGIN
      	SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 65111   
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': ' + @c_Parm9label + ' is empty. '
                         +'(ispGetUCCLABELPDF_Label_MY)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
      	SET @n_PrintAction = 0
         GOTO QUIT_SP
      END
      ELSE IF ISNULL(@c_Parm10label,'') <> '' AND ISNULL(@c_Parm10,'') = ''
      BEGIN
      	SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 65111   
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': ' + @c_Parm10label + ' is empty. '
                         +'(ispGetUCCLABELPDF_Label_MY)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
      	SET @n_PrintAction = 0
         GOTO QUIT_SP
      END
   END

   /*
   SELECT @c_OrderKey    = LTRIM(RTRIM(ISNULL(ORDERS.OrderKey,''))) 
        , @c_DocType     = LTRIM(RTRIM(ISNULL(ORDERS.DocType,''))) 
        , @c_OrdType     = LTRIM(RTRIM(ISNULL(ORDERS.[Type],'')))
        , @c_ExtOrderkey = LTRIM(RTRIM(ISNULL(ORDERS.ExternOrderKey,'')))
        , @c_Shipperkey  = LTRIM(RTRIM(ISNULL(ORDERS.ShipperKey,'')))
        , @c_TrackingNo  = LTRIM(RTRIM(ISNULL(ORDERS.TrackingNo,'')))
        , @c_ECOMFlag    = LTRIM(RTRIM(ISNULL(ORDERS.ECOM_Single_Flag,'')))
   FROM PACKHEADER (NOLOCK)
   JOIN ORDERS (NOLOCK) ON PACKHEADER.Orderkey = ORDERS.Orderkey
   WHERE PACKHEADER.PickSlipNo = @c_Param01 */

   IF (@n_continue = 1 OR @n_continue = 2)
   BEGIN
      IF ISNULL(@c_Printer,'') = ''
      BEGIN
         SELECT TOP 1 
            @c_PrinterID = DefaultPrinter
         FROM RDT.RDTUser (NOLOCK)   
         WHERE UserName = @c_userid
      END
      ELSE
      BEGIN
         IF EXISTS (SELECT 1 FROM RDT.RDTPRINTER (NOLOCK) WHERE PRINTERID = @c_Printer)
         BEGIN
            SET @c_PrinterID = @c_Printer
         END
         ELSE
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60040  
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) 
                  + ': PrinterID not setup. (' + @c_Printer + ')' 
                  + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            SET @n_PrintAction = 0
            GOTO QUIT_SP
         END
      END
   END

   IF (@n_continue = 1 OR @n_continue = 2)
   BEGIN
      IF ISNULL(@c_PdfFolder,'') = '' 
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60050  
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) 
               + ': PDF Image Server Not Yet Setup/Enable In Storerconfig for Configkey :' + @c_Configkey + ' (ispGetUCCLABELPDF_Label_MY) '
               + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         SET @n_PrintAction = 0
         GOTO QUIT_SP
       END

      IF RIGHT(RTRIM(@c_PdfFolder),1) <> '\'
      BEGIN
         SET @c_PdfFolder = @c_PdfFolder + '\'
      END

      IF RIGHT(LTRIM(RTRIM(@c_ArchiveFolder)),1) <> '\'
      BEGIN
         SET @c_ArchiveFolder = @c_ArchiveFolder + '\'
      END

      IF LEFT(LTRIM(@c_ArchiveFolder),2) <> '\\'
      BEGIN
         SET @c_ArchiveFolder = @c_PdfFolder + @c_ArchiveFolder
      END

      --Normal Folder
      SET @n_IsExists = 0

      SET @c_PDFFilePath = @c_PdfFolder + @c_PDFName
      SET @c_PdfFile = @c_PDFFilePath
      EXEC dbo.xp_fileexist @c_PDFFilePath, @n_IsExists OUTPUT

      IF @n_IsExists = 0
      BEGIN
         SET @c_PDFFilePath = @c_ArchiveFolder + @c_PDFName
         SET @c_PdfFile = @c_PDFFilePath
         SET @c_ArchivePath = '' 
         SET @c_ActionType = '2'
         EXEC dbo.xp_fileexist @c_PDFFilePath, @n_IsExists OUTPUT 
      END

      IF @n_IsExists = 0 
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60060   
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': PDF - ' + @c_PDFName + ' Not Found.'
                         +'(ispGetUCCLABELPDF_Label_MY)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         SET @n_PrintAction = 0
         GOTO QUIT_SP  
      END
   END
   
   IF (@n_continue = 1 OR @n_continue = 2)
   BEGIN
      SELECT @c_WinPrinter = WinPrinter  
            ,@c_SpoolerGroup = ISNULL(RTRIM(SpoolerGroup),'') 
      FROM rdt.rdtPrinter WITH (NOLOCK)  
      WHERE PrinterID =  @c_PrinterID 
   
      IF CHARINDEX(',' , @c_WinPrinter) > 0 
      BEGIN
         SET @c_Printer = LEFT( @c_WinPrinter , (CHARINDEX(',' , @c_WinPrinter) - 1) )    
         SET @c_PrinterName = LEFT( @c_WinPrinter , (CHARINDEX(',' , @c_WinPrinter) - 1) )    
      END
      ELSE
      BEGIN
         SET @c_Printer = @c_WinPrinter
         SET @c_PrinterName =  @c_WinPrinter 
      END
   END

   IF ISNULL(@c_PDFFilePath,'') = ''
   BEGIN
      SET @n_PrintAction = 0
   END
   ELSE
   BEGIN
   	SET @n_PrintAction = 1

   	--WL01 START
   	IF ISNUMERIC(@c_GetPrintAction) = 1
   	BEGIN
   		SET @n_PrintAction = CAST(@c_GetPrintAction AS INT)
   	END
   	--WL01 END
   END
           
  --QCMD_END:                  
  --SET @b_success = 2         
                
QUIT_SP:
   IF OBJECT_ID('tempdb..#TEMP_Prefix') IS NOT NULL
      DROP TABLE #TEMP_Prefix

   IF OBJECT_ID('tempdb..#TMP_Table') IS NOT NULL
      DROP TABLE #TMP_Table 

   IF OBJECT_ID('tempdb..#TEMP_Subfolder') IS NOT NULL
      DROP TABLE #TEMP_Subfolder

  IF @n_continue=3  -- Error Occured - Process And Return
  BEGIN
      SELECT @b_success = 0     
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt 
      BEGIN
         ROLLBACK TRAN
      END
      ELSE 
      BEGIN
         WHILE @@TRANCOUNT > @n_starttcnt 
         BEGIN
            COMMIT TRAN
         END          
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, "ispGetUCCLABELPDF_Label_MY"
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE 
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_starttcnt 
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END  

SET QUOTED_IDENTIFIER OFF 

GO