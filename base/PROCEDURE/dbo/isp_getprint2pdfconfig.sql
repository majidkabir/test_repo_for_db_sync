SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/  
/* Stored Procedure: isp_GetPrint2PDFConfig                                */  
/* Creation Date: 22-Oct-2019                                              */  
/* Copyright: MAERSK                                                       */  
/* Written by:                                                             */  
/*                                                                         */  
/* Purpose: Print to PDF  (ispGet<Module>PDFXX)                            */                                 
/*                                                                         */  
/* Called By:                                                              */  
/*                                                                         */  
/*                                                                         */  
/* PVCS Version: 1.7                                                       */  
/*                                                                         */  
/* Version: 7.0                                                            */  
/*                                                                         */  
/* Data Modifications:                                                     */  
/*                                                                         */  
/* Updates:                                                                */  
/* Date           Ver    Author   Purposes                                 */  
/* 07-01-2020     1.1    WLChooi  WMS-13933 & WMS-12449 & WMS-12443 - Print*/
/*                                PDF Enhancement - New Function (WL01)    */
/* 06-04-2021     1.2    WLChooi  WMS-16755 - Add Function to Print From   */
/*                                Order Screen (WL02)                      */
/* 10-06-2021     1.3    WLChooi  WMS-17206 - Indicate Auto Print from     */
/*                                Packing Module (Normal & ECOM) (WL03)    */
/* 09-09-2021     1.4    WLChooi  WMS-17943 - Allow continue other printing*/
/*                                method if print PDF failed (WL04)        */
/* 04-10-2021     1.5    WLChooi  DevOps Combine Script                    */
/* 04-10-2021     1.6    WLChooi  WMS-18094 - Add Function to Print From   */
/*                                MBOL Screen (WL05)                       */
/* 28-Apr-2023    1.7    WLChooi  WMS-22460 - Allow custom dimension for   */
/*                                shipperkey (WL06)                        */
/***************************************************************************/    
CREATE   PROC [dbo].[isp_GetPrint2PDFConfig]    
(     
      @c_Storerkey     NVARCHAR(15),
      @c_Facility      NVARCHAR(5), 
      @c_Configkey     NVARCHAR(30),
      @c_Param01       NVARCHAR(50),
      @c_Param02       NVARCHAR(50),
      @c_Param03       NVARCHAR(50),
      @c_Param04       NVARCHAR(50),
      @c_Param05       NVARCHAR(50),
      @c_PdfFile       NVARCHAR(500) OUTPUT,
      @c_Printer       NVARCHAR(500) OUTPUT,
      @c_ArchiveFolder NVARCHAR(500) OUTPUT,
      @c_ActionType    NVARCHAR(10)  OUTPUT,  --2 = Print and don't move 3 = Print and move (Default)
      @n_PrintAction   INT           OUTPUT,  --0 = Not print PDF  1=Print PDF   2=Print PDF and continue other printing 3-Print PDF through backend (QCommander), continue other printing (no front end printing)
      @c_Dimension     NVARCHAR(50)  OUTPUT,  --Dimension in mm x mm, eg. 210x297
      @n_NoOfPDFSheet  INT = 1,               --PDF Sheets number (For 1 ReportType print multiple layout)
      --@c_PostPrinting  NVARCHAR(1)   OUTPUT,  --Y - PostPrinting, N - DirectPrint (Need to wait)
      @b_Success       INT           OUTPUT,  
      @n_Err           INT           OUTPUT, 
      @c_ErrMsg        NVARCHAR(255) OUTPUT,    
      @c_FromModule    NVARCHAR(100) = ''         --Call from which module from Exceed   --WL01   --For Packing only, @c_FromModule = PACKING - Manual Print, @c_FromModule = PACKING_AUTO - Auto Print upon Pack confirm/New Carton/Close Query
)    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE @n_Continue     INT   
         , @n_StartTCount  INT   
         , @c_SPCode       NVARCHAR(50)
         , @c_SQL          NVARCHAR(MAX)         
         , @c_authority    NVARCHAR(30)
         , @c_option1      NVARCHAR(50)
         , @c_option2      NVARCHAR(50)
         , @c_option3      NVARCHAR(50)
         , @c_option4      NVARCHAR(50)
         , @c_option5      NVARCHAR(4000)
         , @c_PdfFolder    NVARCHAR(500)
         , @dt_timeIn      DATETIME
         , @dt_timeOut     DATETIME

   DECLARE @c_TraceCode   NVARCHAR(20) = 'Print2PDFMainSP'  
         , @c_TraceName   NVARCHAR(80) = 'isp_GetPrint2PDFConfig'   
         
   --WL01 S
   DECLARE   @c_PDFNameFormat     NVARCHAR(4000)
           , @c_Prefix            NVARCHAR(500) 
           , @c_SubFolder         NVARCHAR(500) 
           , @c_GetPrintAction    NVARCHAR(1)  
           , @c_BackendPrinting   NVARCHAR(10)
           , @c_PrinterType       NVARCHAR(100) 
           , @b_Debug             INT = 0
           , @c_SearchMethod      NVARCHAR(10) = '1'
           
   DECLARE @c_Exist               NVARCHAR(MAX)
         , @c_NotExist            NVARCHAR(MAX)
         , @c_Contain             NVARCHAR(MAX)
         
   CREATE TABLE #TEMP_Prefix (SeqNo INT, Prefix NVARCHAR(100))

   CREATE TABLE #TEMP_Subfolder (SeqNo INT, SubFolder NVARCHAR(100))
   
   CREATE TABLE #TEMP_Dimension (SeqNo INT, Dimension NVARCHAR(100))
   
   CREATE TABLE #TEMP_PrinterType (SeqNo INT, PrinterType NVARCHAR(100))
   
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
           @c_ExecArguments NVARCHAR(4000), @c_SQLInsert NVARCHAR(4000), @c_SQL2 NVARCHAR(4000),
           @c_SQLFrom NVARCHAR(4000),
           @n_Count INT = 1, @n_CountCol INT = 0, @c_TempColumn NVARCHAR(4000) = '',
           @c_DelimiterStart NVARCHAR(10) = '<', @c_DelimiterEnd NVARCHAR(10) = '>'
   
   DECLARE @c_TableName NVARCHAR(4000), @c_ColName NVARCHAR(4000), @c_ColType NVARCHAR(50)
   
   DECLARE @b_InValid bit 

   DECLARE @n_RecFound          INT, 
           @c_Type              NVARCHAR(10),
           @c_SQLArg            NVARCHAR(MAX)
              
   DECLARE @c_GetConditionName  NVARCHAR(255),
           @c_GetColumnName     NVARCHAR(255),
           @c_GetCondition      NVARCHAR(MAX),
           @c_GetType           NVARCHAR(255),
           @c_GetOrderkey       NVARCHAR(10),
           @b_CheckConso        BIT,
           @c_OldWayToPrint     NVARCHAR(1) = '0'
           
   --WL01 E

   DECLARE @c_ContinuePrintIfFail NVARCHAR(10) = 'N'   --WL04

   DECLARE @c_GetDimensionFrShipperkey NVARCHAR(10)  = 'N'   --WL06
         , @c_Shipperkey               NVARCHAR(250) = ''    --WL06
         , @c_uDimension               NVARCHAR(250) = ''    --WL06

   --WL03 S
   IF @n_Err = 1
   BEGIN
      SET @b_Debug = 1
      SET @n_Err   = 0
   END
   --WL03 E
   
   SET @b_Success= 1   
   SET @n_Err    = 0    
   SET @c_ErrMsg = ''   
   SET @n_Continue = 1    
   SET @n_StartTCount = @@TRANCOUNT  
   SET @dt_timeIn = GETDATE()

   EXECUTE nspGetRight                                
    @c_Facility  = @c_facility,                     
    @c_StorerKey = @c_StorerKey,                    
    @c_sku       = '',
    @c_ConfigKey =  @c_Configkey,
    @b_Success   = @b_success   OUTPUT,             
    @c_authority = @c_authority OUTPUT,             
    @n_err       = @n_err       OUTPUT,             
    @c_errmsg    = @c_errmsg    OUTPUT,             
    @c_Option1   = @c_option1 OUTPUT,               
    @c_Option2   = @c_option2 OUTPUT,               
    @c_Option3   = @c_option3 OUTPUT,               
    @c_Option4   = @c_option4 OUTPUT,               
    @c_Option5   = @c_option5 OUTPUT   --@c_PdfFolder  @c_ArchiveFolder  @c_Printer @c_PostPrinting @c_Dimension   e.g.  @c_ArchiveFolder=c:\pdf\archive @c_printer=PDF Creator @c_Dimension=210x297
     
   IF ISNULL(@c_authority,'') <> '1'
   BEGIN
        SET @n_PrintAction = 0
        GOTO QUIT_SP
   END
   
   IF ISNULL(@c_ArchiveFolder,'') = ''
      SELECT @c_ArchiveFolder = dbo.fnc_GetParamValueFromString('@c_ArchiveFolder', @c_Option5, @c_ArchiveFolder)  

   IF ISNULL(@c_Printer,'') = ''
      SELECT @c_Printer = dbo.fnc_GetParamValueFromString('@c_Printer', @c_Option5, @c_Printer) 
      
   IF ISNULL(@c_Dimension,'') = ''
      SELECT @c_Dimension = dbo.fnc_GetParamValueFromString('@c_Dimension', @c_Option5, @c_Dimension)       

   --IF ISNULL(@c_PostPrinting,'') = ''
   --   SELECT @c_PostPrinting = dbo.fnc_GetParamValueFromString('@c_PostPrinting', @c_Option5, @c_PostPrinting)  
      
   --IF ISNULL(@c_PostPrinting,'') = ''
   --   SET @c_PostPrinting = 'Y'     --Default = 'Y'
   
   --WL01 S
   IF ISNULL(@c_PDFNameFormat,'') = ''
      SELECT @c_PDFNameFormat = dbo.fnc_GetParamValueFromString('@c_PDFNameFormat', @c_Option5, @c_PDFNameFormat)   

   IF ISNULL(@c_Prefix,'') = ''
      SELECT @c_Prefix = dbo.fnc_GetParamValueFromString('@c_Prefix', @c_Option5, @c_Prefix)   
   
   IF ISNULL(@c_SubFolder,'') = ''
      SELECT @c_SubFolder = dbo.fnc_GetParamValueFromString('@c_SubFolder', @c_Option5, @c_SubFolder)   
      
   SELECT @c_GetPrintAction = dbo.fnc_GetParamValueFromString('@c_GetPrintAction'  , @c_Option5, @c_GetPrintAction)  
   SELECT @c_PrinterType    = dbo.fnc_GetParamValueFromString('@c_PrinterType'     , @c_Option5, @c_PrinterType)  
   SELECT @c_SearchMethod   = dbo.fnc_GetParamValueFromString('@c_SearchMethod'    , @c_Option5, @c_SearchMethod)  

   IF ISNULL(@c_SearchMethod,'') = ''
      SET @c_SearchMethod = '1'

   --WL04
   SELECT @c_ContinuePrintIfFail = dbo.fnc_GetParamValueFromString('@c_ContinuePrintIfFail'
                                                                  , @c_Option5
                                                                  , @c_ContinuePrintIfFail)
    
   --WL06 S
   SELECT @c_GetDimensionFrShipperkey = dbo.fnc_GetParamValueFromString('@c_GetDimensionFrShipperkey'
                                                                       , @c_Option5
                                                                       , @c_GetDimensionFrShipperkey)
   
   --WL06 E

   IF @c_FromModule IN ('PACKING', 'PACKING_AUTO')   --WL03
   BEGIN
      SELECT @c_GetOrderkey = Orderkey
      FROM PACKHEADER (NOLOCK)
      WHERE PickSlipNo = @c_Param01
   
      IF @c_GetOrderkey = ''
      BEGIN
         SET @b_CheckConso = 1
      END
      ELSE
      BEGIN
         SET @b_CheckConso = 0
      END
   END
   --WL01 E

   SELECT @c_PdfFolder = dbo.fnc_GetParamValueFromString('@c_PdfFolder', @c_Option5, @c_PdfFolder)          
   
   IF ISNULL(@c_Option1,'') = ''
   BEGIN
      SET @c_SPCode = 'isp_GetPrint2PDF_Generic'
   END
   ELSE
   BEGIN
      SELECT @c_SPCode = @c_Option1
   END

   --SELECT @c_PdfFolder, @c_ArchiveFolder, @c_Printer, @c_SPCode
   
   --WL01 S
   --Backward Compatibility
   IF NOT EXISTS (SELECT 1
              FROM sys.parameters AS p
              JOIN sys.types AS t ON t.user_type_id = p.user_type_id
              WHERE object_id = OBJECT_ID(RTRIM(@c_SPCode))
              AND   P.name = N'@c_FromModule')
   BEGIN
      SELECT @c_OldWayToPrint = '1'
      GOTO BackwardCompatible
   END
   
   --Backend Printing (Not using ActiveX to print PDF)
   IF(@n_continue = 1 OR @n_continue = 2)
   BEGIN
      SELECT @c_BackendPrinting = dbo.fnc_GetParamValueFromString('@c_BackendPrinting', @c_Option5, @c_BackendPrinting)  
      
      IF @c_BackendPrinting IN ('Y','1')
      BEGIN
         --EXEC SP here
         SET @n_PrintAction = 3
         GOTO QUIT_SP
      END
   END
   
   IF(@n_continue = 1 OR @n_continue = 2)
   BEGIN  
      IF @c_FromModule IN ('PACKING', 'PACKING_AUTO') AND @b_CheckConso = 1   --WL03
      BEGIN
         SET @c_SQL = N' SELECT @n_RecFound = COUNT(1)'
         SET @c_SQLFrom = ' FROM PACKHEADER (NOLOCK) '
                         +' JOIN LOADPLANDETAIL (NOLOCK) ON LOADPLANDETAIL.Loadkey = PACKHEADER.Loadkey '
                         +' JOIN ORDERS (NOLOCK) ON LOADPLANDETAIL.Orderkey = ORDERS.Orderkey '
                         +' JOIN PACKDETAIL (NOLOCK) ON PACKDETAIL.Pickslipno = PACKHEADER.Pickslipno'
                         +' LEFT JOIN PACKINFO (NOLOCK) ON PACKINFO.Pickslipno = PACKDETAIL.Pickslipno AND PACKINFO.CartonNo = PACKDETAIL.CartonNo'
                         +' LEFT JOIN ORDERINFO (NOLOCK) ON ORDERINFO.Orderkey = ORDERS.Orderkey '
                         +' WHERE PACKHEADER.PickSlipNo = @c_Param01 AND PACKDETAIL.CartonNo BETWEEN @c_Param02 AND @c_Param03'
      END
      ELSE IF @c_FromModule IN ('PACKING', 'PACKING_AUTO') AND @b_CheckConso = 0   --WL03
      BEGIN
         SET @c_SQL = N' SELECT @n_RecFound = COUNT(1)'
         SET @c_SQLFrom = ' FROM PACKHEADER (NOLOCK) '
                         +' JOIN ORDERS (NOLOCK) ON PACKHEADER.Orderkey = ORDERS.Orderkey '
                         +' JOIN PACKDETAIL (NOLOCK) ON PACKDETAIL.Pickslipno = PACKHEADER.Pickslipno'
                         +' LEFT JOIN PACKINFO (NOLOCK) ON PACKINFO.Pickslipno = PACKDETAIL.Pickslipno AND PACKINFO.CartonNo = PACKDETAIL.CartonNo'
                         +' LEFT JOIN ORDERINFO (NOLOCK) ON ORDERINFO.Orderkey = ORDERS.Orderkey '
                         +' WHERE PACKHEADER.PickSlipNo = @c_Param01 AND PACKDETAIL.CartonNo BETWEEN @c_Param02 AND @c_Param03'
      END
      ELSE IF @c_FromModule = 'LOADPLAN'
      BEGIN
         IF EXISTS (SELECT 1 FROM ORDERS (NOLOCK) WHERE OrderKey = @c_Param01 AND StorerKey = @c_Storerkey)
         BEGIN
            SET @c_SQL = N' SELECT @n_RecFound = COUNT(1)'
            SET @c_SQLFrom =  ' FROM LOADPLAN (NOLOCK) '
                             +' JOIN LOADPLANDETAIL (NOLOCK) ON LOADPLANDETAIL.Loadkey = LOADPLAN.Loadkey'
                             +' JOIN ORDERS (NOLOCK) ON LOADPLANDETAIL.Orderkey = ORDERS.Orderkey '
                             +' LEFT JOIN ORDERINFO (NOLOCK) ON ORDERINFO.Orderkey = ORDERS.Orderkey '
                             +' WHERE LOADPLANDETAIL.Orderkey = @c_Param01 '
         END
         ELSE
         BEGIN
            SET @c_SQL = N' SELECT @n_RecFound = COUNT(1)'
            SET @c_SQLFrom =  ' FROM LOADPLAN (NOLOCK) '
                             +' JOIN LOADPLANDETAIL (NOLOCK) ON LOADPLANDETAIL.Loadkey = LOADPLAN.Loadkey'
                             +' JOIN ORDERS (NOLOCK) ON LOADPLANDETAIL.Orderkey = ORDERS.Orderkey '
                             +' LEFT JOIN ORDERINFO (NOLOCK) ON ORDERINFO.Orderkey = ORDERS.Orderkey '
                             +' WHERE LOADPLAN.Loadkey = @c_Param01 '
         END
      END
      --WL02 S
      ELSE IF @c_FromModule = 'ORDER'
      BEGIN
         SET @c_SQL = N' SELECT @n_RecFound = COUNT(1)'
         SET @c_SQLFrom =  ' FROM ORDERS (NOLOCK) '
                          +' LEFT JOIN ORDERINFO (NOLOCK) ON ORDERINFO.Orderkey = ORDERS.Orderkey '
                          +' WHERE ORDERS.Orderkey = @c_Param01 '
      END
      --WL02 E
      --WL05 S
      ELSE IF @c_FromModule = 'MBOL'
      BEGIN
         IF EXISTS (SELECT 1 FROM ORDERS (NOLOCK) WHERE OrderKey = @c_Param01 AND StorerKey = @c_Storerkey)
         BEGIN
            SET @c_SQL = N' SELECT @n_RecFound = COUNT(1)'
            SET @c_SQLFrom =  ' FROM MBOL (NOLOCK) '
                             +' JOIN MBOLDETAIL (NOLOCK) ON MBOLDETAIL.MBOLKey = MBOL.MBOLKey'
                             +' JOIN ORDERS (NOLOCK) ON MBOLDETAIL.Orderkey = ORDERS.Orderkey '
                             +' LEFT JOIN ORDERINFO (NOLOCK) ON ORDERINFO.Orderkey = ORDERS.Orderkey '
                             +' WHERE MBOLDETAIL.Orderkey = @c_Param01 '
         END
         ELSE
         BEGIN
            SET @c_SQL = N' SELECT @n_RecFound = COUNT(1)'
            SET @c_SQLFrom =  ' FROM MBOL (NOLOCK) '
                             +' JOIN MBOLDETAIL (NOLOCK) ON MBOLDETAIL.MBOLKey = MBOL.MBOLKey'
                             +' JOIN ORDERS (NOLOCK) ON MBOLDETAIL.Orderkey = ORDERS.Orderkey '
                             +' LEFT JOIN ORDERINFO (NOLOCK) ON ORDERINFO.Orderkey = ORDERS.Orderkey '
                             +' WHERE MBOL.MBOLKey = @c_Param01 '
         END
      END
      --WL05 E

      SET @c_SQL = @c_SQL + @c_SQLFrom
          
      SELECT @c_Exist    = dbo.fnc_GetParamValueFromString('@c_Exist',     @c_Option5, @c_Exist)  
      SELECT @c_NotExist = dbo.fnc_GetParamValueFromString('@c_NotExist',  @c_Option5, @c_NotExist)  
      SELECT @c_Contain  = dbo.fnc_GetParamValueFromString('@c_Contain',   @c_Option5, @c_Contain)  
      
      EXECUTE [dbo].[isp_Print2PDF_Validation_Wrapper]                                    
           @c_Param01  = @c_Param01             
         , @c_Param02  = @c_Param02             
         , @c_Param03  = @c_Param03 
         , @c_Param04  = @c_Param04 
         , @c_Param05  = @c_Param05             
         , @c_Exist    = @c_Exist               
         , @c_NotExist = @c_NotExist            
         , @c_Contain  = @c_Contain             
         , @c_SQL      = @c_SQL                 
         , @b_InValid  = @b_InValid OUTPUT             
         , @b_Success  = @b_Success OUTPUT         
         , @n_Err      = @n_Err     OUTPUT          
         , @c_ErrMsg   = @c_ErrMsg  OUTPUT 
         
      IF @b_InValid = 1
         GOTO QUIT_SP  
   END

   --WL06 S
   IF @c_GetDimensionFrShipperkey = 'Y'
   BEGIN
      SET @c_SQL = 'SELECT TOP 1 @c_Shipperkey = ISNULL(ORDERS.Shipperkey,'''') '
      SET @c_SQL = @c_SQL + @c_SQLFrom
      SET @c_ExecArguments = N'   @c_Param01           NVARCHAR(80) 
                                , @c_Param02           NVARCHAR(80) 
                                , @c_Param03           NVARCHAR(80) 
                                , @c_Param04           NVARCHAR(80) 
                                , @c_Param05           NVARCHAR(80) 
                                , @c_Shipperkey        NVARCHAR(50) OUTPUT '     
                                                   
      EXEC sp_ExecuteSql     @c_SQL
                           , @c_ExecArguments
                           , @c_Param01
                           , @c_Param02
                           , @c_Param03
                           , @c_Param04
                           , @c_Param05
                           , @c_Shipperkey OUTPUT

      SET @c_Shipperkey = '@u_DIM_' + TRIM(@c_Shipperkey)

      SET @c_SQL = 'SELECT @c_uDimension = dbo.fnc_GetParamValueFromString('''+ @c_Shipperkey + ''', @c_Option5, '''') '

      SET @c_ExecArguments = N'  @c_Option5           NVARCHAR(MAX) 
                               , @c_uDimension        NVARCHAR(250) OUTPUT '     
                                                   
      EXEC sp_ExecuteSql @c_SQL
                       , @c_ExecArguments
                       , @c_Option5
                       , @c_uDimension OUTPUT

      IF ISNULL(@c_uDimension,'') <> ''
      BEGIN
         SET @c_Dimension = @c_uDimension
      END
   END
   --WL06 E

   --SELECT * FROM #TMP_Validation
   IF(@n_continue = 1 OR @n_continue = 2)
   BEGIN
      SET @c_PDFName = @c_PDFNameFormat
      SET @c_SQL = 'SELECT TOP 1 '
      
      --Check and extract prefix
      IF(@n_continue = 1 OR @n_continue = 2)
      BEGIN
         INSERT INTO #TEMP_Prefix
         SELECT SeqNo, LTRIM(RTRIM(ColValue)) FROM dbo.fnc_delimsplit (',',@c_Prefix) 

         SELECT @c_Prefix = ISNULL(Prefix,'')
         FROM #TEMP_Prefix
         WHERE SeqNo = @n_NoOfPDFSheet
         
         --IF ISNULL(@c_Prefix,'') = '' 
         --BEGIN
         --   SELECT @n_continue = 3
         --   SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60020  
         --   SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) 
         --                   + ': Invalid @n_NoOfPDFSheet OR Prefix ' 
         --                   + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         --   SET @n_PrintAction = 0
         --   GOTO QUIT_SP
         --END
         
         IF ISNULL(@c_Prefix,'') = ''
         BEGIN
            SELECT TOP 1 @c_Prefix = ISNULL(Prefix,'')
            FROM #TEMP_Prefix
         END
         
         IF ISNULL(@c_Prefix,'') = ''
            SET @c_Prefix = ''
      END
      
      --Check and extract subfolder
      IF(@n_continue = 1 OR @n_continue = 2)
      BEGIN
         INSERT INTO #TEMP_Subfolder
         SELECT SeqNo, LTRIM(RTRIM(ColValue)) FROM dbo.fnc_delimsplit (',',@c_Subfolder) 

         SELECT @c_Subfolder = ISNULL(Subfolder,'')
         FROM #TEMP_Subfolder
         WHERE SeqNo = @n_NoOfPDFSheet

         --IF ISNULL(@c_Subfolder,'') = '' 
         --BEGIN
         --   SELECT @n_continue = 3
         --   SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60020  
         --   SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) 
         --                   + ': Invalid @n_NoOfPDFSheet OR Subfolder ' 
         --                   + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         --   SET @n_PrintAction = 0
         --   GOTO QUIT_SP
         --END
         
         IF ISNULL(@c_Subfolder,'') = ''
         BEGIN
            SELECT TOP 1 @c_Subfolder = ISNULL(Subfolder,'')
            FROM #TEMP_Subfolder
         END
         
         IF ISNULL(@c_Subfolder,'') = ''
            SET @c_Subfolder = ''
      END
      
      --Check and extract dimension
      IF(@n_continue = 1 OR @n_continue = 2)
      BEGIN
         INSERT INTO #TEMP_Dimension
         SELECT SeqNo, LTRIM(RTRIM(ColValue)) FROM dbo.fnc_delimsplit (',',@c_Dimension) 

         SELECT @c_Dimension = ISNULL(Dimension,'')
         FROM #TEMP_Dimension
         WHERE SeqNo = @n_NoOfPDFSheet

         IF ISNULL(@c_Dimension,'') = ''
         BEGIN
            SELECT TOP 1 @c_Dimension = ISNULL(Dimension,'')
            FROM #TEMP_Dimension
         END
         
         IF ISNULL(@c_Dimension,'') = '' 
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60020  
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) 
                            + ': Invalid @n_NoOfPDFSheet OR Dimension ' 
                            + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            SET @n_PrintAction = 0
            GOTO QUIT_SP
         END
      END
      
      --Check and extract PrinterType
      IF(@n_continue = 1 OR @n_continue = 2)
      BEGIN
         INSERT INTO #TEMP_PrinterType
         SELECT SeqNo, LTRIM(RTRIM(ColValue)) FROM dbo.fnc_delimsplit (',',@c_PrinterType) 

         SELECT @c_PrinterType = ISNULL(PrinterType,'')
         FROM #TEMP_PrinterType
         WHERE SeqNo = @n_NoOfPDFSheet
         
         IF ISNULL(@c_PrinterType,'') = ''
         BEGIN
            SELECT TOP 1 @c_PrinterType = ISNULL(PrinterType,'')
            FROM #TEMP_PrinterType
         END
         
         IF ISNULL(@c_PrinterType,'') = ''
            SET @c_PrinterType = 'LABEL'
      END
      
      IF RIGHT(LTRIM(RTRIM(@c_PDFFolder)),1) = '\'
      BEGIN
         SELECT @c_PDFFolder = @c_PDFFolder + @c_Subfolder
      END
      ELSE
      BEGIN
         SELECT @c_PDFFolder = @c_PDFFolder + '\' + @c_Subfolder
      END
      --SELECT @c_Prefix, @c_Subfolder, @c_PDFFolder, @c_ArchiveFolder
   END

   --Main function
   IF(@n_continue = 1 OR @n_continue = 2)
   BEGIN
      SELECT @c_FileEXT = REVERSE(LEFT(REVERSE(@c_PDFNameFormat), CHARINDEX('.',REVERSE(@c_PDFNameFormat))))   --.pdf
      SELECT @c_PDFNameFormat = SUBSTRING(@c_PDFNameFormat, 1, LEN(@c_PDFNameFormat) - LEN(@c_FileEXT))   --<Orders.StorerKey>_<PREFIX>_<Orders.Externorderkey>

      WHILE LEN(@c_PDFNameFormat) > 0
      BEGIN
      	SELECT @c_PDFNameFormat = REPLACE(@c_PDFNameFormat,'.PDF','')
      	
         SET @n_FileNameLen = LEN(LTRIM(RTRIM(@c_PDFNameFormat)))
         SELECT @n_Start = CHARINDEX(@c_DelimiterStart, @c_PDFNameFormat,1)
         SELECT @n_End = CHARINDEX(@c_DelimiterEnd, @c_PDFNameFormat,1)
         
         IF @n_Start = 0 OR @n_End = 0
         BEGIN
            SET @c_PDFNameFormat = ''
            BREAK;
         END
            	
         SELECT @c_GetColumnName = SUBSTRING(@c_PDFNameFormat, @n_Start + 1, @n_End - @n_Start - 1)
         
         SELECT @c_GetColumnName = LTRIM(RTRIM(@c_GetColumnName))

         IF @c_GetColumnName IN ('PREFIX','LIKE') GOTO NEXT_LOOP
         
         SET @c_TableName = LEFT(@c_GetColumnName, CharIndex('.', @c_GetColumnName) - 1)  
         SET @c_ColName  = SUBSTRING(@c_GetColumnName,   
                           CharIndex('.', @c_GetColumnName) + 1, LEN(@c_GetColumnName) - CharIndex('.', @c_GetColumnName))  
         
         SET @c_ColType = ''  
         SELECT @c_ColType = DATA_TYPE   
         FROM   INFORMATION_SCHEMA.COLUMNS   
         WHERE  TABLE_NAME = @c_TableName  
         AND    COLUMN_NAME = @c_ColName  
         
         IF @c_ColType IN ('datetime')
         BEGIN
            SET @c_SQL = @c_SQL + 'ISNULL(RTRIM(CONVERT(NVARCHAR(10),' + @c_GetColumnName + ',112)),'''') AS Parm' + CAST(@n_Count AS NVARCHAR(5)) +',  '
         END
         ELSE
         BEGIN
            SET @c_SQL = @c_SQL + 'ISNULL(RTRIM(' + @c_GetColumnName + '),'''') AS Parm' + CAST(@n_Count AS NVARCHAR(5)) +',  '
         END
         
         SET @c_SQL2 = 'SELECT @c_Parm' + CAST(@n_Count AS NVARCHAR(5)) + 'label = ' + '''' + @c_DelimiterStart + LTRIM(RTRIM(@c_GetColumnName)) + @c_DelimiterEnd + '''' 
         
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

         --Prevent Infinite Loop
         IF @n_Count >=10
            BREAK;
