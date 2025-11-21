SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: lsp_WM_Get_WebReport_URL                                */
/* Creation Date: 2020-08-13                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: LFWM-2278 - LF SCE JReport Integration Phase 2  Backend     */
/*          Setup  SPs Setup                                            */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 8.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2020-08-13  Wan      1.0   Created.                                  */
/* 2022-01-03  Wan01    1.1   DevOps Script Combine                     */
/* 2022-01-03  Wan01    1.1   Fixed. Error # is 6 NVARCHAR              */
/*                      1.1   Add Detail Level Logi report Catalogue    */
/* 2023-08-01  Wan02    1.2   PAC-15:Ecom Packing | Print Packing Report*/
/*                            - Backend                                 */
/* 2023-12-07  WLChooi  1.3   WMS-24329 Add full path for report (WL01) */
/************************************************************************/
CREATE   PROC [WM].[lsp_WM_Get_WebReport_URL]
           @c_ReportID           NVARCHAR(10)
         , @n_DetailRowID        BIGINT   = 0
         , @c_Parm1              NVARCHAR(200)  = ''
         , @c_Parm2              NVARCHAR(200)  = ''
         , @c_Parm3              NVARCHAR(200)  = ''
         , @c_Parm4              NVARCHAR(200)  = ''
         , @c_Parm5              NVARCHAR(200)  = ''
         , @c_Parm6              NVARCHAR(200)  = ''
         , @c_Parm7              NVARCHAR(200)  = ''
         , @c_Parm8              NVARCHAR(200)  = ''
         , @c_Parm9              NVARCHAR(200)  = ''
         , @c_Parm10             NVARCHAR(200)  = ''
         , @c_Parm11             NVARCHAR(200)  = ''
         , @c_Parm12             NVARCHAR(200)  = ''
         , @c_Parm13             NVARCHAR(200)  = ''
         , @c_Parm14             NVARCHAR(200)  = ''
         , @c_Parm15             NVARCHAR(200)  = ''
         , @c_Parm16             NVARCHAR(200)  = ''
         , @c_Parm17             NVARCHAR(200)  = ''
         , @c_Parm18             NVARCHAR(200)  = ''
         , @c_Parm19             NVARCHAR(200)  = ''
         , @c_Parm20             NVARCHAR(200)  = ''
         , @c_ReturnURL          NVARCHAR(4000) = ''  OUTPUT
         , @b_Success            INT = 1              OUTPUT
         , @n_err                INT = 0              OUTPUT
         , @c_ErrMsg             NVARCHAR(255) = ''   OUTPUT
         , @b_PrintOverInternet  INT = 0                                            --(Wan02)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE
           @n_StartTCnt          INT   = @@TRANCOUNT
         , @n_Continue           INT   = 1
         , @c_ReportURL          NVARCHAR(120)  = ''
         , @c_ReportFolder       NVARCHAR(120)  = ''
         , @c_CatalogFolder      NVARCHAR(120)  = ''
         , @c_ReportCatalog      NVARCHAR(120)  = ''
         , @c_ReportCLSFile      NVARCHAR(120)  = ''
         , @c_ReportFormat       NVARCHAR(20)   = '2'
         , @c_ReportFileName     NVARCHAR(50)   = ''
         , @c_NewID              NVARCHAR(50)   = ''
         , @c_ServerLoginAuth    NVARCHAR(120)  = ''
         , @c_Delim              NVARCHAR(1) = '&'
         , @c_ReportParm         NVARCHAR(4000)= ''
         , @c_ReportParmName1   NVARCHAR(100) = ''
         , @c_ReportParmName2   NVARCHAR(100) = ''
         , @c_ReportParmName3   NVARCHAR(100) = ''
         , @c_ReportParmName4   NVARCHAR(100) = ''
         , @c_ReportParmName5   NVARCHAR(100) = ''
         , @c_ReportParmName6   NVARCHAR(100) = ''
         , @c_ReportParmName7   NVARCHAR(100) = ''
         , @c_ReportParmName8   NVARCHAR(100) = ''
         , @c_ReportParmName9   NVARCHAR(100) = ''
         , @c_ReportParmName10  NVARCHAR(100) = ''
         , @c_ReportParmName11  NVARCHAR(100) = ''
         , @c_ReportParmName12  NVARCHAR(100) = ''
         , @c_ReportParmName13  NVARCHAR(100) = ''
         , @c_ReportParmName14  NVARCHAR(100) = ''
         , @c_ReportParmName15  NVARCHAR(100) = ''
         , @c_ReportParmName16  NVARCHAR(100) = ''
         , @c_ReportParmName17  NVARCHAR(100) = ''
         , @c_ReportParmName18  NVARCHAR(100) = ''
         , @c_ReportParmName19  NVARCHAR(100) = ''
         , @c_ReportParmName20  NVARCHAR(100) = ''
   SET @b_Success = 1
   SET @n_err     = 0
   SET @c_ErrMsg  = ''
   SET @c_ReturnURL = ''
   BEGIN TRY
      SELECT @c_ReportURL       = ISNULL(MAX(CASE WHEN CFG.ConfigKey = 'JReportURL'                 THEN CFG.NSQLDescrip ELSE '' END),'')
         ,   @c_ReportFolder    = ISNULL(MAX(CASE WHEN CFG.ConfigKey = 'JReportDefaultReportFolder' THEN CFG.NSQLDescrip ELSE '' END),'')
         ,   @c_CatalogFolder   = ISNULL(MAX(CASE WHEN CFG.ConfigKey = 'JReportDefaultCatalogFolder'THEN CFG.NSQLDescrip ELSE '' END),'')
         ,   @c_ReportCatalog   = ISNULL(MAX(CASE WHEN CFG.ConfigKey = 'JReportDefaultCatalog'      THEN CFG.NSQLDescrip ELSE '' END),'')
         ,   @c_ServerLoginAuth = ISNULL(MAX(CASE WHEN CFG.ConfigKey = 'JReportAuthorization'       THEN CFG.NSQLDescrip ELSE '' END),'')
      FROM NSQLCONFIG CFG (NOLOCK)
      WHERE ConfigKey IN ( 'JReportURL'
                        ,  'JReportDefaultReportFolder'
                        ,  'JReportDefaultCatalogFolder'
                        ,  'JReportDefaultCatalog'
                        ,  'JReportAuthorization'
                        )
      SELECT  @c_ReportCLSFile   = WMRD.ReportTemplate
            , @c_ReportFormat    = WMRD.ReportFormat
            , @c_ReportParmName1 = WMRD.ReportParmName1
            , @c_ReportParmName2 = WMRD.ReportParmName2
            , @c_ReportParmName3 = WMRD.ReportParmName3
            , @c_ReportParmName4 = WMRD.ReportParmName4
            , @c_ReportParmName5 = WMRD.ReportParmName5
            , @c_ReportParmName6 = WMRD.ReportParmName6
            , @c_ReportParmName7 = WMRD.ReportParmName7
            , @c_ReportParmName8 = WMRD.ReportParmName8
            , @c_ReportParmName9 = WMRD.ReportParmName9
            , @c_ReportParmName10= WMRD.ReportParmName10
            , @c_ReportParmName11= WMRD.ReportParmName11
            , @c_ReportParmName12= WMRD.ReportParmName12
            , @c_ReportParmName13= WMRD.ReportParmName13
            , @c_ReportParmName14= WMRD.ReportParmName14
            , @c_ReportParmName15= WMRD.ReportParmName15
            , @c_ReportParmName16= WMRD.ReportParmName16
            , @c_ReportParmName17= WMRD.ReportParmName17
            , @c_ReportParmName18= WMRD.ReportParmName18
            , @c_ReportParmName19= WMRD.ReportParmName19
            , @c_ReportParmName20= WMRD.ReportParmName20
            , @c_ReportCatalog   = CASE WHEN WMRD.ReportCatalog = '' THEN @c_ReportCatalog ELSE WMRD.ReportCatalog END     --(Wan01)
            , @c_CatalogFolder   = CASE WHEN WMRD.ReportCatalog = '' THEN @c_CatalogFolder ELSE '' END                     --(Wan01)
      FROM dbo.WMREPORTDETAIL WMRD WITH (NOLOCK)
      WHERE WMRD.ReportID = @c_ReportID
      AND   WMRD.RowID    = @n_DetailRowID
      IF @c_ReportCLSFile = '' OR @c_ReportCatalog = ''
      BEGIN
         SET @n_Continue = 3
         SET @n_err      = 558651   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_ErrMsg   ='NSQL'+CONVERT(NVARCHAR(6),@n_Err)         --(Wan01)
                         + ': NSQLConfig: Either Report Template OR Report Catalog is not setup (lsp_WM_Get_WebReport_URL)'
         GOTO EXIT_SP
      END
      IF RIGHT(@c_ReportURL,1)     <> '/' SET @c_ReportURL     = @c_ReportURL     + '/'
      IF RIGHT(@c_ReportFolder,1)  <> '/' SET @c_ReportFolder  = @c_ReportFolder  + '/'
      IF RIGHT(@c_CatalogFolder,1) <> '/' AND @c_CatalogFolder <> '' SET @c_CatalogFolder = @c_CatalogFolder + '/'         --(Wan01)
      IF LEFT(@c_ReportCLSFile,1) = '/' AND LEN(@c_ReportCLSFile) > 1 SET @c_ReportCLSFile = RIGHT(@c_ReportCLSFile, LEN(@c_ReportCLSFile) - 1)
      IF @c_ReportFormat   = '' SET @c_ReportFormat = '2'                                    --(Wan02)
      IF @b_PrintOverInternet > 0  SET @c_ReportFormat = '2'                                 --(Wan02)
      SET @c_ReportURL     = @c_ReportURL  + 'jinfonet/tryView.jsp?'
      SET @c_ReportCLSFile = 'jrs.report=' + IIF(LEFT(TRIM(@c_ReportCLSFile),1) = '/', @c_ReportCLSFile, @c_ReportFolder + @c_ReportCLSFile)   --WL01
      SET @c_ReportCatalog = 'jrs.catalog='+ @c_CatalogFolder+ @c_ReportCatalog
      SET @c_ReportFormat  = 'jrs.result_type=' + @c_ReportFormat
      SET @c_ServerLoginAuth = IIF(@b_PrintOverInternet=0,'','jrs.authorization=' + @c_ServerLoginAuth)              --(Wan02) 
      SET @c_NewID = CONVERT(NVARCHAR(50),NEWID())
      SET @c_ReportFileName  = IIF(@b_PrintOverInternet=0,'','jrs.result_file_name=' + RIGHT(@c_NewID,12)) + '.PDF'  --(Wan02)                                                                        --(Wan02) 
      SET @c_ReportParm = ''
      IF @c_ReportParmName1  <> '' SET @c_ReportParm = @c_ReportParm + 'jrs.param' + '$' + @c_ReportParmName1  + '=' + @c_Parm1  + @c_Delim
      IF @c_ReportParmName2  <> '' SET @c_ReportParm = @c_ReportParm + 'jrs.param' + '$' + @c_ReportParmName2  + '=' + @c_Parm2  + @c_Delim
      IF @c_ReportParmName3  <> '' SET @c_ReportParm = @c_ReportParm + 'jrs.param' + '$' + @c_ReportParmName3  + '=' + @c_Parm3  + @c_Delim
      IF @c_ReportParmName4  <> '' SET @c_ReportParm = @c_ReportParm + 'jrs.param' + '$' + @c_ReportParmName4  + '=' + @c_Parm4  + @c_Delim
      IF @c_ReportParmName5  <> '' SET @c_ReportParm = @c_ReportParm + 'jrs.param' + '$' + @c_ReportParmName5  + '=' + @c_Parm5  + @c_Delim
      IF @c_ReportParmName6  <> '' SET @c_ReportParm = @c_ReportParm + 'jrs.param' + '$' + @c_ReportParmName6  + '=' + @c_Parm6  + @c_Delim
      IF @c_ReportParmName7  <> '' SET @c_ReportParm = @c_ReportParm + 'jrs.param' + '$' + @c_ReportParmName7  + '=' + @c_Parm7  + @c_Delim
      IF @c_ReportParmName8  <> '' SET @c_ReportParm = @c_ReportParm + 'jrs.param' + '$' + @c_ReportParmName8  + '=' + @c_Parm8  + @c_Delim
      IF @c_ReportParmName9  <> '' SET @c_ReportParm = @c_ReportParm + 'jrs.param' + '$' + @c_ReportParmName9  + '=' + @c_Parm9  + @c_Delim
      IF @c_ReportParmName10 <> '' SET @c_ReportParm = @c_ReportParm + 'jrs.param' + '$' + @c_ReportParmName10 + '=' + @c_Parm10 + @c_Delim
      IF @c_ReportParmName11 <> '' SET @c_ReportParm = @c_ReportParm + 'jrs.param' + '$' + @c_ReportParmName11 + '=' + @c_Parm11 + @c_Delim
      IF @c_ReportParmName12 <> '' SET @c_ReportParm = @c_ReportParm + 'jrs.param' + '$' + @c_ReportParmName12 + '=' + @c_Parm12 + @c_Delim
      IF @c_ReportParmName13 <> '' SET @c_ReportParm = @c_ReportParm + 'jrs.param' + '$' + @c_ReportParmName13 + '=' + @c_Parm13 + @c_Delim
      IF @c_ReportParmName14 <> '' SET @c_ReportParm = @c_ReportParm + 'jrs.param' + '$' + @c_ReportParmName14 + '=' + @c_Parm14 + @c_Delim
      IF @c_ReportParmName15 <> '' SET @c_ReportParm = @c_ReportParm + 'jrs.param' + '$' + @c_ReportParmName15 + '=' + @c_Parm15 + @c_Delim
      IF @c_ReportParmName16 <> '' SET @c_ReportParm = @c_ReportParm + 'jrs.param' + '$' + @c_ReportParmName16 + '=' + @c_Parm16 + @c_Delim
      IF @c_ReportParmName17 <> '' SET @c_ReportParm = @c_ReportParm + 'jrs.param' + '$' + @c_ReportParmName17 + '=' + @c_Parm17 + @c_Delim
      IF @c_ReportParmName18 <> '' SET @c_ReportParm = @c_ReportParm + 'jrs.param' + '$' + @c_ReportParmName18 + '=' + @c_Parm18 + @c_Delim
      IF @c_ReportParmName19 <> '' SET @c_ReportParm = @c_ReportParm + 'jrs.param' + '$' + @c_ReportParmName19 + '=' + @c_Parm19 + @c_Delim
      IF @c_ReportParmName20 <> '' SET @c_ReportParm = @c_ReportParm + 'jrs.param' + '$' + @c_ReportParmName20 + '=' + @c_Parm20 + @c_Delim
      IF LEN(@c_ReportParm) > 0 SET @c_ReportParm = SUBSTRING(@c_ReportParm, 1, LEN(@c_ReportParm) - 1)
      SET @c_ReturnURL = @c_ReportURL
                       + @c_ReportCLSFile + @c_Delim
                       + @c_ReportCatalog + @c_Delim
                       + @c_ReportFormat  + @c_Delim
                       + @c_ServerLoginAuth + IIF(@c_ServerLoginAuth='','',@c_Delim)             --(Wan02)
                       + @c_ReportFileName  + IIF(@c_ReportFileName='','',@c_Delim)              --(Wan02)
                       + @c_ReportParm
      SET @c_ReturnURL = REPLACE(@c_ReturnURL,SPACE(1),'%20')
   END TRY
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH
   EXIT_SP:
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_WM_Get_WebReport_URL'
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO