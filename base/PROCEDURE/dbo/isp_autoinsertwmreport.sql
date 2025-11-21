SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/  
/* Stored Proc : isp_AutoInsertWMReport                                    */  
/* Creation Date: 08-Jun-2022                                              */  
/* Copyright: MAERSK                                                       */  
/* Written by: WLChooi                                                     */  
/*                                                                         */  
/* Purpose: Auto Insert WMReport & WMReportdetail based on input param     */  
/*                                                                         */  
/* Called By:                                                              */  
/*                                                                         */  
/* PVCS Version: 1.6                                                       */  
/*                                                                         */  
/* Version: 5.4                                                            */  
/*                                                                         */  
/* Data Modifications:                                                     */  
/*                                                                         */  
/* Updates:                                                                */  
/* Date        Author      Ver   Purposes                                  */
/* 08-Jun-2022 WLChooi     1.0   DevOps Combine Script                     */  
/* 27-Jul-2022 WLChooi     1.1   Enhancement (WL01)                        */
/* 14-Sep-2022 WLChooi     1.2   Add more fields (WL02)                    */
/* 15-May-2023 WLChooi     1.3   Extend size (WL03)                        */
/* 26-Jun-2023 WLChooi     1.4   Update ReportTemplate (WL04)              */
/* 16-Nov-2023 WLChooi     1.5   Support insert Bartender (WL05)           */
/* 08-Dec-2023 WLChooi     1.6   Update WMReport (WL06)                    */
/***************************************************************************/  
  
