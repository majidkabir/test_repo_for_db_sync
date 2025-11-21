SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Trigger: isp_GetRCMReportBuildLoadPlanMenu                           */  
/* Creation Date: 22-SEP-2019                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose:                                                             */  
/*        :                                                             */  
/* Called By:  d_dw_rcmreport_buildloadplan_menu                        */  
/*          :                                                           */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver Purposes                                  */  
/* 22-04-2021   WLChooi   1.1 Missing NOLOCK (WL01)                     */
/************************************************************************/  
CREATE PROC [dbo].[isp_GetRCMReportBuildLoadPlanMenu]   
            @c_Storerkey      NVARCHAR(10)  = ''
         ,  @c_UserID         NVARCHAR(30)  = ''
         ,  @c_ComputerName   NVARCHAR(30)  = ''
         ,  @c_Reporttypes    NVARCHAR(255) = '' 
         ,  @c_CallFrom       NVARCHAR(255) = ''
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE    
           @n_StartTCnt       INT  
         , @n_Continue        INT   
         , @b_Success         INT  
         , @n_Err             INT  
         , @c_ErrMsg          NVARCHAR(255)  
  
         , @c_RCMUsingUserID  NVARCHAR(10)  
   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue = 1  
  
   CREATE TABLE #TMP_RPTTYPE  
      ( ReportType   NVARCHAR(10) NULL   
      , ComputerName NVARCHAR(30) NULL )  
  
   INSERT INTO #TMP_RPTTYPE  
      ( ReportType, Computername )       
   SELECT ColValue, @c_ComputerName  
   FROM fnc_DelimSplit (',',@c_Reporttypes)  

   IF @c_Storerkey <> ''
   BEGIN
      EXECUTE nspGetRight   
               ''                   -- facility  
           ,   @c_StorerKey         -- Storerkey  
           ,   ''                   -- Sku  
           ,   'RCMUsingUserID'     -- Configkey  
           ,   @b_Success        OUTPUT  
           ,   @c_RCMUsingUserID OUTPUT  
           ,   @n_Err            OUTPUT  
           ,   @c_ErrMsg         OUTPUT  
  
  
      UPDATE #TMP_RPTTYPE  
           SET ComputerName = CASE WHEN CL.ListName IS NOT NULL OR @c_RCMUsingUserID = '1'   
                                   THEN @c_userid ELSE @c_ComputerName END  
      FROM #TMP_RPTTYPE RT  
      LEFT JOIN CODELKUP CL WITH (NOLOCK) ON  (CL.ListName = 'RCMBYUSER')  
                                          AND (RT.ReportType = CL.Code)  
                                          AND (CL.Storerkey = @c_Storerkey)  
   END

   SELECT  DISTINCT RT.ReportType  
         , Description= CL.Description
         , Event_Name = 'ue_print_' + CASE WHEN RT.ReportType = 'PLISTN' THEN 'normalpickslip'
                                           WHEN RT.ReportType = 'PLISTC' THEN 'consopickslip'
                                           WHEN RT.ReportType = 'OUTLBL' THEN 'outbound_label'
                                           WHEN RT.ReportType = 'POPUPPLIST' THEN 'popup_pickslip'
                                       --    WHEN RT.ReportType = 'CTNLBL' THEN 'carton_label'
                                           ELSE LOWER(RTRIM(RT.ReportType)) END
   FROM #TMP_RPTTYPE RT  
   JOIN RCMREPORT RCMR WITH (NOLOCK) ON (RT.ReportType = RCMR.ReportType)   --WL01  
                                     AND(RT.ComputerName = RCMR.ComputerName)  
   JOIN CODELKUP  CL   WITH (NOLOCK) ON (CL.listname = 'RCMREPORT')   --WL01    
                                     AND(RCMR.ReportType = CL.Code)
                                     AND(CL.code2 = 'w_build_loadplan')
   --WHERE RCMR.Storerkey = @c_Storerkey  
   ORDER BY RT.ReportType  
  
END -- procedure  

GO