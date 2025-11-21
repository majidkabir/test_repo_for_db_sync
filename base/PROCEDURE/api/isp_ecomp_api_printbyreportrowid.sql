SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/              
/* Store procedure: [API].[isp_ECOMP_API_PrintByReportRowID]            */              
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
/* 10-Jul-2023    Allen     #JIRA PAC-7 Add CartonNo param   --(AL01)   */
/************************************************************************/    
CREATE   PROC [API].[isp_ECOMP_API_PrintByReportRowID] (
     @b_Debug           INT            = 0
   , @c_UserID          NVARCHAR(256)  = ''
   , @n_ReportDetRowID  INT            = 0
   , @c_PrintID         NVARCHAR(30)   = ''
   , @c_PickSlipNo      NVARCHAR(10)   = ''
   , @c_StorerKey       NVARCHAR(15)   = ''
   , @c_Facility        NVARCHAR(15)   = ''
   , @n_CartonNo        INT            = 0
   , @b_Success         INT            = 0   OUTPUT
   , @n_ErrNo           INT            = 0   OUTPUT
   , @c_ErrMsg          NVARCHAR(250)  = ''  OUTPUT
   , @c_JobID           NVARCHAR(50)   = ''  OUTPUT
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

         --, @c_PickSlipNo                  NVARCHAR(10)   = ''

         --, @c_StorerKey                   NVARCHAR(15)   = ''
         --, @c_Facility                    NVARCHAR(15)   = ''

         , @c_ReportID                    NVARCHAR(10)   = ''
         , @c_PrintType                   NVARCHAR(10)   = ''
         , @c_KeyFieldName1               NVARCHAR(200)  = ''
         , @c_KeyFieldName2               NVARCHAR(200)  = ''
         , @c_KeyFieldName3               NVARCHAR(200)  = ''
         , @c_KeyFieldName4               NVARCHAR(200)  = ''
         , @c_KeyFieldName5               NVARCHAR(200)  = ''
         , @c_KeyFieldName6               NVARCHAR(200)  = ''
         , @c_KeyFieldName7               NVARCHAR(200)  = ''
         , @c_KeyFieldName8               NVARCHAR(200)  = ''
         , @c_KeyFieldName9               NVARCHAR(200)  = ''
         , @c_KeyFieldName10              NVARCHAR(200)  = ''
         , @c_KeyFieldName11              NVARCHAR(200)  = ''
         , @c_KeyFieldName12              NVARCHAR(200)  = ''
         , @c_KeyFieldName13              NVARCHAR(200)  = ''
         , @c_KeyFieldName14              NVARCHAR(200)  = ''
         , @c_KeyFieldName15              NVARCHAR(200)  = ''
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
         --, @c_PrintID                     NVARCHAR(30)   = ''
         , @n_IsExists                    INT            = 0

         --, @c_JobID                       NVARCHAR(50)   = ''
         , @c_JobIDs                      NVARCHAR(max)  = ''
         , @c_IsPaperPrinter              NVARCHAR(1)    = ''
         , @b_sp_Success                  INT
         , @n_sp_err                      INT
         , @c_sp_errmsg                   NVARCHAR(250)  = ''
         , @c_ExecStatements              NVARCHAR(max)  = ''
         , @c_ExecArguments               NVARCHAR(max)  = ''
         , @c_ExecGroupByStatements       NVARCHAR(500)  = ''
         , @n_ExistedCartonNo             INT            = 0    
         , @n_Exist                       INT            = 0   --(AL01)
           
   --DECLARE @n_CartonNo                    INT            = 0   --(AL01)
         

   SET @b_Success                         = 0
   SET @n_ErrNo                           = 0
   SET @c_ErrMsg                          = ''

   SELECT @n_IsExists       = (1)
         ,@c_ReportID       = ISNULL(RH.ReportID,'') 
         ,@c_PrintType      = ISNULL(RD.PrintType,'')
         ,@c_KeyFieldName1  = ISNULL(RH.KeyFieldName1,'')
         ,@c_KeyFieldName2  = ISNULL(RH.KeyFieldName2,'')
         ,@c_KeyFieldName3  = ISNULL(RH.KeyFieldName3,'')
         ,@c_KeyFieldName4  = ISNULL(RH.KeyFieldName4,'')
         ,@c_KeyFieldName5  = ISNULL(RH.KeyFieldName5,'')
         ,@c_KeyFieldName6  = ISNULL(RH.KeyFieldName6,'')
         ,@c_KeyFieldName7  = ISNULL(RH.KeyFieldName7,'')
         ,@c_KeyFieldName8  = ISNULL(RH.KeyFieldName8,'')
         ,@c_KeyFieldName9  = ISNULL(RH.KeyFieldName9,'')
         ,@c_KeyFieldName10 = ISNULL(RH.KeyFieldName10,'')
         ,@c_KeyFieldName11 = ISNULL(RH.KeyFieldName11,'')
         ,@c_KeyFieldName12 = ISNULL(RH.KeyFieldName12,'')
         ,@c_KeyFieldName13 = ISNULL(RH.KeyFieldName13,'')
         ,@c_KeyFieldName14 = ISNULL(RH.KeyFieldName14,'')
         ,@c_KeyFieldName15 = ISNULL(RH.KeyFieldName15,'')
         ,@c_IsPaperPrinter = CASE WHEN RD.PrintType = 'TCPSPooler' THEN 'Y' ELSE 'N' END
   FROM dbo.WMREPORT RH(NOLOCK) 
   JOIN dbo.WMREPORTDETAIL RD(NOLOCK) ON(RH.ReportID = RD.ReportID)
   WHERE RD.RowID = @n_ReportDetRowID

   IF @n_IsExists <> 1
   BEGIN
      SET @n_Continue = 3      
      SET @n_ErrNo = 54001
      SET @c_ErrMsg = CONVERT(char(5),@n_ErrNo)+': WMREPORTDETAIL.RowRefNo(' + CONVERT(NVARCHAR, @n_ReportDetRowID) + ') is not found.'
      GOTO QUIT  
   END

   SET @n_ExistedCartonNo = 0
   
   IF CHARINDEX('PACKDETAIL.CartonNo',@c_KeyFieldName1) > 0
   BEGIN
      SET @c_KeyFieldName1 = 'MIN('+@c_KeyFieldName1+')'  
      SET @n_ExistedCartonNo = 1  
   END
   IF CHARINDEX('PACKDETAIL.CartonNo',@c_KeyFieldName2) > 0
   BEGIN
      IF @n_ExistedCartonNo > 0
      BEGIN
         SET @c_KeyFieldName2 = 'MAX('+@c_KeyFieldName2+')' 
      END
      ELSE
      BEGIN
         SET @c_KeyFieldName2 = 'MIN('+@c_KeyFieldName2+')' 
         SET @n_ExistedCartonNo = 1   
      END
   END
   IF CHARINDEX('PACKDETAIL.CartonNo',@c_KeyFieldName3) > 0
   BEGIN
      IF @n_ExistedCartonNo > 0
      BEGIN
         SET @c_KeyFieldName3 = 'MAX('+@c_KeyFieldName3+')' 
      END
      ELSE
      BEGIN
         SET @c_KeyFieldName3 = 'MIN('+@c_KeyFieldName3+')' 
         SET @n_ExistedCartonNo = 1   
      END
   END
   IF CHARINDEX('PACKDETAIL.CartonNo',@c_KeyFieldName4) > 0
   BEGIN
      IF @n_ExistedCartonNo > 0
      BEGIN
         SET @c_KeyFieldName4 = 'MAX('+@c_KeyFieldName4+')' 
      END
      ELSE
      BEGIN
         SET @c_KeyFieldName4 = 'MIN('+@c_KeyFieldName4+')' 
         SET @n_ExistedCartonNo = 1   
      END
   END
   IF CHARINDEX('PACKDETAIL.CartonNo',@c_KeyFieldName5) > 0
   BEGIN
      IF @n_ExistedCartonNo > 0
      BEGIN
         SET @c_KeyFieldName5 = 'MAX('+@c_KeyFieldName5+')' 
      END
      ELSE
      BEGIN
         SET @c_KeyFieldName5 = 'MIN('+@c_KeyFieldName5+')' 
         SET @n_ExistedCartonNo = 1   
      END
   END
   IF CHARINDEX('PACKDETAIL.CartonNo',@c_KeyFieldName6) > 0
   BEGIN
      IF @n_ExistedCartonNo > 0
      BEGIN
         SET @c_KeyFieldName6 = 'MAX('+@c_KeyFieldName6+')' 
      END
      ELSE
      BEGIN
         SET @c_KeyFieldName7 = 'MIN('+@c_KeyFieldName6+')' 
         SET @n_ExistedCartonNo = 1   
      END
   END
   IF CHARINDEX('PACKDETAIL.CartonNo',@c_KeyFieldName7) > 0
   BEGIN
      IF @n_ExistedCartonNo > 0
      BEGIN
         SET @c_KeyFieldName7 = 'MAX('+@c_KeyFieldName7+')' 
      END
      ELSE
      BEGIN
         SET @c_KeyFieldName7 = 'MIN('+@c_KeyFieldName7+')' 
         SET @n_ExistedCartonNo = 1   
      END
   END
   IF CHARINDEX('PACKDETAIL.CartonNo',@c_KeyFieldName8) > 0
   BEGIN
      IF @n_ExistedCartonNo > 0
      BEGIN
         SET @c_KeyFieldName8 = 'MAX('+@c_KeyFieldName8+')' 
      END
      ELSE
      BEGIN
         SET @c_KeyFieldName8 = 'MIN('+@c_KeyFieldName8+')' 
         SET @n_ExistedCartonNo = 1   
      END
   END
   IF CHARINDEX('PACKDETAIL.CartonNo',@c_KeyFieldName9) > 0
   BEGIN
      IF @n_ExistedCartonNo > 0
      BEGIN
         SET @c_KeyFieldName9 = 'MAX('+@c_KeyFieldName7+')' 
      END
      ELSE
      BEGIN
         SET @c_KeyFieldName9 = 'MIN('+@c_KeyFieldName9+')' 
         SET @n_ExistedCartonNo = 1   
      END
   END
   IF CHARINDEX('PACKDETAIL.CartonNo',@c_KeyFieldName10) > 0
   BEGIN
      IF @n_ExistedCartonNo > 0
      BEGIN
         SET @c_KeyFieldName10 = 'MAX('+@c_KeyFieldName10+')' 
      END
      ELSE
      BEGIN
         SET @c_KeyFieldName10 = 'MIN('+@c_KeyFieldName10+')' 
         SET @n_ExistedCartonNo = 1   
      END
   END
   IF CHARINDEX('PACKDETAIL.CartonNo',@c_KeyFieldName11) > 0
   BEGIN
      IF @n_ExistedCartonNo > 0
      BEGIN
         SET @c_KeyFieldName11 = 'MAX('+@c_KeyFieldName11+')' 
      END
      ELSE
      BEGIN
         SET @c_KeyFieldName11 = 'MIN('+@c_KeyFieldName11+')' 
         SET @n_ExistedCartonNo = 1   
      END
   END
   IF CHARINDEX('PACKDETAIL.CartonNo',@c_KeyFieldName12) > 0
   BEGIN
      IF @n_ExistedCartonNo > 0
      BEGIN
         SET @c_KeyFieldName12 = 'MAX('+@c_KeyFieldName12+')' 
      END
      ELSE
      BEGIN
         SET @c_KeyFieldName12 = 'MIN('+@c_KeyFieldName12+')' 
         SET @n_ExistedCartonNo = 1   
      END
   END
   IF CHARINDEX('PACKDETAIL.CartonNo',@c_KeyFieldName13) > 0
   BEGIN
      IF @n_ExistedCartonNo > 0
      BEGIN
         SET @c_KeyFieldName13 = 'MAX('+@c_KeyFieldName13+')' 
      END
      ELSE
      BEGIN
         SET @c_KeyFieldName13 = 'MIN('+@c_KeyFieldName13+')' 
         SET @n_ExistedCartonNo = 1   
      END
   END
   IF CHARINDEX('PACKDETAIL.CartonNo',@c_KeyFieldName14) > 0
   BEGIN
      IF @n_ExistedCartonNo > 0
      BEGIN
         SET @c_KeyFieldName14 = 'MAX('+@c_KeyFieldName14+')' 
      END
      ELSE
      BEGIN
         SET @c_KeyFieldName14 = 'MIN('+@c_KeyFieldName14+')' 
         SET @n_ExistedCartonNo = 1   
      END
   END
   IF CHARINDEX('PACKDETAIL.CartonNo',@c_KeyFieldName15) > 0
   BEGIN
      IF @n_ExistedCartonNo > 0
      BEGIN
         SET @c_KeyFieldName15 = 'MAX('+@c_KeyFieldName15+')' 
      END
      ELSE
      BEGIN
         SET @c_KeyFieldName15 = 'MIN('+@c_KeyFieldName15+')' 
         SET @n_ExistedCartonNo = 1   
      END
   END
   
   IF @b_Debug = 1
   BEGIN
     PRINT ' @c_ReportID: ' + @c_ReportID
     PRINT ' @c_PrintType: ' + @c_PrintType
     PRINT ' @c_KeyFieldName1: ' + @c_KeyFieldName1
     PRINT ' @c_KeyFieldName2: ' + @c_KeyFieldName2
     PRINT ' @c_KeyFieldName3: ' + @c_KeyFieldName3
     PRINT ' @c_KeyFieldName4: ' + @c_KeyFieldName4
     PRINT ' @c_KeyFieldName5: ' + @c_KeyFieldName5
     PRINT ' @c_KeyFieldName6: ' + @c_KeyFieldName6
     PRINT ' @c_KeyFieldName7: ' + @c_KeyFieldName7
     PRINT ' @c_KeyFieldName8: ' + @c_KeyFieldName8
     PRINT ' @c_KeyFieldName9: ' + @c_KeyFieldName9
     PRINT ' @c_KeyFieldName10: ' + @c_KeyFieldName10
   END
   
   SET @c_ExecStatements = ''
   SET @c_ExecGroupByStatements = ''
   SET @c_ExecArguments = ''
   
   SET @c_KeyValue1 = ''
   SET @c_KeyValue2 = ''
   SET @c_KeyValue3 = ''
   SET @c_KeyValue4 = ''
   SET @c_KeyValue5 = ''
   SET @c_KeyValue6 = ''
   SET @c_KeyValue7 = ''
   SET @c_KeyValue8 = ''
   SET @c_KeyValue9 = ''
   SET @c_KeyValue10 = ''
   SET @c_KeyValue11 = ''
   SET @c_KeyValue12 = ''
   SET @c_KeyValue13 = ''
   SET @c_KeyValue14 = ''
   SET @c_KeyValue15= ''
   SET @c_JobID = ''
   SET @n_Exist = 0
   
   SET @c_ExecStatements = 'SELECT @n_Exist = 1,' +   --(AL01) 
                                 ' @c_KeyValue1 = ' + CASE WHEN @c_KeyFieldName1 = '' THEN '''''' ELSE @c_KeyFieldName1 END +
                                 ',@c_KeyValue2 = ' + CASE WHEN @c_KeyFieldName2 = '' THEN '''''' ELSE @c_KeyFieldName2 END +
                                 ',@c_KeyValue3 = ' + CASE WHEN @c_KeyFieldName3 = '' THEN '''''' ELSE @c_KeyFieldName3 END +
                                 ',@c_KeyValue4 = ' + CASE WHEN @c_KeyFieldName4 = '' THEN '''''' ELSE @c_KeyFieldName4 END +
                                 ',@c_KeyValue5 = ' + CASE WHEN @c_KeyFieldName5 = '' THEN '''''' ELSE @c_KeyFieldName5 END +
                                 ',@c_KeyValue6 = ' + CASE WHEN @c_KeyFieldName6 = '' THEN '''''' ELSE @c_KeyFieldName6 END +
                                 ',@c_KeyValue7 = ' + CASE WHEN @c_KeyFieldName7 = '' THEN '''''' ELSE @c_KeyFieldName7 END +
                                 ',@c_KeyValue8 = ' + CASE WHEN @c_KeyFieldName8 = '' THEN '''''' ELSE @c_KeyFieldName8 END +
                                 ',@c_KeyValue9 = ' + CASE WHEN @c_KeyFieldName9 = '' THEN '''''' ELSE @c_KeyFieldName9 END +
                                 ',@c_KeyValue10 = ' + CASE WHEN @c_KeyFieldName10 = '' THEN '''''' ELSE @c_KeyFieldName10 END +
                                 ',@c_KeyValue11 = ' + CASE WHEN @c_KeyFieldName11 = '' THEN '''''' ELSE @c_KeyFieldName11 END +
                                 ',@c_KeyValue12 = ' + CASE WHEN @c_KeyFieldName12 = '' THEN '''''' ELSE @c_KeyFieldName12 END +
                                 ',@c_KeyValue13 = ' + CASE WHEN @c_KeyFieldName13 = '' THEN '''''' ELSE @c_KeyFieldName13 END +
                                 ',@c_KeyValue14 = ' + CASE WHEN @c_KeyFieldName14 = '' THEN '''''' ELSE @c_KeyFieldName14 END +
                                 ',@c_KeyValue15 = ' + CASE WHEN @c_KeyFieldName15 = '' THEN '''''' ELSE @c_KeyFieldName15 END +
                           ' FROM dbo.PackHeader PackHeader (NOLOCK)' +
                           ' JOIN dbo.PackDetail PackDetail (NOLOCK)' +
                           ' ON (PackDetail.PickSlipNo = PackHeader.PickSlipNo AND PackDetail.StorerKey = PackHeader.StorerKey)' +
                           ' JOIN dbo.PackInfo PackInfo (NOLOCK)' +
                           ' ON (PackInfo.PickSlipNo = PackHeader.PickSlipNo)' +
                           ' WHERE PackDetail.PickSlipNo = @c_PickSlipNo AND PackHeader.StorerKey = @c_StorerKey' 
                           + CASE WHEN @n_CartonNo = 0 THEN '' ELSE ' AND PackDetail.CartonNo = @n_CartonNo' END   --(AL01)
   
   IF @n_ExistedCartonNo = 1
   BEGIN
      SET @c_ExecGroupByStatements = 
                 CASE WHEN @c_KeyFieldName1 <> '' AND CHARINDEX('PACKDETAIL.CartonNo',@c_KeyFieldName1) = 0 THEN ', '+@c_KeyFieldName1 ELSE '' END 
               + CASE WHEN @c_KeyFieldName2 <> '' AND CHARINDEX('PACKDETAIL.CartonNo',@c_KeyFieldName2) = 0 THEN ', '+@c_KeyFieldName2 ELSE '' END 
               + CASE WHEN @c_KeyFieldName3 <> '' AND CHARINDEX('PACKDETAIL.CartonNo',@c_KeyFieldName3) = 0 THEN ', '+@c_KeyFieldName3 ELSE '' END 
               + CASE WHEN @c_KeyFieldName4 <> '' AND CHARINDEX('PACKDETAIL.CartonNo',@c_KeyFieldName4) = 0 THEN ', '+@c_KeyFieldName4 ELSE '' END 
               + CASE WHEN @c_KeyFieldName5 <> '' AND CHARINDEX('PACKDETAIL.CartonNo',@c_KeyFieldName5) = 0 THEN ', '+@c_KeyFieldName5 ELSE '' END 
               + CASE WHEN @c_KeyFieldName6 <> '' AND CHARINDEX('PACKDETAIL.CartonNo',@c_KeyFieldName6) = 0 THEN ', '+@c_KeyFieldName6 ELSE '' END 
               + CASE WHEN @c_KeyFieldName7 <> '' AND CHARINDEX('PACKDETAIL.CartonNo',@c_KeyFieldName7) = 0 THEN ', '+@c_KeyFieldName7 ELSE '' END 
               + CASE WHEN @c_KeyFieldName8 <> '' AND CHARINDEX('PACKDETAIL.CartonNo',@c_KeyFieldName8) = 0 THEN ', '+@c_KeyFieldName8 ELSE '' END 
               + CASE WHEN @c_KeyFieldName9 <> '' AND CHARINDEX('PACKDETAIL.CartonNo',@c_KeyFieldName9) = 0 THEN ', '+@c_KeyFieldName9 ELSE '' END 
               + CASE WHEN @c_KeyFieldName10 <> '' AND CHARINDEX('PACKDETAIL.CartonNo',@c_KeyFieldName10) = 0 THEN ', '+@c_KeyFieldName10 ELSE '' END 
               + CASE WHEN @c_KeyFieldName11 <> '' AND CHARINDEX('PACKDETAIL.CartonNo',@c_KeyFieldName11) = 0 THEN ', '+@c_KeyFieldName11 ELSE '' END 
               + CASE WHEN @c_KeyFieldName12 <> '' AND CHARINDEX('PACKDETAIL.CartonNo',@c_KeyFieldName12) = 0 THEN ', '+@c_KeyFieldName12 ELSE '' END 
               + CASE WHEN @c_KeyFieldName13 <> '' AND CHARINDEX('PACKDETAIL.CartonNo',@c_KeyFieldName13) = 0 THEN ', '+@c_KeyFieldName13 ELSE '' END 
               + CASE WHEN @c_KeyFieldName14 <> '' AND CHARINDEX('PACKDETAIL.CartonNo',@c_KeyFieldName14) = 0 THEN ', '+@c_KeyFieldName14 ELSE '' END 
               + CASE WHEN @c_KeyFieldName15 <> '' AND CHARINDEX('PACKDETAIL.CartonNo',@c_KeyFieldName15) = 0 THEN ', '+@c_KeyFieldName15 ELSE '' END 
   
      IF @c_ExecGroupByStatements <> ''
      BEGIN
         SET @c_ExecStatements = @c_ExecStatements + ' GROUP BY ' + SUBSTRING(@c_ExecGroupByStatements, 2, LEN(@c_ExecGroupByStatements))
      END
   END
   
   SET @c_ExecArguments = '@c_PickSlipNo           NVARCHAR(10)'    
                        + ', @c_StorerKey          NVARCHAR(15)'    
                        + ', @n_CartonNo           INT'  --(AL01)    
                        + ', @n_Exist              INT            OUTPUT'   --(AL01)
                        + ', @c_KeyValue1          NVARCHAR(60)   OUTPUT'    
                        + ', @c_KeyValue2          NVARCHAR(60)   OUTPUT'    
                        + ', @c_KeyValue3          NVARCHAR(60)   OUTPUT'    
                        + ', @c_KeyValue4          NVARCHAR(60)   OUTPUT'    
                        + ', @c_KeyValue5          NVARCHAR(60)   OUTPUT'    
                        + ', @c_KeyValue6          NVARCHAR(60)   OUTPUT'    
                        + ', @c_KeyValue7          NVARCHAR(60)   OUTPUT'    
                        + ', @c_KeyValue8          NVARCHAR(60)   OUTPUT'    
                        + ', @c_KeyValue9          NVARCHAR(60)   OUTPUT'    
                        + ', @c_KeyValue10         NVARCHAR(60)   OUTPUT'    
                        + ', @c_KeyValue11         NVARCHAR(60)   OUTPUT'    
                        + ', @c_KeyValue12         NVARCHAR(60)   OUTPUT'    
                        + ', @c_KeyValue13         NVARCHAR(60)   OUTPUT'    
                        + ', @c_KeyValue14         NVARCHAR(60)   OUTPUT'    
                        + ', @c_KeyValue15         NVARCHAR(60)   OUTPUT'    
   
   IF @b_Debug = 1
   BEGIN
        PRINT ' @c_ExecStatements: ' + @c_ExecStatements
      END
   
   
   EXEC sp_ExecuteSql @c_ExecStatements    
                    , @c_ExecArguments    
                    , @c_PickSlipNo    
                    , @c_StorerKey    
                    , @n_CartonNo   --(AL01)  
                    , @n_Exist               OUTPUT   --(AL01)
                    , @c_KeyValue1           OUTPUT    
                    , @c_KeyValue2           OUTPUT    
                    , @c_KeyValue3           OUTPUT  
                    , @c_KeyValue4           OUTPUT  
                    , @c_KeyValue5           OUTPUT  
                    , @c_KeyValue6           OUTPUT  
                    , @c_KeyValue7           OUTPUT  
                    , @c_KeyValue8           OUTPUT  
                    , @c_KeyValue9           OUTPUT  
                    , @c_KeyValue10          OUTPUT  
                    , @c_KeyValue11          OUTPUT  
                    , @c_KeyValue12          OUTPUT  
                    , @c_KeyValue13          OUTPUT  
                    , @c_KeyValue14          OUTPUT  
                    , @c_KeyValue15          OUTPUT  
   
   IF @b_Debug = 1
   BEGIN
        PRINT ' @n_Exist: ' + CAST(@n_Exist AS NVARCHAR(5)) --(AL01)
        PRINT ' @c_KeyValue1: ' + @c_KeyValue1
        PRINT ' @c_KeyValue2: ' + @c_KeyValue2
        PRINT ' @c_KeyValue3: ' + @c_KeyValue3
        PRINT ' @c_KeyValue4: ' + @c_KeyValue4
        PRINT ' @c_KeyValue5: ' + @c_KeyValue5    
        PRINT ' @c_KeyValue6: ' + @c_KeyValue6
        PRINT ' @c_KeyValue7: ' + @c_KeyValue7
        PRINT ' @c_KeyValue8: ' + @c_KeyValue8
        PRINT ' @c_KeyValue9: ' + @c_KeyValue9
        PRINT ' @c_KeyValue10: ' + @c_KeyValue10
      END

   IF @n_Exist = 0   --(AL01) -S
   BEGIN
      GOTO QUIT
   END   --(AL01) -E
   
   IF @b_Debug = 1
   BEGIN
     PRINT '@c_PrintID: '        + @c_PrintID
     PRINT '@c_ReportID: '       + @c_ReportID
     PRINT '@c_StorerKey: '      + @c_StorerKey
     PRINT '@c_Facility: '       + @c_Facility
     PRINT '@c_UserID: '         + @c_UserID
     PRINT '@c_IsPaperPrinter: ' + @c_IsPaperPrinter
     PRINT '@c_KeyValue1: '      + @c_KeyValue1
     PRINT '@c_KeyValue2: '      + @c_KeyValue2
     PRINT '@c_KeyValue3: '      + @c_KeyValue3
   END
   
   EXEC [WM].[lsp_WM_Print_Report] 
        @c_ModuleID             = N'EPACKING'                -- nvarchar(30)
      , @c_ReportID             = @c_ReportID                -- nvarchar(10)
      , @c_Storerkey            = @c_StorerKey               -- nvarchar(15)
      , @c_Facility             = @c_Facility                -- nvarchar(5)
      , @c_UserName             = @c_UserID                  -- nvarchar(128)
      , @c_ComputerName         = N''                        -- nvarchar(30)
      , @c_PrinterID            = @c_PrintID                 -- nvarchar(30)
      , @n_NoOfCopy             = 1                          -- int
      , @c_IsPaperPrinter       = @c_IsPaperPrinter          -- nchar(1)
      , @c_KeyValue1            = @c_KeyValue1               -- nvarchar(60)
      , @c_KeyValue2            = @c_KeyValue2               -- nvarchar(60)
      , @c_KeyValue3            = @c_KeyValue3               -- nvarchar(60)
      , @c_KeyValue4            = @c_KeyValue4               -- nvarchar(60)
      , @c_KeyValue5            = @c_KeyValue5               -- nvarchar(60)
      , @c_KeyValue6            = @c_KeyValue6               -- nvarchar(60)
      , @c_KeyValue7            = @c_KeyValue7               -- nvarchar(60)
      , @c_KeyValue8            = @c_KeyValue8               -- nvarchar(60)
      , @c_KeyValue9            = @c_KeyValue9               -- nvarchar(60)
      , @c_KeyValue10           = @c_KeyValue10              -- nvarchar(60)
      , @c_KeyValue11           = @c_KeyValue11              -- nvarchar(60)
      , @c_KeyValue12           = @c_KeyValue12              -- nvarchar(60)
      , @c_KeyValue13           = @c_KeyValue13              -- nvarchar(60)
      , @c_KeyValue14           = @c_KeyValue14              -- nvarchar(60)
      , @c_KeyValue15           = @c_KeyValue15              -- nvarchar(60)
      , @c_ExtendedParmValue1   = N''                        -- nvarchar(60)
      , @c_ExtendedParmValue2   = N''                        -- nvarchar(60)
      , @c_ExtendedParmValue3   = N''                        -- nvarchar(60)
      , @c_ExtendedParmValue4   = N''                        -- nvarchar(60)
      , @c_ExtendedParmValue5   = N''                        -- nvarchar(60)
      , @b_Success              = @b_sp_Success    OUTPUT    -- int
      , @n_Err                  = @n_sp_err        OUTPUT    -- int
      , @c_ErrMsg               = @c_sp_errmsg     OUTPUT    -- nvarchar(255)
      , @c_PrintSource          = N'WMReport'                -- nvarchar(10)
      , @b_SCEPreView           = 0                          -- int
      , @c_JobIDs               = @c_JobID         OUTPUT    -- nvarchar(50)
      , @c_AutoPrint            = N'Y'                       -- nvarchar(1)
   
   --IF @b_Debug = 1
   --BEGIN
   --  PRINT '@c_JobID: ' + @c_JobID
   --  PRINT '@b_sp_Success: ' + CAST(@b_sp_Success AS NVARCHAR(10))
   --  PRINT '@c_sp_errmsg: ' + @c_sp_errmsg
   --END
   
   IF @b_sp_Success <> 1
   BEGIN
      SET @n_Continue = 3      
      SET @n_ErrNo = 51900      
      SET @c_ErrMsg = CONVERT(char(5),@n_ErrNo)+': ' 
                    + CONVERT(char(5),@n_sp_err) + ' - ' + @c_sp_errmsg     
      GOTO QUIT  
   END   

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