CREATE   PROC [dbo].[isp_AutoInsertWMReport] (
        @c_ModuleName            NVARCHAR(50)   --WL03
      , @c_ReportType            NVARCHAR(20) 
      , @c_Storerkey             NVARCHAR(15) = ''
      , @c_ReportTitle           NVARCHAR(60) = ''
      , @c_TemplateName          NVARCHAR(60) 
      , @c_PrintType             NVARCHAR(20) 
      , @c_ReportCatalog         NVARCHAR(500) = ''
      , @c_PrePrintSP            NVARCHAR(200) = ''
      , @c_PreGenRptData         NVARCHAR(200) = ''
      , @c_CreateDetail          NVARCHAR(10) = 'Y'
      , @n_NoOfKeyFieldParms     INT = 0
      , @c_KeyFieldName1         NVARCHAR(200) = ''
      , @c_KeyFieldName2         NVARCHAR(200) = ''
      , @c_KeyFieldName3         NVARCHAR(200) = ''
      , @c_KeyFieldName4         NVARCHAR(200) = ''
      , @c_KeyFieldName5         NVARCHAR(200) = ''
      , @c_KeyFieldName6         NVARCHAR(200) = ''
      , @c_KeyFieldName7         NVARCHAR(200) = ''
      , @c_KeyFieldName8         NVARCHAR(200) = ''
      , @c_KeyFieldName9         NVARCHAR(200) = ''
      , @c_KeyFieldName10        NVARCHAR(200) = ''
      , @c_KeyFieldName11        NVARCHAR(200) = ''
      , @c_KeyFieldName12        NVARCHAR(200) = ''
      , @c_KeyFieldName13        NVARCHAR(200) = ''
      , @c_KeyFieldName14        NVARCHAR(200) = ''
      , @c_KeyFieldName15        NVARCHAR(200) = ''
      , @c_ExtendedParm1         NVARCHAR(200) = ''
      , @c_ExtendedParm2         NVARCHAR(200) = ''
      , @c_ExtendedParm3         NVARCHAR(200) = ''
      , @c_ExtendedParm4         NVARCHAR(200) = ''
      , @c_ExtendedParm5         NVARCHAR(200) = ''
      , @c_KeyFieldParmLabel1    NVARCHAR(200) = ''   --WL02
      , @c_KeyFieldParmLabel2    NVARCHAR(200) = ''   --WL02
      , @c_KeyFieldParmLabel3    NVARCHAR(200) = ''   --WL02
      , @c_KeyFieldParmLabel4    NVARCHAR(200) = ''   --WL02
      , @c_KeyFieldParmLabel5    NVARCHAR(200) = ''   --WL02
      , @c_KeyFieldParmLabel6    NVARCHAR(200) = ''   --WL02
      , @c_KeyFieldParmLabel7    NVARCHAR(200) = ''   --WL02
      , @c_KeyFieldParmLabel8    NVARCHAR(200) = ''   --WL02
      , @c_KeyFieldParmLabel9    NVARCHAR(200) = ''   --WL02
      , @c_KeyFieldParmLabel10   NVARCHAR(200) = ''   --WL02
      , @c_KeyFieldParmLabel11   NVARCHAR(200) = ''   --WL02
      , @c_KeyFieldParmLabel12   NVARCHAR(200) = ''   --WL02
      , @c_KeyFieldParmLabel13   NVARCHAR(200) = ''   --WL02
      , @c_KeyFieldParmLabel14   NVARCHAR(200) = ''   --WL02
      , @c_KeyFieldParmLabel15   NVARCHAR(200) = ''   --WL02
      , @c_ReportParmName1       NVARCHAR(100) = ''
      , @c_ReportParmName2       NVARCHAR(100) = ''
      , @c_ReportParmName3       NVARCHAR(100) = ''
      , @c_ReportParmName4       NVARCHAR(100) = ''
      , @c_ReportParmName5       NVARCHAR(100) = ''
      , @c_ReportParmName6       NVARCHAR(100) = ''
      , @c_ReportParmName7       NVARCHAR(100) = ''
      , @c_ReportParmName8       NVARCHAR(100) = ''
      , @c_ReportParmName9       NVARCHAR(100) = ''
      , @c_ReportParmName10      NVARCHAR(100) = ''
      , @c_ReportParmName11      NVARCHAR(100) = ''
      , @c_ReportParmName12      NVARCHAR(100) = ''
      , @c_ReportParmName13      NVARCHAR(100) = ''
      , @c_ReportParmName14      NVARCHAR(100) = ''
      , @c_ReportParmName15      NVARCHAR(100) = ''
      , @c_ReportParmName16      NVARCHAR(100) = ''
      , @c_ReportParmName17      NVARCHAR(100) = ''
      , @c_ReportParmName18      NVARCHAR(100) = ''
      , @c_ReportParmName19      NVARCHAR(100) = ''
      , @c_ReportParmName20      NVARCHAR(100) = ''
      , @c_ReportLineDesc        NVARCHAR(60) = ''
      , @c_ExtendedParmDefault1  NVARCHAR(200) = ''   --WL06
      , @c_ExtendedParmDefault2  NVARCHAR(200) = ''   --WL06
      , @c_ExtendedParmDefault3  NVARCHAR(200) = ''   --WL06
      , @c_ExtendedParmDefault4  NVARCHAR(200) = ''   --WL06
      , @c_ExtendedParmDefault5  NVARCHAR(200) = ''   --WL06
)
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @c_JReportDefaultCatalog       NVARCHAR(100)
         , @c_JReportDefaultReportFolder  NVARCHAR(100)
         , @n_MaxReportID                 BIGINT = 0
         , @c_ReportID                    NVARCHAR(10) = ''
         , @c_WMDRptLineNo                NVARCHAR(10) = ''
         , @c_MessageOut                  NVARCHAR(4000) = ''
         , @c_WMFlag                      NVARCHAR(1) = 'N'
         , @c_WMDETFlag                   NVARCHAR(1) = 'N'
         , @c_CurrentReportLine           NVARCHAR(5)
         , @n_CurrentRow                  INT
         , @n_Continue                    INT = 1
   
   IF ISNULL(@c_Storerkey,'') = ''
   BEGIN
      SET @n_Continue = 3
      SET @c_MessageOut = 'Storerkey is empty!'
   END

   IF @n_Continue IN (1,2)   --WL05
   BEGIN
      IF ISNULL(@c_ReportTitle,'') = ''
         SET @c_ReportTitle = @c_ReportType + ' - '
      
      --WL05 S
      IF @c_PrintType = 'LOGIREPORT'
      BEGIN
         SELECT @c_JReportDefaultCatalog = REPLACE(ISNULL(NSQLDescrip,''),'WMS','WMGIT') 
         FROM dbo.NSQLCONFIG N (NOLOCK) 
         WHERE N.ConfigKey = 'JReportDefaultCatalog'
         
         SELECT @c_JReportDefaultReportFolder = ISNULL(NSQLDescrip,'') 
         FROM dbo.NSQLCONFIG N (NOLOCK) 
         WHERE N.ConfigKey = 'JReportDefaultReportFolder'
         
         IF ISNULL(@c_ReportCatalog,'') = ''
            SET @c_ReportCatalog = TRIM(@c_JReportDefaultReportFolder) + TRIM(@c_JReportDefaultCatalog)
         
         IF RIGHT(TRIM(@c_TemplateName), 4) <> '.cls'
            SET @c_TemplateName = TRIM(@c_TemplateName) + '.cls'
      END
      --WL05 E

      --Main Process
      --WL06 S 
      ;WITH CTE AS (
         SELECT MIN(ReportId) AS ReportID, 1 AS Sorting                         
         FROM WMREPORT WITH (NOLOCK)  
         WHERE ReportType = @c_ReportType   
         AND ModuleID = @c_ModuleName 
         --Scenario where ReportType and KeyFieldNameXX are blank
         UNION ALL
         SELECT MIN(ReportId) AS ReportID, 2 AS Sorting                         
         FROM WMREPORT WITH (NOLOCK)  
         WHERE ReportTitle LIKE @c_ReportType + '%'
         AND ReportType = ''
         AND ModuleID = @c_ModuleName 
      )
      SELECT TOP 1 @c_ReportID = CTE.ReportID
      FROM CTE
      WHERE ISNULL(CTE.ReportID, '') <> ''
      ORDER BY CTE.Sorting ASC
      --WL06 E

      IF ISNULL(@c_ReportID,'') = ''
      BEGIN
         SELECT TOP 1 @n_MaxReportID = RIGHT(REPORTID,9)   
         FROM WMREPORT W (NOLOCK)   
         WHERE LEFT(REPORTID,1) = 'R'  
         AND ISNUMERIC(RIGHT(REPORTID,9)) = 1  
         ORDER BY RIGHT(REPORTID,9) DESC  
      
         SET @n_MaxReportID = @n_MaxReportID + 1  
         SET @c_ReportID = 'R' + RIGHT('000000000' + CONVERT(NVARCHAR(9), @n_MaxReportID),9)   --WL02 
      
         INSERT INTO dbo.WMREPORT
         (
             ReportID, ReportTitle, ModuleID, PrintMethod, ReportType, NoOfKeyFieldParms,
             KeyFieldName1, KeyFieldName2, KeyFieldName3, KeyFieldName4, KeyFieldName5, KeyFieldName6, KeyFieldName7, KeyFieldName8, KeyFieldName9, KeyFieldName10,
             KeyFieldName11, KeyFieldName12, KeyFieldName13, KeyFieldName14, KeyFieldName15, ExtendedParm1, ExtendedParm2, ExtendedParm3, ExtendedParm4, ExtendedParm5,
             KeyFieldParmLabel1, KeyFieldParmLabel2, KeyFieldParmLabel3, KeyFieldParmLabel4, KeyFieldParmLabel5,        --WL02
             KeyFieldParmLabel6, KeyFieldParmLabel7, KeyFieldParmLabel8, KeyFieldParmLabel9, KeyFieldParmLabel10,       --WL02
             KeyFieldParmLabel11, KeyFieldParmLabel12, KeyFieldParmLabel13, KeyFieldParmLabel14, KeyFieldParmLabel15,   --WL02
             ExtendedParmDefault1, ExtendedParmDefault2, ExtendedParmDefault3, ExtendedParmDefault4, ExtendedParmDefault5   --WL06
         )
         SELECT @c_ReportID, @c_ReportTitle, @c_ModuleName, N'WM', @c_ReportType, @n_NoOfKeyFieldParms,
                @c_KeyFieldName1, @c_KeyFieldName2, @c_KeyFieldName3, @c_KeyFieldName4, @c_KeyFieldName5, @c_KeyFieldName6, @c_KeyFieldName7, @c_KeyFieldName8, @c_KeyFieldName9, @c_KeyFieldName10,
                @c_KeyFieldName11, @c_KeyFieldName12, @c_KeyFieldName13, @c_KeyFieldName14, @c_KeyFieldName15, @c_ExtendedParm1, @c_ExtendedParm2, @c_ExtendedParm3, @c_ExtendedParm4, @c_ExtendedParm5
              , @c_KeyFieldParmLabel1    --WL02
              , @c_KeyFieldParmLabel2    --WL02
              , @c_KeyFieldParmLabel3    --WL02
              , @c_KeyFieldParmLabel4    --WL02
              , @c_KeyFieldParmLabel5    --WL02
              , @c_KeyFieldParmLabel6    --WL02
              , @c_KeyFieldParmLabel7    --WL02
              , @c_KeyFieldParmLabel8    --WL02
              , @c_KeyFieldParmLabel9    --WL02
              , @c_KeyFieldParmLabel10   --WL02
              , @c_KeyFieldParmLabel11   --WL02
              , @c_KeyFieldParmLabel12   --WL02
              , @c_KeyFieldParmLabel13   --WL02
              , @c_KeyFieldParmLabel14   --WL02
              , @c_KeyFieldParmLabel15   --WL02
              , @c_ExtendedParmDefault1  --WL06
              , @c_ExtendedParmDefault2  --WL06
              , @c_ExtendedParmDefault3  --WL06
              , @c_ExtendedParmDefault4  --WL06
              , @c_ExtendedParmDefault5  --WL06
      
         SET @c_WMDRptLineNo = '00000'
         SET @c_WMFlag = 'Y'
      END
      ELSE
      BEGIN
         SELECT TOP 1 @c_WMDRptLineNo = ReportLineNo
         FROM  WMREPORTDETAIL WITH (NOLOCK)  
         WHERE ReportID = @c_ReportID  
         ORDER BY ReportLineNo DESC 

         --WL06 S
         UPDATE dbo.WMREPORT
         SET ReportTitle = @c_ReportTitle
           , ModuleID = @c_ModuleName
           , ReportType = @c_ReportType
           , NoOfKeyFieldParms = @n_NoOfKeyFieldParms
           , KeyFieldName1   = @c_KeyFieldName1
           , KeyFieldName2   = @c_KeyFieldName2
           , KeyFieldName3   = @c_KeyFieldName3
           , KeyFieldName4   = @c_KeyFieldName4
           , KeyFieldName5   = @c_KeyFieldName5
           , KeyFieldName6   = @c_KeyFieldName6
           , KeyFieldName7   = @c_KeyFieldName7
           , KeyFieldName8   = @c_KeyFieldName8
           , KeyFieldName9   = @c_KeyFieldName9
           , KeyFieldName10  = @c_KeyFieldName10
           , KeyFieldName11  = @c_KeyFieldName11
           , KeyFieldName12  = @c_KeyFieldName12
           , KeyFieldName13  = @c_KeyFieldName13
           , KeyFieldName14  = @c_KeyFieldName14
           , KeyFieldName15  = @c_KeyFieldName15 
           , ExtendedParm1 = @c_ExtendedParm1
           , ExtendedParm2 = @c_ExtendedParm2
           , ExtendedParm3 = @c_ExtendedParm3
           , ExtendedParm4 = @c_ExtendedParm4
           , ExtendedParm5 = @c_ExtendedParm5
           , KeyFieldParmLabel1  = @c_KeyFieldParmLabel1 
           , KeyFieldParmLabel2  = @c_KeyFieldParmLabel2 
           , KeyFieldParmLabel3  = @c_KeyFieldParmLabel3 
           , KeyFieldParmLabel4  = @c_KeyFieldParmLabel4 
           , KeyFieldParmLabel5  = @c_KeyFieldParmLabel5 
           , KeyFieldParmLabel6  = @c_KeyFieldParmLabel6 
           , KeyFieldParmLabel7  = @c_KeyFieldParmLabel7 
           , KeyFieldParmLabel8  = @c_KeyFieldParmLabel8 
           , KeyFieldParmLabel9  = @c_KeyFieldParmLabel9 
           , KeyFieldParmLabel10 = @c_KeyFieldParmLabel10
           , KeyFieldParmLabel11 = @c_KeyFieldParmLabel11
           , KeyFieldParmLabel12 = @c_KeyFieldParmLabel12
           , KeyFieldParmLabel13 = @c_KeyFieldParmLabel13
           , KeyFieldParmLabel14 = @c_KeyFieldParmLabel14
           , KeyFieldParmLabel15 = @c_KeyFieldParmLabel15
           , ExtendedParmDefault1 = @c_ExtendedParmDefault1
           , ExtendedParmDefault2 = @c_ExtendedParmDefault2
           , ExtendedParmDefault3 = @c_ExtendedParmDefault3
           , ExtendedParmDefault4 = @c_ExtendedParmDefault4
           , ExtendedParmDefault5 = @c_ExtendedParmDefault5
         WHERE ReportID = @c_ReportID

         SET @c_WMFlag = 'U'
         --WL06 E
      END

      --WL06 S
      IF @c_CreateDetail = 'Y'
      BEGIN
         --WL04 S
         IF EXISTS ( SELECT 1  
                     FROM WMREPORTDETAIL WITH (NOLOCK)  
                     WHERE ReportID = @c_ReportID  
                     AND Storerkey = @c_Storerkey
                     AND PrintType = 'LOGIReport' )
         BEGIN
            SELECT @n_CurrentRow =  WMREPORTDETAIL.RowID
            FROM WMREPORTDETAIL WITH (NOLOCK)  
            WHERE ReportID = @c_ReportID  
            AND  Storerkey = @c_Storerkey  
         
            UPDATE dbo.WMREPORTDETAIL
            SET    Storerkey        = @c_Storerkey
                 , PrintType        = @c_PrintType
                 , ReportTemplate   = @c_TemplateName
                 , ReportCatalog    = @c_ReportCatalog
                 , PrePrintSP       = @c_PrePrintSP
                 , PreGenRptDataSP  = @c_PreGenRptData
                 , ReportParmName1  = @c_ReportParmName1 
                 , ReportParmName2  = @c_ReportParmName2 
                 , ReportParmName3  = @c_ReportParmName3 
                 , ReportParmName4  = @c_ReportParmName4 
                 , ReportParmName5  = @c_ReportParmName5 
                 , ReportParmName6  = @c_ReportParmName6 
                 , ReportParmName7  = @c_ReportParmName7 
                 , ReportParmName8  = @c_ReportParmName8 
                 , ReportParmName9  = @c_ReportParmName9 
                 , ReportParmName10 = @c_ReportParmName10
                 , ReportParmName11 = @c_ReportParmName11
                 , ReportParmName12 = @c_ReportParmName12
                 , ReportParmName13 = @c_ReportParmName13
                 , ReportParmName14 = @c_ReportParmName14
                 , ReportParmName15 = @c_ReportParmName15
                 , ReportParmName16 = @c_ReportParmName16
                 , ReportParmName17 = @c_ReportParmName17
                 , ReportParmName18 = @c_ReportParmName18
                 , ReportParmName19 = @c_ReportParmName19
                 , ReportParmName20 = @c_ReportParmName20
                 , ReportLineDesc   = @c_ReportLineDesc
            WHERE RowID = @n_CurrentRow
            
            SET @c_WMDETFlag = 'U'
         END
         --WL04 E
         ELSE IF NOT EXISTS (  SELECT 1  
                               FROM WMREPORTDETAIL WITH (NOLOCK)  
                               WHERE ReportID = @c_ReportID  
                               AND  Storerkey = @c_Storerkey  
                               AND ReportTemplate = @c_TemplateName
                               AND ReportLineDesc = @c_ReportLineDesc
         ) --AND @c_CreateDetail = 'Y'   --WL06
         BEGIN
            SELECT @c_ReportTitle = MAX(ReportTitle)
            FROM  WMREPORTDETAIL WITH (NOLOCK)  
            WHERE ReportID = @c_ReportID  
         
            --WL01 S
            IF ISNULL(@c_ReportTitle,'') = ''
            BEGIN
               SELECT @c_ReportTitle = TRIM(W.ReportTitle)
               FROM WMREPORT W (NOLOCK)
               WHERE W.ReportID = @c_ReportID
            END
            --WL01 E
         
            SET @c_CurrentReportLine = RIGHT('00000' + CONVERT(NVARCHAR(5), CAST(@c_WMDRptLineNo AS INT) + 1) , 5)
         
            INSERT INTO dbo.WMREPORTDETAIL(ReportID, ReportLineNo, ReportTitle, Storerkey
                                         , PrintType, ReportTemplate, ReportCatalog, PrePrintSP, PreGenRptDataSP
                                         , ReportParmName1, ReportParmName2, ReportParmName3, ReportParmName4, ReportParmName5
                                         , ReportParmName6, ReportParmName7, ReportParmName8, ReportParmName9, ReportParmName10
                                         , ReportParmName11, ReportParmName12, ReportParmName13, ReportParmName14, ReportParmName15
                                         , ReportParmName16, ReportParmName17, ReportParmName18, ReportParmName19, ReportParmName20
                                         , ReportLineDesc)
            VALUES(@c_ReportID
                 , @c_CurrentReportLine
                 , @c_ReportTitle
                 , @c_Storerkey
                 , @c_PrintType
                 , @c_TemplateName
                 , @c_ReportCatalog
                 , @c_PrePrintSP
                 , @c_PreGenRptData
                 , @c_ReportParmName1 
                 , @c_ReportParmName2 
                 , @c_ReportParmName3 
                 , @c_ReportParmName4 
                 , @c_ReportParmName5 
                 , @c_ReportParmName6 
                 , @c_ReportParmName7 
                 , @c_ReportParmName8 
                 , @c_ReportParmName9 
                 , @c_ReportParmName10
                 , @c_ReportParmName11
                 , @c_ReportParmName12
                 , @c_ReportParmName13
                 , @c_ReportParmName14
                 , @c_ReportParmName15
                 , @c_ReportParmName16
                 , @c_ReportParmName17
                 , @c_ReportParmName18
                 , @c_ReportParmName19
                 , @c_ReportParmName20
                 , @c_ReportLineDesc
               )
            SET @c_WMDETFlag = 'Y'
         END
         ELSE
         BEGIN
            SELECT @n_CurrentRow =  WMREPORTDETAIL.RowID
            FROM WMREPORTDETAIL WITH (NOLOCK)  
            WHERE ReportID = @c_ReportID  
            AND  Storerkey = @c_Storerkey  
            AND ReportTemplate = @c_TemplateName
         
            UPDATE dbo.WMREPORTDETAIL
            SET    ReportTitle      = @c_ReportTitle
                 , Storerkey        = @c_Storerkey
                 , PrintType        = @c_PrintType
                 , ReportTemplate   = @c_TemplateName
                 , ReportCatalog    = @c_ReportCatalog
                 , PrePrintSP       = @c_PrePrintSP
                 , PreGenRptDataSP  = @c_PreGenRptData
                 , ReportParmName1  = @c_ReportParmName1 
                 , ReportParmName2  = @c_ReportParmName2 
                 , ReportParmName3  = @c_ReportParmName3 
                 , ReportParmName4  = @c_ReportParmName4 
                 , ReportParmName5  = @c_ReportParmName5 
                 , ReportParmName6  = @c_ReportParmName6 
                 , ReportParmName7  = @c_ReportParmName7 
                 , ReportParmName8  = @c_ReportParmName8 
                 , ReportParmName9  = @c_ReportParmName9 
                 , ReportParmName10 = @c_ReportParmName10
                 , ReportParmName11 = @c_ReportParmName11
                 , ReportParmName12 = @c_ReportParmName12
                 , ReportParmName13 = @c_ReportParmName13
                 , ReportParmName14 = @c_ReportParmName14
                 , ReportParmName15 = @c_ReportParmName15
                 , ReportParmName16 = @c_ReportParmName16
                 , ReportParmName17 = @c_ReportParmName17
                 , ReportParmName18 = @c_ReportParmName18
                 , ReportParmName19 = @c_ReportParmName19
                 , ReportParmName20 = @c_ReportParmName20
                 , ReportLineDesc   = @c_ReportLineDesc
            WHERE RowID = @n_CurrentRow
            
            SET @c_WMDETFlag = 'U'
         END
      END   --WL06
   END

   IF ISNULL(@c_MessageOut,'') = ''
   BEGIN
      SET @c_MessageOut = CASE WHEN @c_WMFlag + @c_WMDETFlag  = 'YN' THEN 'WMReport is created!'
                               WHEN @c_WMFlag + @c_WMDETFlag  = 'YY' THEN 'WMReport & WMReportdetail is created!' 
                               WHEN @c_WMFlag + @c_WMDETFlag  = 'YU' THEN 'WMReport is created, WMReportdetail is updated!' 
                               WHEN @c_WMFlag + @c_WMDETFlag  = 'NN' THEN 'WMReport & WMReportdetail is not created!' 
                               WHEN @c_WMFlag + @c_WMDETFlag  = 'NY' THEN 'WMReport is not created, WMReportdetail is created!' 
                               WHEN @c_WMFlag + @c_WMDETFlag  = 'NU' THEN 'WMReport is not created, WMReportdetail is updated!' 
                               WHEN @c_WMFlag + @c_WMDETFlag  = 'UN' THEN 'WMReport is updated!'                              --WL06
                               WHEN @c_WMFlag + @c_WMDETFlag  = 'UY' THEN 'WMReport is updated, WMReportdetail is created!'   --WL06
                               WHEN @c_WMFlag + @c_WMDETFlag  = 'UU' THEN 'WMReport & WMReportdetail is updated!'             --WL06
                               END
   END

   SELECT @c_MessageOut

   SELECT W.ReportID, W.ReportTitle, W.ModuleID, W.ReportType 
   FROM dbo.WMREPORT W (NOLOCK) WHERE W.ReportType = @c_ReportType AND W.ReportID = @c_ReportID
   
   SELECT W.ReportID, W.ReportLineNo, W.ReportTitle, W.PrintType, W.ReportTemplate, W.Storerkey
   FROM dbo.WMREPORTDETAIL W (NOLOCK) WHERE W.ReportID = @c_ReportID  ORDER BY Adddate DESC, W.ReportID ASC, W.ReportLineNo ASC

END  

GO