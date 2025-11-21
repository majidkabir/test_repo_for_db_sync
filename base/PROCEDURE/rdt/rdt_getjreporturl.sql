SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: rdt_GetJReportURL                                       */
/* Creation Date: 08-OCT-2019                                           */
/* Copyright: LF Logistics                                              */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: Construct JReport URL to view report from Exceed            */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* GitLab Version: 1.4                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 07-07-2023  YeeKung  1.0   Support Cloud Print                       */
/************************************************************************/
CREATE   PROCEDURE [RDT].[rdt_GetJReportURL]
           @c_Storerkey      NVARCHAR(15) = ''
         , @c_ReportType     NVARCHAR(10) = ''    --WL02 - For RCM = RCMReportType, For View JReport = JReport_ID
         , @c_CallFrom       NVARCHAR(50)         --For RCM = MBOL,WAVE,etc..., For View JReport = 'ViewJReport'
         , @c_Parm01         NVARCHAR(100) = ''   --WL02 - Cater for View JReport from EXceed, no need provide parameters
         , @c_Parm02         NVARCHAR(100) = ''   --WL02
         , @c_Parm03         NVARCHAR(100) = ''   --WL02
         , @c_Parm04         NVARCHAR(100) = ''   --WL02
         , @c_Parm05         NVARCHAR(100) = ''   --WL02
         , @c_Parm06         NVARCHAR(100) = ''   --WL02
         , @c_Parm07         NVARCHAR(100) = ''   --WL02
         , @c_Parm08         NVARCHAR(100) = ''   --WL02
         , @c_Parm09         NVARCHAR(100) = ''   --WL02
         , @c_Parm10         NVARCHAR(100) = ''   --WL02
         , @c_PrintFormat    NVARCHAR(100) = '2' 
         , @cJobID           NVARCHAR(20)  = ''
         , @b_Success        INT            OUTPUT
         , @n_Err            INT            OUTPUT
         , @c_ErrMsg         NVARCHAR(255)  OUTPUT
         , @c_CompleteURL    NVARCHAR(MAX)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
           @n_StartTCnt                     INT
         , @n_Continue                      INT
         , @c_SQL                           NVARCHAR(4000)
         , @c_SQLArgument                   NVARCHAR(4000)

         , @c_Orderkey                      NVARCHAR(10)
         , @c_Loadkey                       NVARCHAR(10)

         , @c_Facility                      NVARCHAR(5)

         , @c_GetAuthority                  NVARCHAR(50)

         , @n_IsConso                       INT = 0
         , @c_Configkey                     NVARCHAR(50)

         , @c_JReportURL                    NVARCHAR(4000)
         , @c_JReportCatName                NVARCHAR(255)
         , @c_CountryName                   NVARCHAR(255)
         , @c_Delimiter                     NVARCHAR(5) = '&'
         , @c_jrs_report                    NVARCHAR(4000) = 'jrs.report='
         , @c_jrs_catalog                   NVARCHAR(4000) = 'jrs.catalog='
         , @c_jrs_result_type               NVARCHAR(4000) = 'jrs.result_type='
         , @c_jrs_authorization             NVARCHAR(4000) = 'jrs.authorization='
         , @c_jrs_resultfilename            NVARCHAR(4000) = 'jrs.result_file_name='
         , @c_jrs_param                     NVARCHAR(4000) = ''
         , @c_jrs_paramDelim                NVARCHAR(4000) = 'jrs.param'

         , @c_JReportCatalog                NVARCHAR(60)
         , @c_JReportFilename               NVARCHAR(4000)
         , @c_JReportFlag                   NVARCHAR(60)
         , @c_JReportDefaultReportFolder    NVARCHAR(60)
         , @c_JReportDefaultCatalogFolder   NVARCHAR(60)

         , @c_Param01Label                  NVARCHAR(250)
         , @c_Param01Type                   NVARCHAR(250)
         , @c_Param02Label                  NVARCHAR(250)
         , @c_Param02Type                   NVARCHAR(250)
         , @c_Param03Label                  NVARCHAR(250)
         , @c_Param03Type                   NVARCHAR(250)
         , @c_Param04Label                  NVARCHAR(250)
         , @c_Param04Type                   NVARCHAR(250)
         , @c_Param05Label                  NVARCHAR(250)
         , @c_Param05Type                   NVARCHAR(250)
         , @c_Param06Label                  NVARCHAR(250)
         , @c_Param06Type                   NVARCHAR(250)
         , @c_Param07Label                  NVARCHAR(250)
         , @c_Param07Type                   NVARCHAR(250)
         , @c_Param08Label                  NVARCHAR(250)
         , @c_Param08Type                   NVARCHAR(250)
         , @c_Param09Label                  NVARCHAR(250)
         , @c_Param09Type                   NVARCHAR(250)
         , @c_Param10Label                  NVARCHAR(250)
         , @c_Param10Type                   NVARCHAR(250)

         , @c_AuthorizationString           NVARCHAR(4000)
		 , @cJSpoolerFolder					NVARCHAR(4000)

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   SET @c_JReportURL = ''

   --WL02 Move Up - START
   --JReport URL
   SELECT @c_JReportURL = NSQLDescrip
   FROM dbo.NSQLCONFIG (NOLOCK)
   WHERE ConfigKey = 'JReportURL'

   --JReport Username & Password
   SELECT @c_AuthorizationString = NSQLDescrip
   FROM dbo.NSQLCONFIG (NOLOCK)
   WHERE ConfigKey = 'JReportAuthorization'

   --Default Report Folder
   SELECT @c_JReportDefaultReportFolder  = NSQLDescrip
   FROM dbo.NSQLCONFIG (NOLOCK)
   WHERE ConfigKey = 'JReportDefaultReportFolder'

   --Default Catalog Folder
   SELECT @c_JReportDefaultCatalogFolder  = NSQLDescrip
   FROM dbo.NSQLCONFIG (NOLOCK)
   WHERE ConfigKey = 'JReportDefaultCatalogFolder'
   --WL02 Move Up - END


      --JReport Username & Password
   SELECT   @cJSpoolerFolder  = NSQLDescrip
   FROM dbo.NSQLCONFIG (NOLOCK)
   WHERE ConfigKey = 'JSpoolerFolder'

   IF @c_CallFrom <> 'ViewJReport'      --WL02
   BEGIN                                --WL02
      SELECT   @c_JReportCatalog   = JReportCatalog
             , @c_JReportFilename  = JReportFilename
             , @c_JReportFlag      = JReportFlag
      FROM rdt.RDTreportdetail (NOLOCK)
      WHERE ReportType = @c_ReportType
      AND StorerKey = @c_Storerkey

      IF ISNULL(@c_JReportCatalog,'') = ''
      BEGIN
         SELECT @c_JReportCatalog = NSQLDescrip
         FROM dbo.NSQLCONFIG (NOLOCK)
         WHERE ConfigKey = 'JReportDefaultCatalog'
      END

      IF ISNULL(@c_JReportCatalog,'') = '' OR ISNULL(@c_JReportFilename,'') = ''
      BEGIN
         GOTO QUIT_SP
      END

      --JReport Column Name from View
      SELECT @c_Param01Label = ReportParmName1 
           , @c_Param02Label = ReportParmName2
           , @c_Param03Label = ReportParmName3
           , @c_Param04Label = ReportParmName4
           , @c_Param05Label = ReportParmName5
           , @c_Param06Label = ReportParmName6
           , @c_Param07Label = ReportParmName7
           , @c_Param08Label = ReportParmName8
           , @c_Param09Label = ReportParmName9
           , @c_Param10Label = ReportParmName10
      FROM rdt.RDTreportdetail
      WHERE ReportType = @c_ReportType
      AND StorerKey = @c_Storerkey

   END   --WL02 - START

   IF RIGHT(RTRIM(@c_JReportDefaultReportFolder),1) <> '/'
   BEGIN
      SET @c_JReportDefaultReportFolder = @c_JReportDefaultReportFolder + '/'
   END

   IF RIGHT(RTRIM(@c_JReportDefaultCatalogFolder),1) <> '/'
   BEGIN
      SET @c_JReportDefaultCatalogFolder = @c_JReportDefaultCatalogFolder + '/'
   END

   --Check if RCMReport has setup file path, if not, use the default file path from NSQLConfig
   IF CHARINDEX('/',@c_JReportCatalog,1) = 0
   BEGIN
      SET @c_JReportCatalog  = @c_JReportDefaultCatalogFolder + @c_JReportCatalog
   END

   IF CHARINDEX('/',@c_JReportFilename,1) = 0
   BEGIN
      SET @c_JReportFilename = @c_JReportDefaultReportFolder + @c_JReportFilename
   END

   --Set extension
   SET @c_JReportCatalog  = CASE WHEN CHARINDEX('.', @c_JReportCatalog) > 0  THEN @c_JReportCatalog  ELSE @c_JReportCatalog  + '.cat' END
   SET @c_JReportFilename = CASE WHEN CHARINDEX('.', @c_JReportFilename) > 0 THEN @c_JReportFilename ELSE @c_JReportFilename + '.cls' END

   IF ISNULL(@c_AuthorizationString,'') = ''
   BEGIN
      SET @n_Continue = 3
      SET @n_err      = 80000   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+
                    ': NSQLConfig: JReportAuthorization is not setup (rdt_GetJReportURL)'
      GOTO QUIT_SP
   END

   IF RIGHT(RTRIM(@c_JReportURL),1) = '/'
   BEGIN
      SET @c_JReportURL = @c_JReportURL + 'jinfonet/tryView.jsp?'
   END
   ELSE
   BEGIN
      SET @c_JReportURL = @c_JReportURL + '/jinfonet/tryView.jsp?'
   END



   --jrs.report
   SET @c_jrs_report = @c_jrs_report + @c_JReportFilename

   --jrs.catalog
   SET @c_jrs_catalog = @c_jrs_catalog + @c_JReportCatalog

   --jrs.result_type
   SET @c_jrs_result_type = @c_jrs_result_type + @c_PrintFormat

   --jrs.authorization
   SET @c_jrs_authorization = @c_jrs_authorization + @c_AuthorizationString

   SET @c_jrs_resultfilename = @c_jrs_resultfilename + @cJobID +'.pdf'

   --jrs.param
   --WL04 S
   IF ISNULL(@c_Parm01, '') <> '' OR @c_Param01Label = 'PARAM_WMS_c_Username'
      SET @c_jrs_param =  @c_jrs_param + @c_jrs_paramDelim + N'$' + @c_Param01Label + N'='
                         + CASE WHEN @c_Param01Label = 'PARAM_WMS_c_Username' THEN CASE WHEN ISNULL(@c_Parm01,'') = '' THEN SUSER_SNAME() ELSE @c_Parm01 END
                                ELSE @c_Parm01 END

   IF ISNULL(@c_Parm02, '') <> '' OR @c_Param02Label = 'PARAM_WMS_c_Username'
      SET @c_jrs_param = @c_jrs_param + @c_Delimiter + @c_jrs_paramDelim + N'$' + @c_Param02Label + N'='
                         + CASE WHEN @c_Param02Label = 'PARAM_WMS_c_Username' THEN CASE WHEN ISNULL(@c_Parm02,'') = '' THEN SUSER_SNAME() ELSE @c_Parm02 END
                                ELSE @c_Parm02 END

   IF ISNULL(@c_Parm03, '') <> '' OR @c_Param03Label = 'PARAM_WMS_c_Username'
      SET @c_jrs_param = @c_jrs_param + @c_Delimiter + @c_jrs_paramDelim + N'$' + @c_Param03Label + N'='
                         + CASE WHEN @c_Param03Label = 'PARAM_WMS_c_Username' THEN CASE WHEN ISNULL(@c_Parm03,'') = '' THEN SUSER_SNAME() ELSE @c_Parm03 END
                                ELSE @c_Parm03 END

   IF ISNULL(@c_Parm04, '') <> '' OR @c_Param04Label = 'PARAM_WMS_c_Username'
      SET @c_jrs_param = @c_jrs_param + @c_Delimiter + @c_jrs_paramDelim + N'$' + @c_Param04Label + N'='
                         + CASE WHEN @c_Param04Label = 'PARAM_WMS_c_Username' THEN CASE WHEN ISNULL(@c_Parm04,'') = '' THEN SUSER_SNAME() ELSE @c_Parm04 END
                                ELSE @c_Parm04 END

   IF ISNULL(@c_Parm05, '') <> '' OR @c_Param05Label = 'PARAM_WMS_c_Username'
      SET @c_jrs_param = @c_jrs_param + @c_Delimiter + @c_jrs_paramDelim + N'$' + @c_Param05Label + N'='
                         + CASE WHEN @c_Param05Label = 'PARAM_WMS_c_Username' THEN CASE WHEN ISNULL(@c_Parm05,'') = '' THEN SUSER_SNAME() ELSE @c_Parm05 END
                                ELSE @c_Parm05 END

   IF ISNULL(@c_Parm06, '') <> '' OR @c_Param06Label = 'PARAM_WMS_c_Username'
      SET @c_jrs_param = @c_jrs_param + @c_Delimiter + @c_jrs_paramDelim + N'$' + @c_Param06Label + N'='
                         + CASE WHEN @c_Param06Label = 'PARAM_WMS_c_Username' THEN CASE WHEN ISNULL(@c_Parm06,'') = '' THEN SUSER_SNAME() ELSE @c_Parm06 END
                                ELSE @c_Parm06 END

   IF ISNULL(@c_Parm07, '') <> '' OR @c_Param07Label = 'PARAM_WMS_c_Username'
      SET @c_jrs_param = @c_jrs_param + @c_Delimiter + @c_jrs_paramDelim + N'$' + @c_Param07Label + N'='
                         + CASE WHEN @c_Param07Label = 'PARAM_WMS_c_Username' THEN CASE WHEN ISNULL(@c_Parm07,'') = '' THEN SUSER_SNAME() ELSE @c_Parm07 END
                                ELSE @c_Parm07 END

   IF ISNULL(@c_Parm08, '') <> '' OR @c_Param08Label = 'PARAM_WMS_c_Username'
      SET @c_jrs_param = @c_jrs_param + @c_Delimiter + @c_jrs_paramDelim + N'$' + @c_Param08Label + N'='
                         + CASE WHEN @c_Param08Label = 'PARAM_WMS_c_Username' THEN CASE WHEN ISNULL(@c_Parm08,'') = '' THEN SUSER_SNAME() ELSE @c_Parm08 END
                                ELSE @c_Parm08 END

   IF ISNULL(@c_Parm09, '') <> '' OR @c_Param09Label = 'PARAM_WMS_c_Username'
      SET @c_jrs_param = @c_jrs_param + @c_Delimiter + @c_jrs_paramDelim + N'$' + @c_Param09Label + N'='
                         + CASE WHEN @c_Param09Label = 'PARAM_WMS_c_Username' THEN CASE WHEN ISNULL(@c_Parm09,'') = '' THEN SUSER_SNAME() ELSE @c_Parm09 END
                                ELSE @c_Parm09 END

   IF ISNULL(@c_Parm10, '') <> '' OR @c_Param10Label = 'PARAM_WMS_c_Username'
      SET @c_jrs_param = @c_jrs_param + @c_Delimiter + @c_jrs_paramDelim + N'$' + @c_Param10Label + N'='
                         + CASE WHEN @c_Param10Label = 'PARAM_WMS_c_Username' THEN CASE WHEN ISNULL(@c_Parm10,'') = '' THEN SUSER_SNAME() ELSE @c_Parm10 END
                                ELSE @c_Parm10 END
   --WL04 E

   SET @c_CompleteURL = @c_JReportURL + @c_jrs_report + @c_Delimiter + @c_jrs_catalog + @c_Delimiter +
                        @c_jrs_result_type + @c_Delimiter + @c_jrs_authorization + @c_Delimiter +@c_jrs_resultfilename+ @c_Delimiter+ @c_jrs_param

   --Replace space with %20 for URL
   SET @c_CompleteURL = REPLACE(@c_CompleteURL,SPACE(1),'%20')


   SET @c_CompleteURL = '{

						"TargetURL":"'+@c_CompleteURL+'"

						,"HTTPMethod":"GET"

						,"ContentType":"application/json"

						,"RequestHeader":""

						,"RequestBody":""

						,"SetWebProxy":"N"

						,"CountryFolder":"'+@cJSpoolerFolder+'"

						,"DocType":"Invoice"

						}'

   SELECT @c_CompleteURL

QUIT_SP:
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'rdt_GetJReportURL'
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012   --WL01
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END

   WHILE @@TRANCOUNT < @n_StartTCnt
      BEGIN TRAN;

END -- procedure

GO