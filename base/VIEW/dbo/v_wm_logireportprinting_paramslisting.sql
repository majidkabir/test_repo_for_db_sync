SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* View: V_WM_LogiReportPrinting_ParamsListing                             */
/* Creation Date: 08-Mar-2022                                              */
/* Copyright: LF Logistics                                                 */
/* Written by: WLChooi                                                     */
/*                                                                         */
/* Purpose: For SCE to print Logi Report                                   */
/*        : To show ModuleID, ReportType and its corresponding             */
/*        : parameters for SCE print to Logi Report                        */
/*                                                                         */
/* Called By:                                                              */
/*          :                                                              */
/* GitLab Version: 1.1                                                     */
/*                                                                         */
/* Version: 7.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date        Author   Ver   Purposes                                     */
/* 08-Mar-2022 WLChooi  1.0   DevOps Combine Script                        */
/* 04-Apr-2022 WLChooi  1.1   Use Receiptkey as the only param for all     */
/*                            report type for Receipt module exclude       */
/*                            PPACKLBL,PostRecv,PreRecv (WL01)             */
/***************************************************************************/

CREATE   VIEW [dbo].[V_WM_LogiReportPrinting_ParamsListing] AS

WITH CTE AS (   --WL01
   SELECT WM.ReportID
        , WM.ModuleID
        , WM.ReportType
        , CASE WHEN ISNULL(WMD.ReportParmName1 ,'') = '' 
               THEN CASE WHEN ISNULL(VP.Param01,'') = '' 
                         THEN CASE WHEN CHARINDEX('.', TRIM(WM.KeyFieldName1)) > 0
                                   THEN CASE WHEN CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName1), 'DATE', '|')) > 0 
                                             THEN 'PARAM_WMS_dt_' 
                                             WHEN CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName1), 'qty', '|')) > 0 OR
                                                  CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName1), 'noofcopy', '|')) > 0 OR
                                                  CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName1), 'total', '|')) > 0
                                             THEN 'PARAM_WMS_n_' 
                                             ELSE 'PARAM_WMS_c_' END + SUBSTRING(WM.KeyFieldName1, 
                                                                       CHARINDEX('.', TRIM(WM.KeyFieldName1)) + 1 , 
                                                                       LEN(TRIM(WM.KeyFieldName1)) - CHARINDEX('.', TRIM(WM.KeyFieldName1)) + 1)
                                   WHEN SUBSTRING(TRIM(WM.KeyFieldName1), 1, 1) IN ('@')
                                   THEN 'PARAM_WMS_' + RIGHT(TRIM(WM.KeyFieldName1), LEN(TRIM(WM.KeyFieldName1)) - 1)
                                   ELSE ''
                                   END
                         ELSE ISNULL(VP.Param01 ,'') END
               ELSE ISNULL(WMD.ReportParmName1 ,'') END AS ReportParmName1 
        , WM.KeyFieldName1
        , CASE WHEN ISNULL(WMD.ReportParmName2 ,'') = '' 
               THEN CASE WHEN ISNULL(VP.Param02,'') = '' 
                         THEN CASE WHEN CHARINDEX('.', TRIM(WM.KeyFieldName2)) > 0
                                   THEN CASE WHEN CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName2), 'DATE', '|')) > 0 
                                             THEN 'PARAM_WMS_dt_' 
                                             WHEN CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName2), 'qty', '|')) > 0 OR
                                                  CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName2), 'noofcopy', '|')) > 0 OR
                                                  CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName2), 'total', '|')) > 0
                                             THEN 'PARAM_WMS_n_' 
                                             ELSE 'PARAM_WMS_c_' END + SUBSTRING(WM.KeyFieldName2, 
                                                                       CHARINDEX('.', TRIM(WM.KeyFieldName2)) + 1 , 
                                                                       LEN(TRIM(WM.KeyFieldName2)) - CHARINDEX('.', TRIM(WM.KeyFieldName2)) + 1)
                                   WHEN SUBSTRING(TRIM(WM.KeyFieldName2), 1, 1) IN ('@')
                                   THEN 'PARAM_WMS_' + RIGHT(TRIM(WM.KeyFieldName2), LEN(TRIM(WM.KeyFieldName2)) - 1)
                                   ELSE ''
                                   END
                         ELSE ISNULL(VP.Param02 ,'') END
               ELSE ISNULL(WMD.ReportParmName2 ,'') END AS ReportParmName2
        , WM.KeyFieldName2
        , CASE WHEN ISNULL(WMD.ReportParmName3 ,'') = '' 
               THEN CASE WHEN ISNULL(VP.Param03,'') = '' 
                         THEN CASE WHEN CHARINDEX('.', TRIM(WM.KeyFieldName3)) > 0
                                   THEN CASE WHEN CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName3), 'DATE', '|')) > 0 
                                             THEN 'PARAM_WMS_dt_' 
                                             WHEN CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName3), 'qty', '|')) > 0 OR
                                                  CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName3), 'noofcopy', '|')) > 0 OR
                                                  CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName3), 'total', '|')) > 0
                                             THEN 'PARAM_WMS_n_' 
                                             ELSE 'PARAM_WMS_c_' END + SUBSTRING(WM.KeyFieldName3, 
                                                                       CHARINDEX('.', TRIM(WM.KeyFieldName3)) + 1 , 
                                                                       LEN(TRIM(WM.KeyFieldName3)) - CHARINDEX('.', TRIM(WM.KeyFieldName3)) + 1)
                                   WHEN SUBSTRING(TRIM(WM.KeyFieldName3), 1, 1) IN ('@')
                                   THEN 'PARAM_WMS_' + RIGHT(TRIM(WM.KeyFieldName3), LEN(TRIM(WM.KeyFieldName3)) - 1)
                                   ELSE ''
                                   END
                         ELSE ISNULL(VP.Param03 ,'') END
               ELSE ISNULL(WMD.ReportParmName3 ,'') END AS ReportParmName3
        , WM.KeyFieldName3
        , CASE WHEN ISNULL(WMD.ReportParmName4 ,'') = '' 
               THEN CASE WHEN ISNULL(VP.Param04,'') = '' 
                         THEN CASE WHEN CHARINDEX('.', TRIM(WM.KeyFieldName4)) > 0
                                   THEN CASE WHEN CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName4), 'DATE', '|')) > 0 
                                             THEN 'PARAM_WMS_dt_' 
                                             WHEN CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName4), 'qty', '|')) > 0 OR
                                                  CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName4), 'noofcopy', '|')) > 0 OR
                                                  CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName4), 'total', '|')) > 0
                                             THEN 'PARAM_WMS_n_' 
                                             ELSE 'PARAM_WMS_c_' END + SUBSTRING(WM.KeyFieldName4, 
                                                                       CHARINDEX('.', TRIM(WM.KeyFieldName4)) + 1 , 
                                                                       LEN(TRIM(WM.KeyFieldName4)) - CHARINDEX('.', TRIM(WM.KeyFieldName4)) + 1)
                                   WHEN SUBSTRING(TRIM(WM.KeyFieldName4), 1, 1) IN ('@')
                                   THEN 'PARAM_WMS_' + RIGHT(TRIM(WM.KeyFieldName4), LEN(TRIM(WM.KeyFieldName4)) - 1)
                                   ELSE ''
                                   END
                         ELSE ISNULL(VP.Param04 ,'') END
               ELSE ISNULL(WMD.ReportParmName4 ,'') END AS ReportParmName4
        , WM.KeyFieldName4
        , CASE WHEN ISNULL(WMD.ReportParmName5 ,'') = '' 
               THEN CASE WHEN ISNULL(VP.Param05,'') = '' 
                         THEN CASE WHEN CHARINDEX('.', TRIM(WM.KeyFieldName5)) > 0
                                   THEN CASE WHEN CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName5), 'DATE', '|')) > 0 
                                             THEN 'PARAM_WMS_dt_' 
                                             WHEN CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName5), 'qty', '|')) > 0 OR
                                                  CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName5), 'noofcopy', '|')) > 0 OR
                                                  CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName5), 'total', '|')) > 0
                                             THEN 'PARAM_WMS_n_' 
                                             ELSE 'PARAM_WMS_c_' END + SUBSTRING(WM.KeyFieldName5, 
                                                                       CHARINDEX('.', TRIM(WM.KeyFieldName5)) + 1 , 
                                                                       LEN(TRIM(WM.KeyFieldName5)) - CHARINDEX('.', TRIM(WM.KeyFieldName5)) + 1)
                                   WHEN SUBSTRING(TRIM(WM.KeyFieldName5), 1, 1) IN ('@')
                                   THEN 'PARAM_WMS_' + RIGHT(TRIM(WM.KeyFieldName5), LEN(TRIM(WM.KeyFieldName5)) - 1)
                                   ELSE ''
                                   END
                         ELSE ISNULL(VP.Param05 ,'') END
               ELSE ISNULL(WMD.ReportParmName5 ,'') END AS ReportParmName5
        , WM.KeyFieldName5
        , CASE WHEN ISNULL(WMD.ReportParmName6 ,'') = '' 
               THEN CASE WHEN ISNULL(VP.Param06,'') = '' 
                         THEN CASE WHEN CHARINDEX('.', TRIM(WM.KeyFieldName6)) > 0
                                   THEN CASE WHEN CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName6), 'DATE', '|')) > 0 
                                             THEN 'PARAM_WMS_dt_' 
                                             WHEN CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName6), 'qty', '|')) > 0 OR
                                                  CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName6), 'noofcopy', '|')) > 0 OR
                                                  CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName6), 'total', '|')) > 0
                                             THEN 'PARAM_WMS_n_' 
                                             ELSE 'PARAM_WMS_c_' END + SUBSTRING(WM.KeyFieldName6, 
                                                                       CHARINDEX('.', TRIM(WM.KeyFieldName6)) + 1 , 
                                                                       LEN(TRIM(WM.KeyFieldName6)) - CHARINDEX('.', TRIM(WM.KeyFieldName6)) + 1)
                                   WHEN SUBSTRING(TRIM(WM.KeyFieldName6), 1, 1) IN ('@')
                                   THEN 'PARAM_WMS_' + RIGHT(TRIM(WM.KeyFieldName6), LEN(TRIM(WM.KeyFieldName6)) - 1)
                                   ELSE ''
                                   END
                         ELSE ISNULL(VP.Param06 ,'') END
               ELSE ISNULL(WMD.ReportParmName6 ,'') END AS ReportParmName6
        , WM.KeyFieldName6
        , CASE WHEN ISNULL(WMD.ReportParmName7 ,'') = '' 
               THEN CASE WHEN ISNULL(VP.Param07,'') = '' 
                         THEN CASE WHEN CHARINDEX('.', TRIM(WM.KeyFieldName7)) > 0
                                   THEN CASE WHEN CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName5), 'DATE', '|')) > 0 
                                             THEN 'PARAM_WMS_dt_' 
                                             WHEN CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName7), 'qty', '|')) > 0 OR
                                                  CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName7), 'noofcopy', '|')) > 0 OR
                                                  CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName7), 'total', '|')) > 0
                                             THEN 'PARAM_WMS_n_' 
                                             ELSE 'PARAM_WMS_c_' END + SUBSTRING(WM.KeyFieldName7, 
                                                                       CHARINDEX('.', TRIM(WM.KeyFieldName7)) + 1 , 
                                                                       LEN(TRIM(WM.KeyFieldName7)) - CHARINDEX('.', TRIM(WM.KeyFieldName7)) + 1)
                                   WHEN SUBSTRING(TRIM(WM.KeyFieldName7), 1, 1) IN ('@')
                                   THEN 'PARAM_WMS_' + RIGHT(TRIM(WM.KeyFieldName7), LEN(TRIM(WM.KeyFieldName7)) - 1)
                                   ELSE ''
                                   END
                         ELSE ISNULL(VP.Param07 ,'') END
               ELSE ISNULL(WMD.ReportParmName7 ,'') END AS ReportParmName7
        , WM.KeyFieldName7
        , CASE WHEN ISNULL(WMD.ReportParmName8 ,'') = '' 
               THEN CASE WHEN ISNULL(VP.Param08,'') = '' 
                         THEN CASE WHEN CHARINDEX('.', TRIM(WM.KeyFieldName8)) > 0
                                   THEN CASE WHEN CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName8), 'DATE', '|')) > 0 
                                             THEN 'PARAM_WMS_dt_' 
                                             WHEN CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName8), 'qty', '|')) > 0 OR
                                                  CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName8), 'noofcopy', '|')) > 0 OR
                                                  CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName8), 'total', '|')) > 0
                                             THEN 'PARAM_WMS_n_' 
                                             ELSE 'PARAM_WMS_c_' END + SUBSTRING(WM.KeyFieldName8, 
                                                                       CHARINDEX('.', TRIM(WM.KeyFieldName8)) + 1 , 
                                                                       LEN(TRIM(WM.KeyFieldName8)) - CHARINDEX('.', TRIM(WM.KeyFieldName8)) + 1)
                                   WHEN SUBSTRING(TRIM(WM.KeyFieldName8), 1, 1) IN ('@')
                                   THEN 'PARAM_WMS_' + RIGHT(TRIM(WM.KeyFieldName8), LEN(TRIM(WM.KeyFieldName8)) - 1)
                                   ELSE ''
                                   END
                         ELSE ISNULL(VP.Param08 ,'') END
               ELSE ISNULL(WMD.ReportParmName8 ,'') END AS ReportParmName8
        , WM.KeyFieldName8
        , CASE WHEN ISNULL(WMD.ReportParmName9 ,'') = '' 
               THEN CASE WHEN ISNULL(VP.Param09,'') = '' 
                         THEN CASE WHEN CHARINDEX('.', TRIM(WM.KeyFieldName9)) > 0
                                   THEN CASE WHEN CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName9), 'DATE', '|')) > 0 
                                             THEN 'PARAM_WMS_dt_' 
                                             WHEN CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName9), 'qty', '|')) > 0 OR
                                                  CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName9), 'noofcopy', '|')) > 0 OR
                                                  CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName9), 'total', '|')) > 0
                                             THEN 'PARAM_WMS_n_' 
                                             ELSE 'PARAM_WMS_c_' END + SUBSTRING(WM.KeyFieldName9, 
                                                                       CHARINDEX('.', TRIM(WM.KeyFieldName9)) + 1 , 
                                                                       LEN(TRIM(WM.KeyFieldName9)) - CHARINDEX('.', TRIM(WM.KeyFieldName9)) + 1)
                                   WHEN SUBSTRING(TRIM(WM.KeyFieldName9), 1, 1) IN ('@')
                                   THEN 'PARAM_WMS_' + RIGHT(TRIM(WM.KeyFieldName9), LEN(TRIM(WM.KeyFieldName9)) - 1)
                                   ELSE ''
                                   END
                         ELSE ISNULL(VP.Param09 ,'') END
               ELSE ISNULL(WMD.ReportParmName9 ,'') END AS ReportParmName9
        , WM.KeyFieldName9
        , CASE WHEN ISNULL(WMD.ReportParmName10 ,'') = '' 
               THEN CASE WHEN ISNULL(VP.Param10,'') = '' 
                         THEN CASE WHEN CHARINDEX('.', TRIM(WM.KeyFieldName10)) > 0
                                   THEN CASE WHEN CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName10), 'DATE', '|')) > 0 
                                             THEN 'PARAM_WMS_dt_' 
                                             WHEN CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName10), 'qty', '|')) > 0 OR
                                                  CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName10), 'noofcopy', '|')) > 0 OR
                                                  CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName10), 'total', '|')) > 0
                                             THEN 'PARAM_WMS_n_' 
                                             ELSE 'PARAM_WMS_c_' END + SUBSTRING(WM.KeyFieldName10, 
                                                                       CHARINDEX('.', TRIM(WM.KeyFieldName10)) + 1 , 
                                                                       LEN(TRIM(WM.KeyFieldName10)) - CHARINDEX('.', TRIM(WM.KeyFieldName10)) + 1)
                                   WHEN SUBSTRING(TRIM(WM.KeyFieldName10), 1, 1) IN ('@')
                                   THEN 'PARAM_WMS_' + RIGHT(TRIM(WM.KeyFieldName10), LEN(TRIM(WM.KeyFieldName10)) - 1)
                                   ELSE ''
                                   END
                         ELSE ISNULL(VP.Param10 ,'') END
               ELSE ISNULL(WMD.ReportParmName10 ,'') END AS ReportParmName10
        , WM.KeyFieldName10
        , CASE WHEN ISNULL(WMD.ReportParmName11,'') = ''
               THEN CASE WHEN CHARINDEX('.', TRIM(WM.KeyFieldName11)) > 0
                              THEN CASE WHEN CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName11), 'DATE', '|')) > 0 
                                        THEN 'PARAM_WMS_dt_' 
                                        WHEN CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName11), 'qty', '|')) > 0 OR
                                             CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName11), 'noofcopy', '|')) > 0 OR
                                             CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName11), 'total', '|')) > 0
                                        THEN 'PARAM_WMS_n_' 
                                        ELSE 'PARAM_WMS_c_' END + SUBSTRING(WM.KeyFieldName11, 
                                                                  CHARINDEX('.', TRIM(WM.KeyFieldName11)) + 1 , 
                                                                  LEN(TRIM(WM.KeyFieldName11)) - CHARINDEX('.', TRIM(WM.KeyFieldName11)) + 1)
                              WHEN SUBSTRING(TRIM(WM.KeyFieldName11), 1, 1) IN ('@')
                              THEN 'PARAM_WMS_' + RIGHT(TRIM(WM.KeyFieldName11), LEN(TRIM(WM.KeyFieldName11)) - 1)
                              ELSE ''
                              END
               ELSE ISNULL(WMD.ReportParmName11 ,'') END AS ReportParmName11
        , WM.KeyFieldName11
        , CASE WHEN ISNULL(WMD.ReportParmName12,'') = ''
               THEN CASE WHEN CHARINDEX('.', TRIM(WM.KeyFieldName12)) > 0
                              THEN CASE WHEN CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName12), 'DATE', '|')) > 0 
                                        THEN 'PARAM_WMS_dt_' 
                                        WHEN CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName12), 'qty', '|')) > 0 OR
                                             CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName12), 'noofcopy', '|')) > 0 OR
                                             CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName12), 'total', '|')) > 0
                                        THEN 'PARAM_WMS_n_' 
                                        ELSE 'PARAM_WMS_c_' END + SUBSTRING(WM.KeyFieldName12, 
                                                                  CHARINDEX('.', TRIM(WM.KeyFieldName12)) + 1 , 
                                                                  LEN(TRIM(WM.KeyFieldName12)) - CHARINDEX('.', TRIM(WM.KeyFieldName12)) + 1)
                              WHEN SUBSTRING(TRIM(WM.KeyFieldName12), 1, 1) IN ('@')
                              THEN 'PARAM_WMS_' + RIGHT(TRIM(WM.KeyFieldName12), LEN(TRIM(WM.KeyFieldName12)) - 1)
                              ELSE ''
                              END
               ELSE ISNULL(WMD.ReportParmName12 ,'') END AS ReportParmName12
        , WM.KeyFieldName12
        , CASE WHEN ISNULL(WMD.ReportParmName13,'') = ''
               THEN CASE WHEN CHARINDEX('.', TRIM(WM.KeyFieldName13)) > 0
                              THEN CASE WHEN CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName13), 'DATE', '|')) > 0 
                                        THEN 'PARAM_WMS_dt_' 
                                        WHEN CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName13), 'qty', '|')) > 0 OR
                                             CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName13), 'noofcopy', '|')) > 0 OR
                                             CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName13), 'total', '|')) > 0
                                        THEN 'PARAM_WMS_n_' 
                                        ELSE 'PARAM_WMS_c_' END + SUBSTRING(WM.KeyFieldName13, 
                                                                  CHARINDEX('.', TRIM(WM.KeyFieldName13)) + 1 , 
                                                                  LEN(TRIM(WM.KeyFieldName13)) - CHARINDEX('.', TRIM(WM.KeyFieldName13)) + 1)
                              WHEN SUBSTRING(TRIM(WM.KeyFieldName13), 1, 1) IN ('@')
                              THEN 'PARAM_WMS_' + RIGHT(TRIM(WM.KeyFieldName13), LEN(TRIM(WM.KeyFieldName13)) - 1)
                              ELSE ''
                              END
               ELSE ISNULL(WMD.ReportParmName13 ,'') END AS ReportParmName13
        , WM.KeyFieldName13
        , CASE WHEN ISNULL(WMD.ReportParmName14,'') = ''
               THEN CASE WHEN CHARINDEX('.', TRIM(WM.KeyFieldName14)) > 0
                              THEN CASE WHEN CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName14), 'DATE', '|')) > 0 
                                        THEN 'PARAM_WMS_dt_' 
                                        WHEN CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName14), 'qty', '|')) > 0 OR
                                             CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName14), 'noofcopy', '|')) > 0 OR
                                             CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName14), 'total', '|')) > 0
                                        THEN 'PARAM_WMS_n_' 
                                        ELSE 'PARAM_WMS_c_' END + SUBSTRING(WM.KeyFieldName14, 
                                                                  CHARINDEX('.', TRIM(WM.KeyFieldName14)) + 1 , 
                                                                  LEN(TRIM(WM.KeyFieldName14)) - CHARINDEX('.', TRIM(WM.KeyFieldName14)) + 1)
                              WHEN SUBSTRING(TRIM(WM.KeyFieldName14), 1, 1) IN ('@')
                              THEN 'PARAM_WMS_' + RIGHT(TRIM(WM.KeyFieldName14), LEN(TRIM(WM.KeyFieldName14)) - 1)
                              ELSE ''
                              END
               ELSE ISNULL(WMD.ReportParmName14 ,'') END AS ReportParmName14
        , WM.KeyFieldName14
        , CASE WHEN ISNULL(WMD.ReportParmName15,'') = ''
               THEN CASE WHEN CHARINDEX('.', TRIM(WM.KeyFieldName15)) > 0
                              THEN CASE WHEN CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName15), 'DATE', '|')) > 0 
                                        THEN 'PARAM_WMS_dt_' 
                                        WHEN CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName15), 'qty', '|')) > 0 OR
                                             CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName15), 'noofcopy', '|')) > 0 OR
                                             CHARINDEX('|', REPLACE(TRIM(WM.KeyFieldName15), 'total', '|')) > 0
                                        THEN 'PARAM_WMS_n_' 
                                        ELSE 'PARAM_WMS_c_' END + SUBSTRING(WM.KeyFieldName15, 
                                                                  CHARINDEX('.', TRIM(WM.KeyFieldName15)) + 1 , 
                                                                  LEN(TRIM(WM.KeyFieldName15)) - CHARINDEX('.', TRIM(WM.KeyFieldName15)) + 1)
                              WHEN SUBSTRING(TRIM(WM.KeyFieldName15), 1, 1) IN ('@')
                              THEN 'PARAM_WMS_' + RIGHT(TRIM(WM.KeyFieldName15), LEN(TRIM(WM.KeyFieldName15)) - 1)
                              ELSE ''
                              END
               ELSE ISNULL(WMD.ReportParmName15 ,'') END AS ReportParmName15
        , WM.KeyFieldName15
        , CASE WHEN ISNULL(WMD.ReportParmName16,'') = ''
               THEN CASE WHEN CHARINDEX('.', TRIM(WM.ExtendedParm1)) > 0
                              THEN CASE WHEN CHARINDEX('|', REPLACE(TRIM(WM.ExtendedParm1), 'DATE', '|')) > 0 
                                        THEN 'PARAM_WMS_dt_' 
                                        WHEN CHARINDEX('|', REPLACE(TRIM(WM.ExtendedParm1), 'qty', '|')) > 0 OR
                                             CHARINDEX('|', REPLACE(TRIM(WM.ExtendedParm1), 'noofcopy', '|')) > 0 OR
                                             CHARINDEX('|', REPLACE(TRIM(WM.ExtendedParm1), 'total', '|')) > 0
                                        THEN 'PARAM_WMS_n_' 
                                        ELSE 'PARAM_WMS_c_' END + SUBSTRING(WM.ExtendedParm1, 
                                                                  CHARINDEX('.', TRIM(WM.ExtendedParm1)) + 1 , 
                                                                  LEN(TRIM(WM.ExtendedParm1)) - CHARINDEX('.', TRIM(WM.ExtendedParm1)) + 1)
                              WHEN SUBSTRING(TRIM(WM.ExtendedParm1), 1, 1) IN ('@')
                              THEN 'PARAM_WMS_' + RIGHT(TRIM(WM.ExtendedParm1), LEN(TRIM(WM.ExtendedParm1)) - 1)
                              ELSE ''
                              END
               ELSE ISNULL(WMD.ReportParmName16 ,'') END AS ReportParmName16
        , WM.ExtendedParm1
        , CASE WHEN ISNULL(WMD.ReportParmName17,'') = ''
               THEN CASE WHEN CHARINDEX('.', TRIM(WM.ExtendedParm2)) > 0
                              THEN CASE WHEN CHARINDEX('|', REPLACE(TRIM(WM.ExtendedParm2), 'DATE', '|')) > 0 
                                        THEN 'PARAM_WMS_dt_' 
                                        WHEN CHARINDEX('|', REPLACE(TRIM(WM.ExtendedParm2), 'qty', '|')) > 0 OR
                                             CHARINDEX('|', REPLACE(TRIM(WM.ExtendedParm2), 'noofcopy', '|')) > 0 OR
                                             CHARINDEX('|', REPLACE(TRIM(WM.ExtendedParm2), 'total', '|')) > 0
                                        THEN 'PARAM_WMS_n_' 
                                        ELSE 'PARAM_WMS_c_' END + SUBSTRING(WM.ExtendedParm2, 
                                                                  CHARINDEX('.', TRIM(WM.ExtendedParm2)) + 1 , 
                                                                  LEN(TRIM(WM.ExtendedParm2)) - CHARINDEX('.', TRIM(WM.ExtendedParm2)) + 1)
                              WHEN SUBSTRING(TRIM(WM.ExtendedParm2), 1, 1) IN ('@')
                              THEN 'PARAM_WMS_' + RIGHT(TRIM(WM.ExtendedParm2), LEN(TRIM(WM.ExtendedParm2)) - 1)
                              ELSE ''
                              END
               ELSE ISNULL(WMD.ReportParmName17 ,'') END AS ReportParmName17
        , WM.ExtendedParm2
        , CASE WHEN ISNULL(WMD.ReportParmName18,'') = ''
               THEN CASE WHEN CHARINDEX('.', TRIM(WM.ExtendedParm3)) > 0
                              THEN CASE WHEN CHARINDEX('|', REPLACE(TRIM(WM.ExtendedParm3), 'DATE', '|')) > 0 
                                        THEN 'PARAM_WMS_dt_' 
                                        WHEN CHARINDEX('|', REPLACE(TRIM(WM.ExtendedParm3), 'qty', '|')) > 0 OR
                                             CHARINDEX('|', REPLACE(TRIM(WM.ExtendedParm3), 'noofcopy', '|')) > 0 OR
                                             CHARINDEX('|', REPLACE(TRIM(WM.ExtendedParm3), 'total', '|')) > 0
                                        THEN 'PARAM_WMS_n_' 
                                        ELSE 'PARAM_WMS_c_' END + SUBSTRING(WM.ExtendedParm3, 
                                                                  CHARINDEX('.', TRIM(WM.ExtendedParm3)) + 1 , 
                                                                  LEN(TRIM(WM.ExtendedParm3)) - CHARINDEX('.', TRIM(WM.ExtendedParm3)) + 1)
                              WHEN SUBSTRING(TRIM(WM.ExtendedParm3), 1, 1) IN ('@')
                              THEN 'PARAM_WMS_' + RIGHT(TRIM(WM.ExtendedParm3), LEN(TRIM(WM.ExtendedParm3)) - 1)
                              ELSE ''
                              END
               ELSE ISNULL(WMD.ReportParmName18 ,'') END AS ReportParmName18
        , WM.ExtendedParm3
        , CASE WHEN ISNULL(WMD.ReportParmName19,'') = ''
               THEN CASE WHEN CHARINDEX('.', TRIM(WM.ExtendedParm4)) > 0
                              THEN CASE WHEN CHARINDEX('|', REPLACE(TRIM(WM.ExtendedParm4), 'DATE', '|')) > 0 
                                        THEN 'PARAM_WMS_dt_' 
                                        WHEN CHARINDEX('|', REPLACE(TRIM(WM.ExtendedParm4), 'qty', '|')) > 0 OR
                                             CHARINDEX('|', REPLACE(TRIM(WM.ExtendedParm4), 'noofcopy', '|')) > 0 OR
                                             CHARINDEX('|', REPLACE(TRIM(WM.ExtendedParm4), 'total', '|')) > 0
                                        THEN 'PARAM_WMS_n_' 
                                        ELSE 'PARAM_WMS_c_' END + SUBSTRING(WM.ExtendedParm4, 
                                                                  CHARINDEX('.', TRIM(WM.ExtendedParm4)) + 1 , 
                                                                  LEN(TRIM(WM.ExtendedParm4)) - CHARINDEX('.', TRIM(WM.ExtendedParm4)) + 1)
                              WHEN SUBSTRING(TRIM(WM.ExtendedParm4), 1, 1) IN ('@')
                              THEN 'PARAM_WMS_' + RIGHT(TRIM(WM.ExtendedParm4), LEN(TRIM(WM.ExtendedParm4)) - 1)
                              ELSE ''
                              END
               ELSE ISNULL(WMD.ReportParmName19 ,'') END AS ReportParmName19
        , WM.ExtendedParm4
        , CASE WHEN ISNULL(WMD.ReportParmName20,'') = ''
               THEN CASE WHEN CHARINDEX('.', TRIM(WM.ExtendedParm5)) > 0
                              THEN CASE WHEN CHARINDEX('|', REPLACE(TRIM(WM.ExtendedParm5), 'DATE', '|')) > 0 
                                        THEN 'PARAM_WMS_dt_' 
                                        WHEN CHARINDEX('|', REPLACE(TRIM(WM.ExtendedParm5), 'qty', '|')) > 0 OR
                                             CHARINDEX('|', REPLACE(TRIM(WM.ExtendedParm5), 'noofcopy', '|')) > 0 OR
                                             CHARINDEX('|', REPLACE(TRIM(WM.ExtendedParm5), 'total', '|')) > 0
                                        THEN 'PARAM_WMS_n_' 
                                        ELSE 'PARAM_WMS_c_' END + SUBSTRING(WM.ExtendedParm5, 
                                                                  CHARINDEX('.', TRIM(WM.ExtendedParm5)) + 1 , 
                                                                  LEN(TRIM(WM.ExtendedParm5)) - CHARINDEX('.', TRIM(WM.ExtendedParm5)) + 1)
                              WHEN SUBSTRING(TRIM(WM.ExtendedParm5), 1, 1) IN ('@')
                              THEN 'PARAM_WMS_' + RIGHT(TRIM(WM.ExtendedParm5), LEN(TRIM(WM.ExtendedParm5)) - 1)
                              ELSE ''
                              END
               ELSE ISNULL(WMD.ReportParmName20 ,'') END AS ReportParmName20
        , WM.ExtendedParm5
   FROM WMREPORT WM (NOLOCK)
   LEFT JOIN (SELECT DISTINCT 
                     WMR.ReportParmName1,  WMR.ReportParmName2
                   , WMR.ReportParmName3,  WMR.ReportParmName4
                   , WMR.ReportParmName5,  WMR.ReportParmName6
                   , WMR.ReportParmName7,  WMR.ReportParmName8
                   , WMR.ReportParmName9,  WMR.ReportParmName10
                   , WMR.ReportParmName11, WMR.ReportParmName12
                   , WMR.ReportParmName13, WMR.ReportParmName14
                   , WMR.ReportParmName15, WMR.ReportParmName16
                   , WMR.ReportParmName17, WMR.ReportParmName18
                   , WMR.ReportParmName19, WMR.ReportParmName20
                   , WMR.ReportID
              FROM WMREPORTDETAIL WMR (NOLOCK)
              WHERE WMR.ReportParmName1  <> '' OR WMR.ReportParmName2  <> ''
                AND WMR.ReportParmName3  <> '' OR WMR.ReportParmName4  <> ''
                AND WMR.ReportParmName5  <> '' OR WMR.ReportParmName6  <> ''
                AND WMR.ReportParmName7  <> '' OR WMR.ReportParmName8  <> ''
                AND WMR.ReportParmName9  <> '' OR WMR.ReportParmName10 <> ''
                AND WMR.ReportParmName11 <> '' OR WMR.ReportParmName12 <> ''
                AND WMR.ReportParmName13 <> '' OR WMR.ReportParmName14 <> ''
                AND WMR.ReportParmName15 <> '' OR WMR.ReportParmName16 <> ''
                AND WMR.ReportParmName17 <> '' OR WMR.ReportParmName18 <> ''
                AND WMR.ReportParmName19 <> '' OR WMR.ReportParmName20 <> '') AS WMD ON WMD.ReportID = WM.ReportID
   LEFT JOIN (SELECT VJRPP.Module, VJRPP.ReportType
                   , VJRPP.Param01, VJRPP.Param02
                   , VJRPP.Param03, VJRPP.Param04
                   , VJRPP.Param05, VJRPP.Param06
                   , VJRPP.Param07, VJRPP.Param08
                   , VJRPP.Param09, VJRPP.Param10
              FROM V_JReportPrinting_Params VJRPP) AS VP ON VP.Module = CASE WHEN LEFT(TRIM(WM.ModuleID), 7) = 'RECEIPT' 
                                                                             THEN LEFT(TRIM(WM.ModuleID), 7) 
                                                                             ELSE WM.ModuleID END 
                                                        AND VP.ReportType = WM.ReportType 
   WHERE WM.ReportID LIKE 'R%')
