SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store procedure: [API].[isp_ECOMP_API_CloseCartonPrint_M]            */
/* Creation Date: 15-AUG-2023                                           */
/* Copyright: Maersk                                                    */
/* Written by: Alex                                                     */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By: SCE_API                                                   */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date           Author   Purposes										*/
/* 15-AUG-2023    Alex     #JIRA PAC-7 Initial                          */
/* 03-JAN-2024    Alex01   #JIRA PAC-176 Pass ComputerName to Print SP  */
/* 14-MAY-2024    Alex02   #JIRA PAC-341 LogiReport Printing            */
/************************************************************************/
CREATE   PROC [API].[isp_ECOMP_API_CloseCartonPrint_M](
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

         , @c_ReportID                    NVARCHAR(10)   = ''
         , @c_PrintType                   NVARCHAR(10)   = ''
         , @c_PrintID                     NVARCHAR(30)   = ''
         , @c_JobID                       NVARCHAR(50)   = ''
         , @c_JobIDs                      NVARCHAR(max)  = ''
         , @c_IsPaperPrinter              NVARCHAR(1)    = ''
         , @b_sp_Success                  INT
         , @n_sp_err                      INT
         , @c_sp_errmsg                   NVARCHAR(250)  = ''
         , @c_ExecStatements              NVARCHAR(max)  = ''
         , @c_ExecArguments               NVARCHAR(max)  = ''
         , @c_ExecGroupByStatements       NVARCHAR(500)  = ''
         , @n_ExistedCartonNo             INT            = 0    
         
   DECLARE @n_CartonNo                    INT            = 0   --(AL01)
         , @n_Exist                       INT            = 0   --(AL01)
         , @c_OrderKey                    NVARCHAR(10)   = ''
         , @c_TaskBatchID                 NVARCHAR(10)   = ''

         , @n_RD_RowID                    INT            = 0
         , @n_IsExists                    INT            = 0
         , @c_OrderMode                   NVARCHAR(1)    = ''

         , @c_KeyValue1                   NVARCHAR(60)   = ''
         , @c_KeyValue2                   NVARCHAR(60)   = ''
         , @c_KeyValue3                   NVARCHAR(60)   = ''
         , @c_KeyValue4                   NVARCHAR(60)   = ''
         , @c_KeyValue5                   NVARCHAR(60)   = ''
         , @c_KeyValue6                   NVARCHAR(60)   = ''
         , @c_KeyValue7                   NVARCHAR(60)   = ''
         , @c_KeyValue8                   NVARCHAR(60)   = ''
         , @c_KeyValue9                   NVARCHAR(60)   = ''
         , @c_KeyValue10                  NVARCHAR(60)   = ''
         , @c_KeyValue11                  NVARCHAR(60)   = ''
         , @c_KeyValue12                  NVARCHAR(60)   = ''
         , @c_KeyValue13                  NVARCHAR(60)   = ''
         , @c_KeyValue14                  NVARCHAR(60)   = ''
         , @c_KeyValue15                  NVARCHAR(60)   = ''

         , @n_TotalWMRDetail              INT            = 0 
         , @c_DefaultPrinterID            NVARCHAR(30)   = ''
         , @b_RecordExists                INT            = 0 

         , @b_IsLastCarton                BIT            = 0

         , @n_TotalCarton                 INT            = 0
         , @n_EstimateTotalCtn            INT            = 0

         , @c_PrintSource                 NVARCHAR(10)   = 'WMReport'   --(Alex02)

   IF CURSOR_STATUS('LOCAL' , 'C_Pack_CloseCartonPrint') in (0 , 1)
   BEGIN
      CLOSE C_Pack_CloseCartonPrint 
      DEALLOCATE C_Pack_CloseCartonPrint 
   END

   SET @b_Success                         = 0
   SET @n_ErrNo                           = 0
   SET @c_ErrMsg                          = ''
   SET @c_ResponseString                  = ''

   --Change Login User
   SET @n_sp_err = 0     
   EXEC [WM].[lsp_SetUser] @c_UserName = @c_UserID OUTPUT, @n_Err = @n_sp_err OUTPUT, @c_ErrMsg = @c_sp_errmsg OUTPUT
       
   EXECUTE AS LOGIN = @c_UserID
       
   IF @n_sp_err <> 0     
   BEGIN      
      SET @n_Continue = 3      
      SET @n_ErrNo = @n_sp_err      
      SET @c_ErrMsg = @c_sp_errmsg     
      GOTO QUIT
   END

   SELECT @c_PickSlipNo    = ISNULL(RTRIM(PickSlipNo  ), '')
         ,@c_ComputerName  = ISNULL(RTRIM(ComputerName), '')
         ,@n_CartonNo      = ISNULL(CartonNo, 0)   
         ,@b_IsLastCarton  = ISNULL(IsLastCarton, 0)
   FROM OPENJSON (@c_RequestString)
   WITH ( 
      ComputerName     NVARCHAR(30)       '$.ComputerName',  
      PickSlipNo       NVARCHAR(10)       '$.PickSlipNo',
      CartonNo         INT                '$.CartonNo', 
      IsLastCarton     BIT                '$.IsLastCarton'
   )

   IF @b_Debug = 1
   BEGIN
     PRINT ' @c_PickSlipNo: ' + @c_PickSlipNo
     PRINT ' @c_ComputerName: ' + @c_ComputerName
     PRINT ' @n_CartonNo: ' + CONVERT(NVARCHAR(2), @n_CartonNo)
   END
      
   SELECT TOP 1 @n_IsExists = (1)
               ,@c_OrderMode = Left(UPPER(OrderMode),1) 
               ,@c_OrderKey = ISNULL(RTRIM(PT.Orderkey), '')
               ,@c_TaskBatchID = ISNULL(RTRIM(PT.TaskBatchNo), '')
   FROM [dbo].[PackTask] PT WITH (NOLOCK) 
   WHERE EXISTS (SELECT 1 FROM [dbo].[PackHeader] PH WITH (NOLOCK)
      WHERE PH.PickSlipNo = @c_PickSlipNo
      AND PH.TaskBatchNo = PT.TaskBatchNo
      AND PH.OrderKey = PT.Orderkey 
      AND PH.OrderKey <> '' AND PH.OrderKey IS NOT NULL)

   IF @n_IsExists <> 1
   BEGIN
      SET @n_Continue = 3      
      SET @n_ErrNo = 54101
      SET @c_ErrMsg = CONVERT(char(5),@n_ErrNo)+': PickSlipNo(' + @c_PickSlipNo + ') is not found.'
      GOTO QUIT
   END

   IF @c_OrderMode <> 'M'
   BEGIN
      SET @n_Continue = 3      
      SET @n_ErrNo = 54102
      SET @c_ErrMsg = CONVERT(char(5),@n_ErrNo)+': OrderKey(' + @c_OrderKey + ') is NOT Multi mode.'
      GOTO QUIT
   END

   SELECT @c_StorerKey  = ISNULL(RTRIM(StorerKey), '')
         ,@c_Facility   = ISNULL(RTRIM(Facility), '')
   FROM [dbo].[Orders] WITH (NOLOCK)
   WHERE OrderKey = @c_OrderKey


   IF @b_Debug = 1
   BEGIN
      PRINT ' @c_TaskBatchID: ' + @c_TaskBatchID
      PRINT ' @c_OrderKey: ' + @c_OrderKey
      PRINT ' @c_StorerKey: ' + @c_StorerKey
      PRINT ' @c_Facility: ' + @c_Facility
   END
   
   IF @b_IsLastCarton = 1 AND dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'PackUpdateEstTotalCtn') = '1' 
   BEGIN
      SELECT @n_TotalCarton = ISNULL(MAX(CartonNo), 0)
      FROM [dbo].[PackDetail] WITH (NOLOCK) 
      WHERE PickSlipNo = @c_PickSlipNo

      SELECT @n_EstimateTotalCtn = ISNULL(EstimateTotalCtn, 0 )
      FROM [dbo].[PackHeader] WITH (NOLOCK) 
      WHERE PickSlipNo = @c_PickSlipNo

      IF @b_Debug = 1
      BEGIN
         PRINT '@n_TotalCarton = ' + CONVERT(NVARCHAR(5), @n_TotalCarton)
         PRINT '@n_EstimateTotalCtn = ' + CONVERT(NVARCHAR(5), @n_EstimateTotalCtn)
      END

      IF @n_TotalCarton <> @n_EstimateTotalCtn
      BEGIN
         --Skip print last carton if estimated != actual carton number
         GOTO GENERATE_OUTPUT
      END
   END

   IF dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'EPACKCloseCartonPrint')  <> '1'  
      AND dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'EPACKNewCartonSkipPrint')  = '1'
   BEGIN
      GOTO GENERATE_OUTPUT
   END

   IF @b_Debug = 1
   BEGIN
      PRINT '>>>>>>> Report Printing (START)'
   END

   DECLARE C_Pack_CloseCartonPrint CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT COUNT(1) As TotalWMRDetail
            ,RH.ReportID   
      FROM [dbo].[WMReport] RH(nolock)   
      JOIN [dbo].[WMREPORTDETAIL] RD(NOLOCK) ON(RH.ReportID = RD.ReportID)  
      WHERE RH.ModuleID = 'EPACKING' 
      AND RD.AutoPrint = 'Y'
      AND RD.StorerKey = @c_StorerKey
      AND ISNULL(RD.Facility,'') IN('',@c_Facility)  
      GROUP BY RH.ReportID

   OPEN C_Pack_CloseCartonPrint
   FETCH NEXT FROM C_Pack_CloseCartonPrint INTO @n_TotalWMRDetail, @c_ReportID
   WHILE @@FETCH_STATUS <> -1   
   BEGIN
         SET @c_PrintSource         = 'WMReport'        --(Alex02)
         SET @c_IsPaperPrinter      = ''
         SET @c_DefaultPrinterID    = ''
         SET @b_sp_Success          = 0
         SET @n_sp_err              = 0
         SET @c_sp_errmsg           = ''

         --If Close Carton Print turn on
         IF [API].[fnc_IsCloseCartonPrintReport](@c_ReportID) <> 1
         BEGIN
            GOTO NEXT_RECORD
         END

         IF @n_TotalWMRDetail = 1
         BEGIN
            SELECT @c_IsPaperPrinter   = CASE 
                                           WHEN ISNULL(RTRIM(IsPaperPrinter),'') IN ('Y', '1') THEN 'Y' 
                                           WHEN ISNULL(RTRIM(IsPaperPrinter),'') IN ('N', '0') THEN 'N' 
                                           ELSE '' 
                                         END
                  ,@c_DefaultPrinterID = ISNULL(RTRIM(DefaultPrinterID), '')
                  ,@c_PrintSource      = CASE 
                                           WHEN  ISNULL(RTRIM(PrintType),'') = 'LOGIReport' THEN 'JReport' 
                                           ELSE 'WMReport'
                                         END                    --(Alex02)
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
         END

         IF @b_Debug = 1
         BEGIN
            PRINT '--------------'
            PRINT '@c_ReportID = ' + @c_ReportID
            PRINT '@c_IsPaperPrinter = ' + @c_IsPaperPrinter
            PRINT '@c_DefaultPrinterID = ' + @c_DefaultPrinterID
         END

         EXEC [API].[isp_ECOMP_GetReportParamValue] 
              @b_Debug                    = @b_Debug
            , @c_ReportID                 = @c_ReportID
            , @c_PickSlipNo               = @c_PickSlipNo
            , @c_StorerKey                = @c_StorerKey
            , @c_Facility                 = @c_Facility
            , @n_FromCarton               = @n_CartonNo 
            , @n_ToCarton                 = @n_CartonNo   
            , @c_KeyValue1                = @c_KeyValue1       OUTPUT
            , @c_KeyValue2                = @c_KeyValue2       OUTPUT
            , @c_KeyValue3                = @c_KeyValue3       OUTPUT
            , @c_KeyValue4                = @c_KeyValue4       OUTPUT
            , @c_KeyValue5                = @c_KeyValue5       OUTPUT
            , @c_KeyValue6                = @c_KeyValue6       OUTPUT
            , @c_KeyValue7                = @c_KeyValue7       OUTPUT
            , @c_KeyValue8                = @c_KeyValue8       OUTPUT
            , @c_KeyValue9                = @c_KeyValue9       OUTPUT
            , @c_KeyValue10               = @c_KeyValue10      OUTPUT
            , @c_KeyValue11               = @c_KeyValue11      OUTPUT
            , @c_KeyValue12               = @c_KeyValue12      OUTPUT
            , @c_KeyValue13               = @c_KeyValue13      OUTPUT
            , @c_KeyValue14               = @c_KeyValue14      OUTPUT
            , @c_KeyValue15               = @c_KeyValue15      OUTPUT
            , @b_RecordExists             = @b_RecordExists    OUTPUT
            , @b_Success                  = @b_sp_Success      OUTPUT
            , @n_ErrNo                    = @n_sp_err          OUTPUT
            , @c_ErrMsg                   = @c_sp_errmsg       OUTPUT
         
         IF @b_RecordExists = 0
         BEGIN 
            GOTO NEXT_RECORD
         END

         IF @b_sp_Success <> 1
         BEGIN
            SET @n_Continue = 3
            SET @n_ErrNo  = 54103
            SET @c_ErrMsg = CONVERT(char(5),@n_ErrNo)+': ' 
                          + CONVERT(char(5),@n_sp_err) + ' - Failed to get report parameter value. \n ' + @c_sp_errmsg     
            GOTO QUIT
         END

         IF @b_Debug = 1
         BEGIN
            PRINT '@c_KeyValue1  = ' + @c_KeyValue1 
            PRINT '@c_KeyValue2  = ' + @c_KeyValue2 
            PRINT '@c_KeyValue3  = ' + @c_KeyValue3 
            PRINT '@c_KeyValue4  = ' + @c_KeyValue4 
            PRINT '@c_KeyValue5  = ' + @c_KeyValue5 
            PRINT '@c_KeyValue6  = ' + @c_KeyValue6 
            PRINT '@c_KeyValue7  = ' + @c_KeyValue7 
            PRINT '@c_KeyValue8  = ' + @c_KeyValue8 
            PRINT '@c_KeyValue9  = ' + @c_KeyValue9 
            PRINT '@c_KeyValue10 = ' + @c_KeyValue10
            PRINT '@c_KeyValue11 = ' + @c_KeyValue11
            PRINT '@c_KeyValue12 = ' + @c_KeyValue12
            PRINT '@c_KeyValue13 = ' + @c_KeyValue13
            PRINT '@c_KeyValue14 = ' + @c_KeyValue14
            PRINT '@c_KeyValue15 = ' + @c_KeyValue15
         END

         SET @b_sp_Success    = 0
         SET @n_sp_err        = 0
         SET @c_sp_errmsg     = ''

         --Execute Print
         EXEC [WM].[lsp_WM_Print_Report] 
            @c_ModuleID             = N'EPACKING',         
            @c_ReportID             = @c_ReportID,         
            @c_Storerkey            = @c_StorerKey,        
            @c_Facility             = @c_Facility,         
            @c_UserName             = @c_UserID,           
            @c_ComputerName         = @c_ComputerName, --Alex01                
            @c_PrinterID            = @c_DefaultPrinterID,          
            @n_NoOfCopy             = 1,                   
            @c_IsPaperPrinter       = @c_IsPaperPrinter,       
            @c_KeyValue1            = @c_KeyValue1,            
            @c_KeyValue2            = @c_KeyValue2,            
            @c_KeyValue3            = @c_KeyValue3,            
            @c_KeyValue4            = @c_KeyValue4,            
            @c_KeyValue5            = @c_KeyValue5,            
            @c_KeyValue6            = @c_KeyValue6,            
            @c_KeyValue7            = @c_KeyValue7,            
            @c_KeyValue8            = @c_KeyValue8,            
            @c_KeyValue9            = @c_KeyValue9,            
            @c_KeyValue10           = @c_KeyValue10,           
            @c_KeyValue11           = @c_KeyValue11,           
            @c_KeyValue12           = @c_KeyValue12,           
            @c_KeyValue13           = @c_KeyValue13,           
            @c_KeyValue14           = @c_KeyValue14,           
            @c_KeyValue15           = @c_KeyValue15,           
            @c_ExtendedParmValue1   = N'',    
            @c_ExtendedParmValue2   = N'',    
            @c_ExtendedParmValue3   = N'',    
            @c_ExtendedParmValue4   = N'',    
            @c_ExtendedParmValue5   = N'',    
            @b_Success              = @b_sp_Success      OUTPUT,
            @n_Err                  = @n_sp_err          OUTPUT,
            @c_ErrMsg               = @c_sp_errmsg       OUTPUT,
            @c_PrintSource          = @c_PrintSource,                          --(Alex02)
            @b_SCEPreView           = 0,         
            @c_JobIDs               = @c_JobID           OUTPUT, 
            @c_AutoPrint            = N'Y'

         IF @b_sp_Success <> 1
         BEGIN
            SET @n_Continue = 3      
            SET @n_ErrNo = 54104      
            SET @c_ErrMsg = CONVERT(char(5),@n_ErrNo)+': ' 
                          + CONVERT(char(5),@n_sp_err) + ' - Report(' + @c_ReportID + ') print failed. \n ' + @c_sp_errmsg     
            GOTO QUIT  
         END

         IF @c_JobIDs <> '' AND @c_JobID <> ''
         BEGIN
            SET @c_JobIDs = @c_JobIDs + ',' + REPLACE(@c_JobID,'|',',')
         END
         ELSE IF @c_JobIDs = ''
         BEGIN
            --SET @c_JobIDs = @c_JobID --(AL03)
            SET @c_JobIDs = REPLACE(@c_JobID,'|',',') --(AL03)
         END

         NEXT_RECORD:   --(AL01) 
         FETCH NEXT FROM C_Pack_CloseCartonPrint INTO @n_TotalWMRDetail, @c_ReportID
      END
   CLOSE C_Pack_CloseCartonPrint  
   DEALLOCATE C_Pack_CloseCartonPrint


   IF @b_Debug = 1
   BEGIN
      PRINT '>>>>>>> Report Printing (Completed)'
   END

   GENERATE_OUTPUT: 
   SET @c_ResponseString = ISNULL(( 
                              SELECT CAST ( 1 AS BIT ) AS 'Success', JSON_QUERY('[' + @c_JobIDs + N']') AS 'PrintJobIDs' FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                           ), '')

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