NEXT_LOOP: 
         IF @b_Debug = 1     
            SELECT @c_ColType, @n_FileNameLen, @c_GetColumnName, @c_TableName, @c_ColName, @n_End
      
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
                         +'(isp_GetPrint2PDFConfig)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         SET @n_PrintAction = 0
         GOTO QUIT_SP
      END
      ELSE IF ISNULL(@c_Parm2label,'') <> '' AND ISNULL(@c_Parm2,'') = ''
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 65111   
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': ' + @c_Parm2label + ' is empty. '
                         +'(isp_GetPrint2PDFConfig)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         SET @n_PrintAction = 0
         GOTO QUIT_SP
      END
      ELSE IF ISNULL(@c_Parm3label,'') <> '' AND ISNULL(@c_Parm3,'') = ''
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 65111   
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': ' + @c_Parm3label + ' is empty. '
                         +'(isp_GetPrint2PDFConfig)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         SET @n_PrintAction = 0
         GOTO QUIT_SP
      END
      ELSE IF ISNULL(@c_Parm4label,'') <> '' AND ISNULL(@c_Parm4,'') = ''
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 65111   
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': ' + @c_Parm4label + ' is empty. '
                         +'(isp_GetPrint2PDFConfig)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         SET @n_PrintAction = 0
         GOTO QUIT_SP
      END
      ELSE IF ISNULL(@c_Parm5label,'') <> '' AND ISNULL(@c_Parm5,'') = ''
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 65111   
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': ' + @c_Parm5label + ' is empty. '
                         +'(isp_GetPrint2PDFConfig)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         SET @n_PrintAction = 0
         GOTO QUIT_SP
      END
      ELSE IF ISNULL(@c_Parm6label,'') <> '' AND ISNULL(@c_Parm6,'') = ''
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 65111   
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': ' + @c_Parm6label + ' is empty. '
                         +'(isp_GetPrint2PDFConfig)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         SET @n_PrintAction = 0
         GOTO QUIT_SP
      END
      ELSE IF ISNULL(@c_Parm7label,'') <> '' AND ISNULL(@c_Parm7,'') = ''
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 65111   
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': ' + @c_Parm7label + ' is empty. '
                         +'(isp_GetPrint2PDFConfig)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         SET @n_PrintAction = 0
         GOTO QUIT_SP
      END
      ELSE IF ISNULL(@c_Parm8label,'') <> '' AND ISNULL(@c_Parm8,'') = ''
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 65111   
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': ' + @c_Parm8label + ' is empty. '
                         +'(isp_GetPrint2PDFConfig)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         SET @n_PrintAction = 0
         GOTO QUIT_SP
      END
      ELSE IF ISNULL(@c_Parm9label,'') <> '' AND ISNULL(@c_Parm9,'') = ''
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 65111   
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': ' + @c_Parm9label + ' is empty. '
                         +'(isp_GetPrint2PDFConfig)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         SET @n_PrintAction = 0
         GOTO QUIT_SP
      END
      ELSE IF ISNULL(@c_Parm10label,'') <> '' AND ISNULL(@c_Parm10,'') = ''
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 65111   
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': ' + @c_Parm10label + ' is empty. '
                         +'(isp_GetPrint2PDFConfig)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         SET @n_PrintAction = 0
         GOTO QUIT_SP
      END
   END
   --WL01 S