--WL01 S
SELECT * 
FROM CTE
WHERE CTE.ModuleID NOT IN ('ReceiptA','ReceiptR','ReceiptX')
UNION ALL
SELECT * 
FROM CTE
WHERE CTE.ReportType IN ('PPACKLBL','PostRecv','PreRecv')
AND CTE.ModuleID IN ('ReceiptA','ReceiptR','ReceiptX')
UNION ALL
SELECT ReportID         = ReportID
     , ModuleID         = ModuleID
     , ReportType       = ReportType
     , ReportParmName1  = 'PARAM_WMS_c_Receiptkey'
     , KeyFieldName1    = 'RECEIPT.Receiptkey'
     , ReportParmName2  = ''
     , KeyFieldName2    = ''
     , ReportParmName3  = ''
     , KeyFieldName3    = ''
     , ReportParmName4  = ''
     , KeyFieldName4    = ''
     , ReportParmName5  = ''
     , KeyFieldName5    = ''
     , ReportParmName6  = ''
     , KeyFieldName6    = ''
     , ReportParmName7  = ''
     , KeyFieldName7    = ''
     , ReportParmName8  = ''
     , KeyFieldName8    = ''
     , ReportParmName9  = ''
     , KeyFieldName9    = ''
     , ReportParmName10 = ''
     , KeyFieldName10   = ''
     , ReportParmName11 = ''
     , KeyFieldName11   = ''
     , ReportParmName12 = ''
     , KeyFieldName12   = ''
     , ReportParmName13 = ''
     , KeyFieldName13   = ''
     , ReportParmName14 = ''
     , KeyFieldName14   = ''
     , ReportParmName15 = ''
     , KeyFieldName15   = ''
     , ReportParmName16 = ''
     , ExtendedParm1    = ''
     , ReportParmName17 = ''
     , ExtendedParm2    = ''
     , ReportParmName18 = ''
     , ExtendedParm3    = ''
     , ReportParmName19 = ''
     , ExtendedParm4    = ''
     , ReportParmName20 = ''
     , ExtendedParm5    = ''
FROM CTE
WHERE CTE.ReportType NOT IN ('PPACKLBL','PostRecv','PreRecv')
AND CTE.ModuleID IN ('ReceiptA','ReceiptR','ReceiptX')
--WL01 E

GO