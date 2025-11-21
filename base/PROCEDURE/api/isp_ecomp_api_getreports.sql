SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/              
/* Store procedure: [API].[isp_ECOMP_API_GetReports]                    */              
/* Creation Date: 12-May-2023                                           */
/* Copyright: Maersk                                                    */
/* Written by: Allen                                                    */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By: SCEAPI                                                    */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date           Author   Purposes	                                    */
/* 12-May-2023    Allen     #JIRA PAC-65 Initial                        */
/* 22-May-2023    Alex     Rename sp name to isp_ECOMP_API_GetReports   */
/* 05-Sep-2023    Allen    Change default return string  (AL01)         */
/************************************************************************/

CREATE   PROC [API].[isp_ECOMP_API_GetReports] (  
     @b_Debug           INT            = 0  
   , @c_Format          VARCHAR(10)    = ''  
   , @c_UserID          NVARCHAR(256)  = ''  
   , @c_OperationType   NVARCHAR(60)   = ''  
   , @c_RequestString   NVARCHAR(MAX)  = ''  
   , @b_Success         INT            = 0   OUTPUT  
   , @n_ErrNo           INT            = 0   OUTPUT  
   , @c_ErrMsg          NVARCHAR(250)  = ''  OUTPUT  
   , @c_ResponseString  NVARCHAR(MAX)  = ''  OUTPUT  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_DEFAULTS OFF   
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @n_Continue                    INT            = 1  
         , @n_StartCnt                    INT            = @@TRANCOUNT  
  
         , @c_ComputerName                NVARCHAR(30)   = ''  
  
         , @c_PickSlipNo                  NVARCHAR(10)   = ''  
  
         , @c_StorerKey                   NVARCHAR(15)   = ''  
         , @c_Facility                    NVARCHAR(15)   = ''  
         , @c_TaskBatchNo                 NVARCHAR(10)   = ''  
         , @c_OrderKey                    NVARCHAR(10)   = ''  
  
         , @b_sp_Success                  INT  
         , @n_sp_err                      INT  
         , @c_sp_errmsg                   NVARCHAR(250)  = ''  
  

         , @n_TotalWMRDetail              INT          
         , @c_ReportID                    NVARCHAR(10) 
         , @c_ReportTitle                 NVARCHAR(60) 
         , @n_NoOfKeyFieldParms           INT          
         , @c_IsPaperPrinter              NVARCHAR(2)  
         , @c_DefaultPrinterID            NVARCHAR(30)



   DECLARE @t_Report_Temp AS Table (
      TotalWMRDetail       INT            NULL,
      ReportID             NVARCHAR(10)   NULL,
      ReportTitle          NVARCHAR(60)   NULL,
      NoOfKeyFieldParms    INT            NULL,
      IsPaperPrint         NVARCHAR(2)    NULL DEFAULT(''),
      DefaultPrinterID     NVARCHAR(30)   NULL DEFAULT('')
   )

   SET @b_Success                         = 0  
   SET @n_ErrNo                           = 0  
   SET @c_ErrMsg                          = ''  
   SET @c_ResponseString                  = ''  
  
   --Change Login User  
   SET @n_sp_err = 0       
   EXEC [WM].[lsp_SetUser] @c_UserName = @c_UserID OUTPUT, @n_Err = @n_sp_err OUTPUT, @c_ErrMsg = @c_sp_errmsg OUTPUT      
         
   EXECUTE AS LOGIN = @c_UserID      
         
   SELECT @c_UserID
   IF @n_sp_err <> 0       
   BEGIN        
      SET @n_Continue = 3        
      SET @n_ErrNo = @n_sp_err        
      SET @c_ErrMsg = @c_sp_errmsg       
      GOTO QUIT        
   END    
     
   SELECT @c_StorerKey     = ISNULL(RTRIM(StorerKey      ), '')  
         ,@c_Facility      = ISNULL(RTRIM(Facility    ), '')  
         ,@c_ComputerName  = ISNULL(RTRIM(ComputerName), '')  
         --,@c_PickSlipNo    = ISNULL(RTRIM(PickSlipNo), '')  
   FROM OPENJSON (@c_RequestString)  
   WITH (   
      StorerKey        NVARCHAR(15)       '$.StorerKey',  
      Facility         NVARCHAR(15)       '$.Facility',  
      ComputerName     NVARCHAR(30)       '$.ComputerName'    
      --PickSlipNo       NVARCHAR(10)       '$.PickSlipNo'  
   )    
  
   INSERT INTO @t_Report_Temp (TotalWMRDetail, ReportID, ReportTitle, NoOfKeyFieldParms)
   SELECT COUNT(1) As TotalWMRDetail
         ,RH.ReportID   
         ,RH.ReportTitle  
         ,RH.NoOfKeyFieldParms  
   FROM [dbo].[WMReport] RH(nolock)   
   JOIN [dbo].[WMREPORTDETAIL] RD(NOLOCK) ON(RH.ReportID = RD.ReportID)  
   WHERE RH.ModuleID = 'EPACKING'   
   AND RH.ReportType IN ('CtnManifst','CTNMNFLBL','CtnMarkLBL','PACKLIST','UCCLabel')  
   AND RD.StorerKey = @c_StorerKey
   AND ISNULL(RD.Facility,'') IN('',@c_Facility)  
   GROUP BY RH.ReportID, RH.ReportTitle , RH.NoOfKeyFieldParms  

   DECLARE C_LOOP_RPT_TEMP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT TotalWMRDetail   
         , ReportID         
         , ReportTitle      
         , NoOfKeyFieldParms
   FROM @t_Report_Temp

   OPEN C_LOOP_RPT_TEMP
   FETCH NEXT FROM C_LOOP_RPT_TEMP INTO @n_TotalWMRDetail, @c_ReportID, @c_ReportTitle, @n_NoOfKeyFieldParms
   WHILE @@FETCH_STATUS <> -1   
   BEGIN
      IF @n_TotalWMRDetail = 1
      BEGIN
         SELECT @c_IsPaperPrinter = CASE 
                                    WHEN ISNULL(RTRIM(IsPaperPrinter),'') IN ('Y', '1') THEN 'Y' 
                                    WHEN ISNULL(RTRIM(IsPaperPrinter),'') IN ('N', '0') THEN 'N' 
                                    ELSE '' 
                                  END
               ,@c_DefaultPrinterID = ISNULL(RTRIM(DefaultPrinterID), '')
         FROM [dbo].[WMREPORTDETAIL] (NOLOCK) 
         WHERE ReportID = @c_ReportID
         AND StorerKey = @c_StorerKey
         AND ISNULL(Facility,'') IN('',@c_Facility)  

         IF @c_DefaultPrinterID = ''
         BEGIN
            SELECT @c_DefaultPrinterID = 
               CASE 
                  WHEN @c_IsPaperPrinter = 'Y' THEN ISNULL(RTRIM(DefaultPrinter_Paper), '') 
                  WHEN @c_IsPaperPrinter = 'N' THEN ISNULL(RTRIM(DefaultPrinter), '') 
                  ELSE ''
               END
            FROM [rdt].[rdtUser] WITH (NOLOCK) 
            WHERE UserName = @c_UserID
         END

         UPDATE @t_Report_Temp
         SET IsPaperPrint        = @c_IsPaperPrinter
            ,DefaultPrinterID    = @c_DefaultPrinterID
         WHERE ReportID = @c_ReportID

         IF @b_Debug = 1
         BEGIN
            PRINT '--------------'
            PRINT '@c_ReportID = ' + @c_ReportID
            PRINT '@c_IsPaperPrinter = ' + @c_IsPaperPrinter
            PRINT '@c_DefaultPrinterID = ' + @c_DefaultPrinterID
         END
      END
      FETCH NEXT FROM C_LOOP_RPT_TEMP INTO @n_TotalWMRDetail, @c_ReportID, @c_ReportTitle, @n_NoOfKeyFieldParms
   END -- WHILE @@FETCH_STATUS <> -1   
   CLOSE C_LOOP_RPT_TEMP
   DEALLOCATE C_LOOP_RPT_TEMP

   SET @c_ResponseString = ISNULL((   
                              SELECT 
                              (
                                 SELECT ROW_NUMBER() OVER (ORDER BY ReportID ASC) As [ReportRowID]
                                       ,ReportID         
                                       ,ReportTitle      
                                       ,NoOfKeyFieldParms
                                       ,IsPaperPrint     
                                       ,DefaultPrinterID 
                                 FROM @t_Report_Temp
                                 FOR JSON PATH
                              ) As 'Reports'
                              FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                           ), '') 

   --SET @c_ResponseString = ISNULL((   
   --                           SELECT 
   --                           (
   --                              SELECT RD.RowID AS ReportRowID  
   --                              ,RD.ReportID   
   --                              ,RD.ReportTitle  
   --                              ,RH.NoOfKeyFieldParms  
   --                              ,CASE WHEN RD.PrintType = 'TCPSPooler' THEN 'Y' ELSE 'N' END AS IsPaperPrint  
   --                              FROM dbo.WMReport RH(nolock)   
   --                              JOIN dbo.WMREPORTDETAIL RD(NOLOCK) ON(RH.ReportID = RD.ReportID)  
   --                              WHERE RH.ModuleID = 'EPACKING'   
   --                              AND RH.ReportType IN ('CtnManifst','CTNMNFLBL','CtnMarkLBL','PACKLIST','UCCLabel')  
   --                              --AND RD.PrintType IN ('TCPSPOOLER', 'BARTENDER')   
   --                              AND RD.StorerKey = @c_StorerKey   
   --                              AND ISNULL(RD.Facility,'') IN('',@c_Facility)  
   --                              FOR JSON PATH
   --                           ) As 'Reports'
   --                           FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
   --                        ), '')  
   
   IF ISNULL(@c_RequestString, '') = '' --(AL01)
      SET @c_RequestString = '[]'
   --SET @c_ResponseString = '{"Reports":' + ISNULL(@c_ResponseString, '[]' + '}'  
  
   QUIT:  
   IF @n_Continue= 3  -- Error Occured - Process And Return        
   BEGIN        
      SET @b_Success = 0        
      IF @@TRANCOUNT > @n_StartCnt AND @@TRANCOUNT = 1   
      BEGIN                 
         ROLLBACK TRAN        
      END        
      ELSE        
      BEGIN        
         WHILE @@TRANCOUNT > @n_StartCnt        
         BEGIN        
            COMMIT TRAN        
         END        
      END     
      RETURN        
   END        
   ELSE        
   BEGIN        
      SELECT @b_Success = 1        
      WHILE @@TRANCOUNT > @n_StartCnt        
      BEGIN        
         COMMIT TRAN        
      END        
      RETURN        
   END  
END -- Procedure    
GO