NEXT:
   --SELECT @c_PDFName, @c_PdfFolder, @c_ArchiveFolder

   SET @c_PdfFile = @c_PDFName
   
BackwardCompatible:
   IF ISNULL(@c_SPCode,'') <> ''
   BEGIN
      IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPCode) AND type = 'P')  
      BEGIN  
            SET @n_Continue = 3
            SET @n_err      = 83010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+
            ': Storerconfig' + RTRIM(@c_configkey) + '.Option1 - Stored Proc name is invalid (isp_GetPrint2PDFConfig )'        
            GOTO QUIT_SP  
      END  
      
      --WL01 S
      --Remove Space
      SELECT @c_PDFFile = CAST(RTRIM(LTRIM(REPLACE(REPLACE(REPLACE(@c_PDFFile,CHAR(9),' '),CHAR(10),' '),CHAR(13),' '))) AS NVARCHAR(500))
   
      --IF EXISTS (SELECT 1
      --        FROM sys.parameters AS p
      --        JOIN sys.types AS t ON t.user_type_id = p.user_type_id
      --        WHERE object_id = OBJECT_ID(RTRIM(@c_SPCode))
      --        AND   P.name = N'@c_FromModule')
      IF @c_OldWayToPrint = '0'
      BEGIN      
         SET @c_SQL = 'EXEC ' + @c_SPCode + ' @c_Storerkey=@c_StorerkeyP, @c_Facility=@c_FacilityP, @c_Configkey=@c_ConfigkeyP, 
                      @c_Param01=@c_Param01P, @c_Param02=@c_Param02P, @c_Param03=@c_Param03P,@c_Param04=@c_Param04P, @c_Param05=@c_Param05P, @c_PdfFolder=@c_PdffolderP,
                      @c_PdfFile=@c_PdfFileP OUTPUT, @c_Printer=@c_PrinterP OUTPUT, @c_ArchiveFolder=@c_ArchiveFolderP OUTPUT, @c_ActionType=@c_ActionTypeP OUTPUT, @n_PrintAction=@n_PrintActionP OUTPUT,
                      @c_Dimension=@c_DimensionP OUTPUT, @n_NoOfPDFSheet=@n_NoOfPDFSheetP, @c_FromModule=@c_FromModuleP, @c_PrinterType=@c_PrinterTypeP, @c_SearchMethod=@c_SearchMethodP,
                      @b_Success=@b_SuccessP OUTPUT, @n_Err=@n_ErrP OUTPUT, @c_ErrMsg=@c_ErrMsgP OUTPUT '  
                      
         EXEC sp_executesql @c_SQL   
             ,N'@c_StorerkeyP NVARCHAR(15), @c_FacilityP NVARCHAR(5), @c_ConfigkeyP NVARCHAR(30), 
               @c_Param01P NVARCHAR(50), @c_Param02P NVARCHAR(50), @c_Param03P NVARCHAR(50),@c_Param04P NVARCHAR(50), @c_Param05P NVARCHAR(50), @c_PdfFolderP NVARCHAR(500),
               @c_PdfFileP NVARCHAR(500) OUTPUT, @c_PrinterP NVARCHAR(500) OUTPUT, @c_ArchiveFolderP NVARCHAR(500) OUTPUT, @c_ActionTypeP NVARCHAR(10) OUTPUT, @n_PrintActionP INT OUTPUT,
               @c_DimensionP NVARCHAR(50) OUTPUT, @n_NoOfPDFSheetP INT, @c_FromModuleP NVARCHAR(100), @c_PrinterTypeP NVARCHAR(100), @c_SearchMethodP NVARCHAR(10),
               @b_SuccessP INT OUTPUT, @n_ErrP INT OUTPUT, @c_ErrMsgP NVARCHAR(255) OUTPUT '   
             ,@c_Storerkey
             ,@c_Facility 
             ,@c_Configkey
             ,@c_Param01       
             ,@c_Param02
             ,@c_Param03
             ,@c_Param04
             ,@c_Param05
             ,@c_Pdffolder
             ,@c_PdfFile       OUTPUT
             ,@c_Printer       OUTPUT
             ,@c_ArchiveFolder OUTPUT
             ,@c_ActionType    OUTPUT  --2 = Print and don't move 3 = Print and move (Default)
             ,@n_PrintAction   OUTPUT  --0 =Not print PDF  1=Print PDF   2=Print PDF and continue other printing
             ,@c_Dimension     OUTPUT  --Dimension in mm x mm, eg. 210x297
             ,@n_NoOfPDFSheet          --PDF Sheets number (For 1 ReportType print multiple layout)
             ,@c_FromModule            --Call from which module from Exceed
             ,@c_PrinterType           --PrinterType: LABEL / PAPER, Default Label
             ,@c_SearchMethod          --1 = Get the PDF with complete file name 2 = Search the folder with partial PDF name
             --,@c_PostPrinting  OUTPUT  --Y - PostPrinting, N - DirectPrint (Need to wait)
             ,@b_Success       OUTPUT  
             ,@n_Err           OUTPUT  
             ,@c_ErrMsg        OUTPUT           
      END
      ELSE
      BEGIN
         SET @c_SQL = 'EXEC ' + @c_SPCode + ' @c_Storerkey=@c_StorerkeyP, @c_Facility=@c_FacilityP, @c_Configkey=@c_ConfigkeyP, 
                      @c_Param01=@c_Param01P, @c_Param02=@c_Param02P, @c_Param03=@c_Param03P,@c_Param04=@c_Param04P, @c_Param05=@c_Param05P, @c_PdfFolder=@c_PdffolderP,
                      @c_PdfFile=@c_PdfFileP OUTPUT, @c_Printer=@c_PrinterP OUTPUT, @c_ArchiveFolder=@c_ArchiveFolderP OUTPUT, @c_ActionType=@c_ActionTypeP OUTPUT, @n_PrintAction=@n_PrintActionP OUTPUT,
                      @c_Dimension=@c_DimensionP OUTPUT, @n_NoOfPDFSheet=@n_NoOfPDFSheetP,
                      @b_Success=@b_SuccessP OUTPUT, @n_Err=@n_ErrP OUTPUT, @c_ErrMsg=@c_ErrMsgP OUTPUT '  

         EXEC sp_executesql @c_SQL   
             ,N'@c_StorerkeyP NVARCHAR(15), @c_FacilityP NVARCHAR(5), @c_ConfigkeyP NVARCHAR(30), 
               @c_Param01P NVARCHAR(50), @c_Param02P NVARCHAR(50), @c_Param03P NVARCHAR(50),@c_Param04P NVARCHAR(50), @c_Param05P NVARCHAR(50), @c_PdfFolderP NVARCHAR(500),
               @c_PdfFileP NVARCHAR(500) OUTPUT, @c_PrinterP NVARCHAR(500) OUTPUT, @c_ArchiveFolderP NVARCHAR(500) OUTPUT, @c_ActionTypeP NVARCHAR(10) OUTPUT, @n_PrintActionP INT OUTPUT,
               @c_DimensionP NVARCHAR(50) OUTPUT, @n_NoOfPDFSheetP INT,
               @b_SuccessP INT OUTPUT, @n_ErrP INT OUTPUT, @c_ErrMsgP NVARCHAR(255) OUTPUT '   
             ,@c_Storerkey
             ,@c_Facility 
             ,@c_Configkey
             ,@c_Param01       
             ,@c_Param02
             ,@c_Param03
             ,@c_Param04
             ,@c_Param05
             ,@c_Pdffolder
             ,@c_PdfFile       OUTPUT
             ,@c_Printer       OUTPUT
             ,@c_ArchiveFolder OUTPUT
             ,@c_ActionType    OUTPUT  --2 = Print and don't move 3 = Print and move (Default)
             ,@n_PrintAction   OUTPUT  --0 =Not print PDF  1=Print PDF   2=Print PDF and continue other printing
             ,@c_Dimension     OUTPUT  --Dimension in mm x mm, eg. 210x297
             ,@n_NoOfPDFSheet          --PDF Sheets number (For 1 ReportType print multiple layout)
             --,@c_PostPrinting  OUTPUT  --Y - PostPrinting, N - DirectPrint (Need to wait)
             ,@b_Success       OUTPUT  
             ,@n_Err           OUTPUT  
             ,@c_ErrMsg        OUTPUT 
      END
      --WL01 E
      
      IF @b_Success <> 1
      BEGIN
         SET @n_Continue = 3
      END             
   END      
   ELSE
      SET @n_PrintAction = 1
   
   IF @n_PrintAction = 1
   BEGIN    
      IF ISNUMERIC(@c_GetPrintAction) = 1
      BEGIN
         SET @n_PrintAction = CAST(@c_GetPrintAction AS INT)
      END
   END  
   
