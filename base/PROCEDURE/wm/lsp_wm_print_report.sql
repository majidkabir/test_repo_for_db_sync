SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: lsp_WM_Print_Report                                     */
/* Creation Date: 02-FEB-2018                                           */
/* Copyright: Maersk                                                    */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: LFWM-183:List of Labels, Document Print and Reports to be   */
/*          considered & DB procedute Details for the same              */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.8                                                    */
/*                                                                      */
/* Version: 8.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2020-08-18  Wan01    1.1   LFWM-2278 - LF SCE JReport Integration    */
/*                            Phase 2  Backend Setup  SPs Setup         */
/* 2021-02-15  Wan01    1.1   Add Big Outer Begin try/Catch             */
/*                            Execute Login if @c_UserName<>SUSER_SNAME()*/
/* 2021-06-17  Wan02    1.2   LFWM-2841 - SCE JReport Phase 1 & Phase 2 */  
/*                            SCE JReport Rebrand to Logi Report in UAT &*/  
/*                            PROD                                      */ 
/* 2021-06-03  Wan03    1.3   LFWM-2800 - RG UAT PB Report Print Preview*/
/*                            SP & sharedrive for PDF Storage           */
/* 2021-09-24  Wan03    1.3   DevOps Combine Script                     */
/* 2021-11-05  Wan04    1.4   LFWM-3029 - UAT CN - Wave report Carters  */
/*                            PRINT issue                               */
/* 2022-01-03  Wan05    1.5   Fixed. Set @n_Continue =  2 if Error      */
/*                            Fixed. Add Criteria parameters            */
/*                            Add Call to PreGenRptData                 */
/* 2022-07-06  WLChooi  1.6   Fixed. Move PRINT_START Label to before   */
/*                            PreGenRptDataSP (WL01)                    */
/* 2022-10-14  WLChooi  1.7   Fixed. Extend Char Size for RowID (WL02)  */
/* 2023-02-27  Wan06    1.8   LFWM-3913 - Ship Reference Enhancement ?  */
/*                            Print Interface Document                  */
/* 2022-02-27  Wan07    1.9   LFWM-3967-SCE UAT Reports-Report Configuration*/
/*                            Add fields to Details                     */
/* 2023-07-07  Wan08    1.9   PAC-15:Ecom Packing | Print Packing Report*/
/*                            - Backend                                 */
/*                            DevOps Combine Script                     */
/* 2023-07-14  WLChooi  2.0   WMS-22860 - Add PostPrintSP (WL03)        */
/* 2023-09-05  WLChooi  2.1   LFWM-4454 - Enhance Pre/Post Print STD SP */
/*                            (WL04)                                    */
/* 2023-11-17  Wan09    2.1   Fixed Matching Criteria Print SQL if print*/
/*                            by column range                           */
/* 2023-12-06  WLChooi  2.2   WMS-24329 - Allow calling PreGenRptDataSP */
/*                            with custom parameter (WL05)              */
/* 2023-12-19  Wan      2.3   UWP-12373-MWMS Deploy MasterSP to V2      */
/************************************************************************/
CREATE   PROC [WM].[lsp_WM_Print_Report]
           @c_ModuleID           NVARCHAR(30)
         , @c_ReportID           NVARCHAR(10)
         , @c_Storerkey          NVARCHAR(15)
         , @c_Facility           NVARCHAR(5)
         , @c_UserName           NVARCHAR(128)              --(Wan04) 
         , @c_ComputerName       NVARCHAR(30) 
         , @c_PrinterID          NVARCHAR(30)
         , @n_NoOfCopy           INT            = 1
         , @c_IsPaperPrinter     NCHAR(1)       = 'Y'
         , @c_KeyValue1          NVARCHAR(60)
         , @c_KeyValue2          NVARCHAR(60)   = ''
         , @c_KeyValue3          NVARCHAR(60)   = ''
         , @c_KeyValue4          NVARCHAR(60)   = ''
         , @c_KeyValue5          NVARCHAR(60)   = ''
         , @c_KeyValue6          NVARCHAR(60)   = ''
         , @c_KeyValue7          NVARCHAR(60)   = ''
         , @c_KeyValue8          NVARCHAR(60)   = ''
         , @c_KeyValue9          NVARCHAR(60)   = ''
         , @c_KeyValue10         NVARCHAR(60)   = ''         
         , @c_KeyValue11         NVARCHAR(60)   = ''
         , @c_KeyValue12         NVARCHAR(60)   = ''
         , @c_KeyValue13         NVARCHAR(60)   = ''
         , @c_KeyValue14         NVARCHAR(60)   = ''
         , @c_KeyValue15         NVARCHAR(60)   = ''
         , @c_ExtendedParmValue1 NVARCHAR(60)   = ''
         , @c_ExtendedParmValue2 NVARCHAR(60)   = ''
         , @c_ExtendedParmValue3 NVARCHAR(60)   = ''
         , @c_ExtendedParmValue4 NVARCHAR(60)   = ''
         , @c_ExtendedParmValue5 NVARCHAR(60)   = ''
         , @b_Success            INT            OUTPUT
         , @n_Err                INT            OUTPUT
         , @c_ErrMsg             NVARCHAR(255)  OUTPUT
         , @c_PrintSource        NVARCHAR(10)   = 'WMReport' --Wan01  1: Report, 2: JReport 
         , @b_SCEPreView         INT            = 0          --(Wan03) -- 1:If call from Preview Button and not JREport
         , @c_JobIDs             NVARCHAR(50)   = '' OUTPUT  --(Wan03) -- May return multiple jobs ID.JobID seperate by '|'
         , @c_AutoPrint          NVARCHAR(1)    = 'N'        --(Wan07)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE  
           @n_StartTCnt             INT
         , @n_Continue              INT 
         , @n_FunctionID            INT
         , @n_NoOfKeyFieldParms     INT   
         , @n_NoOfParms             INT
         , @c_Parm1                 NVARCHAR(60)      = '' 
         , @c_Parm2                 NVARCHAR(60)      = '' 
         , @c_Parm3                 NVARCHAR(60)      = '' 
         , @c_Parm4                 NVARCHAR(60)      = '' 
         , @c_Parm5                 NVARCHAR(60)      = '' 
         , @c_Parm6                 NVARCHAR(60)      = '' 
         , @c_Parm7                 NVARCHAR(60)      = '' 
         , @c_Parm8                 NVARCHAR(60)      = '' 
         , @c_Parm9                 NVARCHAR(60)      = '' 
         , @c_Parm10                NVARCHAR(60)      = '' 
         , @c_Parm11                NVARCHAR(60)      = '' 
         , @c_Parm12                NVARCHAR(60)      = '' 
         , @c_Parm13                NVARCHAR(60)      = '' 
         , @c_Parm14                NVARCHAR(60)      = '' 
         , @c_Parm15                NVARCHAR(60)      = '' 
         , @c_Parm16                NVARCHAR(60)      = '' 
         , @c_Parm17                NVARCHAR(60)      = '' 
         , @c_Parm18                NVARCHAR(60)      = '' 
         , @c_Parm19                NVARCHAR(60)      = '' 
         , @c_Parm20                NVARCHAR(60)      = ''  
         , @c_Parm                  NVARCHAR(60)      = '' 
         , @c_Parms                 NVARCHAR(500)     = '' 
         , @c_ParmLabel1            NVARCHAR(60)      = '' 
         , @c_ParmLabel2            NVARCHAR(60)      = '' 
         , @c_ParmLabel3            NVARCHAR(60)      = '' 
         , @c_ParmLabel4            NVARCHAR(60)      = '' 
         , @c_ParmLabel5            NVARCHAR(60)      = '' 
         , @c_ParmLabel6            NVARCHAR(60)      = '' 
         , @c_ParmLabel7            NVARCHAR(60)      = '' 
         , @c_ParmLabel8            NVARCHAR(60)      = '' 
         , @c_ParmLabel9            NVARCHAR(60)      = '' 
         , @c_ParmLabel10           NVARCHAR(60)      = '' 
         , @c_ParmLabel11           NVARCHAR(60)      = '' 
         , @c_ParmLabel12           NVARCHAR(60)      = '' 
         , @c_ParmLabel13           NVARCHAR(60)      = '' 
         , @c_ParmLabel14           NVARCHAR(60)      = '' 
         , @c_ParmLabel15           NVARCHAR(60)      = '' 
         , @c_ParmLabel16           NVARCHAR(60)      = '' 
         , @c_ParmLabel17           NVARCHAR(60)      = '' 
         , @c_ParmLabel18           NVARCHAR(60)      = '' 
         , @c_ParmLabel19           NVARCHAR(60)      = '' 
         , @c_ParmLabel20           NVARCHAR(60)      = ''  
         , @c_ParmLabel             NVARCHAR(60)      = '' 
         , @c_KeyParms              NVARCHAR(500)     = ''
         , @c_KeyLableParms         NVARCHAR(500)     = ''
         , @c_KeyParm               NVARCHAR(60)      = ''
         , @c_ParmValue             NVARCHAR(60)      = ''
         , @c_TableName             NVARCHAR(50)      = ''
         , @c_SQLPrint              NVARCHAR(4000)    = ''
         , @c_SQLWhere              NVARCHAR(4000)    = ''
         , @b_Exists                BIT               = 0
         , @b_ContinuePrint         BIT               = 0
         , @n_RowID                 BIGINT            = 0
         , @c_ReportLineNo          NVARCHAR(5)       = ''
         , @c_PrintMethod           NVARCHAR(30)      = ''   
         , @c_PrintType             NVARCHAR(30)      = ''
         , @c_PrintGroup            NVARCHAR(10)      = ''
         , @c_PrintGroup_Last       NVARCHAR(10)      = ''
         , @c_ReportTemplate        NVARCHAR(4000)    = ''
         , @c_GreaterLessEqual      NVARCHAR(5)       = ''                          --2023-11-17
         , @c_CriteriaParm1         NVARCHAR(60)      = ''
         , @c_CriteriaParm2         NVARCHAR(60)      = ''
         , @c_CriteriaParm3         NVARCHAR(60)      = ''
         , @c_CriteriaParm4         NVARCHAR(60)      = ''
         , @c_CriteriaParm5         NVARCHAR(60)      = ''
         , @c_CriteriaParm6         NVARCHAR(60)      = ''
         , @c_CriteriaParm7         NVARCHAR(60)      = ''
         , @c_CriteriaParm8         NVARCHAR(60)      = ''
         , @c_CriteriaParm9         NVARCHAR(60)      = ''
         , @c_CriteriaParm10        NVARCHAR(60)      = ''
         , @c_CriteriaParm11        NVARCHAR(60)      = ''
         , @c_CriteriaParm12        NVARCHAR(60)      = ''
         , @c_CriteriaParm13        NVARCHAR(60)      = ''
         , @c_CriteriaParm14        NVARCHAR(60)      = ''
         , @c_CriteriaParm15        NVARCHAR(60)      = ''
         , @c_CriteriaParm16        NVARCHAR(60)      = ''              --(Wan05)
         , @c_CriteriaParm17        NVARCHAR(60)      = ''              --(Wan05)
         , @c_CriteriaParm18        NVARCHAR(60)      = ''              --(Wan05)
         , @c_CriteriaParm19        NVARCHAR(60)      = ''              --(Wan05)
         , @c_CriteriaParm20        NVARCHAR(60)      = ''              --(Wan05)
         , @c_CriteriaMatching01    NVARCHAR(100)     = ''
         , @c_CriteriaMatching02    NVARCHAR(100)     = ''
         , @c_CriteriaMatching03    NVARCHAR(100)     = ''
         , @c_CriteriaMatching04    NVARCHAR(100)     = ''
         , @c_CriteriaMatching05    NVARCHAR(MAX)     = ''              --(Wan07)  
         , @c_PreprintSP            NVARCHAR(50)      = ''  
         , @c_PrintData             NVARCHAR(4000)    = ''
         , @c_JobType               NVARCHAR(30)      = ''  
         , @n_JobID                 INT               = 0               --(Wan03)
         , @c_PrinterGroup          NVARCHAR(10)      = ''
         , @c_Printer               NVARCHAR(30)      = ''
         , @c_DefaultPrinterID      NVARCHAR(30)      = ''              --(Wan08)  
         , @n_StartPosK             INT = 0
         , @n_StopPosK              INT = 1
         , @n_StartPosV             INT = 0
         , @n_StopPosV              INT = 1
         , @n_StartPosL             INT = 0
         , @n_StopPosL              INT = 1
         , @n_ParmsCnt              INT = 1
         , @b_Insert                BIT = 0
         , @c_SQL                   NVARCHAR(MAX)
         , @c_SQLParms              NVARCHAR(MAX)
         , @c_PreGenRptData_SP      NVARCHAR(1000)    = ''  --(Wan05)   --WL05
         , @c_PostPrintSP           NVARCHAR(50)      = ''  --WL03
         , @c_PrintSP_STD           NVARCHAR(50)      = ''  --WL04
         , @b_PrintNextOnFail       INT               = 0   --(Wan07)
         , @CUR_GROUP               CURSOR
         , @CUR_PARM                CURSOR
         --WL05 S
         , @c_SPName       NVARCHAR(4000) = N''
         , @n_idx          INT            = 0
         , @c_ExcludeVar   NVARCHAR(4000) = N''
         , @c_VarList      NVARCHAR(4000) = N''
         --WL05 E
   --(Wan01) - START
         , @c_ReturnURL             NVARCHAR(4000) = ''
   DECLARE @RPTURL                  TABLE
         (  RowNo       INT            NOT NULL IDENTITY(1,1) PRIMARY KEY
         ,  ReportID    NVARCHAR(10)   NOT NULL DEFAULT ('')
         ,  DetailRowID BIGINT         NOT NULL DEFAULT(0)
         ,  REPORT_URL  NVARCHAR(4000) NOT NULL DEFAULT ('')
         )
   --(Wan01) - END
   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @b_Success  = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''
   SET @c_JobIDs   = ''    --(Wan03)
   SET @n_Err = 0 
   --(Wan01) - START 
   IF SUSER_SNAME() <> @c_UserName 
   BEGIN
      EXEC [WM].[lsp_SetUser] 
         @c_UserName = @c_UserName  OUTPUT
      ,  @n_Err      = @n_Err       OUTPUT
      ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT
      IF @n_Err <> 0 
      BEGIN
         GOTO EXIT_SP
      END
      EXECUTE AS LOGIN = @c_UserName
   END
   --(Wan01) - END
   --(Wan01) - START
   BEGIN TRY
      IF @n_NoOfCopy = 0  SET @n_NoOfCopy = '1'
      --(Wan01) - START
      IF ISNULL(@c_PrintSource,'') = '' SET @c_PrintSource = 'WMReport'
      --(MOve out From Loop) - START
      SELECT @c_PrintMethod= ISNULL(RTRIM(WMR.PrintMethod),'')
            ,@n_NoOfKeyFieldParms = ISNULL(WMR.NoOfKeyFieldParms,0)
            ,@c_KeyParms   = ISNULL(RTRIM(WMR.KeyFieldName1),'')                
                           + ',' + ISNULL(RTRIM(WMR.KeyFieldName2),'')                
                           + ',' + ISNULL(RTRIM(WMR.KeyFieldName3),'')                
                           + ',' + ISNULL(RTRIM(WMR.KeyFieldName4),'')                
                           + ',' + ISNULL(RTRIM(WMR.KeyFieldName5),'')                
                           + ',' + ISNULL(RTRIM(WMR.KeyFieldName6),'')                
                           + ',' + ISNULL(RTRIM(WMR.KeyFieldName7),'')                
                           + ',' + ISNULL(RTRIM(WMR.KeyFieldName8),'')                
                           + ',' + ISNULL(RTRIM(WMR.KeyFieldName9),'')                
                           + ',' + ISNULL(RTRIM(WMR.KeyFieldName10),'')                
                           + ',' + ISNULL(RTRIM(WMR.KeyFieldName11),'')                
                           + ',' + ISNULL(RTRIM(WMR.KeyFieldName12),'')                
                           + ',' + ISNULL(RTRIM(WMR.KeyFieldName13),'')                
                           + ',' + ISNULL(RTRIM(WMR.KeyFieldName14),'')                
                           + ',' + ISNULL(RTRIM(WMR.KeyFieldName15),'')                
                           + ',' + ISNULL(RTRIM(WMR.ExtendedParm1),'')         
                           + ',' + ISNULL(RTRIM(WMR.ExtendedParm2),'')         
                           + ',' + ISNULL(RTRIM(WMR.ExtendedParm3),'')         
                           + ',' + ISNULL(RTRIM(WMR.ExtendedParm4),'')         
                           + ',' + ISNULL(RTRIM(WMR.ExtendedParm5),'')  
            ,@c_KeyLableParms = ISNULL(RTRIM(WMR.KeyFieldParmLabel1),'')                
                           + ',' + ISNULL(RTRIM(WMR.KeyFieldParmLabel2),'')                
                           + ',' + ISNULL(RTRIM(WMR.KeyFieldParmLabel3),'')                
                           + ',' + ISNULL(RTRIM(WMR.KeyFieldParmLabel4),'')                
                           + ',' + ISNULL(RTRIM(WMR.KeyFieldParmLabel5),'')                
                           + ',' + ISNULL(RTRIM(WMR.KeyFieldParmLabel6),'')                
                           + ',' + ISNULL(RTRIM(WMR.KeyFieldParmLabel7),'')                
                           + ',' + ISNULL(RTRIM(WMR.KeyFieldParmLabel8),'')                
                           + ',' + ISNULL(RTRIM(WMR.KeyFieldParmLabel9),'')                
                           + ',' + ISNULL(RTRIM(WMR.KeyFieldParmLabel10),'')                
                           + ',' + ISNULL(RTRIM(WMR.KeyFieldParmLabel11),'')                
                           + ',' + ISNULL(RTRIM(WMR.KeyFieldParmLabel12),'')                
                           + ',' + ISNULL(RTRIM(WMR.KeyFieldParmLabel13),'')                
                           + ',' + ISNULL(RTRIM(WMR.KeyFieldParmLabel14),'')                
                           + ',' + ISNULL(RTRIM(WMR.KeyFieldParmLabel15),'')   
      FROM dbo.WMREPORT       WMR  WITH (NOLOCK)
      WHERE WMR.ReportID = @c_ReportID    
      IF @n_NoOfKeyFieldParms = 0 OR @n_NoOfKeyFieldParms > 15
      BEGIN
         SET @n_NoOfKeyFieldParms = 15
      END
      SET @c_Parms= ISNULL(RTRIM(@c_KeyValue1),'')                
            + ',' + ISNULL(RTRIM(@c_KeyValue2),'')                
            + ',' + ISNULL(RTRIM(@c_KeyValue3),'')                
            + ',' + ISNULL(RTRIM(@c_KeyValue4),'')                
            + ',' + ISNULL(RTRIM(@c_KeyValue5),'')                
            + ',' + ISNULL(RTRIM(@c_KeyValue6),'')                
            + ',' + ISNULL(RTRIM(@c_KeyValue7),'')                
            + ',' + ISNULL(RTRIM(@c_KeyValue8),'')                
            + ',' + ISNULL(RTRIM(@c_KeyValue9),'')                
            + ',' + ISNULL(RTRIM(@c_KeyValue10),'')                
            + ',' + ISNULL(RTRIM(@c_KeyValue11),'')                
            + ',' + ISNULL(RTRIM(@c_KeyValue12),'')                
            + ',' + ISNULL(RTRIM(@c_KeyValue13),'')                
            + ',' + ISNULL(RTRIM(@c_KeyValue14),'')                
            + ',' + ISNULL(RTRIM(@c_KeyValue15),'')                
            + ',' + ISNULL(RTRIM(@c_ExtendedParmValue1),'')         
            + ',' + ISNULL(RTRIM(@c_ExtendedParmValue2),'')         
            + ',' + ISNULL(RTRIM(@c_ExtendedParmValue3),'')         
            + ',' + ISNULL(RTRIM(@c_ExtendedParmValue4),'')         
            + ',' + ISNULL(RTRIM(@c_ExtendedParmValue5),'') 
      SET @n_StartPosK = 0
      SET @n_StopPosK  = 1
      SET @n_StartPosV = 0
      SET @n_StopPosV  = 1
      SET @n_StartPosL = 0
      SET @n_StopPosL  = 1
      SET @n_NoofParms = 0
      SET @n_ParmsCnt  = 1
      WHILE @n_ParmsCnt <= 20
      BEGIN
         SET @c_Parm = ''
         SET @c_KeyParm =''
         SET @c_ParmValue = ''
         SET @b_Insert = 0
         SET @n_StopPosK = CHARINDEX(',', @c_KeyParms, @n_StartPosK  + 1)
         IF @n_StopPosK > 0 
         BEGIN
            SET @c_KeyParm = SUBSTRING(@c_KeyParms, @n_StartPosK + 1, @n_StopPosK - @n_StartPosK - 1)
            SET @n_StartPosK = @n_StopPosK
         END
         SET @n_StopPosV = CHARINDEX(',', @c_Parms, @n_StartPosV + 1)
         IF @n_StopPosV > 0 
         BEGIN
            SET @c_ParmValue = SUBSTRING(@c_Parms, @n_StartPosV + 1, @n_StopPosV - @n_StartPosV - 1)
            SET @n_StartPosV = @n_StopPosV
         END
         IF @n_ParmsCnt <= @n_NoOfKeyFieldParms
         BEGIN
            SET @n_StopPosL = CHARINDEX(',', @c_KeyLableParms, @n_StartPosL  + 1)
            IF @n_StopPosL > 0 
            BEGIN
               SET @c_ParmLabel = SUBSTRING(@c_KeyLableParms, @n_StartPosL + 1, @n_StopPosL - @n_StartPosL - 1)
               SET @n_StartPosL = @n_StopPosL
            END
            SET @c_Parm = @c_KeyParm                     -- Get Default Value or Special Variable @c_UserName
            IF ISNULL(CHARINDEX('.', @c_KeyParm),0) > 0  -- IF KeyValue pass by UI, get Pass in value
            BEGIN
               SET @c_Parm = @c_ParmValue
            END
            IF @c_ParmLabel <> ''                        -- IF there is Parameter Label setup, get Pass in value
            BEGIN
               SET @c_Parm = @c_ParmValue
            END
            SET @b_Insert = 1
         END
         ELSE IF @n_ParmsCnt > 15                        -- IF Extended Parameters
         BEGIN 
            IF @c_KeyParm <> ''                          -- Get Pass In Value if extended parameters has setup value
            BEGIN
               SET @c_Parm = @c_ParmValue
               SET @b_Insert = 1
            END
         END
         IF @b_Insert = 1
         BEGIN
            SET @n_NoofParms = @n_NoofParms + 1
            IF @c_Parm = '@c_UserName' SET @c_Parm = @c_UserName
            IF @n_NoofParms = 1  SET @c_Parm1 = @c_Parm
            IF @n_NoofParms = 2  SET @c_Parm2 = @c_Parm
            IF @n_NoofParms = 3  SET @c_Parm3 = @c_Parm
            IF @n_NoofParms = 4  SET @c_Parm4 = @c_Parm
            IF @n_NoofParms = 5  SET @c_Parm5 = @c_Parm
            IF @n_NoofParms = 6  SET @c_Parm6 = @c_Parm
            IF @n_NoofParms = 7  SET @c_Parm7 = @c_Parm
            IF @n_NoofParms = 8  SET @c_Parm8 = @c_Parm
            IF @n_NoofParms = 9  SET @c_Parm9 = @c_Parm
            IF @n_NoofParms = 10 SET @c_Parm10= @c_Parm
            IF @n_NoofParms = 11 SET @c_Parm11= @c_Parm
            IF @n_NoofParms = 12 SET @c_Parm12= @c_Parm
            IF @n_NoofParms = 13 SET @c_Parm13= @c_Parm
            IF @n_NoofParms = 14 SET @c_Parm14= @c_Parm
            IF @n_NoofParms = 15 SET @c_Parm15= @c_Parm
            IF @n_NoofParms = 16 SET @c_Parm16= @c_Parm
            IF @n_NoofParms = 17 SET @c_Parm17= @c_Parm
            IF @n_NoofParms = 18 SET @c_Parm18= @c_Parm
            IF @n_NoofParms = 19 SET @c_Parm19= @c_Parm
            IF @n_NoofParms = 20 SET @c_Parm20= @c_Parm
            IF ISNULL(CHARINDEX('.', @c_KeyParm),0) > 0
            BEGIN
               IF @c_TableName = ''
               BEGIN
                  SET @c_TableName = SUBSTRING(@c_KeyParm, 1, ISNULL(CHARINDEX('.', @c_KeyParm),0) - 1)
                  SET @c_SQLPrint = N'SELECT @b_ContinuePrint = 1 FROM ' + @c_TableName + ' WITH (NOLOCK) WHERE '
               END
               ELSE 
               BEGIN
                  SET @c_SQLPrint = @c_SQLPrint + ' AND '
               END
               --(Wan09) - START
               SET @c_GreaterLessEqual = ' = '
               -- @n_StopPosK: Last position on current @c_KeyParm
               IF CHARINDEX(@c_KeyParm, @c_KeyParms, @n_StopPosK) > 0
               BEGIN 
                  SET @c_GreaterLessEqual = ' >= '
               END
               ELSE 
               -- Find from First to Start pos of current @c_KeyParm
               IF CHARINDEX(@c_KeyParm, @c_KeyParms, 1) < @n_StopPosK - LEN(@c_KeyParm)
               BEGIN
                  SET @c_GreaterLessEqual = ' <= '
               END
               --(Wan09) - END
               SET @c_SQLPrint = @c_SQLPrint + @c_KeyParm + @c_GreaterLessEqual                    --(Wan09)                 
                               + '@c_CriteriaParm'+ CONVERT(NVARCHAR(2), @n_NoofParms) 
               IF @n_NoofParms = 1  SET @c_CriteriaParm1 = @c_Parm
               IF @n_NoofParms = 2  SET @c_CriteriaParm2 = @c_Parm
               IF @n_NoofParms = 3  SET @c_CriteriaParm3 = @c_Parm
               IF @n_NoofParms = 4  SET @c_CriteriaParm4 = @c_Parm
               IF @n_NoofParms = 5  SET @c_CriteriaParm5 = @c_Parm
               IF @n_NoofParms = 6  SET @c_CriteriaParm6 = @c_Parm
               IF @n_NoofParms = 7  SET @c_CriteriaParm7 = @c_Parm
               IF @n_NoofParms = 8  SET @c_CriteriaParm8 = @c_Parm
               IF @n_NoofParms = 9  SET @c_CriteriaParm9 = @c_Parm
               IF @n_NoofParms = 10 SET @c_CriteriaParm10= @c_Parm
               IF @n_NoofParms = 11 SET @c_CriteriaParm11= @c_Parm
               IF @n_NoofParms = 12 SET @c_CriteriaParm12= @c_Parm
               IF @n_NoofParms = 13 SET @c_CriteriaParm13= @c_Parm
               IF @n_NoofParms = 14 SET @c_CriteriaParm14= @c_Parm
               IF @n_NoofParms = 15 SET @c_CriteriaParm15= @c_Parm 
               IF @n_NoofParms = 16 SET @c_CriteriaParm16= @c_Parm               --(Wan05)    
               IF @n_NoofParms = 17 SET @c_CriteriaParm17= @c_Parm               --(Wan05)
               IF @n_NoofParms = 18 SET @c_CriteriaParm18= @c_Parm               --(Wan05)
               IF @n_NoofParms = 19 SET @c_CriteriaParm19= @c_Parm               --(Wan05)
               IF @n_NoofParms = 20 SET @c_CriteriaParm20= @c_Parm               --(Wan05)                                   
            END
         END
         SET @n_ParmsCnt = @n_ParmsCnt + 1
      END
      --(MOve out From Loop) - END
      SET @CUR_GROUP = CURSOR FAST_FORWARD READ_ONLY FOR                                  
      SELECT  RowID          = WMRD.RowID
             ,ReportLineNo   = WMRD.ReportLineNo
             ,PrintGroup     = ISNULL(RTRIM(WMRD.PrintGroup),'')
             ,PrintType      = ISNULL(RTRIM(WMRD.PrintType),'')
             ,ReportTemplate = ISNULL(RTRIM(WMRD.ReportTemplate),'')
             ,CriteriaMatching01 = ISNULL(RTRIM(WMRD.CriteriaMatching01),'')
             ,CriteriaMatching02 = ISNULL(RTRIM(WMRD.CriteriaMatching02),'')
             ,CriteriaMatching03 = ISNULL(RTRIM(WMRD.CriteriaMatching03),'')
             ,CriteriaMatching04 = ISNULL(RTRIM(WMRD.CriteriaMatching04),'')
             ,CriteriaMatching05 = ISNULL(RTRIM(WMRD.CriteriaMatching05),'')
             ,PreprintSP         = ISNULL(RTRIM(WMRD.PreprintSP),'')
             ,PreGenRptData_SP   = ISNULL(RTRIM(WMRD.PreGenRptDataSP),'')      --(Wan05)
             ,PostPrintSP        = ISNULL(RTRIM(WMRD.PostPrintSP),'')                              --WL03
             ,DefaultPrinterID   = ISNULL(RTRIM(WMRD.DefaultPrinterID),'')                         --(Wan08) Packing to get this default to display on screen
             ,IsPaperPrinter     = IIF(RTRIM(WMRD.IsPaperPrinter)='',@c_IsPaperPrinter             --(Wan08)
                                      ,RTRIM(WMRD.IsPaperPrinter))                                 --(Wan08)
             ,PrintNextOnFail    = ISNULL(RTRIM(WMRD.PrintNextOnFail),0)                           --(Wan08)
             ,PrintSP_STD        = 'WM.lsp_' + TRIM(@c_ModuleID) + '_' + ISNULL(TRIM(WMR.ReportType),'') + '_Print_'   --WL04
      FROM dbo.WMREPORT       WMR  WITH (NOLOCK)
      JOIN dbo.WMREPORTDETAIL WMRD WITH (NOLOCK) ON (WMR.ReportID = WMRD.ReportID)
      JOIN WM.fnc_Get_WMReportDetail (@c_ReportID, @c_Storerkey, @c_Facility, @c_UserName, @c_ComputerName, 'N') MD
                                                 ON (WMRD.RowID = MD.RowID)
      JOIN CODELKUP CL WITH (NOLOCK) ON  CL.ListName = 'WMPrintTyp'           --(Wan01)
                                     AND CL.Code     = WMRD.PrintType         --(Wan01)
      WHERE WMR.ReportID = @c_ReportID
      AND CL.Short = @c_PrintSource                                           --(Wan01)
      ORDER BY PrintGroup
            ,  PrintType
      OPEN @CUR_GROUP
      FETCH NEXT FROM @CUR_GROUP INTO @n_RowID
                                    , @c_ReportLineNo
                                    , @c_PrintGroup
                                    , @c_PrintType
                                    , @c_ReportTemplate
                                    , @c_CriteriaMatching01
                                    , @c_CriteriaMatching02
                                    , @c_CriteriaMatching03
                                    , @c_CriteriaMatching04
                                    , @c_CriteriaMatching05
                                    , @c_PreprintSP
                                    , @c_PreGenRptData_SP                        --(Wan05)
                                    , @c_PostPrintSP                             --WL03
                                    , @c_DefaultPrinterID                        --(Wan08)
                                    , @c_IsPaperPrinter                          --(Wan08)
                                    , @b_PrintNextOnFail                         --(Wan08)   
                                    , @c_PrintSP_STD                             --WL04
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         --(Wan01) - START
         --IF @c_PrintGroup = @c_PrintGroup_Last
         --BEGIN
         --   GOTO PRINT_START
         --END
         IF ISNULL(@c_PrintType,'') = ''
         BEGIN
            GOTO NEXT_REC
         END
         --(Wan01) - END
         SET @c_SQLWhere = ''
         IF @c_CriteriaMatching01 <> ''
         BEGIN
            SET @c_SQLWhere = @c_SQLWhere +  ' AND '+ @c_CriteriaMatching01
         END
         IF @c_CriteriaMatching02 <> ''
         BEGIN
            IF @c_SQLWhere <> '' 
            BEGIN
               SET @c_SQLWhere = @c_SQLWhere + ' AND '
            END 
            SET @c_SQLWhere = @c_SQLWhere + @c_CriteriaMatching02
         END
         IF @c_CriteriaMatching03 <> ''
         BEGIN
            IF @c_SQLWhere <> '' 
            BEGIN
               SET @c_SQLWhere = @c_SQLWhere + ' AND '
            END 
            SET @c_SQLWhere = @c_SQLWhere + @c_CriteriaMatching03
         END
         IF @c_CriteriaMatching04 <> ''
         BEGIN
            IF @c_SQLWhere <> '' 
            BEGIN
               SET @c_SQLWhere = @c_SQLWhere + ' AND '
            END 
            SET @c_SQLWhere = @c_SQLWhere + @c_CriteriaMatching04
         END
         IF @c_CriteriaMatching05 <> ''
         BEGIN
            IF @c_SQLWhere <> '' 
            BEGIN
               SET @c_SQLWhere = @c_SQLWhere + ' AND '
            END 
            SET @c_SQLWhere = @c_SQLWhere + @c_CriteriaMatching05
         END
         SET @b_ContinuePrint = 1
         IF @c_SQLWhere <> ''
         BEGIN
            SET @c_SQL = @c_SQLPrint + ' AND ' + @c_SQLWhere                        --(Wan07)
            SET @b_ContinuePrint = 0
            SET @c_SQLParms= N'@b_ContinuePrint  BIT OUTPUT '
                           + ',@c_CriteriaParm1  NVARCHAR(60) '
                           + ',@c_CriteriaParm2  NVARCHAR(60) '
                           + ',@c_CriteriaParm3  NVARCHAR(60) '
                           + ',@c_CriteriaParm4  NVARCHAR(60) '
                           + ',@c_CriteriaParm5  NVARCHAR(60) '
                           + ',@c_CriteriaParm6  NVARCHAR(60) '
                           + ',@c_CriteriaParm7  NVARCHAR(60) '
                           + ',@c_CriteriaParm8  NVARCHAR(60) '
                           + ',@c_CriteriaParm9  NVARCHAR(60) '
                           + ',@c_CriteriaParm10 NVARCHAR(60) '
                           + ',@c_CriteriaParm11 NVARCHAR(60) '
                           + ',@c_CriteriaParm12 NVARCHAR(60) '
                           + ',@c_CriteriaParm13 NVARCHAR(60) '
                           + ',@c_CriteriaParm14 NVARCHAR(60) '
                           + ',@c_CriteriaParm15 NVARCHAR(60) '
                           + ',@c_CriteriaParm16 NVARCHAR(60) '                  --(Wan05)
                           + ',@c_CriteriaParm17 NVARCHAR(60) '                  --(Wan05)
                           + ',@c_CriteriaParm18 NVARCHAR(60) '                  --(Wan05)
                           + ',@c_CriteriaParm19 NVARCHAR(60) '                  --(Wan05)
                           + ',@c_CriteriaParm20 NVARCHAR(60) '                  --(Wan05) 
            EXEC sp_ExecuteSQL @c_SQL
                             , @c_SQLParms
                             , @b_ContinuePrint    OUTPUT
                             , @c_CriteriaParm1   
                             , @c_CriteriaParm2   
                             , @c_CriteriaParm3   
                             , @c_CriteriaParm4   
                             , @c_CriteriaParm5   
                             , @c_CriteriaParm6   
                             , @c_CriteriaParm7   
                             , @c_CriteriaParm8   
                             , @c_CriteriaParm9   
                             , @c_CriteriaParm10  
                             , @c_CriteriaParm11  
                             , @c_CriteriaParm12  
                             , @c_CriteriaParm13  
                             , @c_CriteriaParm14  
                             , @c_CriteriaParm15
                             , @c_CriteriaParm16                                 --(Wan05)
                             , @c_CriteriaParm17                                 --(Wan05)
                             , @c_CriteriaParm18                                 --(Wan05)
                             , @c_CriteriaParm19                                 --(Wan05)
                             , @c_CriteriaParm20                                 --(Wan05)  
            IF @b_ContinuePrint = 0 
            BEGIN 
               GOTO NEXT_REC
            END
            --GOTO PRINT_START   --WL01
         END
         IF @c_PrinterID = '' AND @c_DefaultPrinterID <> ''                         --(Wan08)
         BEGIN
            SET @c_PrinterID = @c_DefaultPrinterID
         END
         --(Wan04) - Start Move UP 
         SET @c_Printer = @c_PrinterID
         IF @c_PrinterID <> '' AND @c_PrintType NOT IN ( 'JReport', 'LogiReport')   
         BEGIN
            -- Check if printer is a group
            SET @c_PrinterGroup = @c_Printer
            IF EXISTS( SELECT TOP 1 1 FROM rdt.rdtPrinterGroup WITH (NOLOCK) WHERE PrinterGroup = @c_PrinterGroup)
            BEGIN
               SET @c_Printer = ''
               SET @n_FunctionID = 999
               -- Check if report print to a specific printer in group
               SELECT @c_Printer = PrinterID
               FROM rdt.rdtReportToPrinter WITH (NOLOCK)
               WHERE  Function_ID = @n_FunctionID
                  AND StorerKey   = @c_StorerKey
                  AND ReportType  = @c_ReportID
                  AND ReportLineNo= @c_ReportLineNo
                  AND PrinterGroup= @c_PrinterGroup
               IF @c_Printer = ''
               BEGIN
                  -- Get default printer in the group
                  SELECT @c_Printer = PrinterID
                  FROM rdt.rdtPrinterGroup WITH (NOLOCK)
                  WHERE PrinterGroup = @c_PrinterGroup
                  AND DefaultPrinter = 1
                  -- Check no default printer
                  IF @c_Printer = ''
                  BEGIN
                     SET @n_Continue=3 
                     SET @n_Err    = 552651
                     SET @c_Errmsg = 'NSQL' + CONVERT(NCHAR(6), @n_Err) 
                                    + ': Default Printer Not Setup for PrintGroup:' + RTRIM(@c_PrinterGroup)
                                    + ' |' + RTRIM(@c_PrinterGroup)
                     GOTO EXIT_SP 
                  END
               END
            END
         END
         --(Wan04) - END Move UP 
         --WL04 S
         IF ISNULL(@c_PrintSP_STD,'') <> ''
         BEGIN
            IF EXISTS (SELECT 1 FROM sysobjects o WHERE id = OBJECT_ID(@c_PrintSP_STD + 'Pre_Std')  AND TYPE = 'P')
            BEGIN
               SET @b_ContinuePrint = 0
               SET @c_SQL  = 'EXECUTE ' + @c_PrintSP_STD + 'Pre_Std' 
                           + ' @n_WMReportRowID = @n_RowID'
                           + ',@c_UserName      = @c_UserName '
                           + ',@c_Parm1         = @c_Parm1           OUTPUT '              
                           + ',@c_Parm2         = @c_Parm2           OUTPUT '              
                           + ',@c_Parm3         = @c_Parm3           OUTPUT '              
                           + ',@c_Parm4         = @c_Parm4           OUTPUT '              
                           + ',@c_Parm5         = @c_Parm5           OUTPUT '              
                           + ',@c_Parm6         = @c_Parm6           OUTPUT '              
                           + ',@c_Parm7         = @c_Parm7           OUTPUT '              
                           + ',@c_Parm8         = @c_Parm8           OUTPUT '              
                           + ',@c_Parm9         = @c_Parm9           OUTPUT '              
                           + ',@c_Parm10        = @c_Parm10          OUTPUT '              
                           + ',@c_Parm11        = @c_Parm11          OUTPUT '              
                           + ',@c_Parm12        = @c_Parm12          OUTPUT '              
                           + ',@c_Parm13        = @c_Parm13          OUTPUT '              
                           + ',@c_Parm14        = @c_Parm14          OUTPUT '              
                           + ',@c_Parm15        = @c_Parm15          OUTPUT '              
                           + ',@c_Parm16        = @c_Parm16          OUTPUT '              
                           + ',@c_Parm17        = @c_Parm17          OUTPUT '              
                           + ',@c_Parm18        = @c_Parm18          OUTPUT '              
                           + ',@c_Parm19        = @c_Parm19          OUTPUT '              
                           + ',@c_Parm20        = @c_Parm20          OUTPUT '  
                           + ',@n_Noofparms     = @n_Noofparms       OUTPUT '              
                           + ',@b_ContinuePrint = @b_ContinuePrint   OUTPUT '    --1/0     
                           + ',@n_NoOfCopy      = @n_NoOfCopy        OUTPUT '              
                           + ',@c_PrinterID     = @c_Printer         OUTPUT '              
                           + ',@c_PrintData     = @c_PrintData       OUTPUT '  
                           + ',@b_Success       = @b_Success         OUTPUT '
                           + ',@n_Err           = @n_Err             OUTPUT '
                           + ',@c_ErrMsg        = @c_ErrMsg          OUTPUT ' 
                           + ',@c_PrintSource   = @c_PrintSource '  
                           + ',@b_SCEPreView    = @b_SCEPreView  '
                           + ',@n_JobID         = @n_JobID           OUTPUT '
                 SET @c_SQLParms= N'@n_RowID       BIGINT '
                              + ',@c_UserName      NVARCHAR(128) '            
                              + ',@c_Parm1         NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm2         NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm3         NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm4         NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm5         NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm6         NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm7         NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm8         NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm9         NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm10        NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm11        NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm12        NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm13        NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm14        NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm15        NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm16        NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm17        NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm18        NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm19        NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm20        NVARCHAR(60)   OUTPUT ' 
                              + ',@n_Noofparms     INT            OUTPUT '            
                              + ',@b_ContinuePrint BIT            OUTPUT '    --1/0  
                              + ',@n_NoOfCopy      INT            OUTPUT '           
                              + ',@c_Printer       NVARCHAR(30)   OUTPUT '           
                              + ',@c_PrintData     NVARCHAR(4000) OUTPUT '  
                              + ',@b_Success       INT            OUTPUT '
                              + ',@n_Err           INT            OUTPUT '
                              + ',@c_ErrMsg        NVARCHAR(255)  OUTPUT ' 
                              + ',@c_PrintSource   NVARCHAR(10) '
                              + ',@b_SCEPreView    INT '
                              + ',@n_JobID         INT            OUTPUT '                                        
               EXEC sp_ExecuteSQL @c_SQL
                                 ,@c_SQLParms
                                 ,@n_RowID 
                                 ,@c_UserName
                                 ,@c_Parm1         OUTPUT           
                                 ,@c_Parm2         OUTPUT            
                                 ,@c_Parm3         OUTPUT          
                                 ,@c_Parm4         OUTPUT         
                                 ,@c_Parm5         OUTPUT          
                                 ,@c_Parm6         OUTPUT            
                                 ,@c_Parm7         OUTPUT          
                                 ,@c_Parm8         OUTPUT            
                                 ,@c_Parm9         OUTPUT            
                                 ,@c_Parm10        OUTPUT
                                 ,@c_Parm11        OUTPUT           
                                 ,@c_Parm12        OUTPUT            
                                 ,@c_Parm13        OUTPUT          
                                 ,@c_Parm14        OUTPUT         
                                 ,@c_Parm15        OUTPUT          
                                 ,@c_Parm16        OUTPUT            
                                 ,@c_Parm17        OUTPUT          
                                 ,@c_Parm18        OUTPUT            
                                 ,@c_Parm19        OUTPUT            
                                 ,@c_Parm20        OUTPUT
                                 ,@n_Noofparms     OUTPUT
                                 ,@b_ContinuePrint OUTPUT      --1/0
                                 ,@n_NoOfCopy      OUTPUT
                                 ,@c_Printer       OUTPUT
                                 ,@c_PrintData     OUTPUT
                                 ,@b_Success       OUTPUT 
                                 ,@n_Err           OUTPUT  
                                 ,@c_ErrMsg        OUTPUT  
                                 ,@c_PrintSource 
                                 ,@b_SCEPreView 
                                 ,@n_JobID        OUTPUT
               IF @b_Success <> 1
               BEGIN
                  SET @n_Continue=3 
                  SET @n_Err    = 552658
                  SET @c_Errmsg = 'NSQL' + CONVERT(NCHAR(6), @n_Err) 
                                 + ': Error Executing Standard Pre-Print SP:' + TRIM(@c_PrintSP_STD + 'Pre_Std') 
                                 + ' (lsp_WM_Print_Report) ( ' + @c_errmsg + ' )' 
                                 + ' |' + TRIM(@c_PrintSP_STD + 'Pre_Std') 
                  GOTO EXIT_SP 
               END
               IF @b_ContinuePrint = 1  
               BEGIN
                  GOTO PREPRINT_SP
               END 
            END
            IF @b_ContinuePrint = 0 
            BEGIN
               IF @n_JobID > 0 
               BEGIN 
                  SET @c_JobIDs = @c_JobIDs + CONVERT(NVARCHAR(10),@n_JobID) 
               END
               GOTO NEXT_REC
            END 
         END
         PREPRINT_SP:
         --WL04 E
         IF @c_PreprintSP <> ''
         BEGIN
            SET @b_ContinuePrint = 0
            IF EXISTS (SELECT 1 FROM sysobjects o WHERE id = OBJECT_ID(@c_PreprintSP)  AND TYPE = 'P')               --(Wan04) 
            BEGIN
               SET @c_SQL  = 'EXECUTE ' + @c_PreprintSP 
                           + ' @n_WMReportRowID = @n_RowID'
                           + ',@c_UserName      = @c_UserName '                  --(Wan04) 
                           + ',@c_Parm1         = @c_Parm1           OUTPUT '              
                           + ',@c_Parm2         = @c_Parm2           OUTPUT '              
                           + ',@c_Parm3         = @c_Parm3           OUTPUT '              
                           + ',@c_Parm4         = @c_Parm4           OUTPUT '              
                           + ',@c_Parm5         = @c_Parm5           OUTPUT '              
                           + ',@c_Parm6         = @c_Parm6           OUTPUT '              
                           + ',@c_Parm7         = @c_Parm7           OUTPUT '              
                           + ',@c_Parm8         = @c_Parm8           OUTPUT '              
                           + ',@c_Parm9         = @c_Parm9           OUTPUT '              
                           + ',@c_Parm10        = @c_Parm10          OUTPUT '              
                           + ',@c_Parm11        = @c_Parm11          OUTPUT '              
                           + ',@c_Parm12        = @c_Parm12          OUTPUT '              
                           + ',@c_Parm13        = @c_Parm13          OUTPUT '              
                           + ',@c_Parm14        = @c_Parm14          OUTPUT '              
                           + ',@c_Parm15        = @c_Parm15          OUTPUT '              
                           + ',@c_Parm16        = @c_Parm16          OUTPUT '              
                           + ',@c_Parm17        = @c_Parm17          OUTPUT '              
                           + ',@c_Parm18        = @c_Parm18          OUTPUT '              
                           + ',@c_Parm19        = @c_Parm19          OUTPUT '              
                           + ',@c_Parm20        = @c_Parm20          OUTPUT '  
                           + ',@n_Noofparms     = @n_Noofparms       OUTPUT '              
                           + ',@b_ContinuePrint = @b_ContinuePrint   OUTPUT '    --1/0     
                           + ',@n_NoOfCopy      = @n_NoOfCopy        OUTPUT '              
                           + ',@c_PrinterID     = @c_Printer         OUTPUT '              
                           + ',@c_PrintData     = @c_PrintData       OUTPUT '  
                           + ',@b_Success       = @b_Success         OUTPUT '
                           + ',@n_Err           = @n_Err             OUTPUT '
                           + ',@c_ErrMsg        = @c_ErrMsg          OUTPUT ' 
                           + ',@c_PrintSource   = @c_PrintSource '               --(Wan04)     
                           + ',@b_SCEPreView    = @b_SCEPreView  '               --(Wan04) 
                           + ',@n_JobID         = @n_JobID           OUTPUT '    --(Wan04) 
                 SET @c_SQLParms= N'@n_RowID       BIGINT '
                              + ',@c_UserName      NVARCHAR(128) '               --(Wan04)               
                              + ',@c_Parm1         NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm2         NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm3         NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm4         NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm5         NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm6         NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm7         NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm8         NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm9         NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm10        NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm11        NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm12        NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm13        NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm14        NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm15        NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm16        NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm17        NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm18        NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm19        NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm20        NVARCHAR(60)   OUTPUT ' 
                              + ',@n_Noofparms     INT            OUTPUT '            
                              + ',@b_ContinuePrint BIT            OUTPUT '    --1/0  
                              + ',@n_NoOfCopy      INT            OUTPUT '           
                              + ',@c_Printer       NVARCHAR(30)   OUTPUT '           
                              + ',@c_PrintData     NVARCHAR(4000) OUTPUT '  
                              + ',@b_Success       INT            OUTPUT '
                              + ',@n_Err           INT            OUTPUT '
                              + ',@c_ErrMsg        NVARCHAR(255)  OUTPUT ' 
                              + ',@c_PrintSource   NVARCHAR(10) '             --(Wan04)     
                              + ',@b_SCEPreView    INT '                      --(Wan04)  
                              + ',@n_JobID         INT            OUTPUT '    --(Wan04)                                         
               EXEC sp_ExecuteSQL @c_SQL
                                 ,@c_SQLParms
                                 ,@n_RowID 
                                 ,@c_UserName                  --(Wan04) 
                                 ,@c_Parm1         OUTPUT           
                                 ,@c_Parm2         OUTPUT            
                                 ,@c_Parm3         OUTPUT          
                                 ,@c_Parm4         OUTPUT         
                                 ,@c_Parm5         OUTPUT          
                                 ,@c_Parm6         OUTPUT            
                                 ,@c_Parm7         OUTPUT          
                                 ,@c_Parm8         OUTPUT            
                                 ,@c_Parm9         OUTPUT            
                                 ,@c_Parm10        OUTPUT
                                 ,@c_Parm11        OUTPUT           
                                 ,@c_Parm12        OUTPUT            
                                 ,@c_Parm13        OUTPUT          
                                 ,@c_Parm14        OUTPUT         
                                 ,@c_Parm15        OUTPUT          
                                 ,@c_Parm16        OUTPUT            
                                 ,@c_Parm17        OUTPUT          
                                 ,@c_Parm18        OUTPUT            
                                 ,@c_Parm19        OUTPUT            
                                 ,@c_Parm20        OUTPUT
                                 ,@n_Noofparms     OUTPUT
                                 ,@b_ContinuePrint OUTPUT      --1/0
                                 ,@n_NoOfCopy      OUTPUT
                                 ,@c_Printer       OUTPUT
                                 ,@c_PrintData     OUTPUT
                                 ,@b_Success       OUTPUT 
                                 ,@n_Err           OUTPUT  
                                 ,@c_ErrMsg        OUTPUT  
                                 ,@c_PrintSource               --(Wan04)      
                                 ,@b_SCEPreView                --(Wan04)
                                 ,@n_JobID        OUTPUT       --(Wan04)
               IF @b_Success <> 1
               BEGIN
                  SET @n_Continue=3 
                  SET @n_Err    = 552652
                  SET @c_Errmsg = 'NSQL' + CONVERT(NCHAR(6), @n_Err) 
                                 + ': Error Executing Pre-Print SP:' + RTRIM(@c_PreprintSP) 
                                 + ' (lsp_WM_Print_Report) ( ' + @c_errmsg + ' )' 
                                 + ' |' + RTRIM(@c_PreprintSP) 
                  GOTO EXIT_SP 
               END
               IF @b_ContinuePrint = 1  
               BEGIN
                  GOTO PRINT_START
               END 
            END
            IF @b_ContinuePrint = 0 
            BEGIN
               --(Wan04) - START 
               IF @n_JobID > 0 
               BEGIN 
                  SET @c_JobIDs = @c_JobIDs + CONVERT(NVARCHAR(10),@n_JobID) 
               END
               --(Wan04) - END
               GOTO NEXT_REC
            END        
         END
         PRINT_START:   --WL01
         --(Wan05) - START
         IF @c_PreGenRptData_SP <> ''
         BEGIN
            --WL05 S
            SET @n_idx = CHARINDEX(' ', TRIM(@c_PreGenRptData_SP), 1)
            IF @n_idx > 0
            BEGIN
               SET @c_VarList = SUBSTRING(
                                   @c_PreGenRptData_SP
                                 , CHARINDEX('@', @c_PreGenRptData_SP, 1)
                                 , LEN(@c_PreGenRptData_SP) - CHARINDEX('@', @c_PreGenRptData_SP, 1) + 1)
               SELECT @c_ExcludeVar = STUFF(
                                      (  SELECT ',' + SUBSTRING('@' + TRIM(ColValue), 1, CHARINDEX('=', '@' + TRIM(ColValue)) - 1)
                                         FROM dbo.fnc_DelimSplit('@', @c_VarList)
                                         WHERE ColValue <> ''
                                         FOR XML PATH(''))
                                    , 1
                                    , 1
                                    , '')
               SET @c_SPName = SUBSTRING(@c_PreGenRptData_SP, 1, @n_idx - 1)
               ;WITH SPP AS
               (
                  SELECT RowID = ROW_NUMBER() OVER (ORDER BY CASE WHEN p.name = '@c_PreGenRptData' THEN 9999 ELSE p.parameter_id END ASC)
                       , p.[name]
                  FROM sys.parameters AS p (NOLOCK)
                  WHERE p.[object_id] = OBJECT_ID(@c_SPName)
                  AND   p.name NOT IN (  SELECT DISTINCT TRIM(ColValue)
                                         FROM dbo.fnc_DelimSplit(',', @c_ExcludeVar) )
                  AND   p.name NOT IN ( '@b_Success', '@n_Err', '@c_Errmsg' )
               )
               SELECT @c_SQL = STRING_AGG(SPP.[name] + '=' + CASE WHEN SPP.[name] = '@c_PreGenRptData' THEN '''Y'''
                                                                  ELSE '@c_Parm' + CONVERT(CHAR(5), SPP.RowID) END
                                        , ',') WITHIN GROUP(ORDER BY SPP.RowID ASC)
               FROM SPP
               SET @c_SQL = N'EXEC ' + @c_PreGenRptData_SP + CASE WHEN CHARINDEX('@', @c_PreGenRptData_SP, 1) > 0 THEN ','
                                                                  ELSE '' END + N' ' + @c_SQL
               SET @c_SQLParms= N'@c_Parm1  NVARCHAR(60) '
                              + ',@c_Parm2  NVARCHAR(60) '
                              + ',@c_Parm3  NVARCHAR(60) '
                              + ',@c_Parm4  NVARCHAR(60) '
                              + ',@c_Parm5  NVARCHAR(60) '
                              + ',@c_Parm6  NVARCHAR(60) '
                              + ',@c_Parm7  NVARCHAR(60) '
                              + ',@c_Parm8  NVARCHAR(60) '
                              + ',@c_Parm9  NVARCHAR(60) '
                              + ',@c_Parm10 NVARCHAR(60) '
                              + ',@c_Parm11 NVARCHAR(60) '
                              + ',@c_Parm12 NVARCHAR(60) '
                              + ',@c_Parm13 NVARCHAR(60) '
                              + ',@c_Parm14 NVARCHAR(60) '
                              + ',@c_Parm15 NVARCHAR(60) '
                              + ',@c_Parm16 NVARCHAR(60) '
                              + ',@c_Parm17 NVARCHAR(60) '
                              + ',@c_Parm18 NVARCHAR(60) '
                              + ',@c_Parm19 NVARCHAR(60) '
                              + ',@c_Parm20 NVARCHAR(60) '                           
               EXEC sp_ExecuteSQL @c_SQL
                                , @c_SQLParms
                                , @c_Parm1   
                                , @c_Parm2   
                                , @c_Parm3   
                                , @c_Parm4   
                                , @c_Parm5   
                                , @c_Parm6   
                                , @c_Parm7   
                                , @c_Parm8   
                                , @c_Parm9   
                                , @c_Parm10  
                                , @c_Parm11  
                                , @c_Parm12  
                                , @c_Parm13  
                                , @c_Parm14  
                                , @c_Parm15
                                , @c_Parm16  
                                , @c_Parm17  
                                , @c_Parm18  
                                , @c_Parm19  
                                , @c_Parm20
            END
            ELSE
            BEGIN --WL05 E
               ; WITH SPP AS 
               ( SELECT RowID = ROW_NUMBER() OVER (ORDER BY CASE WHEN p.NAME = '@c_PreGenRptData' THEN 9999 ELSE p.parameter_id END ASC)
                      , p.[Name]
                 FROM sys.parameters AS p (NOLOCK) WHERE p.[object_id] = OBJECT_ID(@c_PreGenRptData_SP)
               )
               SELECT @c_SQL = STRING_AGG (SPP.[Name] + '=' + CASE WHEN SPP.[Name] = '@c_PreGenRptData' THEN '''Y''' ELSE '@c_Parm' + CONVERT(CHAR(5),SPP.RowID) END   --WL02
                                          , ',') 
                                 WITHIN GROUP ( ORDER BY SPP.RowID ASC )
               FROM SPP 
               IF @c_SQL <> '' AND @c_SQL IS NOT NULL AND CHARINDEX('PreGenRptData',@c_SQL,1) > 0
               BEGIN
                  SET @c_SQL = N'EXEC ' + @c_PreGenRptData_SP + ' ' + @c_SQL
                  SET @c_SQLParms= N'@c_Parm1  NVARCHAR(60) '
                                 + ',@c_Parm2  NVARCHAR(60) '
                                 + ',@c_Parm3  NVARCHAR(60) '
                                 + ',@c_Parm4  NVARCHAR(60) '
                                 + ',@c_Parm5  NVARCHAR(60) '
                                 + ',@c_Parm6  NVARCHAR(60) '
                                 + ',@c_Parm7  NVARCHAR(60) '
                                 + ',@c_Parm8  NVARCHAR(60) '
                                 + ',@c_Parm9  NVARCHAR(60) '
                                 + ',@c_Parm10 NVARCHAR(60) '
                                 + ',@c_Parm11 NVARCHAR(60) '
                                 + ',@c_Parm12 NVARCHAR(60) '
                                 + ',@c_Parm13 NVARCHAR(60) '
                                 + ',@c_Parm14 NVARCHAR(60) '
                                 + ',@c_Parm15 NVARCHAR(60) '
                                 + ',@c_Parm16 NVARCHAR(60) '
                                 + ',@c_Parm17 NVARCHAR(60) '
                                 + ',@c_Parm18 NVARCHAR(60) '
                                 + ',@c_Parm19 NVARCHAR(60) '
                                 + ',@c_Parm20 NVARCHAR(60) '                           
                  EXEC sp_ExecuteSQL @c_SQL
                                   , @c_SQLParms
                                   , @c_Parm1   
                                   , @c_Parm2   
                                   , @c_Parm3   
                                   , @c_Parm4   
                                   , @c_Parm5   
                                   , @c_Parm6   
                                   , @c_Parm7   
                                   , @c_Parm8   
                                   , @c_Parm9   
                                   , @c_Parm10  
                                   , @c_Parm11  
                                   , @c_Parm12  
                                   , @c_Parm13  
                                   , @c_Parm14  
                                   , @c_Parm15
                                   , @c_Parm16  
                                   , @c_Parm17  
                                   , @c_Parm18  
                                   , @c_Parm19  
                                   , @c_Parm20                                
               END
            END   --WL05
         END
         --(Wan05) - END
         --(Wan01) - START
         --PRINT_START:   --WL01
         IF @c_PrintType IN ( 'JReport', 'LogiReport')   --Wan02
         BEGIN
            SET @c_ReturnURL = ''                                                   --(Wan08) - START
            --EXEC WM.lsp_WM_Get_WebReport_URL
            --,  @c_ReportID    = @c_ReportID
            --,  @n_DetailRowID = @n_RowID
            EXEC [WM].[lsp_WM_Print_WebReport_Wrapper]
               @n_WMReportRowID  = @n_RowID 
            ,  @c_Storerkey      = @c_Storerkey     
            ,  @c_Facility       = @c_Facility      
            ,  @c_UserName       = @c_UserName      
            ,  @n_Noofcopy       = @n_Noofcopy                                                       
            ,  @c_PrinterID      = @c_PrinterID     
            ,  @c_IsPaperPrinter = @c_IsPaperPrinter
            ,  @n_Noofparms      = @n_Noofparms     
            ,  @c_Parm1          = @c_Parm1           
            ,  @c_Parm2          = @c_Parm2           
            ,  @c_Parm3          = @c_Parm3           
            ,  @c_Parm4          = @c_Parm4           
            ,  @c_Parm5          = @c_Parm5           
            ,  @c_Parm6          = @c_Parm6           
            ,  @c_Parm7          = @c_Parm7           
            ,  @c_Parm8          = @c_Parm8           
            ,  @c_Parm9          = @c_Parm9           
            ,  @c_Parm10         = @c_Parm10          
            ,  @c_Parm11         = @c_Parm11          
            ,  @c_Parm12         = @c_Parm12          
            ,  @c_Parm13         = @c_Parm13          
            ,  @c_Parm14         = @c_Parm14          
            ,  @c_Parm15         = @c_Parm15          
            ,  @c_Parm16         = @c_Parm16          
            ,  @c_Parm17         = @c_Parm17          
            ,  @c_Parm18         = @c_Parm18          
            ,  @c_Parm19         = @c_Parm19          
            ,  @c_Parm20         = @c_Parm20    
            ,  @c_ReturnURL      = @c_ReturnURL OUTPUT      
            ,  @b_Success        = @b_Success   OUTPUT  
            ,  @n_err            = @n_err       OUTPUT                                                                                                             
            ,  @c_ErrMsg         = @c_ErrMsg    OUTPUT
            IF @b_Success = 0 AND @b_PrintNextOnFail = 0                            --(Wan08)
            BEGIN
               SET @n_Continue = 3                 --(Wan05)
               SET @n_err = 552656
               --SET @c_ErrMsg = ERROR_MESSAGE()   --(Wan05)
               SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Error Executing lsp_WM_Print_WebReport_Wrapper. (lsp_WM_Print_Report)'
                             + '( ' + @c_errmsg + ' )'
               GOTO EXIT_SP
            END
            IF @c_ReturnURL <> ''
            BEGIN
               INSERT INTO @RPTURL (ReportID, DetailRowID, REPORT_URL)
               VALUES (@c_ReportID, @n_RowID, @c_ReturnURL)
            END                                                                     --(Wan08) - END
            GOTO NEXT_REC
         END
         --(Wan01) - END  
         IF @c_PrintType = 'BARTENDER'                                              --(Wan07) - START
         BEGIN
         --   SET @c_IsPaperPrinter = 'N'
         --   IF @c_ModuleID = 'PACKING'
         --   BEGIN
         --      BEGIN TRY
         --         EXEC isp_packing_bartender_print
         --            @c_PrinterID    = @c_Printer
         --         ,  @c_LabelType    = @c_ReportTemplate
         --         ,  @c_Userid       = @c_UserName
         --         ,  @c_Parm01       = @c_Parm1
         --         ,  @c_Parm02       = @c_Parm2
         --         ,  @c_Parm03       = @c_Parm3
         --         ,  @c_Parm04       = @c_Parm4
         --         ,  @c_Parm05       = @c_Parm5
         --         ,  @c_Parm06       = @c_Parm6
         --         ,  @c_Parm07       = @c_Parm7
         --         ,  @c_Parm08       = @c_Parm8
         --         ,  @c_Parm09       = @c_Parm9
         --         ,  @c_Parm10       = @c_Parm10
         --         ,  @c_Storerkey    = @c_Storerkey
         --         ,  @c_NoOfCopy     = @n_NoOfCopy
         --         ,  @c_SubType      = '' --@c_ReportID
         --         ,  @b_Success      = @b_Success
         --         ,  @n_err          = @n_err         OUTPUT  
         --         ,  @c_errmsg       = @c_errmsg      OUTPUT
         --      END TRY
         --      BEGIN CATCH   
         --         SET @n_Err = 552653
         --         SET @c_ErrMsg = ERROR_MESSAGE()
         --         SET @c_ErrMsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ':Error Executing isp_packing_bartender_print. (lsp_WM_Print_Report)'
         --                       + ' ( ' + @c_errmsg + ' )' 
         --      END CATCH
         --      IF @b_Success = 0 OR @n_Err <> 0
         --      BEGIN
         --         SET @n_Continue = 3
         --         SET @c_errmsg = @c_errmsg
         --         GOTO EXIT_SP
         --      END
         --      IF @b_Success = 2 -- Report Has been Printed and stop to print to next template for the same group
         --      BEGIN
         --         BREAK
         --      END
         --      GOTO NEXT_REC         
         --   END
            --BEGIN TRY
            --  EXEC isp_BT_GenBartenderCommand
            --      @cPrinterID       = @c_PrinterID
            --   ,  @c_LabelType      = @c_ReportTemplate
            --   ,  @c_Userid         = @c_UserName
            --   ,  @c_Parm01         = @c_Parm1
            --   ,  @c_Parm02         = @c_Parm2
            --   ,  @c_Parm03         = @c_Parm3
            --   ,  @c_Parm04         = @c_Parm4
            --   ,  @c_Parm05         = @c_Parm5
            --   ,  @c_Parm06         = @c_Parm6
            --   ,  @c_Parm07         = @c_Parm7
            --   ,  @c_Parm08         = @c_Parm8
            --   ,  @c_Parm09         = @c_Parm9
            --   ,  @c_Parm10         = @c_Parm10
            --   ,  @c_Storerkey      = @c_Storerkey
            --   ,  @c_NoCopy         = @n_NoOfCopy
            --   ,  @c_Returnresult   ='N'   
            --   ,  @n_err            = @n_err          OUTPUT  
            --   ,  @c_errmsg         = @c_errmsg       OUTPUT 
            --   ,  @c_QCmdSubmitFlag = @c_QCmdSubmitFlag  
            --END TRY
            --BEGIN CATCH
            --   SET @n_Err = 552654
            --   SET @c_ErrMsg = ERROR_MESSAGE()
            --   SET @c_ErrMsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ':Error Executing isp_BT_GenBartenderCommand. (lsp_WM_Print_Report)'
            --                  + ' ( ' + @c_errmsg + ' )' 
            --END CATCH
            --IF @n_Err <> 0 
            --BEGIN
            --   SET @n_Continue = 3
            --   SET @c_errmsg = @c_errmsg
            --   GOTO EXIT_SP
            --END
            EXEC [WM].[lsp_WM_Print_Bartender_Wrapper]
               @n_WMReportRowID  = @n_RowID 
            ,  @c_Storerkey      = @c_Storerkey     
            ,  @c_Facility       = @c_Facility      
            ,  @c_UserName       = @c_UserName  
            ,  @n_Noofcopy       = @n_Noofcopy
            ,  @c_PrinterID      = @c_Printer     
            ,  @c_IsPaperPrinter = @c_IsPaperPrinter
            ,  @n_Noofparms      = @n_Noofparms     
            ,  @c_Parm1          = @c_Parm1         
            ,  @c_Parm2          = @c_Parm2         
            ,  @c_Parm3          = @c_Parm3         
            ,  @c_Parm4          = @c_Parm4         
            ,  @c_Parm5          = @c_Parm5         
            ,  @c_Parm6          = @c_Parm6         
            ,  @c_Parm7          = @c_Parm7         
            ,  @c_Parm8          = @c_Parm8         
            ,  @c_Parm9          = @c_Parm9         
            ,  @c_Parm10         = @c_Parm10               
            ,  @c_Parm11         = @c_Parm11        
            ,  @c_Parm12         = @c_Parm12        
            ,  @c_Parm13         = @c_Parm13        
            ,  @c_Parm14         = @c_Parm14       
            ,  @c_Parm15         = @c_Parm15          
            ,  @c_Parm16         = @c_Parm16          
            ,  @c_Parm17         = @c_Parm17          
            ,  @c_Parm18         = @c_Parm18          
            ,  @c_Parm19         = @c_Parm19          
            ,  @c_Parm20         = @c_Parm20          
            ,  @b_Success        = @b_Success         OUTPUT
            ,  @n_Err            = @n_Err             OUTPUT
            ,  @c_ErrMsg         = @c_ErrMsg          OUTPUT
            IF @b_Success = 0 AND @b_PrintNextOnFail = 0                            --(Wan08)
            BEGIN
               SET @n_Continue = 3
               GOTO EXIT_SP
            END                                                                     --(Wan07) - END
            GOTO NEXT_REC
         END
         --(Wan06) - START
         IF @c_PrintType IN ('ITFDOC')
         BEGIN
            EXEC [WM].[lsp_WM_Print_ITFDoc_Wrapper]
               @n_WMReportRowID  = @n_RowID 
            ,  @c_Storerkey      = @c_Storerkey     
            ,  @c_Facility       = @c_Facility      
            ,  @c_UserName       = @c_UserName
            ,  @n_Noofcopy       = @n_Noofcopy                                      --(Wan07)            
            ,  @c_PrinterID      = @c_Printer     
            ,  @c_IsPaperPrinter = @c_IsPaperPrinter
            ,  @n_Noofparms      = @n_Noofparms     
            ,  @c_Parm1          = @c_Parm1         
            ,  @c_Parm2          = @c_Parm2         
            ,  @c_Parm3          = @c_Parm3         
            ,  @c_Parm4          = @c_Parm4         
            ,  @c_Parm5          = @c_Parm5         
            ,  @c_Parm6          = @c_Parm6         
            ,  @c_Parm7          = @c_Parm7         
            ,  @c_Parm8          = @c_Parm8         
            ,  @c_Parm9          = @c_Parm9         
            ,  @c_Parm10         = @c_Parm10               
            ,  @c_Parm11         = @c_Parm11        
            ,  @c_Parm12         = @c_Parm12        
            ,  @c_Parm13         = @c_Parm13        
            ,  @c_Parm14         = @c_Parm14       
            ,  @c_Parm15         = @c_Parm15          
            ,  @c_Parm16         = @c_Parm16          
            ,  @c_Parm17         = @c_Parm17          
            ,  @c_Parm18         = @c_Parm18          
            ,  @c_Parm19         = @c_Parm19          
            ,  @c_Parm20         = @c_Parm20          
            ,  @b_Success        = @b_Success         OUTPUT
            ,  @n_Err            = @n_Err             OUTPUT
            ,  @c_ErrMsg         = @c_ErrMsg          OUTPUT
            IF @b_Success = 0 AND @b_PrintNextOnFail = 0                            --(Wan08)
            BEGIN
               SET @n_Continue = 3
               GOTO EXIT_SP
            END
            GOTO NEXT_REC
         END
         --(Wan06) - END
         --(Wan08) - START
         IF @c_PrintType IN ('ZPL')
         BEGIN
            EXEC [WM].[lsp_WM_Print_ZPL_Wrapper]
               @n_WMReportRowID  = @n_RowID 
            ,  @c_Storerkey      = @c_Storerkey     
            ,  @c_Facility       = @c_Facility      
            ,  @c_UserName       = @c_UserName
            ,  @n_Noofcopy       = @n_Noofcopy                                                   
            ,  @c_PrinterID      = @c_Printer     
            ,  @c_IsPaperPrinter = @c_IsPaperPrinter
            ,  @n_Noofparms      = @n_Noofparms     
            ,  @c_Parm1          = @c_Parm1         
            ,  @c_Parm2          = @c_Parm2         
            ,  @c_Parm3          = @c_Parm3         
            ,  @c_Parm4          = @c_Parm4         
            ,  @c_Parm5          = @c_Parm5         
            ,  @c_Parm6          = @c_Parm6         
            ,  @c_Parm7          = @c_Parm7         
            ,  @c_Parm8          = @c_Parm8         
            ,  @c_Parm9          = @c_Parm9         
            ,  @c_Parm10         = @c_Parm10               
            ,  @c_Parm11         = @c_Parm11        
            ,  @c_Parm12         = @c_Parm12        
            ,  @c_Parm13         = @c_Parm13        
            ,  @c_Parm14         = @c_Parm14       
            ,  @c_Parm15         = @c_Parm15          
            ,  @c_Parm16         = @c_Parm16          
            ,  @c_Parm17         = @c_Parm17          
            ,  @c_Parm18         = @c_Parm18          
            ,  @c_Parm19         = @c_Parm19          
            ,  @c_Parm20         = @c_Parm20          
            ,  @b_Success        = @b_Success         OUTPUT
            ,  @n_Err            = @n_Err             OUTPUT
            ,  @c_ErrMsg         = @c_ErrMsg          OUTPUT
            IF @b_Success = 0 AND @b_PrintNextOnFail = 0                            
            BEGIN
               SET @n_Continue = 3
               GOTO EXIT_SP
            END
            GOTO NEXT_REC
         END
         IF @c_PrintType IN ('TPPRINT')
         BEGIN
            EXEC [WM].[lsp_WM_Print_TPPrint_Wrapper]
               @n_WMReportRowID  = @n_RowID 
            ,  @c_Storerkey      = @c_Storerkey     
            ,  @c_Facility       = @c_Facility      
            ,  @c_UserName       = @c_UserName
            ,  @n_Noofcopy       = @n_Noofcopy                                                   
            ,  @c_PrinterID      = @c_Printer     
            ,  @c_IsPaperPrinter = @c_IsPaperPrinter
            ,  @n_Noofparms      = @n_Noofparms     
            ,  @c_Parm1          = @c_Parm1         
            ,  @c_Parm2          = @c_Parm2         
            ,  @c_Parm3          = @c_Parm3         
            ,  @c_Parm4          = @c_Parm4         
            ,  @c_Parm5          = @c_Parm5         
            ,  @c_Parm6          = @c_Parm6         
            ,  @c_Parm7          = @c_Parm7         
            ,  @c_Parm8          = @c_Parm8         
            ,  @c_Parm9          = @c_Parm9         
            ,  @c_Parm10         = @c_Parm10               
            ,  @c_Parm11         = @c_Parm11        
            ,  @c_Parm12         = @c_Parm12        
            ,  @c_Parm13         = @c_Parm13        
            ,  @c_Parm14         = @c_Parm14       
            ,  @c_Parm15         = @c_Parm15          
            ,  @c_Parm16         = @c_Parm16          
            ,  @c_Parm17         = @c_Parm17          
            ,  @c_Parm18         = @c_Parm18          
            ,  @c_Parm19         = @c_Parm19          
            ,  @c_Parm20         = @c_Parm20          
            ,  @b_Success        = @b_Success         OUTPUT
            ,  @n_Err            = @n_Err             OUTPUT
            ,  @c_ErrMsg         = @c_ErrMsg          OUTPUT
            IF @b_Success = 0 AND @b_PrintNextOnFail = 0                            
            BEGIN
               SET @n_Continue = 3
               GOTO EXIT_SP
            END
            GOTO NEXT_REC
         END
         --(Wan08) - END
         IF @c_PrintMethod = 'WM' OR @c_PrintType NOT IN ( 'LOGIREPORT' )    --2020-08-24 Change WebPrint to JREport
         BEGIN
            --IF ISNULL(@c_PrintData,'') <> ''
            --BEGIN
            --   SET @c_ReportTemplate = ''
            --END
            SET @n_JobID = 0                       --(Wan03)
            BEGIN TRY
               EXEC [WM].[lsp_WM_SendPrintJobToProcessApp] 
                  @c_ReportID       = @c_ReportID      
               ,  @c_ReportLineNo   = @c_ReportLineNo  
               ,  @c_Storerkey      = @c_Storerkey     
               ,  @c_Facility       = @c_Facility      
               ,  @n_NoOfParms      = @n_NoOfParms     
               ,  @c_Parm1          = @c_Parm1       
               ,  @c_Parm2          = @c_Parm2       
               ,  @c_Parm3          = @c_Parm3       
               ,  @c_Parm4          = @c_Parm4       
               ,  @c_Parm5          = @c_Parm5       
               ,  @c_Parm6          = @c_Parm6       
               ,  @c_Parm7          = @c_Parm7       
               ,  @c_Parm8          = @c_Parm8       
               ,  @c_Parm9          = @c_Parm9       
               ,  @c_Parm10         = @c_Parm10
               ,  @c_Parm11         = @c_Parm11  
               ,  @c_Parm12         = @c_Parm12  
               ,  @c_Parm13         = @c_Parm13   
               ,  @c_Parm14         = @c_Parm14   
               ,  @c_Parm15         = @c_Parm15   
               ,  @c_Parm16         = @c_Parm16   
               ,  @c_Parm17         = @c_Parm17   
               ,  @c_Parm18         = @c_Parm18   
               ,  @c_Parm19         = @c_Parm19   
               ,  @c_Parm20         = @c_Parm20           
               ,  @n_Noofcopy       = @n_Noofcopy       
               ,  @c_PrinterID      = @c_PrinterID      
               ,  @c_IsPaperPrinter = @c_IsPaperPrinter 
               ,  @c_ReportTemplate = @c_ReportTemplate
               ,  @c_PrintData      = ''      
               ,  @c_PrintType      = @c_PrintType      
               ,  @c_UserName       = @c_UserName       
               ,  @b_SCEPreView     = @b_SCEPreView       
               ,  @n_JobID          = @n_JobID           OUTPUT   
               ,  @b_success        = @b_success         OUTPUT 
               ,  @n_err            = @n_err             OUTPUT 
               ,  @c_errmsg         = @c_errmsg          OUTPUT
            END TRY
            BEGIN CATCH
               SET @n_err = 552655
               SET @c_ErrMsg = ERROR_MESSAGE()
               SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Error Executing lsp_SendPrintJobToPrintApp. (lsp_WM_Print_Report)'
                             + '( ' + @c_errmsg + ' )'
            END CATCH
            IF (@b_Success = 0 OR @n_Err <> 0) AND @b_PrintNextOnFail = 0                          --(Wan08)
            BEGIN
               SET @n_Continue=3 
               SET @c_errmsg = @c_errmsg
               GOTO EXIT_SP 
            END
            IF @c_JobIDs <> '' SET @c_JobIDs = @c_JobIDs + '|'          --(Wan03)
            SET @c_JobIDs = @c_JobIDs + CONVERT(NVARCHAR(10),@n_JobID)  --(Wan03)
            GOTO NEXT_REC
         END
         NEXT_REC:
         --WL04 S
         IF @b_ContinuePrint = 1 AND ISNULL(@c_PrintSP_STD,'') <> ''
         BEGIN
            IF EXISTS (SELECT 1 FROM sysobjects o WHERE id = OBJECT_ID(@c_PrintSP_STD + 'Post_Std')  AND TYPE = 'P')
            BEGIN
               SET @c_SQL  = 'EXECUTE ' + @c_PrintSP_STD + 'Post_Std' 
                           + ' @n_WMReportRowID = @n_RowID'
                           + ',@c_UserName      = @c_UserName '
                           + ',@c_Parm1         = @c_Parm1           OUTPUT '              
                           + ',@c_Parm2         = @c_Parm2           OUTPUT '              
                           + ',@c_Parm3         = @c_Parm3           OUTPUT '              
                           + ',@c_Parm4         = @c_Parm4           OUTPUT '              
                           + ',@c_Parm5         = @c_Parm5           OUTPUT '              
                           + ',@c_Parm6         = @c_Parm6           OUTPUT '              
                           + ',@c_Parm7         = @c_Parm7           OUTPUT '              
                           + ',@c_Parm8         = @c_Parm8           OUTPUT '              
                           + ',@c_Parm9         = @c_Parm9           OUTPUT '              
                           + ',@c_Parm10        = @c_Parm10          OUTPUT '              
                           + ',@c_Parm11        = @c_Parm11          OUTPUT '              
                           + ',@c_Parm12        = @c_Parm12          OUTPUT '              
                           + ',@c_Parm13        = @c_Parm13          OUTPUT '              
                           + ',@c_Parm14        = @c_Parm14          OUTPUT '              
                           + ',@c_Parm15        = @c_Parm15          OUTPUT '              
                           + ',@c_Parm16        = @c_Parm16          OUTPUT '              
                           + ',@c_Parm17        = @c_Parm17          OUTPUT '              
                           + ',@c_Parm18        = @c_Parm18          OUTPUT '              
                           + ',@c_Parm19        = @c_Parm19          OUTPUT '              
                           + ',@c_Parm20        = @c_Parm20          OUTPUT '  
                           + ',@n_Noofparms     = @n_Noofparms       OUTPUT '              
                           + ',@b_ContinuePrint = @b_ContinuePrint   OUTPUT '    --1/0     
                           + ',@n_NoOfCopy      = @n_NoOfCopy        OUTPUT '              
                           + ',@c_PrinterID     = @c_Printer         OUTPUT '              
                           + ',@c_PrintData     = @c_PrintData       OUTPUT '  
                           + ',@b_Success       = @b_Success         OUTPUT '
                           + ',@n_Err           = @n_Err             OUTPUT '
                           + ',@c_ErrMsg        = @c_ErrMsg          OUTPUT ' 
                           + ',@c_PrintSource   = @c_PrintSource '  
                           + ',@b_SCEPreView    = @b_SCEPreView  '
                           + ',@n_JobID         = @n_JobID           OUTPUT '
                 SET @c_SQLParms= N'@n_RowID       BIGINT '
                              + ',@c_UserName      NVARCHAR(128) '          
                              + ',@c_Parm1         NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm2         NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm3         NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm4         NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm5         NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm6         NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm7         NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm8         NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm9         NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm10        NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm11        NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm12        NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm13        NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm14        NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm15        NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm16        NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm17        NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm18        NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm19        NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm20        NVARCHAR(60)   OUTPUT ' 
                              + ',@n_Noofparms     INT            OUTPUT '            
                              + ',@b_ContinuePrint BIT            OUTPUT '    --1/0  
                              + ',@n_NoOfCopy      INT            OUTPUT '           
                              + ',@c_Printer       NVARCHAR(30)   OUTPUT '           
                              + ',@c_PrintData     NVARCHAR(4000) OUTPUT '  
                              + ',@b_Success       INT            OUTPUT '
                              + ',@n_Err           INT            OUTPUT '
                              + ',@c_ErrMsg        NVARCHAR(255)  OUTPUT ' 
                              + ',@c_PrintSource   NVARCHAR(10) '  
                              + ',@b_SCEPreView    INT '
                              + ',@n_JobID         INT            OUTPUT '                                       
               EXEC sp_ExecuteSQL @c_SQL
                                 ,@c_SQLParms
                                 ,@n_RowID 
                                 ,@c_UserName
                                 ,@c_Parm1         OUTPUT           
                                 ,@c_Parm2         OUTPUT            
                                 ,@c_Parm3         OUTPUT          
                                 ,@c_Parm4         OUTPUT         
                                 ,@c_Parm5         OUTPUT          
                                 ,@c_Parm6         OUTPUT            
                                 ,@c_Parm7         OUTPUT          
                                 ,@c_Parm8         OUTPUT            
                                 ,@c_Parm9         OUTPUT            
                                 ,@c_Parm10        OUTPUT
                                 ,@c_Parm11        OUTPUT           
                                 ,@c_Parm12        OUTPUT            
                                 ,@c_Parm13        OUTPUT          
                                 ,@c_Parm14        OUTPUT         
                                 ,@c_Parm15        OUTPUT          
                                 ,@c_Parm16        OUTPUT            
                                 ,@c_Parm17        OUTPUT          
                                 ,@c_Parm18        OUTPUT            
                                 ,@c_Parm19        OUTPUT            
                                 ,@c_Parm20        OUTPUT
                                 ,@n_Noofparms     OUTPUT
                                 ,@b_ContinuePrint OUTPUT      --1/0
                                 ,@n_NoOfCopy      OUTPUT
                                 ,@c_Printer       OUTPUT
                                 ,@c_PrintData     OUTPUT
                                 ,@b_Success       OUTPUT 
                                 ,@n_Err           OUTPUT  
                                 ,@c_ErrMsg        OUTPUT  
                                 ,@c_PrintSource      
                                 ,@b_SCEPreView
                                 ,@n_JobID        OUTPUT
               IF @b_Success <> 1
               BEGIN
                  SET @n_Continue=3 
                  SET @n_Err    = 552659
                  SET @c_Errmsg = 'NSQL' + CONVERT(NCHAR(6), @n_Err) 
                                 + ': Error Executing Standard Post-Print SP:' + TRIM(@c_PrintSP_STD + 'Post_Std')
                                 + ' (lsp_WM_Print_Report) ( ' + @c_errmsg + ' )' 
                                 + ' |' + TRIM(@c_PrintSP_STD + 'Post_Std')
                  GOTO EXIT_SP 
               END
            END     
         END
         --WL04 E
         --WL03 S
         IF @b_ContinuePrint = 1 AND @c_PostPrintSP <> ''
         BEGIN
            IF EXISTS (SELECT 1 FROM sysobjects o WHERE id = OBJECT_ID(@c_PostPrintSP)  AND TYPE = 'P')
            BEGIN
               SET @c_SQL  = 'EXECUTE ' + @c_PostPrintSP 
                           + ' @n_WMReportRowID = @n_RowID'
                           + ',@c_UserName      = @c_UserName '
                           + ',@c_Parm1         = @c_Parm1           OUTPUT '              
                           + ',@c_Parm2         = @c_Parm2           OUTPUT '              
                           + ',@c_Parm3         = @c_Parm3           OUTPUT '              
                           + ',@c_Parm4         = @c_Parm4           OUTPUT '              
                           + ',@c_Parm5         = @c_Parm5           OUTPUT '              
                           + ',@c_Parm6         = @c_Parm6           OUTPUT '              
                           + ',@c_Parm7         = @c_Parm7           OUTPUT '              
                           + ',@c_Parm8         = @c_Parm8           OUTPUT '              
                           + ',@c_Parm9         = @c_Parm9           OUTPUT '              
                           + ',@c_Parm10        = @c_Parm10          OUTPUT '              
                           + ',@c_Parm11        = @c_Parm11          OUTPUT '              
                           + ',@c_Parm12        = @c_Parm12          OUTPUT '              
                           + ',@c_Parm13        = @c_Parm13          OUTPUT '              
                           + ',@c_Parm14        = @c_Parm14          OUTPUT '              
                           + ',@c_Parm15        = @c_Parm15          OUTPUT '              
                           + ',@c_Parm16        = @c_Parm16          OUTPUT '              
                           + ',@c_Parm17        = @c_Parm17          OUTPUT '              
                           + ',@c_Parm18        = @c_Parm18          OUTPUT '              
                           + ',@c_Parm19        = @c_Parm19          OUTPUT '              
                           + ',@c_Parm20        = @c_Parm20          OUTPUT '  
                           + ',@n_Noofparms     = @n_Noofparms       OUTPUT '              
                           + ',@b_ContinuePrint = @b_ContinuePrint   OUTPUT '    --1/0     
                           + ',@n_NoOfCopy      = @n_NoOfCopy        OUTPUT '              
                           + ',@c_PrinterID     = @c_Printer         OUTPUT '              
                           + ',@c_PrintData     = @c_PrintData       OUTPUT '  
                           + ',@b_Success       = @b_Success         OUTPUT '
                           + ',@n_Err           = @n_Err             OUTPUT '
                           + ',@c_ErrMsg        = @c_ErrMsg          OUTPUT ' 
                           + ',@c_PrintSource   = @c_PrintSource '  
                           + ',@b_SCEPreView    = @b_SCEPreView  '
                           + ',@n_JobID         = @n_JobID           OUTPUT '
                 SET @c_SQLParms= N'@n_RowID       BIGINT '
                              + ',@c_UserName      NVARCHAR(128) '          
                              + ',@c_Parm1         NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm2         NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm3         NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm4         NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm5         NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm6         NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm7         NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm8         NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm9         NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm10        NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm11        NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm12        NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm13        NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm14        NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm15        NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm16        NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm17        NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm18        NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm19        NVARCHAR(60)   OUTPUT '           
                              + ',@c_Parm20        NVARCHAR(60)   OUTPUT ' 
                              + ',@n_Noofparms     INT            OUTPUT '            
                              + ',@b_ContinuePrint BIT            OUTPUT '    --1/0  
                              + ',@n_NoOfCopy      INT            OUTPUT '           
                              + ',@c_Printer       NVARCHAR(30)   OUTPUT '           
                              + ',@c_PrintData     NVARCHAR(4000) OUTPUT '  
                              + ',@b_Success       INT            OUTPUT '
                              + ',@n_Err           INT            OUTPUT '
                              + ',@c_ErrMsg        NVARCHAR(255)  OUTPUT ' 
                              + ',@c_PrintSource   NVARCHAR(10) '  
                              + ',@b_SCEPreView    INT '
                              + ',@n_JobID         INT            OUTPUT '                                       
               EXEC sp_ExecuteSQL @c_SQL
                                 ,@c_SQLParms
                                 ,@n_RowID 
                                 ,@c_UserName
                                 ,@c_Parm1         OUTPUT           
                                 ,@c_Parm2         OUTPUT            
                                 ,@c_Parm3         OUTPUT          
                                 ,@c_Parm4         OUTPUT         
                                 ,@c_Parm5         OUTPUT          
                                 ,@c_Parm6         OUTPUT            
                                 ,@c_Parm7         OUTPUT          
                                 ,@c_Parm8         OUTPUT            
                                 ,@c_Parm9         OUTPUT            
                                 ,@c_Parm10        OUTPUT
                                 ,@c_Parm11        OUTPUT           
                                 ,@c_Parm12        OUTPUT            
                                 ,@c_Parm13        OUTPUT          
                                 ,@c_Parm14        OUTPUT         
                                 ,@c_Parm15        OUTPUT          
                                 ,@c_Parm16        OUTPUT            
                                 ,@c_Parm17        OUTPUT          
                                 ,@c_Parm18        OUTPUT            
                                 ,@c_Parm19        OUTPUT            
                                 ,@c_Parm20        OUTPUT
                                 ,@n_Noofparms     OUTPUT
                                 ,@b_ContinuePrint OUTPUT      --1/0
                                 ,@n_NoOfCopy      OUTPUT
                                 ,@c_Printer       OUTPUT
                                 ,@c_PrintData     OUTPUT
                                 ,@b_Success       OUTPUT 
                                 ,@n_Err           OUTPUT  
                                 ,@c_ErrMsg        OUTPUT  
                                 ,@c_PrintSource      
                                 ,@b_SCEPreView
                                 ,@n_JobID        OUTPUT
               IF @b_Success <> 1
               BEGIN
                  SET @n_Continue=3 
                  SET @n_Err    = 552657
                  SET @c_Errmsg = 'NSQL' + CONVERT(NCHAR(6), @n_Err) 
                                 + ': Error Executing Post-Print SP:' + RTRIM(@c_PostPrintSP) 
                                 + ' (lsp_WM_Print_Report) ( ' + @c_errmsg + ' )' 
                                 + ' |' + RTRIM(@c_PostPrintSP) 
                  GOTO EXIT_SP 
               END
            END     
         END
         --WL03 E
         SET @c_PrintGroup_Last = @c_PrintGroup
         FETCH NEXT FROM @CUR_GROUP INTO @n_RowID
                                       , @c_ReportLineNo
                                       , @c_PrintGroup
                                       , @c_PrintType
                                       , @c_ReportTemplate
                                       , @c_CriteriaMatching01
                                       , @c_CriteriaMatching02
                                       , @c_CriteriaMatching03
                                       , @c_CriteriaMatching04
                                       , @c_CriteriaMatching05
                                       , @c_PreprintSP
                                       , @c_PreGenRptData_SP                        --(Wan05)
                                       , @c_PostPrintSP                             --WL03                                       
                                       , @c_DefaultPrinterID                        --(Wan08)                                       
                                       , @c_IsPaperPrinter                          --(Wan08)
                                       , @b_PrintNextOnFail                         --(Wan08) 
                                       , @c_PrintSP_STD                             --WL04
      END 
      CLOSE @CUR_GROUP
      DEALLOCATE @CUR_GROUP
      --(Wan01) - START
      IF EXISTS (SELECT 1 FROM @RPTURL)
      BEGIN
         SELECT RowNo, ReportID, DetailRowID, Report_URL FROM @RPTURL
      END
      --(Wan01) - END
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
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_WM_Print_Report'
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
   REVERT
   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END -- procedure

GO