SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/              
/* Store procedure: [API].[isp_ECOMP_API_GetReportParam]                */              
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
/* Date           Author   Purposes                                     */
/* 12-May-2023    Allen     #JIRA PAC-65 Initial                        */
/* 19-May-2023    Alex     Enhancement                                  */
/* 22-May-2023    Alex     Rename sp to isp_ECOMP_API_GetReportParam    */
/************************************************************************/  
  
CREATE   PROC [API].[isp_ECOMP_API_GetReportParam](  
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
         , @n_ReportRowID                 INT            = 0
         , @c_ReportID                    NVARCHAR(10)   = ''  
         , @c_PickSlipNo                  NVARCHAR(10)   = ''  
  
         , @c_StorerKey                   NVARCHAR(15)   = ''  
         , @c_Facility                    NVARCHAR(15)   = ''  
         , @c_TaskBatchNo                 NVARCHAR(10)   = ''  
         , @c_OrderKey                    NVARCHAR(10)   = ''  
         , @n_IsExist                     INT            = 0

         , @b_sp_Success                  INT  
         , @n_sp_err                      INT  
         , @c_sp_errmsg                   NVARCHAR(250)= ''  
  
         --, @c_KeyFieldName1               NVARCHAR(200)  = ''  
         --, @c_KeyFieldName2               NVARCHAR(200)  = ''  
         --, @c_KeyFieldName3               NVARCHAR(200)  = ''  
         --, @c_KeyFieldName4               NVARCHAR(200)  = ''  
         --, @c_KeyFieldName5               NVARCHAR(200)  = ''  
         --, @c_KeyFieldName6               NVARCHAR(200)  = ''  
         --, @c_KeyFieldName7               NVARCHAR(200)  = ''  
         --, @c_KeyFieldName8               NVARCHAR(200)  = ''  
         --, @c_KeyFieldName9               NVARCHAR(200)  = ''  
         --, @c_KeyFieldName10              NVARCHAR(200)  = ''  
         --, @c_KeyFieldName11              NVARCHAR(200)  = ''  
         --, @c_KeyFieldName12              NVARCHAR(200)  = ''  
         --, @c_KeyFieldName13              NVARCHAR(200)  = ''  
         --, @c_KeyFieldName14              NVARCHAR(200)  = ''  
         --, @c_KeyFieldName15              NVARCHAR(200)  = ''  
         , @c_H_KeyFieldName1             NVARCHAR(200)  = ''  
         , @c_H_KeyFieldName2             NVARCHAR(200)  = ''  
         , @c_H_KeyFieldName3             NVARCHAR(200)  = ''  
         , @c_H_KeyFieldName4             NVARCHAR(200)  = ''  
         , @c_H_KeyFieldName5             NVARCHAR(200)  = ''  
         , @c_H_KeyFieldName6             NVARCHAR(200)  = ''  
         , @c_H_KeyFieldName7             NVARCHAR(200)  = ''  
         , @c_H_KeyFieldName8             NVARCHAR(200)  = ''  
         , @c_H_KeyFieldName9             NVARCHAR(200)  = ''  
         , @c_H_KeyFieldName10            NVARCHAR(200)  = ''  
         , @c_H_KeyFieldName11            NVARCHAR(200)  = ''  
         , @c_H_KeyFieldName12            NVARCHAR(200)  = ''  
         , @c_H_KeyFieldName13            NVARCHAR(200)  = ''  
         , @c_H_KeyFieldName14            NVARCHAR(200)  = ''  
         , @c_H_KeyFieldName15            NVARCHAR(200)  = ''  
         , @c_KeyFieldParmLabel1          NVARCHAR(200)  = ''
         , @c_KeyFieldParmLabel2          NVARCHAR(200)  = ''
         , @c_KeyFieldParmLabel3          NVARCHAR(200)  = ''
         , @c_KeyFieldParmLabel4          NVARCHAR(200)  = ''
         , @c_KeyFieldParmLabel5          NVARCHAR(200)  = ''
         , @c_KeyFieldParmLabel6          NVARCHAR(200)  = ''
         , @c_KeyFieldParmLabel7          NVARCHAR(200)  = ''
         , @c_KeyFieldParmLabel8          NVARCHAR(200)  = ''
         , @c_KeyFieldParmLabel9          NVARCHAR(200)  = ''
         , @c_KeyFieldParmLabel10         NVARCHAR(200)  = ''
         , @c_KeyFieldParmLabel11         NVARCHAR(200)  = ''
         , @c_KeyFieldParmLabel12         NVARCHAR(200)  = ''
         , @c_KeyFieldParmLabel13         NVARCHAR(200)  = ''
         , @c_KeyFieldParmLabel14         NVARCHAR(200)  = ''
         , @c_KeyFieldParmLabel15         NVARCHAR(200)  = ''
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
         --, @c_ExecStatements              NVARCHAR(MAX)  = ''  
         --, @c_ExecArguments               NVARCHAR(MAX)  = ''  
         --, @c_ExecGroupByStatements       NVARCHAR(500)  = ''
         --, @c_ResponseString1             NVARCHAR(MAX)  = '' 
         --, @n_ExistedCartonNo             INT            = 0    
         , @n_FromCarton                  INT            = 0           
         , @n_ToCarton                    INT            = 0           
    
   SET @b_Success                         = 0  
   SET @n_ErrNo                           = 0  
   SET @c_ErrMsg                          = ''  
   SET @c_ResponseString                  = ''  
  
   --Change Login User  
   --SET @n_sp_err = 0       
   --EXEC [WM].[lsp_SetUser] @c_UserName = @c_UserID OUTPUT, @n_Err = @n_sp_err OUTPUT, @c_ErrMsg = @c_sp_errmsg OUTPUT      
         
   --EXECUTE AS LOGIN = @c_UserID      
         
   --IF @n_sp_err <> 0       
   --BEGIN        
   --   SET @n_Continue = 3        
   --   SET @n_ErrNo = @n_sp_err        
   --   SET @c_ErrMsg = @c_sp_errmsg       
   --   GOTO QUIT        
   --END    
     
   SELECT @c_StorerKey     = ISNULL(RTRIM(StorerKey      ), '')  
         ,@c_Facility      = ISNULL(RTRIM(Facility       ), '')  
         ,@c_ComputerName  = ISNULL(RTRIM(ComputerName   ), '')  
         ,@c_ReportID    = ISNULL(RTRIM(ReportID), '')   --Alex
         --,@n_ReportRowID   = ReportRowID
         ,@c_PickSlipNo    = ISNULL(RTRIM(PickSlipNo     ), '')
         ,@n_FromCarton    = FromCarton
         ,@n_ToCarton      = ToCarton
   FROM OPENJSON (@c_RequestString)  
   WITH (   
      StorerKey         NVARCHAR(15)         '$.StorerKey',  
      Facility          NVARCHAR(15)         '$.Facility',  
      ComputerName      NVARCHAR(30)         '$.ComputerName',   
      ReportID          NVARCHAR(10)         '$.ReportID', --Alex
      --ReportRowID       INT                  '$.ReportRowID',
      PickSlipNo        NVARCHAR(30)         '$.PickSlipNo',
      FromCarton        INT                  '$.FromCarton',
      ToCarton          INT                  '$.ToCarton'
   )    
  
   SELECT @n_IsExist             = (1)
         --,@c_KeyFieldName1       = ISNULL(RH.KeyFieldName1,'')  
         --,@c_KeyFieldName2       = ISNULL(RH.KeyFieldName2,'')  
         --,@c_KeyFieldName3       = ISNULL(RH.KeyFieldName3,'')  
         --,@c_KeyFieldName4       = ISNULL(RH.KeyFieldName4,'')  
         --,@c_KeyFieldName5       = ISNULL(RH.KeyFieldName5,'')  
         --,@c_KeyFieldName6       = ISNULL(RH.KeyFieldName6,'')  
         --,@c_KeyFieldName7       = ISNULL(RH.KeyFieldName7,'')  
         --,@c_KeyFieldName8       = ISNULL(RH.KeyFieldName8,'')  
         --,@c_KeyFieldName9       = ISNULL(RH.KeyFieldName9,'')  
         --,@c_KeyFieldName10      = ISNULL(RH.KeyFieldName10,'')  
         --,@c_KeyFieldName11      = ISNULL(RH.KeyFieldName11,'')  
         --,@c_KeyFieldName12      = ISNULL(RH.KeyFieldName12,'')  
         --,@c_KeyFieldName13      = ISNULL(RH.KeyFieldName13,'')  
         --,@c_KeyFieldName14      = ISNULL(RH.KeyFieldName14,'')  
         --,@c_KeyFieldName15      = ISNULL(RH.KeyFieldName15,'')  
         ,@c_H_KeyFieldName1     = ISNULL(RH.KeyFieldName1,'')  
         ,@c_H_KeyFieldName2     = ISNULL(RH.KeyFieldName2,'')  
         ,@c_H_KeyFieldName3     = ISNULL(RH.KeyFieldName3,'')  
         ,@c_H_KeyFieldName4     = ISNULL(RH.KeyFieldName4,'')  
         ,@c_H_KeyFieldName5     = ISNULL(RH.KeyFieldName5,'')  
         ,@c_H_KeyFieldName6     = ISNULL(RH.KeyFieldName6,'')  
         ,@c_H_KeyFieldName7     = ISNULL(RH.KeyFieldName7,'')  
         ,@c_H_KeyFieldName8     = ISNULL(RH.KeyFieldName8,'')  
         ,@c_H_KeyFieldName9     = ISNULL(RH.KeyFieldName9,'')  
         ,@c_H_KeyFieldName10    = ISNULL(RH.KeyFieldName10,'')  
         ,@c_H_KeyFieldName11    = ISNULL(RH.KeyFieldName11,'')  
         ,@c_H_KeyFieldName12    = ISNULL(RH.KeyFieldName12,'')  
         ,@c_H_KeyFieldName13    = ISNULL(RH.KeyFieldName13,'')  
         ,@c_H_KeyFieldName14    = ISNULL(RH.KeyFieldName14,'')  
         ,@c_H_KeyFieldName15    = ISNULL(RH.KeyFieldName15,'')  
         ,@c_KeyFieldParmLabel1  = ISNULL(RH.KeyFieldParmLabel1,'')
         ,@c_KeyFieldParmLabel2  = ISNULL(RH.KeyFieldParmLabel2,'')
         ,@c_KeyFieldParmLabel3  = ISNULL(RH.KeyFieldParmLabel3,'')
         ,@c_KeyFieldParmLabel4  = ISNULL(RH.KeyFieldParmLabel4,'')
         ,@c_KeyFieldParmLabel5  = ISNULL(RH.KeyFieldParmLabel5,'')
         ,@c_KeyFieldParmLabel6  = ISNULL(RH.KeyFieldParmLabel6,'')
         ,@c_KeyFieldParmLabel7  = ISNULL(RH.KeyFieldParmLabel7,'')
         ,@c_KeyFieldParmLabel8  = ISNULL(RH.KeyFieldParmLabel8,'')
         ,@c_KeyFieldParmLabel9  = ISNULL(RH.KeyFieldParmLabel9,'')
         ,@c_KeyFieldParmLabel10 = ISNULL(RH.KeyFieldParmLabel10,'')
         ,@c_KeyFieldParmLabel11 = ISNULL(RH.KeyFieldParmLabel11,'')
         ,@c_KeyFieldParmLabel12 = ISNULL(RH.KeyFieldParmLabel12,'')
         ,@c_KeyFieldParmLabel13 = ISNULL(RH.KeyFieldParmLabel13,'')
         ,@c_KeyFieldParmLabel14 = ISNULL(RH.KeyFieldParmLabel14,'')
         ,@c_KeyFieldParmLabel15 = ISNULL(RH.KeyFieldParmLabel15,'')
   FROM dbo.WMReport RH(nolock)   
   WHERE ModuleID = 'EPACKING'
   AND ReportID = @c_ReportID

   IF @n_IsExist <> 1
   BEGIN
      SET @n_Continue = 3
      SET @n_ErrNo  = 53001
      SET @c_ErrMsg = 'Invalid Report Row ID - ' + CONVERT(NVARCHAR(15), @n_ReportRowID)
   END
   EXEC [API].[isp_ECOMP_GetReportParamValue] 
        @b_Debug                    = 1
      , @c_ReportID                 = @c_ReportID
      , @c_PickSlipNo               = @c_PickSlipNo
      , @c_StorerKey                = @c_StorerKey
      , @c_Facility                 = @c_Facility
      , @n_FromCarton               = @n_FromCarton 
      , @n_ToCarton                 = @n_ToCarton   
      , @c_KeyValue1                = @c_KeyValue1   OUTPUT
      , @c_KeyValue2                = @c_KeyValue2   OUTPUT
      , @c_KeyValue3                = @c_KeyValue3   OUTPUT
      , @c_KeyValue4                = @c_KeyValue4   OUTPUT
      , @c_KeyValue5                = @c_KeyValue5   OUTPUT
      , @c_KeyValue6                = @c_KeyValue6   OUTPUT
      , @c_KeyValue7                = @c_KeyValue7   OUTPUT
      , @c_KeyValue8                = @c_KeyValue8   OUTPUT
      , @c_KeyValue9                = @c_KeyValue9   OUTPUT
      , @c_KeyValue10               = @c_KeyValue10  OUTPUT
      , @c_KeyValue11               = @c_KeyValue11  OUTPUT
      , @c_KeyValue12               = @c_KeyValue12  OUTPUT
      , @c_KeyValue13               = @c_KeyValue13  OUTPUT
      , @c_KeyValue14               = @c_KeyValue14  OUTPUT
      , @c_KeyValue15               = @c_KeyValue15  OUTPUT
      , @b_Success                  = @b_Success     OUTPUT
      , @n_ErrNo                    = @n_ErrNo       OUTPUT
      , @c_ErrMsg                   = @c_ErrMsg      OUTPUT

   IF @b_Success <> 1
   BEGIN
      SET @n_Continue = 3
      SET @n_ErrNo  = 53002
      GOTO QUIT
   END

   SET @c_ResponseString = ISNULL(( 
                           SELECT 
                              JSON_QUERY((
                                 SELECT @c_H_KeyFieldName1        [KeyFieldName1] 
                                       ,@c_H_KeyFieldName2        [KeyFieldName2] 
                                       ,@c_H_KeyFieldName3        [KeyFieldName3] 
                                       ,@c_H_KeyFieldName4        [KeyFieldName4] 
                                       ,@c_H_KeyFieldName5        [KeyFieldName5] 
                                       ,@c_H_KeyFieldName6        [KeyFieldName6] 
                                       ,@c_H_KeyFieldName7        [KeyFieldName7] 
                                       ,@c_H_KeyFieldName8        [KeyFieldName8] 
                                       ,@c_H_KeyFieldName9        [KeyFieldName9] 
                                       ,@c_H_KeyFieldName10       [KeyFieldName10]
                                       ,@c_H_KeyFieldName11       [KeyFieldName11]
                                       ,@c_H_KeyFieldName12       [KeyFieldName12]
                                       ,@c_H_KeyFieldName13       [KeyFieldName13]
                                       ,@c_H_KeyFieldName14       [KeyFieldName14]
                                       ,@c_H_KeyFieldName15       [KeyFieldName15]
                                       ,@c_KeyFieldParmLabel1     [KeyFieldParmLabel1] 
                                       ,@c_KeyFieldParmLabel2     [KeyFieldParmLabel2] 
                                       ,@c_KeyFieldParmLabel3     [KeyFieldParmLabel3] 
                                       ,@c_KeyFieldParmLabel4     [KeyFieldParmLabel4] 
                                       ,@c_KeyFieldParmLabel5     [KeyFieldParmLabel5] 
                                       ,@c_KeyFieldParmLabel6     [KeyFieldParmLabel6] 
                                       ,@c_KeyFieldParmLabel7     [KeyFieldParmLabel7] 
                                       ,@c_KeyFieldParmLabel8     [KeyFieldParmLabel8] 
                                       ,@c_KeyFieldParmLabel9     [KeyFieldParmLabel9] 
                                       ,@c_KeyFieldParmLabel10    [KeyFieldParmLabel10]
                                       ,@c_KeyFieldParmLabel11    [KeyFieldParmLabel11]
                                       ,@c_KeyFieldParmLabel12    [KeyFieldParmLabel12]
                                       ,@c_KeyFieldParmLabel13    [KeyFieldParmLabel13]
                                       ,@c_KeyFieldParmLabel14    [KeyFieldParmLabel14]
                                       ,@c_KeyFieldParmLabel15    [KeyFieldParmLabel15]
                                       ,@c_KeyValue1              [KeyFieldValue1] 
                                       ,@c_KeyValue2              [KeyFieldValue2] 
                                       ,@c_KeyValue3              [KeyFieldValue3] 
                                       ,@c_KeyValue4              [KeyFieldValue4] 
                                       ,@c_KeyValue5              [KeyFieldValue5] 
                                       ,@c_KeyValue6              [KeyFieldValue6] 
                                       ,@c_KeyValue7              [KeyFieldValue7] 
                                       ,@c_KeyValue8              [KeyFieldValue8] 
                                       ,@c_KeyValue9              [KeyFieldValue9] 
                                       ,@c_KeyValue10             [KeyFieldValue10]
                                       ,@c_KeyValue11             [KeyFieldValue11]
                                       ,@c_KeyValue12             [KeyFieldValue12]
                                       ,@c_KeyValue13             [KeyFieldValue13]
                                       ,@c_KeyValue14             [KeyFieldValue14]
                                       ,@c_KeyValue15             [KeyFieldValue15]
                                       --,@n_FromCarton             [FromCartton]
                                       --,@n_ToCarton               [ToCartton]
                                 FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                              )) As 'KeyFields'
                           FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
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