QUIT_SP:
   IF OBJECT_ID('tempdb..#TEMP_Prefix') IS NOT NULL
      DROP TABLE #TEMP_Prefix
      
   IF OBJECT_ID('tempdb..#TEMP_Subfolder') IS NOT NULL
      DROP TABLE #TEMP_Subfolder
      
   IF OBJECT_ID('tempdb..#TEMP_Dimension') IS NOT NULL
      DROP TABLE #TEMP_Dimension
      
   IF OBJECT_ID('tempdb..#TEMP_PrinterType') IS NOT NULL
      DROP TABLE #TEMP_PrinterType
      
   IF OBJECT_ID('tempdb..#TMP_Table') IS NOT NULL
      DROP TABLE #TMP_Table
        
   SET @dt_timeOut = GETDATE()

   EXEC isp_InsertTraceInfo
           @c_TraceCode = @c_TraceCode
         , @c_TraceName = @c_TraceName
         , @c_starttime = @dt_timeIn 
         , @c_endtime   = @dt_timeOut  
         , @c_step1     = 'Param01'    
         , @c_step2     = 'Param02'    
         , @c_step3     = 'Param03'    
         , @c_step4     = 'Param04'    
         , @c_step5     = 'Param05'    
         , @c_col1      = @c_Param01   
         , @c_col2      = @c_Param02   
         , @c_col3      = @c_Param03   
         , @c_col4      = @c_Param04   
         , @c_col5      = @c_Param05 
         , @b_Success   = @b_Success
         , @n_Err       = @n_Err    
         , @c_ErrMsg    = @c_ErrMsg 


   IF @n_continue = 3  -- Error Occured - Process And Return  
   BEGIN  
      SET @b_success = 0  

      --WL04 S
      IF @n_PrintAction = 0 AND @c_ContinuePrintIfFail = 'Y'
      BEGIN
         SET @n_PrintAction = 2
      END
      ELSE
      BEGIN
         SET @n_PrintAction = 0
      END
      --WL04 E
  
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCount  
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_StartTCount  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
      Execute nsp_logerror @n_err, @c_errmsg, 'isp_GetPrint2PDFConfig'  
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE  
   BEGIN  
      SET @b_success = 1  
      WHILE @@TRANCOUNT > @n_StartTCount  
      BEGIN  
         COMMIT TRAN  
      END   
  
      RETURN  
   END   
END 

GO